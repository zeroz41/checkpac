#!/bin/sh

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

Usage: pacheck [options] <search-term>

Options:
    -h, --help     Show this help message
    -r, --remote   Include remote packages in search
    -d, --desc     Search package descriptions (requires expac)

Examples:
    pacheck python         # Search installed packages for "python"
    pacheck -r node       # Search all packages (installed and remote)
    pacheck -d git        # Search names and descriptions
    pacheck -rd docker    # Search everything, everywhere

Note: The -d flag requires 'expac' to be installed for optimal performance.
      Install it with: pacman -S expac
EOF
}

pkgcheck() {
    local search=""
    local check_remote=false
    local search_desc=false
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
            -*)
                if [[ "$1" =~ r ]]; then
                    check_remote=true
                fi
                if [[ "$1" =~ d ]]; then
                    search_desc=true
                fi
                shift
                ;;
            *)
                search="$1"
                shift
                ;;
        esac
    done

    if [ -z "$search" ]; then
        show_help
        return 1
    fi

    echo -e "${COL_BOLD}Searching for packages containing '$search'...${COL_RESET}\n"

    # Track found packages to avoid duplicates
    declare -A found_packages
    declare -A pkg_versions
    declare -A remote_versions

    # Cache common package information
    local all_installed_info=$(pacman -Q)
    local aur_cache=$(pacman -Qm)
    local official_info=$(pacman -Sl)

    # Cache installed package versions
    while IFS=' ' read -r pkg version; do
        pkg_versions[$pkg]=$version
    done <<< "$all_installed_info"

    # Cache official remote versions
    while IFS=' ' read -r repo pkg version rest; do
        remote_versions[$pkg]=$version
    done <<< "$official_info"

    # local official check
    echo -e "${COL_BOLD_CYAN}Official Repositories Installed:${COL_RESET}"
    echo -e "${COL_BLUE}$DIVIDER${COL_RESET}"
    local installed_count=0

    # official repos installed packages
    if [ "$search_desc" = true ] && command -v expac >/dev/null 2>&1; then
        local installed_pkgs=$(expac '%n %d' | grep -i "$search")
    else
        local installed_pkgs=$(echo "$all_installed_info" | grep -i "^${search}")
    fi

    while IFS= read -r line; do
        local pkg=$(echo "$line" | cut -d' ' -f1)
        # Skip AUR
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

    # AUR installed packages
    local found_aur=false
    if [ "$search_desc" = true ] && command -v expac >/dev/null 2>&1; then
        local aur_pkgs=$(expac -Q '%n %d' | grep -i "$search" | grep -f <(echo "$aur_cache" | cut -d' ' -f1))
    else
        local aur_pkgs=$(echo "$aur_cache" | grep -i "^${search}")
    fi

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
            local remote_version=$(yay -Si "$pkg" 2>/dev/null | grep Version | awk '{print $3}')

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

    # remote check if -r flag
    if [ "$check_remote" = true ]; then
        local remote_count=0
        local found_official=false
        local found_remote_aur=false

        # search official and aur
        {
            # Stream official repo results
            if [ "$search_desc" = true ]; then
                # Search with descriptions
                pacman -Ss "$search"
            else
                # Name-only search
                pacman -Slq | grep -i "^${search}$" | while read -r pkg; do
                    pacman -Si "$pkg" 2>/dev/null | grep -E "^Name|^Version" | paste - - | \
                    sed -n 's/Name[[:space:]]*:[[:space:]]*\([^[:space:]]*\).*Version[[:space:]]*:[[:space:]]*\([^[:space:]]*\).*/repo\/\1 \2/p'
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
        } &

        # print aur remote as we get them
        {
            if [ "$search_desc" = true ]; then
                yay -Ssa "$search" 2>/dev/null
            else
                # Use -Ssq for exact match on package names
                yay -Ssq "^${search}$" 2>/dev/null | while read -r pkg; do
                    yay -Si "$pkg" 2>/dev/null | grep -E "^Name|^Version" | paste - - | \
                    sed -n 's/Name[[:space:]]*:[[:space:]]*\([^[:space:]]*\).*Version[[:space:]]*:[[:space:]]*\([^[:space:]]*\).*/aur\/\1 \2/p'
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
