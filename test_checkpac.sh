#!/bin/bash

# Test script for pacheck - tests all flag combinations and paths
# Run with: ./test_pacheck.sh [quick|full|interactive]

# Colors for output
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"
BOLD="\e[1m"

# Test configuration
SCRIPT_PATH="./bin/checkpac"  # Adjust if your script is elsewhere
TEST_MODE="${1:-quick}"   # quick, full, or interactive
TIMEOUT_SECONDS=25        # Timeout for each test

# Test packages (adjust based on your system)
# Using common packages likely to be found
INSTALLED_PKG="bash"           # Almost always installed
PARTIAL_NAME="lib"             # Common partial match
AUR_PKG="yay"                 # Common AUR helper
EXACT_PKG="git"               # For exact match testing
DESC_KEYWORD="compression"     # Common in descriptions
NONEXISTENT="zzz-nonexistent-pkg-xxx"

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Test results array
declare -a TEST_RESULTS

# Function to print test header
print_header() {
    echo -e "\n${BOLD}${BLUE}════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}PACHECK TEST SUITE - $TEST_MODE MODE${RESET}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════${RESET}\n"
}

# Function to print test section
print_section() {
    echo -e "\n${BOLD}${YELLOW}──────────────────────────────────────────${RESET}"
    echo -e "${BOLD}${YELLOW}► $1${RESET}"
    echo -e "${BOLD}${YELLOW}──────────────────────────────────────────${RESET}"
}

# Function to run a single test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expect_output="${3:-true}"  # Whether we expect output
    local timeout_override="${4:-$TIMEOUT_SECONDS}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -ne "${CYAN}Testing:${RESET} $test_name... "
    
    # Run the command with timeout
    local output_file=$(mktemp)
    local error_file=$(mktemp)
    
    if [ "$TEST_MODE" = "interactive" ]; then
        echo -e "\n${BLUE}Command:${RESET} $SCRIPT_PATH $test_cmd"
        read -p "Press Enter to run (or 's' to skip): " response
        if [ "$response" = "s" ]; then
            echo -e "${YELLOW}SKIPPED${RESET}"
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            rm -f "$output_file" "$error_file"
            return
        fi
    fi
    
    # Execute with timeout
    timeout "$timeout_override" bash -c "$SCRIPT_PATH $test_cmd" > "$output_file" 2> "$error_file"
    local exit_code=$?
    
    # Check results
    local output=$(cat "$output_file")
    local errors=$(cat "$error_file")
    local output_lines=$(wc -l < "$output_file")
    
    if [ $exit_code -eq 124 ]; then
        echo -e "${RED}TIMEOUT${RESET} (exceeded ${timeout_override}s)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("FAIL: $test_name - Timeout")
    elif [ $exit_code -ne 0 ] && [ "$test_cmd" != "--help" ] && [ "$test_cmd" != "-h" ]; then
        echo -e "${RED}FAILED${RESET} (exit code: $exit_code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("FAIL: $test_name - Exit code $exit_code")
        [ -n "$errors" ] && echo -e "  ${RED}Error:${RESET} $(echo "$errors" | head -1)"
    elif [ "$expect_output" = "true" ] && [ $output_lines -lt 3 ]; then
        echo -e "${YELLOW}WARNING${RESET} (minimal output: $output_lines lines)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TEST_RESULTS+=("WARN: $test_name - Minimal output")
    else
        echo -e "${GREEN}PASSED${RESET} (${output_lines} lines)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TEST_RESULTS+=("PASS: $test_name")
    fi
    
    # Show sample output in verbose mode
    if [ "$TEST_MODE" = "full" ] || [ "$TEST_MODE" = "interactive" ]; then
        if [ $output_lines -gt 0 ]; then
            echo -e "  ${BLUE}Sample output:${RESET}"
            head -3 "$output_file" | sed 's/^/    /'
            [ $output_lines -gt 3 ] && echo "    ..."
        fi
    fi
    
    rm -f "$output_file" "$error_file"
}

# Function to test interrupt handling
test_interrupt() {
    echo -ne "${CYAN}Testing:${RESET} Interrupt handling (Ctrl+C)... "
    
    local output_file=$(mktemp)
    
    # Start the command in background
    timeout 5 bash -c "$SCRIPT_PATH -r lib" > "$output_file" 2>&1 &
    local pid=$!
    
    # Give it a moment to start
    sleep 1
    
    # Send interrupt signal
    kill -INT $pid 2>/dev/null
    
    # Wait a bit
    sleep 0.5
    
    # Check if process terminated
    if ! kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}PASSED${RESET} (process terminated cleanly)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TEST_RESULTS+=("PASS: Interrupt handling")
    else
        # Force kill if still running
        kill -9 $pid 2>/dev/null
        echo -e "${RED}FAILED${RESET} (process didn't terminate)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("FAIL: Interrupt handling")
    fi
    
    rm -f "$output_file"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Function to print summary
print_summary() {
    echo -e "\n${BOLD}${BLUE}════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}TEST SUMMARY${RESET}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════${RESET}"
    
    echo -e "${BOLD}Total Tests:${RESET}    $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${RESET}         $PASSED_TESTS"
    echo -e "${RED}Failed:${RESET}         $FAILED_TESTS"
    echo -e "${YELLOW}Skipped:${RESET}        $SKIPPED_TESTS"
    
    # Calculate percentage
    if [ $TOTAL_TESTS -gt 0 ]; then
        local percent=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo -e "${BOLD}Success Rate:${RESET}   ${percent}%"
    fi
    
    # Show failed tests
    if [ $FAILED_TESTS -gt 0 ]; then
        echo -e "\n${RED}${BOLD}Failed Tests:${RESET}"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ $result == FAIL:* ]]; then
                echo "  • ${result#FAIL: }"
            fi
        done
    fi
    
    # Show warnings
    local warn_count=0
    for result in "${TEST_RESULTS[@]}"; do
        [[ $result == WARN:* ]] && ((warn_count++))
    done
    
    if [ $warn_count -gt 0 ]; then
        echo -e "\n${YELLOW}${BOLD}Warnings:${RESET}"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ $result == WARN:* ]]; then
                echo "  • ${result#WARN: }"
            fi
        done
    fi
    
    echo ""
}

