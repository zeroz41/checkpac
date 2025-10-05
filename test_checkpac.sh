#!/bin/bash

# Comprehensive test script for pacheck - tests all flag combinations and paths
# Run with: ./test_pacheck.sh [quick|full|interactive|performance]

# Colors for output
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

# Test configuration
SCRIPT_PATH="./bin/checkpac"  # Adjust if your script is elsewhere
TEST_MODE="${1:-quick}"        # quick, full, interactive, or performance
TIMEOUT_SECONDS=25             # Timeout for each test

# Test packages (adjust based on your system)
# Using common packages likely to be found
INSTALLED_PKG="bash"           # Almost always installed
PARTIAL_NAME="lib"             # Common partial match
AUR_PKG="yay"                 # Common AUR helper
EXACT_PKG="git"               # For exact match testing
DESC_KEYWORD="compression"     # Common in descriptions
NONEXISTENT="zzz-nonexistent-pkg-xxx"
MULTI_SEARCH_1="python"       # For multi-term search
MULTI_SEARCH_2="ruby"         # For multi-term search

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
PERFORMANCE_TESTS=0

# Test results array
declare -a TEST_RESULTS
declare -A PERFORMANCE_METRICS

# Function to print test header
print_header() {
    echo -e "\n${BOLD}${BLUE}════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}PACHECK COMPREHENSIVE TEST SUITE - $TEST_MODE MODE${RESET}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════${RESET}\n"
    echo -e "${DIM}Testing script at: $SCRIPT_PATH${RESET}"
    echo -e "${DIM}Test started at: $(date '+%Y-%m-%d %H:%M:%S')${RESET}\n"
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
    local validate_func="${5:-}"      # Optional validation function
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -ne "${CYAN}Testing:${RESET} $test_name... "
    
    # Run the command with timeout
    local output_file=$(mktemp)
    local error_file=$(mktemp)
    local timing_file=$(mktemp)
    
    if [ "$TEST_MODE" = "interactive" ]; then
        echo -e "\n${BLUE}Command:${RESET} $SCRIPT_PATH $test_cmd"
        read -p "Press Enter to run (or 's' to skip): " response
        if [ "$response" = "s" ]; then
            echo -e "${YELLOW}SKIPPED${RESET}"
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            rm -f "$output_file" "$error_file" "$timing_file"
            return
        fi
    fi
    
    # Execute with timing
    local start_time=$(date +%s%N)
    timeout "$timeout_override" bash -c "$SCRIPT_PATH $test_cmd" > "$output_file" 2> "$error_file"
    local exit_code=$?
    local end_time=$(date +%s%N)
    local elapsed_ms=$(( (end_time - start_time) / 1000000 ))
    
    # Save timing for performance analysis
    echo "$elapsed_ms" > "$timing_file"
    PERFORMANCE_METRICS["$test_name"]=$elapsed_ms
    
    # Check results
    local output=$(cat "$output_file")
    local errors=$(cat "$error_file")
    local output_lines=$(wc -l < "$output_file")
    
    # Determine test result
    local test_passed=true
    local failure_reason=""
    
    if [ $exit_code -eq 124 ]; then
        test_passed=false
        failure_reason="Timeout (>${timeout_override}s)"
    elif [ $exit_code -ne 0 ] && [ "$test_cmd" != "--help" ] && [ "$test_cmd" != "-h" ]; then
        test_passed=false
        failure_reason="Exit code $exit_code"
    elif [ "$expect_output" = "true" ] && [ $output_lines -lt 1 ]; then
        test_passed=false
        failure_reason="No output (${output_lines} lines)"
    fi
    
    # Run custom validation if provided
    if [ -n "$validate_func" ] && [ "$test_passed" = true ]; then
        if ! $validate_func "$output" "$test_cmd"; then
            test_passed=false
            failure_reason="Validation failed"
        fi
    fi
    
    # Report result
    if [ "$test_passed" = true ]; then
        echo -e "${GREEN}PASSED${RESET} (${output_lines} lines, ${elapsed_ms}ms)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TEST_RESULTS+=("PASS: $test_name")
    else
        echo -e "${RED}FAILED${RESET} ($failure_reason)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("FAIL: $test_name - $failure_reason")
        [ -n "$errors" ] && echo -e "  ${RED}Error:${RESET} $(echo "$errors" | head -1)"
    fi
    
    # Show sample output in verbose mode
    if [ "$TEST_MODE" = "full" ] || [ "$TEST_MODE" = "interactive" ]; then
        if [ $output_lines -gt 0 ]; then
            echo -e "  ${BLUE}Sample output:${RESET}"
            head -3 "$output_file" | sed 's/^/    /'
            [ $output_lines -gt 3 ] && echo "    ..."
        fi
    fi
    
    rm -f "$output_file" "$error_file" "$timing_file"
}

