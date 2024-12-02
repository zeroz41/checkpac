#!/bin/bash

#made by zeroz/tj

#dependencies:
#pacman,expac
#optdepends:
#yay

# pretty sh colors
COL_RESET="\e[0m"
COL_BOLD="\e[1m"
COL_RED="\e[31m"
COL_GREEN="\e[32m"
COL_YELLOW="\e[33m"
COL_BLUE="\e[34m"
COL_CYAN="\e[36m"
COL_MAGENTA="\e[35m"
COL_BOLD_CYAN="\e[1;36m"
COL_BOLD_YELLOW="\e[1;33m"
COL_BOLD_BLUE="\e[1;34m"

# Function to get package repo type and color
get_repo_type() {
    local pkg=$1
    local repo_type=$(pacman -Si "$pkg" 2>/dev/null | grep "Repository" | awk '{print $3}')
    
    case "$repo_type" in
        "core") echo -e "${COL_RED}core${COL_RESET}";;
        "extra") echo -e "${COL_GREEN}extra${COL_RESET}";;
        "community") echo -e "${COL_MAGENTA}community${COL_RESET}";;
        *) echo "";;
    esac
}

# generate a hash for repos color based on it's name. If its unique...
get_hash_color() {
    local str=$1
    local hash=$(echo -n "$str" | md5sum | cut -d' ' -f1)
    local r=$((0x${hash:0:2}))
    local g=$((0x${hash:2:2}))
    local b=$((0x${hash:4:2}))
    # Ensure minimum brightness for readability
    r=$(( (r + 128) % 256 ))
    g=$(( (g + 128) % 256 ))
    b=$(( (b + 128) % 256 ))
    echo "\e[38;2;${r};${g};${b}m"
}

# get package repo type and color
get_repo_type() {
    local pkg=$1
    local repo_info=$(pacman -Si "$pkg" 2>/dev/null | grep "Repository" | awk '{print $3}')
    
    case "$repo_info" in
        "core") echo -e "${COL_RED}core${COL_RESET}";;
        "extra") echo -e "${COL_GREEN}extra${COL_RESET}";;
        "community") echo -e "${COL_MAGENTA}community${COL_RESET}";;
        "multilib") echo -e "${COL_CYAN}multilib${COL_RESET}";;
        "testing") echo -e "${COL_YELLOW}testing${COL_RESET}";;
        "community-testing") echo -e "\e[38;2;255;165;0mcommunity-testing${COL_RESET}";; # orange
        "extra-testing") echo -e "\e[38;2;138;43;226mextra-testing${COL_RESET}";; # blueviolet
        "multilib-testing") echo -e "\e[38;2;219;112;147mmultilib-testing${COL_RESET}";; # palevioletred
        "")
            # Try to get repo from pacman -Sl for installed packages
            local repo=$(pacman -Sl | grep " $pkg " | cut -d' ' -f1 | head -n1)
            if [ -n "$repo" ]; then
                # Use hash-based color for unknown repos
                local color=$(get_hash_color "$repo")
                echo -e "${color}${repo}${COL_RESET}"
            else
                echo ""
            fi
            ;;
        *)
            # Use hash-based color for unknown repos
            local color=$(get_hash_color "$repo_info")
            echo -e "${color}${repo_info}${COL_RESET}"
            ;;
    esac
}

