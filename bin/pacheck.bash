#!/bin/bash

#made by zeroz/tj

# pretty sh colors
COL_RESET="\e[0m"
COL_BOLD="\e[1m"
COL_RED="\e[31m"
COL_GREEN="\e[32m"
COL_YELLOW="\e[33m"
COL_BLUE="\e[34m"
COL_CYAN="\e[36m"
COL_BOLD_CYAN="\e[1;36m"
COL_BOLD_YELLOW="\e[1;33m"
COL_BOLD_BLUE="\e[1;34m"

show_help() {
    cat << EOF
pacheck - Search and check status of Arch Linux packages

Usage: pacheck [options] <search-terms...>

Options:
    -h, --help          Show this help message
    -r, --remote        Include remote packages in search
    -d, --desc          Search package descriptions (requires expac)
    -e, --exact         Match package names exactly (case insensitive)
    --exclude-aur       Exclude AUR packages from search results
    --exclude-arch      Exclude official Arch repository packages from search results

Examples:
    pacheck python              # Search installed packages for "python"
    pacheck -r node            # Search all packages (installed and remote)
    pacheck -d git             # Search names and descriptions
    pacheck -rd docker         # Search everything, everywhere
    pacheck -e wine           # Search for exact package name match
    pacheck --exclude-aur git  # Search only in official repositories
    pacheck --exclude-arch git # Search only in AUR

Note: The -d flag requires 'expac' to be installed for optimal performance.
      Install it with: pacman -S expac
      The -e flag overrides -d as exact matching doesn't use descriptions.
EOF
}

