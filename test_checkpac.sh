#!/bin/bash

# Test script for checkpac
# Usage: ./test_checkpac.sh [path-to-checkpac]

SCRIPT="${1:-./bin/checkpac}"

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

PASS=0
FAIL=0
SKIP=0

test_run() {
    local name="$1"
    local cmd="$2"
    local expect_pattern="$3"
    local should_match="${4:-true}"
    
    echo -ne "${CYAN}Testing:${RESET} $name... "
    
    local output
    output=$(timeout 15 $SCRIPT $cmd 2>&1)
    local code=$?
    
    if [ $code -eq 124 ]; then
        echo -e "${RED}TIMEOUT${RESET}"
        FAIL=$((FAIL + 1))
        return
    fi
    
    if [ -n "$expect_pattern" ]; then
        if grep -qE "$expect_pattern" <<< "$output"; then
            if [ "$should_match" = "true" ]; then
                echo -e "${GREEN}PASS${RESET}"
                PASS=$((PASS + 1))
            else
                echo -e "${RED}FAIL${RESET} (unexpected match)"
                FAIL=$((FAIL + 1))
            fi
        else
            if [ "$should_match" = "false" ]; then
                echo -e "${GREEN}PASS${RESET}"
                PASS=$((PASS + 1))
            else
                echo -e "${RED}FAIL${RESET} (pattern not found)"
                FAIL=$((FAIL + 1))
            fi
        fi
    else
        echo -e "${GREEN}PASS${RESET}"
        PASS=$((PASS + 1))
    fi
}

