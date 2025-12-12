# Testing Guide

This document describes the testing strategy and tools for the Codegenial project.

## Requirements

### Unix/Linux/macOS
- **Bash** 3.2 or higher (compatible with macOS default bash)
- Standard Unix utilities: `sed`, `grep`, `find`, `chmod`
- `bash` must be in PATH

Check your bash version:
```bash
bash --version
```

### Windows
- Windows 7 or higher
- Command Prompt (cmd.exe)
- ANSI color support (Windows 10+) - optional but recommended

## Quick Start

Run all tests:
```bash
# Unix/Linux/macOS
./test-setup.sh

# Windows
test-setup.bat
```

## Test Suite

### Unix/Linux/macOS Smoke Tests (`test-setup.sh`)

Comprehensive automated tests that verify core functionality without modifying your system.

**12 Tests:**

1. **Setup script exists and is executable** - Verifies the setup script is present and has execute permissions
2. **tools.conf exists** - Ensures configuration file is present
3. **setup script has valid syntax** - Validates bash syntax
4. **build-and-summarize script has valid syntax** - Validates build script syntax
5. **Source directory for claude tool exists** - Checks source files are present
6. **No arguments shows usage** - Tests help text display
7. **setup --help command works** - Verifies help command
8. **setup list command works** - Tests tool listing functionality
9. **Invalid tool name fails gracefully** - Tests error handling
10. **Missing target directory fails gracefully** - Tests path validation
11. **Actual installation to temporary directory** - Full end-to-end installation test
12. **Overwrite prompt works** - Tests interactive overwrite protection

**Features:**
- Uses temporary directory (`test-install/`) - no system modifications
- Colored output (green ✓ for pass, red ✗ for fail)
- Detailed failure reporting
- Exit code 0 on success, 1 on any failure

### Windows Smoke Tests (`test-setup.bat`)

Windows-specific automated tests for the setup.bat script.

**8 Tests:**

1. **Setup.bat exists** - Verifies the Windows setup script is present
2. **tools.conf exists** - Ensures configuration file is present
3. **Source directory for claude tool exists** - Checks source files are present
4. **setup.bat list command works** - Tests tool listing functionality
5. **Invalid tool name fails gracefully** - Tests error handling
6. **Missing target directory fails gracefully** - Tests path validation
7. **Actual installation to temporary directory** - Full end-to-end installation test
8. **Overwrite prompt works** - Tests interactive overwrite protection

**Features:**
- Uses temporary directory (`test-install\`) - no system modifications
- ANSI colored output where supported
- Tests batch script functionality
- Exit code 0 on success, 1 on any failure

### Running Tests Locally

```bash
# Unix/Linux/macOS
./test-setup.sh

# Windows
test-setup.bat

# Manual syntax checks (Unix only)
bash -n setup
bash -n claude/commands/build-and-summarize
bash -n test-setup.sh

# Test individual commands
./setup list          # Unix
setup.bat list        # Windows

./setup --help        # Unix
setup.bat --help      # Windows
```

### ShellCheck (Optional)

Install ShellCheck for additional static analysis:

```bash
# Ubuntu/Debian
sudo apt-get install shellcheck

# macOS
brew install shellcheck

# Run on all scripts
shellcheck setup claude/commands/build-and-summarize test-setup.sh
```

## Continuous Integration

GitHub Actions automatically runs tests on:
- Every push to `main` branch
- Every pull request targeting `main` branch

### CI Jobs

1. **Smoke Tests (Unix)** (Ubuntu + macOS)
   - Runs the full test suite on both platforms
   - Requires: Bash 3.2+, standard Unix utilities
   - Ensures cross-platform Unix compatibility
   - Verifies setup commands work
   - Validates all shell script syntax

2. **Smoke Tests (Windows)** (Windows Latest)
   - Runs Windows-specific test suite
   - Requires: Windows 7+, cmd.exe
   - Tests setup.bat functionality
   - Verifies installation on Windows

3. **ShellCheck** (Ubuntu)
   - Static analysis of shell scripts
   - Catches common scripting errors
   - Warning-only (doesn't fail builds)

4. **Markdown Lint** (Ubuntu)
   - Validates documentation formatting
   - Ensures consistent style
   - Warning-only (doesn't fail builds)

### Viewing CI Results

After pushing to GitHub or creating a PR:
1. Go to the "Actions" tab in your repository
2. Click on the latest workflow run
3. View job results and logs
4. All smoke tests must pass before merging

## Test Development

### Adding New Tests

To add a new test to `test-setup.sh`:

```bash
test_new_feature() {
    print_test "Description of what you're testing"

    # Your test logic here
    if [ condition ]; then
        fail "Error message" "test_identifier"
        return
    fi

    pass
}
```

Then add to `main()`:
```bash
main() {
    # ... existing tests ...
    test_new_feature || true
    # ...
}
```

### Test Guidelines

- Each test should be independent
- Use `|| true` in main() to prevent early exit
- Clean up any temporary files
- Use descriptive test names
- Provide clear failure messages
- Test both success and failure cases

## Pre-Release Testing

Before creating a release:

```bash
# Run all tests
./test-setup.sh

# Test actual installation
./setup claude /tmp/test-project
cd /tmp/test-project
ls -la .claude/

# Verify files were copied correctly
test -f .claude/agents/build-logs-analyst.md
test -x .claude/commands/build-and-summarize

# Clean up
rm -rf /tmp/test-project
```

## Troubleshooting

### Tests Fail Locally

#### Unix/Linux/macOS

1. **Check script permissions:**
   ```bash
   ls -l setup test-setup.sh claude/commands/build-and-summarize
   ```

2. **Ensure you're in the project root:**
   ```bash
   pwd
   ls tools.conf  # Should exist
   ```

3. **Check bash version:**
   ```bash
   bash --version  # Should be 4.0+
   ```

4. **Check tools.conf is readable:**
   ```bash
   cat tools.conf | head -20
   ```

#### Windows

1. **Ensure you're in the project root:**
   ```cmd
   dir tools.conf
   ```

2. **Check setup.bat exists:**
   ```cmd
   dir setup.bat test-setup.bat
   ```

3. **Run with error output:**
   ```cmd
   test-setup.bat 2>&1 | more
   ```

### CI Tests Fail on GitHub

1. Check the Actions tab for detailed logs
2. Look for permission errors
3. Verify all files are committed
4. Check that .gitignore isn't excluding necessary files

## Platform Support

**Tested Platforms:**
- Ubuntu (latest) - Full CI testing
- macOS (latest) - Full CI testing
- Windows - Setup script only (via Git Bash/WSL)

**Note:** The `build-and-summarize` command requires a bash environment on Windows (WSL, Git Bash, or Cygwin).
