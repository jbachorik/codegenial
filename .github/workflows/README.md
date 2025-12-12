# GitHub Actions Workflows

This directory contains automated CI/CD workflows for the Codegenial project.

## Workflows

### Tests (`test.yml`)

**Triggers:**
- Push to `main` branch
- Pull requests targeting `main` branch

This ensures all changes to the main branch are tested, and all pull requests are validated before merge.

**Jobs:**

1. **Smoke Tests (Unix)** (Ubuntu & macOS)
   - Checks out code
   - Makes scripts executable
   - Runs the automated smoke test suite (`test-setup.sh`)
   - Verifies setup commands work
   - Validates shell script syntax

2. **Smoke Tests (Windows)** (Windows Latest)
   - Checks out code
   - Runs Windows smoke test suite (`test-setup.bat`)
   - Verifies setup.bat commands work
   - Tests installation on Windows platform

3. **ShellCheck** (Ubuntu)
   - Runs ShellCheck static analysis on all shell scripts
   - Helps catch common shell scripting errors
   - Continues even if issues are found (warnings only)

4. **Markdown Lint** (Ubuntu)
   - Lints all Markdown documentation files
   - Ensures consistent documentation style
   - Continues even if issues are found (warnings only)

## Local Testing

Before pushing, run the same tests locally:

```bash
# Run smoke tests
./test-setup.sh

# Check syntax
bash -n setup
bash -n claude/commands/build-and-summarize

# Install shellcheck (optional)
# Ubuntu/Debian: apt-get install shellcheck
# macOS: brew install shellcheck
shellcheck setup claude/commands/build-and-summarize
```

## Matrix Testing

The smoke tests run on multiple operating systems:
- **Ubuntu** (latest) - Linux compatibility
- **macOS** (latest) - macOS compatibility
- **Windows** (latest) - Windows compatibility

This ensures full cross-platform compatibility across all major operating systems.

## Adding New Tests

To add new tests:

1. Add test functions to `test-setup.sh`
2. Call them from the `main()` function
3. Tests should use the existing pass/fail framework
4. Test locally before pushing
5. The GitHub Actions will automatically pick up and run new tests
