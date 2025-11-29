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
        if echo "$output" | grep -qE "$expect_pattern"; then
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

echo -e "${BOLD}═══════════════════════════════════════${RESET}"
echo -e "${BOLD}CHECKPAC TEST SUITE${RESET}"
echo -e "${BOLD}═══════════════════════════════════════${RESET}"
echo -e "${DIM}Testing: $SCRIPT${RESET}\n"

# Basic tests
echo -e "${YELLOW}── Basic ──${RESET}"
test_run "Help -h" "-h" "Usage:"
test_run "Help --help" "--help" "Usage:"

# Search tests
echo -e "\n${YELLOW}── Search ──${RESET}"
test_run "Official pkg search" "bash" "Official"
test_run "Partial search" "lib" "✔"

# Flag tests
echo -e "\n${YELLOW}── Flags ──${RESET}"
test_run "Description -d" "-d compression" ""
test_run "Exact -e" "-e bash" "bash"
test_run "Remote -r" "-r python" "Available"

# Simple mode
echo -e "\n${YELLOW}── Simple Mode ──${RESET}"
output=$($SCRIPT -s lib 2>&1)
echo -ne "${CYAN}Testing:${RESET} Simple mode no colors... "
if echo "$output" | grep -qP '\x1b\['; then
    echo -e "${RED}FAIL${RESET}"
    FAIL=$((FAIL + 1))
else
    echo -e "${GREEN}PASS${RESET}"
    PASS=$((PASS + 1))
fi

echo -ne "${CYAN}Testing:${RESET} Simple mode no symbols... "
if echo "$output" | grep -qE '[✔✗→▲]|Source:'; then
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
VCS_PKG=$(pacman -Qmq 2>/dev/null | grep -E '-(git|svn|hg|bzr)$' | head -1)
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