# Main test execution
main() {
    # Check if script exists
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}Error: pacheck script not found at $SCRIPT_PATH${RESET}"
        echo "Please update SCRIPT_PATH variable in this test script"
        exit 1
    fi
    
    # Make sure script is executable
    chmod +x "$SCRIPT_PATH"
    
    print_header
    
    # Quick sanity check
    if ! command -v pacman &>/dev/null; then
        echo -e "${RED}Error: pacman not found. This test requires an Arch Linux system.${RESET}"
        exit 1
    fi
    
    # Test 1: Help and basic functionality
    print_section "BASIC FUNCTIONALITY"
    run_test "Help flag (-h)" "-h" true 5
    run_test "Help flag (--help)" "--help" true 5
    run_test "No arguments" "" true 5
    
    # Test 2: Basic search (installed packages only)
    print_section "BASIC SEARCH (Installed Only)"
    run_test "Search installed by name" "$INSTALLED_PKG"
    run_test "Partial name search" "$PARTIAL_NAME"
    run_test "Multiple search terms" "bash git"
    run_test "Non-existent package" "$NONEXISTENT" false
    
    # Test 3: Description search
    print_section "DESCRIPTION SEARCH (-d flag)"
    run_test "Description search" "-d $DESC_KEYWORD"
    run_test "Description with partial name" "-d lib"
    run_test "Description with multiple terms" "-d compression file"
    
    # Test 4: Exact match
    print_section "EXACT MATCH (-e flag)"
    run_test "Exact match existing" "-e $EXACT_PKG"
    run_test "Exact match non-existing" "-e $NONEXISTENT" false
    run_test "Exact overrides description" "-ed $EXACT_PKG"
    
    # Test 5: Remote search
    if [ "$TEST_MODE" != "quick" ]; then
        print_section "REMOTE SEARCH (-r flag)"
        run_test "Remote search basic" "-r python" true 15
        run_test "Remote with description" "-rd compression" true 15
        run_test "Remote exact match" "-re $EXACT_PKG" true 15
        run_test "Remote non-existent" "-r $NONEXISTENT" true 10
    fi
    
    # Test 6: Exclusion flags
    print_section "EXCLUSION FLAGS"
    run_test "Exclude AUR" "--exclude-aur $PARTIAL_NAME"
    run_test "Exclude Arch repos" "--exclude-arch $AUR_PKG"
    
    if [ "$TEST_MODE" != "quick" ]; then
        run_test "Exclude AUR with remote" "-r --exclude-aur python" true 15
        run_test "Exclude Arch with remote" "-r --exclude-arch lib" true 20
    fi
    
    # Test 7: Combined flags
    print_section "COMBINED FLAGS"
    run_test "Multiple short flags (-rd)" "-rd $PARTIAL_NAME" true 15
    run_test "All short flags (-rde)" "-rde $EXACT_PKG" true 15
    
    # Test 8: Edge cases
    if [ "$TEST_MODE" = "full" ] || [ "$TEST_MODE" = "interactive" ]; then
        print_section "EDGE CASES & STRESS TESTS"
        run_test "Very long search term" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" false
        run_test "Special characters" "lib*" 
        run_test "Multiple exact matches" "-e bash -e git"
        run_test "Case sensitivity" "BASH"
        
        # Test interrupt handling
        test_interrupt
    fi
    
    # Test 9: AUR-specific tests (if yay/paru is installed)
    if command -v yay &>/dev/null || command -v paru &>/dev/null; then
        if [ "$TEST_MODE" != "quick" ]; then
            print_section "AUR FUNCTIONALITY"
            run_test "AUR installed search" "$AUR_PKG"
            run_test "AUR remote search" "-r brave" true 20
            run_test "AUR with description" "-rd browser" true 20
        fi
    else
        echo -e "\n${YELLOW}Note: AUR tests skipped (no AUR helper found)${RESET}"
    fi
    
    # Performance test in full mode
    if [ "$TEST_MODE" = "full" ]; then
        print_section "PERFORMANCE TESTS"
        
        echo -e "${CYAN}Testing:${RESET} Response time for basic search... "
        local start_time=$(date +%s%N)
        timeout 5 $SCRIPT_PATH bash >/dev/null 2>&1
        local end_time=$(date +%s%N)
        local elapsed=$(( (end_time - start_time) / 1000000 ))
        
        if [ $elapsed -lt 1000 ]; then
            echo -e "${GREEN}FAST${RESET} (${elapsed}ms)"
        elif [ $elapsed -lt 3000 ]; then
            echo -e "${YELLOW}MODERATE${RESET} (${elapsed}ms)"
        else
            echo -e "${RED}SLOW${RESET} (${elapsed}ms)"
        fi
    fi
    
    print_summary
    
    # Exit with appropriate code
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}${BOLD}All tests passed successfully!${RESET}"
        exit 0
    else
        echo -e "${RED}${BOLD}Some tests failed. Please review the results.${RESET}"
        exit 1
    fi
}

# Run main
main