pkgcheck() {
    local check_remote=false
    local search_desc=false
    local exact_match=false
    local exclude_aur=false
    local exclude_arch=false
    local search_terms=()
    local CHECK_MARK=$'\u2714'
    local X_MARK=$'\u2718'
    local UP_ARROW=$'\u2191'
    local WARNING=$'\u25B2'
    local DIVIDER="────────────────────────────────────"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                return 0
                ;;
            -r|--remote)
                check_remote=true
                shift
                ;;
            -d|--desc)
                search_desc=true
                shift
                ;;
            -e|--exact)
                exact_match=true
                search_desc=false  # exact match overrides description search
                shift
                ;;
            --exclude-aur)
                exclude_aur=true
                shift
                ;;
            --exclude-arch)
                exclude_arch=true
                shift
                ;;
            -*)
                if [[ "$1" =~ r ]]; then
                    check_remote=true
                fi
                if [[ "$1" =~ d ]]; then
                    search_desc=true
                fi
                if [[ "$1" =~ e ]]; then
                    exact_match=true
                    search_desc=false  # exact match overrides description search
                fi
                shift
                ;;
            *)
                search_terms+=("$1")
                shift
                ;;
        esac
    done

    if [ ${#search_terms[@]} -eq 0 ]; then
        show_help
        return 1
    fi

    echo -e "${COL_BOLD}Searching for packages: ${search_terms[*]}${COL_RESET}\n"

    # avoid duplicates
    declare -A found_packages
    declare -A pkg_versions
    declare -A remote_versions
    declare -A aur_remote_versions

    fetch_aur_versions() {
        local pkgs="$1"
        # Only fetch if we have packages to check and AUR isn't excluded
        if [ -n "$pkgs" ] && [ "$exclude_aur" = false ]; then
            while read -r pkg version; do
                aur_remote_versions[$pkg]=$version
            done < <(echo "$pkgs" | tr ' ' '\n' | xargs -r yay -Si 2>/dev/null | \
                    awk '/^Name/ { name=$3 } /^Version/ { print name " " $3 }')
        fi
    }

    # caching
    local all_installed_info=$(pacman -Q)
    local aur_cache=$(pacman -Qm)
    local official_info=$(pacman -Sl)

    while IFS=' ' read -r pkg version; do
        pkg_versions[$pkg]=$version
    done <<< "$all_installed_info"

    # cache official remote versions
    if [ "$exclude_arch" = false ]; then
        while IFS=' ' read -r repo pkg version rest; do
            remote_versions[$pkg]=$version
        done <<< "$official_info"
    fi

    # local official check
    if [ "$exclude_arch" = false ]; then
        echo -e "${COL_BOLD_CYAN}Official Repositories Installed:${COL_RESET}"
        echo -e "${COL_BLUE}$DIVIDER${COL_RESET}"
        local installed_count=0

        # official repos installed packages
        local installed_pkgs=""
        if [ "$exact_match" = true ]; then
            for term in "${search_terms[@]}"; do
                if [ -n "$installed_pkgs" ]; then
                    installed_pkgs="$installed_pkgs"$'\n'"$(echo "$all_installed_info" | grep -i "^${term} ")"
                else
                    installed_pkgs="$(echo "$all_installed_info" | grep -i "^${term} ")"
                fi
            done
        elif [ "$search_desc" = true ] && command -v expac >/dev/null 2>&1; then
            for term in "${search_terms[@]}"; do
                if [ -n "$installed_pkgs" ]; then
                    installed_pkgs="$installed_pkgs"$'\n'"$(expac '%n %d' | grep -i "$term")"
                else
                    installed_pkgs="$(expac '%n %d' | grep -i "$term")"
                fi
            done
        else
            for term in "${search_terms[@]}"; do
                if [ -n "$installed_pkgs" ]; then
                    installed_pkgs="$installed_pkgs"$'\n'"$(echo "$all_installed_info" | grep -i "$term")"
                else
                    installed_pkgs="$(echo "$all_installed_info" | grep -i "$term")"
                fi
            done
        fi

        # remove duplicates while preserving order
        installed_pkgs=$(echo "$installed_pkgs" | awk '!seen[$0]++')

        while IFS= read -r line; do
            local pkg=$(echo "$line" | cut -d' ' -f1)
            # Skip AUR and empty lines
            if [[ -n "$pkg" ]] && ! echo "$aur_cache" | grep -q "^${pkg} "; then
                installed_count=$((installed_count + 1))
                found_packages[$pkg]=1
                local current_version="${pkg_versions[$pkg]}"
                local remote_version="${remote_versions[$pkg]}"

                echo -e "${COL_GREEN}$CHECK_MARK $pkg${COL_RESET} ${COL_CYAN}(v$current_version)${COL_RESET}"
                echo -e "${COL_BLUE}└─ Source: Official repositories${COL_RESET}"

                if [[ -z "$remote_version" ]]; then
                    echo -e "${COL_YELLOW}   $WARNING Unable to fetch remote version${COL_RESET}"
                elif [[ "$current_version" != "$remote_version" ]]; then
                    echo -e "${COL_YELLOW}   $UP_ARROW Update available: v$remote_version${COL_RESET}"
                else
                    echo -e "${COL_GREEN}   $CHECK_MARK Up to date${COL_RESET}"
                fi
                echo
            fi
        done <<< "$installed_pkgs"

        if [ $installed_count -eq 0 ]; then
            echo -e "${COL_RED}$X_MARK No installed packages found${COL_RESET}\n"
        fi
    fi

    # AUR installed packages
    if [ "$exclude_aur" = false ]; then
        local found_aur=false
        local aur_pkgs=""
        local aur_names=""
        
        if [ "$exact_match" = true ]; then
            for term in "${search_terms[@]}"; do
                if [ -n "$aur_pkgs" ]; then
                    aur_pkgs="$aur_pkgs"$'\n'"$(echo "$aur_cache" | grep -i "^${term} ")"
                else
                    aur_pkgs="$(echo "$aur_cache" | grep -i "^${term} ")"
                fi
            done
        elif [ "$search_desc" = true ] && command -v expac >/dev/null 2>&1; then
            for term in "${search_terms[@]}"; do
                if [ -n "$aur_pkgs" ]; then
                    aur_pkgs="$aur_pkgs"$'\n'"$(expac -Q '%n %d' | grep -i "$term" | grep -f <(echo "$aur_cache" | cut -d' ' -f1))"
                else
                    aur_pkgs="$(expac -Q '%n %d' | grep -i "$term" | grep -f <(echo "$aur_cache" | cut -d' ' -f1))"
                fi
            done
        else
            for term in "${search_terms[@]}"; do
                if [ -n "$aur_pkgs" ]; then
                    aur_pkgs="$aur_pkgs"$'\n'"$(echo "$aur_cache" | grep -i "$term")"
                else
                    aur_pkgs="$(echo "$aur_cache" | grep -i "$term")"
                fi
            done
        fi

        # Remove duplicates while preserving order
        aur_pkgs=$(echo "$aur_pkgs" | awk '!seen[$0]++')
        
        # Extract package names for bulk version fetching
        aur_names=$(echo "$aur_pkgs" | cut -d' ' -f1 | tr '\n' ' ')
        
        # Fetch all AUR versions in one go
        fetch_aur_versions "$aur_names"

        while IFS= read -r line; do
            local pkg=$(echo "$line" | cut -d' ' -f1)
            if [[ -n "$pkg" ]]; then
                if [[ "$found_aur" == false ]]; then
                    echo -e "${COL_YELLOW}$DIVIDER${COL_RESET}"
                    echo -e "${COL_BOLD_YELLOW}AUR Installed:${COL_RESET}"
                    found_aur=true
                fi
                installed_count=$((installed_count + 1))
                found_packages[$pkg]=1
                local current_version="${pkg_versions[$pkg]}"
                local remote_version="${aur_remote_versions[$pkg]}"

                echo -e "${COL_GREEN}$CHECK_MARK $pkg${COL_RESET} ${COL_CYAN}(v$current_version)${COL_RESET}"
                echo -e "${COL_YELLOW}└─ Source: AUR${COL_RESET}"

                if [[ -z "$remote_version" ]]; then
                    echo -e "${COL_YELLOW}   $WARNING Unable to fetch remote version${COL_RESET}"
                elif [[ "$current_version" != "$remote_version" ]]; then
                    echo -e "${COL_YELLOW}   $UP_ARROW Update available: v$remote_version${COL_RESET}"
                else
                    echo -e "${COL_GREEN}   $CHECK_MARK Up to date${COL_RESET}"
                fi
                echo
            fi
        done <<< "$aur_pkgs"
    fi

    # remote check if -r flag
    if [ "$check_remote" = true ]; then
        local remote_count=0
        local found_official=false
        local found_remote_aur=false

        # search official and aur
        {
            # stream official repo results if not excluded
            if [ "$exclude_arch" = false ]; then
                if [ "$exact_match" = true ]; then
                    for term in "${search_terms[@]}"; do
                        pacman -Sl | grep -i "^[^ ]* ${term}$" | while read -r repo pkg version rest; do
                            echo "repo/$pkg $version"
                        done
                    done
                elif [ "$search_desc" = true ]; then
                    for term in "${search_terms[@]}"; do
                        pacman -Ss "$term"
                    done
                else
                    for term in "${search_terms[@]}"; do
                        pacman -Sl | grep -i "$term" | while read -r repo pkg version rest; do
                            echo "repo/$pkg $version"
                        done
                    done
                fi | while IFS= read -r line; do
                    if [[ -n "$line" ]] && [[ $line =~ ^[^\ ] ]]; then
                        local pkg=$(echo "$line" | cut -d'/' -f2 | cut -d' ' -f1)
                        local version=$(echo "$line" | cut -d' ' -f2)
                        if [[ -n "$pkg" ]] && [[ -z "${found_packages[$pkg]}" ]]; then
                            if [[ "$found_official" == false ]]; then
                                echo -e "${COL_BLUE}$DIVIDER${COL_RESET}"
                                echo -e "${COL_BOLD_BLUE}Official Repositories Available:${COL_RESET}"
                                found_official=true
                            fi
                            remote_count=$((remote_count + 1))
                            found_packages[$pkg]=1
                            echo -e "${COL_RED}$X_MARK $pkg${COL_RESET} ${COL_CYAN}(v$version)${COL_RESET}"
                            echo -e "${COL_BLUE}└─ Available in official repositories${COL_RESET}"
                            echo
                        fi
                    fi
                done
            fi
        } &

        # print aur remote if not excluded
        if [ "$exclude_aur" = false ]; then
            {
                if [ "$exact_match" = true ]; then
                    for term in "${search_terms[@]}"; do
                        yay -Ss "^$term$" 2>/dev/null | grep -E "^aur/" | cut -d'/' -f2- | grep -Ev "^[[:space:]]" | while read -r line; do
                            pkg=$(echo "$line" | cut -d' ' -f1)
                            version=$(echo "$line" | cut -d' ' -f2)
                            echo "aur/$pkg $version"
                        done
                    done
                elif [ "$search_desc" = true ]; then
                    for term in "${search_terms[@]}"; do
                        yay -Ssa "$term" 2>/dev/null
                    done
                else
                    for term in "${search_terms[@]}"; do
                        yay -Ss "$term" 2>/dev/null | grep -E "^aur/" | grep -i "$term" | while read -r line; do
                        pkg=$(echo "$line" | cut -d'/' -f2 | cut -d' ' -f1)
                            version=$(echo "$line" | cut -d' ' -f2)
                            echo "aur/$pkg $version"
                        done
                    done
                fi | while IFS= read -r line; do
                    if [[ $line =~ ^aur/ ]]; then
                        local pkg=$(echo "$line" | cut -d'/' -f2 | cut -d' ' -f1)
                        local version=$(echo "$line" | cut -d' ' -f2)
                        if [[ -n "$pkg" ]] && [[ -z "${found_packages[$pkg]}" ]]; then
                            if [[ "$found_remote_aur" == false ]]; then
                                echo -e "${COL_YELLOW}$DIVIDER${COL_RESET}"
                                echo -e "${COL_BOLD_YELLOW}AUR Available:${COL_RESET}"
                                found_remote_aur=true
                            fi
                            remote_count=$((remote_count + 1))
                            found_packages[$pkg]=1
                            echo -e "${COL_RED}$X_MARK $pkg${COL_RESET} ${COL_CYAN}(v$version)${COL_RESET}"
                            echo -e "${COL_YELLOW}└─ Available in AUR${COL_RESET}"
                            echo
                        fi
                    fi
                done
            } &
        fi

        # wait for background processes
        wait

        if [ $remote_count -eq 0 ]; then
            echo -e "${COL_RED}$X_MARK No additional packages found in repositories${COL_RESET}"
        fi
    fi
}

# run
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    pkgcheck "$@"
fi