# Validation functions for complex tests
validate_description_search() {
    local output="$1"
    local cmd="$2"
    # Check if output contains description-related content
    echo "$output" | grep -qi "compress\|archive\|extract" 2>/dev/null
}

validate_multiple_terms() {
    local output="$1"
    local cmd="$2"
    # Check if both search terms produced results
    local has_results=$(echo "$output" | grep -E "^[[:space:]]*[✓✗]" | wc -l)
    [ "$has_results" -gt 0 ]
}

validate_remote_search() {
    local output="$1"
    local cmd="$2"
    # Check for "Available" section in output
    echo "$output" | grep -q "Available" 2>/dev/null
}

validate_exact_match() {
    local output="$1"
    local cmd="$2"
    # For exact match, should not have partial matches
    local pkg_name=$(echo "$cmd" | grep -oE '[^ ]+$')
    ! echo "$output" | grep -E "^[[:space:]]*[✓✗]" | grep -vE "^[[:space:]]*[✓✗] $pkg_name " 2>/dev/null
}

validate_simple_mode() {
    local output="$1"
    local cmd="$2"
    
    # Simple mode should have:
    # 1. No ANSI color codes
    # 2. No Unicode symbols (✓, ✗, etc.)
    # 3. No version numbers in parentheses
    # 4. No dividers/headers
    # 5. Just package names, one per line
    
    # Check for ANSI codes (should be absent)
    if echo "$output" | grep -qE '\x1b\['; then
        return 1
    fi
    
    # Check for common formatting characters
    if echo "$output" | grep -qE '[✓✗→]|v[0-9]|\(|\)'; then
        return 1
    fi
    
    # Check for dividers or headers
    if echo "$output" | grep -qE '────|Official|AUR|Available|Installed|Source'; then
        return 1
    fi
    
    # Each line should be a simple package name (alphanumeric, hyphens, underscores, dots)
    # Allow empty lines
    local has_invalid_line=false
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Check if line matches package name pattern
        if ! [[ "$line" =~ ^[a-zA-Z0-9._+-]+$ ]]; then
            has_invalid_line=true
            break
        fi
    done <<< "$output"
    
    [ "$has_invalid_line" = false ]
}

# Performance benchmark function
run_performance_test() {
    local test_name="$1"
    local test_cmd="$2"
    local iterations="${3:-3}"
    
    echo -ne "${MAGENTA}Benchmarking:${RESET} $test_name ($iterations iterations)... "
    
    local total_time=0
    local min_time=999999
    local max_time=0
    
    for i in $(seq 1 $iterations); do
        local start_time=$(date +%s%N)
        timeout 30 bash -c "$SCRIPT_PATH $test_cmd" >/dev/null 2>&1
        local exit_code=$?
        local end_time=$(date +%s%N)
        
        if [ $exit_code -eq 124 ]; then
            echo -e "${RED}TIMEOUT${RESET}"
            return
        fi
        
        local elapsed=$(( (end_time - start_time) / 1000000 ))
        total_time=$((total_time + elapsed))
        
        [ $elapsed -lt $min_time ] && min_time=$elapsed
        [ $elapsed -gt $max_time ] && max_time=$elapsed
    done
    
    local avg_time=$((total_time / iterations))
    
    # Color code based on performance
    local color=$GREEN
    [ $avg_time -gt 1000 ] && color=$YELLOW
    [ $avg_time -gt 3000 ] && color=$RED
    
    echo -e "${color}AVG: ${avg_time}ms${RESET} (min: ${min_time}ms, max: ${max_time}ms)"
    
    PERFORMANCE_TESTS=$((PERFORMANCE_TESTS + 1))
    PERFORMANCE_METRICS["PERF_${test_name}_avg"]=$avg_time
}