test_value() {
    local name="$1"
    local actual="$2"
    local expected="$3"

    echo -ne "${CYAN}Testing:${RESET} $name... "
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${RESET}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${RESET}"
        echo "  expected: $expected"
        echo "  actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

echo -e "${BOLD}═══════════════════════════════════════${RESET}"
echo -e "${BOLD}CHECKPAC TEST SUITE${RESET}"
echo -e "${BOLD}═══════════════════════════════════════${RESET}"
echo -e "${DIM}Testing: $SCRIPT${RESET}\n"

# Basic tests
echo -e "${YELLOW}── Basic ──${RESET}"
test_run "Help -h" "-h" "Usage:"
test_run "Help --help" "--help" "Usage:"

# Deterministic helper tests
echo -e "\n${YELLOW}── Metadata and Ranking ──${RESET}"
if [ -r "$SCRIPT" ]; then
    # The executable guard in checkpac makes its helpers safe to source.
    source "$SCRIPT"
    set +o pipefail

    CHECKPAC_NOW=100000000
    test_value "Age under one minute" "$(format_age 99999970)" "just now"
    test_value "Age singular" "$(format_age 99996400)" "1 hour ago"
    test_value "Age plural" "$(format_age 99827200)" "2 days ago"
    test_value "Age in months" "$(format_age 94740400)" "2 months ago"

    search_terms=(foo)
    aur_popularity=([foo]=0.1 [foobar]=2 [foo-old]=2 [xfoo]=10)
    aur_votes=([foo]=1 [foobar]=20 [foo-old]=10 [xfoo]=999)
    ranking=$(sort_aur_package_names xfoo foo-old foo foobar)
    test_value "Exact, popularity, and vote ranking" "$ranking" $'foo\nfoobar\nfoo-old\nxfoo'
    unset CHECKPAC_NOW
else
    echo -e "${YELLOW}SKIP${RESET} - Script is not readable for helper tests"
    SKIP=$((SKIP + 5))
fi

# Search tests
echo -e "\n${YELLOW}── Search ──${RESET}"
test_run "Official pkg search" "bash" "Official"
test_run "Partial search" "lib" "✔"

# Flag tests
echo -e "\n${YELLOW}── Flags ──${RESET}"
test_run "Description -d" "-d compression" ""
test_run "Exact -e" "-e bash" "bash"
mapfile -t REMOTE_PACKAGES < <(comm -23 \
    <(expac -S '%n' 2>/dev/null | LC_ALL=C sort) \
    <(pacman -Qq 2>/dev/null | LC_ALL=C sort))
REMOTE_PKG=${REMOTE_PACKAGES[0]:-}
if [ -n "$REMOTE_PKG" ]; then
    test_run "Remote -r" "-re --exclude-aur $REMOTE_PKG" "Available"
else
    echo -e "${YELLOW}SKIP${RESET} - No uninstalled official package"
    SKIP=$((SKIP + 1))
fi

# Simple mode
echo -e "\n${YELLOW}── Simple Mode ──${RESET}"
output=$($SCRIPT -s lib 2>&1)
echo -ne "${CYAN}Testing:${RESET} Simple mode no colors... "
if grep -qP '\x1b\[' <<< "$output"; then
    echo -e "${RED}FAIL${RESET}"
    FAIL=$((FAIL + 1))
else
    echo -e "${GREEN}PASS${RESET}"
    PASS=$((PASS + 1))
fi

echo -ne "${CYAN}Testing:${RESET} Simple mode no symbols... "
if grep -qE '[✔✗→▲]|Source:' <<< "$output"; then
    echo -e "${RED}FAIL${RESET}"
    FAIL=$((FAIL + 1))
else
    echo -e "${GREEN}PASS${RESET}"
    PASS=$((PASS + 1))
fi

# Combined flags
echo -e "\n${YELLOW}── Combined Flags ──${RESET}"
test_run "Combined -rd" "-rd editor" ""
test_run "Combined -rs" "-rs lib" ""
test_run "Combined -re" "-re git" ""

# AUR tests
echo -e "\n${YELLOW}── AUR/Local ──${RESET}"
AUR_PKG=$(pacman -Qmq 2>/dev/null | head -1)
if [ -n "$AUR_PKG" ]; then
    test_run "AUR section header" "$AUR_PKG" "AUR/Local Installed:"
    test_run "AUR source shown" "$AUR_PKG" "Source:"
else
    echo -e "${YELLOW}SKIP${RESET} - No AUR packages"
    SKIP=$((SKIP + 2))
fi

# Local package detection
echo -e "\n${YELLOW}── Local Detection ──${RESET}"
if pacman -Q my-untracked-test-pkg &>/dev/null; then
    test_run "Local pkg detected" "my-untracked-test-pkg" "Source: Local"
    test_run "Local not AUR" "my-untracked-test-pkg" "Source: AUR" false
else
    echo -e "${YELLOW}SKIP${RESET} - my-untracked-test-pkg not installed"
    SKIP=$((SKIP + 2))
fi

# VCS packages
echo -e "\n${YELLOW}── VCS Packages ──${RESET}"
VCS_PKG=$(pacman -Qmq 2>/dev/null | grep -E -- '-(git|svn|hg|bzr)$' | head -1)
if [ -n "$VCS_PKG" ]; then
    test_run "VCS shows devel" "$VCS_PKG" "devel"
else
    echo -e "${YELLOW}SKIP${RESET} - No VCS packages"
    SKIP=$((SKIP + 1))
fi

# Version highlighting test
echo -e "\n${YELLOW}── Version Highlighting ──${RESET}"
OUTDATED=$(pacman -Qu 2>/dev/null | head -1 | cut -d' ' -f1)
if [ -n "$OUTDATED" ]; then
    test_run "Update shows arrow" "$OUTDATED" "→"
    test_run "Update has versions" "$OUTDATED" "Update:"
else
    echo -e "${YELLOW}SKIP${RESET} - No outdated packages"
    SKIP=$((SKIP + 2))
fi

# Exhaustive flag matrix with deterministic package and AUR fixtures.
echo -e "\n${YELLOW}── All Flag Combinations ──${RESET}"

pacman() {
    case "$1" in
        -Q)
            printf '%s\n' 'pkg 1.0-1' 'pkg-aur-installed 1.0-1'
            ;;
        -Qm)
            printf '%s\n' 'pkg-aur-installed 1.0-1'
            ;;
    esac
}

expac() {
    case "$1" in
        -S)
            printf 'pkg\t1.0-1\tcore\t99900000\tFIXTURE_OFFICIAL_INSTALLED needle\n'
            printf 'pkg-official-remote\t2.0-1\textra\t99800000\tFIXTURE_OFFICIAL_REMOTE needle\n'
            ;;
        -Q)
            printf '%s\n' 'FIXTURE_AUR_INSTALLED needle'
            ;;
    esac
}