# semantic versioning comparison for color coding
compare_versions() {
    local current=$1
    local remote=$2
    
    # remove epoch and release suffix
    current=$(echo "$current" | sed 's/^[0-9]*://' | sed 's/-[^-]*$//')
    remote=$(echo "$remote" | sed 's/^[0-9]*://' | sed 's/-[^-]*$//')
    
    # split
    IFS='.' read -ra current_parts <<< "$current"
    IFS='.' read -ra remote_parts <<< "$remote"
    
    local output=""
    local different=false
    local max_parts=$(( ${#current_parts[@]} > ${#remote_parts[@]} ? ${#current_parts[@]} : ${#remote_parts[@]} ))
    
    for (( i=0; i<max_parts; i++ )); do
        local curr_part=${current_parts[$i]:-0}
        local rem_part=${remote_parts[$i]:-0}
        
        # dont use for compare
        local curr_num=$(echo "$curr_part" | sed 's/[^0-9].*//')
        local rem_num=$(echo "$rem_part" | sed 's/[^0-9].*//')
        
        if [ "$different" = true ]; then
            output+="${COL_RED}${curr_part}${COL_RESET}"
        elif [ "$curr_num" -lt "$rem_num" ]; then
            output+="${COL_RED}${curr_part}${COL_RESET}"
            different=true
        elif [ "$curr_num" -gt "$rem_num" ]; then
            output+="${COL_GREEN}${curr_part}${COL_RESET}"
            different=true
        else
            output+="$curr_part"
        fi
        
        # Add separator if not last part
        if [ $i -lt $(( max_parts - 1 )) ]; then
            output+="."
        fi
    done

    # Add back release suffix if present
    if [[ $1 =~ -[0-9]+ ]]; then
        local suffix=$(echo "$1" | grep -o -- '-[0-9]\+')
        if [[ $different == true ]]; then
            output+="${COL_RED}${suffix}${COL_RESET}"
        else
            local curr_rel=$(echo "$1" | grep -o '[0-9]\+$')
            local rem_rel=$(echo "$2" | grep -o '[0-9]\+$')
            if [ "$curr_rel" -lt "$rem_rel" ]; then
                output+="${COL_RED}${suffix}${COL_RESET}"
            elif [ "$curr_rel" -gt "$rem_rel" ]; then
                output+="${COL_GREEN}${suffix}${COL_RESET}"
            else
                output+="$suffix"
            fi
        fi
    fi
    
    echo "$output"
}

test_version_compare() {
    echo "Testing version comparison..."
    local test_cases=(
        "1.60.0 1.64.0"
        "5.116.0-1 5.116.0-2"
        "1.11.0-1 1.11.1-1"
        "0.21.5-1 0.21.5-2"
    )

    for test in "${test_cases[@]}"; do
        read -r v1 v2 <<< "$test"
        echo -e "\nComparing $v1 -> $v2:"
        echo -e "Current: $(compare_versions "$v1" "$v2")"
        echo -e "Remote:  $(compare_versions "$v2" "$v1")"
    done
    exit 0
}

#testing only
#test_version_compare

show_help() {
    local script_name=$(basename "$0")
    cat << EOF
${script_name} - Search and check status of Arch Linux packages

Usage: ${script_name} [options] <search-terms...>

Options:
    -h, --help          Show this help message
    -r, --remote        Include remote packages in search
    -d, --desc          Search package descriptions (requires expac)
    -e, --exact         Match package names exactly (case insensitive)
    --exclude-aur       Exclude AUR packages from search results
    --exclude-arch      Exclude official repository packages from search results

Examples:
    ${script_name} python              # Search installed packages for "python"
    ${script_name} -r node             # Search all packages (installed and remote)
    ${script_name} -d git              # Search names and descriptions
    ${script_name} -rd docker          # Search everything, everywhere
    ${script_name} -e wine             # Search for exact package name match
    ${script_name} --exclude-aur git   # Search only in official repositories
    ${script_name} --exclude-arch git  # Search only in AUR

Note:
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
                local repo_type=$(get_repo_type "$pkg")

                echo -e "${COL_GREEN}$CHECK_MARK $pkg${COL_RESET} ${COL_CYAN}(v$current_version)${COL_RESET}"
                echo -e "${COL_BLUE}└─ Source: Official repositories [${COL_RESET}${repo_type}${COL_BLUE}]${COL_RESET}"
                if [[ -z "$remote_version" ]]; then
                    echo -e "${COL_YELLOW}   $WARNING Unable to fetch remote version${COL_RESET}"
                elif [[ "$current_version" != "$remote_version" ]]; then
                    local colored_current=$(compare_versions "$current_version" "$remote_version")
                    local colored_remote=$(compare_versions "$remote_version" "$current_version")
                    echo -e "   ${COL_YELLOW}$UP_ARROW Update available: ${COL_RESET}v$colored_current -> v$colored_remote"
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

                # dev package? (-git, -svn, etc.)
                if [[ "$pkg" =~ -(git|svn|hg|bzr|cvs)$ ]]; then
                    local pkg_type="${COL_CYAN}devel${COL_RESET}"
                else
                    local pkg_type="${COL_YELLOW}aur${COL_RESET}"
                fi

                # colored version strings
                local colored_current=$(compare_versions "$current_version" "$remote_version")
                local colored_remote=$(compare_versions "$remote_version" "$current_version")

                echo -e "${COL_GREEN}$CHECK_MARK $pkg${COL_RESET} ${COL_CYAN}(v$current_version)${COL_RESET}"
                echo -e "${COL_YELLOW}└─ Source: AUR [${COL_RESET}${pkg_type}${COL_YELLOW}]${COL_RESET}"
                if [[ -z "$remote_version" ]]; then
                    echo -e "${COL_YELLOW}   $WARNING Unable to fetch remote version${COL_RESET}"
                elif [[ "$current_version" != "$remote_version" ]]; then
                    echo -e "   ${COL_YELLOW}$UP_ARROW${COL_RESET} Update available: v$colored_current -> v$colored_remote"
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
                            local repo_type=$(get_repo_type "$pkg")
                            echo -e "${COL_RED}$X_MARK $pkg${COL_RESET} ${COL_CYAN}(v$version)${COL_RESET}"
                            echo -e "${COL_BLUE}└─ Available in official repositories [${COL_RESET}${repo_type}${COL_BLUE}]${COL_RESET}"
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
                            
                            # check if dev package (-git, -svn, etc.)
                            if [[ "$pkg" =~ -(git|svn|hg|bzr|cvs)$ ]]; then
                                local pkg_type="${COL_CYAN}devel${COL_RESET}"
                            else
                                local pkg_type="${COL_YELLOW}aur${COL_RESET}"
                            fi

                            echo -e "${COL_RED}$X_MARK $pkg${COL_RESET} ${COL_CYAN}(v$version)${COL_RESET}"
                            echo -e "${COL_YELLOW}└─ Available in AUR [${COL_RESET}${pkg_type}${COL_YELLOW}]${COL_RESET}"
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

main() {
    # check for yay
    if ! pacman -Qi yay &>/dev/null; then
        echo -e "\e[33mWarning: 'yay' is not installed. AUR functionality will be disabled.\e[0m"
        # If no yay, turn on exclude aur flag if not already present
        if [[ ! " $@ " =~ " --exclude-aur " ]]; then
            pkgcheck "$@" --exclude-aur
        else
            pkgcheck "$@"
        fi
    else
        # yay is installed, run normally
        pkgcheck "$@"
    fi
}

main "$@"
                