# Function to test AUR batch optimization
test_aur_batch_performance() {
    echo -e "\n${BOLD}${MAGENTA}Testing AUR Batch Optimization${RESET}"
    
    # Count AUR packages
    local aur_count=$(pacman -Qm | wc -l)
    echo -e "  Found $aur_count AUR packages installed"
    
    if [ $aur_count -gt 0 ]; then
        # Test searching all AUR packages
        echo -ne "  Testing AUR listing speed... "
        local start_time=$(date +%s%N)
        timeout 10 bash -c "$SCRIPT_PATH lib" >/dev/null 2>&1
        local end_time=$(date +%s%N)
        local elapsed=$(( (end_time - start_time) / 1000000 ))
        
        if [ $elapsed -lt 2000 ]; then
            echo -e "${GREEN}FAST${RESET} (${elapsed}ms for $aur_count packages)"
        elif [ $elapsed -lt 5000 ]; then
            echo -e "${YELLOW}MODERATE${RESET} (${elapsed}ms for $aur_count packages)"
        else
            echo -e "${RED}SLOW${RESET} (${elapsed}ms for $aur_count packages)"
        fi
        
        # Calculate per-package time
        if [ $aur_count -gt 0 ]; then
            local per_pkg=$((elapsed / aur_count))
            echo -e "  ${DIM}Average: ${per_pkg}ms per package${RESET}"
        fi
    else
        echo -e "  ${YELLOW}No AUR packages found - skipping AUR performance test${RESET}"
    fi
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
    
    # Performance summary
    if [ $PERFORMANCE_TESTS -gt 0 ]; then
        echo -e "\n${BOLD}${MAGENTA}Performance Metrics:${RESET}"
        for key in "${!PERFORMANCE_METRICS[@]}"; do
            if [[ $key == PERF_* ]]; then
                echo -e "  ${key#PERF_}: ${PERFORMANCE_METRICS[$key]}ms"
            fi
        done
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
    run_test "No arguments (should show help)" "" true 5
    
    # Test 2: Basic search (installed packages only)
    print_section "BASIC SEARCH (Installed Only)"
    run_test "Search installed by name" "$INSTALLED_PKG"
    run_test "Partial name search" "$PARTIAL_NAME"
    run_test "Multiple search terms" "bash git"
    run_test "Non-existent package" "$NONEXISTENT" false
    
    # Test 3: Simple mode tests - CRITICAL
    print_section "SIMPLE MODE (-s flag) - CRITICAL"
    run_test "Simple mode basic" "-s $INSTALLED_PKG" true 10 validate_simple_mode
    run_test "Simple mode partial" "-s lib" true 10 validate_simple_mode
    run_test "Simple mode multiple terms" "-s bash git" true 10 validate_simple_mode
    run_test "Simple with exact match" "-se $EXACT_PKG" true 10 validate_simple_mode
    run_test "Simple with description search" "-sd lib" true 10 validate_simple_mode
    
    # Test 4: Simple mode combined flags
    print_section "SIMPLE MODE COMBINED FLAGS"
    run_test "Simple + Remote (-rs)" "-rs python" true 15 validate_simple_mode
    run_test "Simple + Remote + Desc (-rds)" "-rds compression" true 15 validate_simple_mode
    run_test "Simple + Remote + Exact (-rse)" "-rse $EXACT_PKG" true 15 validate_simple_mode
    run_test "Simple + Description (-sd)" "-sd archive" true 10 validate_simple_mode
    run_test "Simple with exclusion (--exclude-aur -s)" "--exclude-aur -s lib" true 10 validate_simple_mode
    
    # Test 5: Description search
    print_section "DESCRIPTION SEARCH (-d flag)"
    run_test "Description search single term" "-d $DESC_KEYWORD" true 10 validate_description_search
    run_test "Description with partial name" "-d lib"
    run_test "Description with multiple terms" "-d compression archive"
    
    # Test 6: Exact match
    print_section "EXACT MATCH (-e flag)"
    run_test "Exact match existing" "-e $EXACT_PKG" true 10 validate_exact_match
    run_test "Exact match non-existing" "-e $NONEXISTENT" false
    run_test "Exact overrides description" "-ed $EXACT_PKG"
    run_test "Multiple exact matches" "-e bash git"
    
    # Test 7: Combined flag tests (CRITICAL)
    print_section "COMBINED FLAGS - CRITICAL TESTS"
    run_test "Combined -rd (remote + desc)" "-rd compression" true 15 validate_description_search
    run_test "Combined -rd with multiple terms" "-rd python ruby" true 15 validate_multiple_terms
    run_test "Combined -re (remote + exact)" "-re $EXACT_PKG" true 15 validate_exact_match
    run_test "Combined -rde (all flags)" "-rde $EXACT_PKG" true 15
    run_test "Combined short flags (-dr same as -rd)" "-dr lib" true 15
    run_test "Combined -rds (remote + desc + simple)" "-rds lib" true 15 validate_simple_mode
    
    # Test 8: Remote search with combinations
    if [ "$TEST_MODE" != "quick" ]; then
        print_section "REMOTE SEARCH COMBINATIONS (-r flag)"
        run_test "Remote search basic" "-r python" true 15 validate_remote_search
        run_test "Remote with description" "-rd compression" true 15 validate_remote_search
        run_test "Remote exact match" "-re $EXACT_PKG" true 15
        run_test "Remote non-existent" "-r $NONEXISTENT" true 10
        run_test "Remote with multiple packages" "-r python ruby nodejs" true 20
        run_test "Remote desc with multiple terms" "-rd archive extract compress" true 20
        run_test "Remote simple mode" "-rs lib" true 15 validate_simple_mode
    fi
    
    # Test 9: Exclusion flags with combinations
    print_section "EXCLUSION FLAGS WITH COMBINATIONS"
    run_test "Exclude AUR basic" "--exclude-aur $PARTIAL_NAME"
    run_test "Exclude Arch repos basic" "--exclude-arch $AUR_PKG"
    run_test "Exclude AUR with description" "--exclude-aur -d compression"
    run_test "Exclude Arch with exact" "--exclude-arch -e $AUR_PKG"
    run_test "Exclude AUR with simple" "--exclude-aur -s lib" true 10 validate_simple_mode
    
    if [ "$TEST_MODE" != "quick" ]; then
        run_test "Exclude AUR with remote" "-r --exclude-aur python" true 15
        run_test "Exclude Arch with remote" "-r --exclude-arch lib" true 20
        run_test "Both exclusions (should show nothing)" "--exclude-aur --exclude-arch bash" false
        run_test "Exclude + simple + remote" "-rs --exclude-aur lib" true 15 validate_simple_mode
    fi
    
    # Test 10: Multiple search terms with all flags
    print_section "MULTIPLE SEARCH TERMS - ADVANCED"
    run_test "Multiple terms basic" "python ruby"
    run_test "Multiple with description" "-d python ruby"
    run_test "Multiple with exact" "-e git bash"
    run_test "Multiple with remote" "-r python ruby nodejs" true 20
    run_test "Multiple with -rd" "-rd browser editor terminal" true 20
    run_test "Multiple with exclusions" "--exclude-aur python ruby perl"
    run_test "Multiple with simple" "-s python ruby" true 10 validate_simple_mode
    run_test "Multiple with simple + remote" "-rs python ruby" true 20 validate_simple_mode
    
    # Test 11: Edge cases
    if [ "$TEST_MODE" = "full" ] || [ "$TEST_MODE" = "interactive" ]; then
        print_section "EDGE CASES & STRESS TESTS"
        run_test "Very long search term" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" false
        run_test "Special characters in search" "lib*" 
        run_test "Case sensitivity check" "BASH"
        run_test "Unicode in search" "café"
        run_test "Empty string with quotes" '""' false
        run_test "Many search terms" "a b c d e f g h i j k l" true 15
        run_test "Simple mode with special chars" "-s lib*" true 10 validate_simple_mode
        
        # Test interrupt handling
        test_interrupt
    fi
    
    # Test 12: AUR-specific tests (if yay/paru is installed)
    if command -v yay &>/dev/null || command -v paru &>/dev/null; then
        if [ "$TEST_MODE" != "quick" ]; then
            print_section "AUR FUNCTIONALITY"
            run_test "AUR installed search" "$AUR_PKG"
            run_test "AUR with description" "-d $AUR_PKG"
            run_test "AUR exact match" "-e $AUR_PKG"
            run_test "AUR remote search" "-r brave-bin" true 20
            run_test "AUR remote with description" "-rd browser" true 20
            run_test "AUR VCS package handling" "-r wine-git" true 15
            run_test "AUR simple mode" "-s $AUR_PKG" true 10 validate_simple_mode
            run_test "AUR remote simple" "-rs brave-bin" true 20 validate_simple_mode
        fi
    else
        echo -e "\n${YELLOW}Note: AUR tests skipped (no AUR helper found)${RESET}"
    fi
    
    # Performance tests
    if [ "$TEST_MODE" = "performance" ] || [ "$TEST_MODE" = "full" ]; then
        print_section "PERFORMANCE BENCHMARKS"
        
        # Basic performance tests
        run_performance_test "Basic search" "bash" 5
        run_performance_test "Partial search" "lib" 3
        run_performance_test "Description search" "-d compression" 3
        run_performance_test "Exact match" "-e git" 5
        run_performance_test "Simple mode" "-s lib" 5
        
        # Remote performance tests
        if [ "$TEST_MODE" = "performance" ]; then
            run_performance_test "Remote search" "-r python" 3
            run_performance_test "Remote with desc" "-rd editor" 3
            run_performance_test "Multiple remote" "-r python ruby nodejs" 3
            run_performance_test "Remote simple" "-rs python" 3
        fi
        
        # AUR batch optimization test
        test_aur_batch_performance
    fi
    
    # Test 13: Specific validation tests
    if [ "$TEST_MODE" = "full" ]; then
        print_section "VALIDATION TESTS"
        
        echo -e "${CYAN}Validating -rd flag behavior:${RESET}"
        local output=$(timeout 15 $SCRIPT_PATH -rd compression 2>/dev/null)
        
        # Check if searching descriptions
        if echo "$output" | grep -i "description\|compress\|archive" >/dev/null 2>&1; then
            echo -e "  ✓ Description search: ${GREEN}Working${RESET}"
        else
            echo -e "  ✗ Description search: ${RED}Not working${RESET}"
        fi
        
        # Check if including remote
        if echo "$output" | grep -i "available" >/dev/null 2>&1; then
            echo -e "  ✓ Remote search: ${GREEN}Working${RESET}"
        else
            echo -e "  ✗ Remote search: ${YELLOW}May not be working${RESET}"
        fi
        
        echo -e "\n${CYAN}Validating simple mode output format:${RESET}"
        output=$(timeout 10 $SCRIPT_PATH -s lib 2>/dev/null)
        
        # Count lines and check format
        local line_count=$(echo "$output" | wc -l)
        local has_colors=$(echo "$output" | grep -c $'\x1b\[' || true)
        local has_symbols=$(echo "$output" | grep -c '[✓✗]' || true)
        
        echo -e "  Lines: $line_count"
        echo -e "  Color codes: $has_colors"
        echo -e "  Symbols: $has_symbols"
        
        if [ $has_colors -eq 0 ] && [ $has_symbols -eq 0 ]; then
            echo -e "  ✓ Simple mode format: ${GREEN}Correct${RESET}"
        else
            echo -e "  ✗ Simple mode format: ${RED}Contains formatting${RESET}"
        fi
        
        echo -e "\n${CYAN}Validating multiple search terms:${RESET}"
        output=$(timeout 10 $SCRIPT_PATH python ruby 2>/dev/null)
        local python_found=$(echo "$output" | grep -c "python")
        local ruby_found=$(echo "$output" | grep -c "ruby")
        
        echo -e "  Python matches: $python_found"
        echo -e "  Ruby matches: $ruby_found"
        
        if [ $python_found -gt 0 ] || [ $ruby_found -gt 0 ]; then
            echo -e "  ✓ Multiple terms: ${GREEN}Working${RESET}"
        else
            echo -e "  ✗ Multiple terms: ${RED}Not working${RESET}"
        fi
    fi
    
    print_summary
    
    # Save performance report if requested
    if [ "$TEST_MODE" = "performance" ] && [ ${#PERFORMANCE_METRICS[@]} -gt 0 ]; then
        local report_file="pacheck_performance_$(date +%Y%m%d_%H%M%S).txt"
        echo -e "\n${CYAN}Saving performance report to: $report_file${RESET}"
        {
            echo "PACHECK Performance Report - $(date)"
            echo "========================================"
            for key in "${!PERFORMANCE_METRICS[@]}"; do
                echo "$key: ${PERFORMANCE_METRICS[$key]}ms"
            done | sort
        } > "$report_file"
    fi
    
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