curl() {
    local url=${!#}

    if [[ "$url" == *'/rpc/v5/info'* ]]; then
        printf '%s\n' '{"type":"multiinfo","resultcount":1,"results":[{"Name":"pkg-aur-installed","Version":"1.0-1","Description":"FIXTURE_AUR_INSTALLED needle","LastModified":99700000,"Popularity":1.5,"NumVotes":5}]}'
    else
        printf '%s\n' '{"type":"search","resultcount":1,"results":[{"Name":"pkg-aur-remote","Version":"2.0-1","Description":"FIXTURE_AUR_REMOTE needle","LastModified":99600000,"Popularity":2.5,"NumVotes":10}]}'
    fi
}

export -f pacman expac curl

fixture_has_package() {
    local output=$1
    local package=$2
    local plain
    plain=$(sed $'s/\033\\[[0-9;]*m//g' <<< "$output")
    grep -Eq "^(✔ |✘ )?${package}([[:space:](]|$)" <<< "$plain"
}

test_flag_matrix_case() {
    local mask=$1
    local letters=""
    local -a args=()
    local -a order=(r d e s)
    local -A bits=([r]=1 [d]=2 [e]=4 [s]=8)
    local flag

    # Alternate order so compact flags are tested in both directions.
    [ $((mask % 2)) -eq 1 ] && order=(s e d r)
    for flag in "${order[@]}"; do
        [ $((mask & bits[$flag])) -ne 0 ] && letters+="$flag"
    done
    [ -n "$letters" ] && args+=("-$letters")
    [ $((mask & 16)) -ne 0 ] && args+=(--exclude-aur)
    [ $((mask & 32)) -ne 0 ] && args+=(--exclude-arch)
    args+=(pkg)

    local output code=0
    output=$(timeout 5 bash "$SCRIPT" "${args[@]}" 2>&1) || code=$?

    local remote=$((mask & 1))
    local exact=$((mask & 4))
    local simple=$((mask & 8))
    local include_aur=$((!(mask & 16)))
    local include_arch=$((!(mask & 32)))
    local -A expected=(
        [pkg]=$include_arch
        [pkg-aur-installed]=$((include_aur && !exact))
        [pkg-official-remote]=$((remote && include_arch && !exact))
        [pkg-aur-remote]=$((remote && include_aur && !exact))
    )
    local package found errors=""

    [ "$code" -ne 0 ] && errors+=" exit=$code"
    for package in pkg pkg-aur-installed pkg-official-remote pkg-aur-remote; do
        found=0
        fixture_has_package "$output" "$package" && found=1
        if [ "$found" -ne "${expected[$package]}" ]; then
            errors+=" $package(expected=${expected[$package]},actual=$found)"
        fi
    done

    if [ "$simple" -ne 0 ] && grep -qP '\x1b\[' <<< "$output"; then
        errors+=" simple-output-has-colors"
    fi

    printf "${CYAN}Testing:${RESET} flag matrix %02d... " "$mask"
    if [ -z "$errors" ]; then
        echo -e "${GREEN}PASS${RESET}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${RESET}$errors"
        echo "  args: ${args[*]}"
        echo "  output:"
        sed 's/^/    /' <<< "$output"
        FAIL=$((FAIL + 1))
    fi
}

test_fixture_packages() {
    local name=$1
    local expected=$2
    shift 2

    local output code=0 package actual=""
    output=$(timeout 5 bash "$SCRIPT" "$@" 2>&1) || code=$?
    for package in pkg pkg-aur-installed pkg-official-remote pkg-aur-remote; do
        fixture_has_package "$output" "$package" && actual+=" $package"
    done
    actual=${actual# }

    echo -ne "${CYAN}Testing:${RESET} $name... "
    if [ "$code" -eq 0 ] && [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${RESET}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${RESET}"
        echo "  expected: $expected"
        echo "  actual:   $actual (exit $code)"
        FAIL=$((FAIL + 1))
    fi
}

for ((mask = 0; mask < 64; mask++)); do
    test_flag_matrix_case "$mask"
done

test_fixture_packages "Description search" \
    "pkg pkg-aur-installed" -d needle
test_fixture_packages "Remote description search" \
    "pkg pkg-aur-installed pkg-official-remote pkg-aur-remote" -rd needle
test_fixture_packages "Exact overrides compact -de" "" -de needle
test_fixture_packages "Exact overrides compact -ed" "" -ed needle
test_fixture_packages "Exact overrides separate -d -e" "" -d -e needle
test_fixture_packages "Exact overrides separate -e -d" "" -e -d needle
test_fixture_packages "Long option aliases" \
    "pkg pkg-aur-installed pkg-official-remote pkg-aur-remote" \
    --remote --desc --simple needle
test_fixture_packages "Long --exact" "pkg" --exact pkg
test_fixture_packages "Long --exclude-aur" "pkg" --exclude-aur pkg
test_fixture_packages "Long --exclude-arch" "pkg-aur-installed" --exclude-arch pkg
test_fixture_packages "Flags after search term" \
    "pkg pkg-aur-installed pkg-official-remote pkg-aur-remote" pkg -rs

unset -f pacman expac curl fixture_has_package

# Summary
echo -e "\n${BOLD}═══════════════════════════════════════${RESET}"
echo -e "${GREEN}Passed:${RESET} $PASS"
echo -e "${RED}Failed:${RESET} $FAIL"
echo -e "${YELLOW}Skipped:${RESET} $SKIP"

if [ $FAIL -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}All tests passed!${RESET}"
    exit 0
else
    echo -e "\n${RED}${BOLD}Some tests failed${RESET}"
    exit 1
fi
