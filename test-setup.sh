#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/test-install"
CONFIG_FILE="${SCRIPT_DIR}/tools.conf"
PASSED=0
FAILED=0

# Test result tracking
declare -a FAILED_TESTS=()

# Parse first tool from tools.conf
get_first_tool() {
    local tool_id=""
    local tool_source=""
    local tool_target=""

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Tool section header
        if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\] ]]; then
            if [ -n "$tool_id" ]; then
                # We already found one, return it
                echo "$tool_id|$tool_source|$tool_target"
                return
            fi
            tool_id="${BASH_REMATCH[1]}"
            continue
        fi

        # Parse key-value pairs
        if [ -n "$tool_id" ] && [[ "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # Trim whitespace
            key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

            case "$key" in
                source) tool_source="$value" ;;
                target) tool_target="$value" ;;
            esac
        fi
    done < "$CONFIG_FILE"

    # Return last tool if we exited the loop
    if [ -n "$tool_id" ]; then
        echo "$tool_id|$tool_source|$tool_target"
    fi
}

# Get test tool info from config
get_tool_instructions() {
    local tool_id="$1"
    local instructions_file=""

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\] ]]; then
            if [ "${BASH_REMATCH[1]}" = "$tool_id" ]; then
                # Found our tool, keep reading
                continue
            elif [ -n "$instructions_file" ]; then
                # Found another tool, we're done
                break
            fi
        fi

        if [[ "$line" =~ ^[[:space:]]*instructions_file[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            instructions_file="${BASH_REMATCH[1]}"
            instructions_file="$(echo "$instructions_file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        fi
    done < "$CONFIG_FILE"

    echo "$instructions_file"
}

TEST_TOOL_INFO=$(get_first_tool)
TEST_TOOL_ID=$(echo "$TEST_TOOL_INFO" | cut -d'|' -f1)
TEST_TOOL_SOURCE=$(echo "$TEST_TOOL_INFO" | cut -d'|' -f2)
TEST_TOOL_TARGET=$(echo "$TEST_TOOL_INFO" | cut -d'|' -f3)
TEST_TOOL_INSTRUCTIONS_FILE=$(get_tool_instructions "$TEST_TOOL_ID")

print_test() {
    echo -e "${BLUE}TEST:${NC} $1"
}

pass() {
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
    echo ""
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAILED_TESTS+=("$2")
    ((FAILED++))
    echo ""
}

cleanup() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

setup_test_env() {
    cleanup
    mkdir -p "$TEST_DIR"

    # Create CLAUDE.md if instructions_file is specified
    if [ -n "$TEST_TOOL_INSTRUCTIONS_FILE" ]; then
        echo "# Test Instructions" > "$TEST_DIR/$TEST_TOOL_INSTRUCTIONS_FILE"
    fi
}

# Test 1: Setup script exists and is executable
test_setup_exists() {
    print_test "Setup script exists and is executable"

    if [ ! -f "$SCRIPT_DIR/setup" ]; then
        fail "setup script not found" "setup_exists"
        return
    fi

    if [ ! -x "$SCRIPT_DIR/setup" ]; then
        fail "setup script is not executable" "setup_executable"
        return
    fi

    pass
}

# Test 2: Tools.conf exists
test_config_exists() {
    print_test "tools.conf exists"

    if [ ! -f "$SCRIPT_DIR/tools.conf" ]; then
        fail "tools.conf not found" "config_exists"
        return
    fi

    pass
}

# Test 3: Setup list command works
test_list_command() {
    print_test "setup list command works"

    output=$("$SCRIPT_DIR/setup" list 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        fail "list command failed with exit code $exit_code" "list_command"
        return
    fi

    if ! echo "$output" | grep -q "$TEST_TOOL_ID"; then
        fail "list command does not show '$TEST_TOOL_ID' tool" "list_shows_tool"
        return
    fi

    pass
}

# Test 4: Setup help command works
test_help_command() {
    print_test "setup --help command works"

    output=$("$SCRIPT_DIR/setup" --help 2>&1)
    exit_code=$?

    # Help should exit with code 1
    if [ $exit_code -ne 1 ]; then
        fail "help command should exit with code 1, got $exit_code" "help_exit_code"
        return
    fi

    if ! echo "$output" | grep -q "Usage:"; then
        fail "help command does not show usage" "help_shows_usage"
        return
    fi

    pass
}

# Test 5: Invalid tool name fails gracefully
test_invalid_tool() {
    print_test "Invalid tool name fails gracefully"

    setup_test_env
    output=$("$SCRIPT_DIR/setup" nonexistent "$TEST_DIR" 2>&1 || true)

    if ! echo "$output" | grep -q "not found in configuration"; then
        fail "should show 'not found in configuration' error" "invalid_tool_error"
        return
    fi

    pass
}

# Test 6: Missing target directory fails
test_missing_target() {
    print_test "Missing target directory fails gracefully"

    output=$("$SCRIPT_DIR/setup" claude "/nonexistent/path/$$" 2>&1 || true)

    if ! echo "$output" | grep -q "does not exist"; then
        fail "should show 'does not exist' error" "missing_target_error"
        return
    fi

    pass
}

# Test 7: Source directory exists
test_source_directory() {
    print_test "Source directory for $TEST_TOOL_ID tool exists"

    if [ ! -d "$SCRIPT_DIR/$TEST_TOOL_SOURCE" ]; then
        fail "$TEST_TOOL_SOURCE source directory not found" "source_dir_exists"
        return
    fi

    if [ ! -d "$SCRIPT_DIR/$TEST_TOOL_SOURCE/agents" ]; then
        fail "$TEST_TOOL_SOURCE/agents directory not found" "agents_dir_exists"
        return
    fi

    if [ ! -d "$SCRIPT_DIR/$TEST_TOOL_SOURCE/commands" ]; then
        fail "$TEST_TOOL_SOURCE/commands directory not found" "commands_dir_exists"
        return
    fi

    pass
}

# Test 8: Actual installation to temp directory
test_installation() {
    print_test "Actual installation to temporary directory"

    setup_test_env

    # Run installation non-interactively
    output=$("$SCRIPT_DIR/setup" "$TEST_TOOL_ID" "$TEST_DIR" 2>&1 <<< "")
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        fail "installation failed with exit code $exit_code" "install_exit_code"
        return
    fi

    # Check target directory was created
    if [ ! -d "$TEST_DIR/$TEST_TOOL_TARGET" ]; then
        fail "target directory $TEST_TOOL_TARGET was not created" "install_creates_dir"
        return
    fi

    # Check agents directory
    if [ ! -d "$TEST_DIR/$TEST_TOOL_TARGET/agents" ]; then
        fail "agents directory was not copied" "install_copies_agents"
        return
    fi

    # Check commands directory
    if [ ! -d "$TEST_DIR/$TEST_TOOL_TARGET/commands" ]; then
        fail "commands directory was not copied" "install_copies_commands"
        return
    fi

    # Check build-logs-analyst agent exists
    if [ ! -f "$TEST_DIR/$TEST_TOOL_TARGET/agents/build-logs-analyst.md" ]; then
        fail "build-logs-analyst.md was not copied" "install_copies_agent_file"
        return
    fi

    # Check build-and-summarize command exists
    if [ ! -f "$TEST_DIR/$TEST_TOOL_TARGET/commands/build-and-summarize" ]; then
        fail "build-and-summarize was not copied" "install_copies_command_file"
        return
    fi

    # Check build-and-summarize is executable
    if [ ! -x "$TEST_DIR/$TEST_TOOL_TARGET/commands/build-and-summarize" ]; then
        fail "build-and-summarize is not executable after installation" "install_makes_executable"
        return
    fi

    pass
}

# Test 9: Overwrite prompt works
test_overwrite_prompt() {
    print_test "Overwrite prompt works for existing installation"

    setup_test_env

    # First installation
    "$SCRIPT_DIR/setup" "$TEST_TOOL_ID" "$TEST_DIR" 2>&1 <<< "" > /dev/null

    # Create a marker file
    echo "test" > "$TEST_DIR/$TEST_TOOL_TARGET/marker.txt"

    # Try to install again and say no
    output=$("$SCRIPT_DIR/setup" "$TEST_TOOL_ID" "$TEST_DIR" 2>&1 <<< "n" || true)

    if ! echo "$output" | grep -q "already exists"; then
        fail "should show 'already exists' warning" "overwrite_warning"
        return
    fi

    # Marker file should still exist (we said no)
    if [ ! -f "$TEST_DIR/$TEST_TOOL_TARGET/marker.txt" ]; then
        fail "installation should have been cancelled" "overwrite_cancelled"
        return
    fi

    # Now try with yes
    "$SCRIPT_DIR/setup" "$TEST_TOOL_ID" "$TEST_DIR" 2>&1 <<< "y" > /dev/null

    # Marker file should be gone (we said yes)
    if [ -f "$TEST_DIR/$TEST_TOOL_TARGET/marker.txt" ]; then
        fail "old installation should have been removed" "overwrite_removed"
        return
    fi

    pass
}

# Test 10: Build-and-summarize script syntax
test_build_script_syntax() {
    print_test "build-and-summarize script has valid syntax"

    if ! bash -n "$SCRIPT_DIR/$TEST_TOOL_SOURCE/commands/build-and-summarize" 2>&1; then
        fail "syntax check failed" "build_script_syntax"
        return
    fi

    pass
}

# Test 11: Setup script syntax
test_setup_syntax() {
    print_test "setup script has valid syntax"

    if ! bash -n "$SCRIPT_DIR/setup" 2>&1; then
        fail "syntax check failed" "setup_syntax"
        return
    fi

    pass
}

# Test 12: No arguments shows usage
test_no_args() {
    print_test "No arguments shows usage"

    output=$("$SCRIPT_DIR/setup" 2>&1 || true)

    if ! echo "$output" | grep -q "Usage:"; then
        fail "should show usage when no arguments provided" "no_args_usage"
        return
    fi

    pass
}

# Run all tests
main() {
    echo "======================================"
    echo "  Setup Script Smoke Tests"
    echo "======================================"
    echo ""

    cd "$SCRIPT_DIR"

    test_setup_exists || true
    test_config_exists || true
    test_setup_syntax || true
    test_build_script_syntax || true
    test_source_directory || true
    test_no_args || true
    test_help_command || true
    test_list_command || true
    test_invalid_tool || true
    test_missing_target || true
    test_installation || true
    test_overwrite_prompt || true

    # Cleanup
    cleanup

    # Summary
    echo "======================================"
    echo "  Test Summary"
    echo "======================================"
    echo -e "${GREEN}Passed: $PASSED${NC}"

    if [ $FAILED -gt 0 ]; then
        echo -e "${RED}Failed: $FAILED${NC}"
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
        echo ""
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        echo ""
        exit 0
    fi
}

main "$@"
