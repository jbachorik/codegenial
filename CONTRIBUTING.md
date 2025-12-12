# Contributing to Codegenial

Thank you for your interest in contributing to Codegenial! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Issues

- Use the GitHub issue tracker to report bugs or suggest features
- Check if the issue already exists before creating a new one
- Provide clear descriptions and reproduction steps for bugs
- Include environment details (OS, shell version, build tool versions)

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature-name`)
3. Make your changes
4. Test your changes thoroughly
5. Commit with clear, descriptive messages
6. Push to your fork
7. Create a Pull Request

### Coding Standards

#### Shell Scripts (setup, build-and-summarize)

- Use `set -euo pipefail` for error handling
- Quote variables: `"$variable"`
- Use meaningful variable names
- Add comments for complex logic
- Test on multiple platforms when applicable

#### Batch Scripts (setup.bat)

- Use `setlocal enabledelayedexpansion`
- Quote paths with spaces
- Provide error messages for failures
- Test on Windows systems

#### Agent Definitions (*.md files in claude/agents/)

- Use YAML frontmatter for metadata (name, description)
- Write clear, actionable instructions
- Include examples where helpful
- Document expected inputs and outputs
- Keep agent focus specific and well-defined

#### Configuration Files (tools.conf)

- Use INI-style format
- Include comments explaining sections
- Validate that source directories exist
- Use relative paths for portability

### Adding New Tools

To add a new tool to the collection:

1. Create a directory for your tool (e.g., `cursor/`, `copilot/`)
2. Add tool files (agents, commands, configuration)
3. Add an entry to `tools.conf`:
   ```ini
   [tool-id]
   name = Display Name
   description = Short description of the tool
   source = directory-name
   target = .target-subdirectory
   ```
4. Test installation with `./setup list` and `./setup tool-id test-dir`
5. Update README.md with tool documentation
6. Create a PR with your changes

### Testing

Before submitting:

- Run the smoke tests: `./test-setup.sh`
- Test setup script on your platform
- Verify tool installation to a test directory
- Test any new commands or agents
- Check that documentation is accurate
- Verify no personal or sensitive information is included

#### Running Tests

The project includes automated smoke tests for the setup script:

```bash
# Run all tests
./test-setup.sh
```

The tests verify:
- Setup script exists and is executable
- Configuration file is present and valid
- List and help commands work
- Error handling for invalid inputs
- Actual installation to a temporary directory
- Overwrite protection works correctly
- Script syntax is valid

All tests must pass before submitting a pull request.

#### Continuous Integration

The project uses GitHub Actions for automated testing:
- Smoke tests run on Ubuntu and macOS
- ShellCheck validates shell scripts
- Markdown linting ensures documentation quality

All checks must pass before pull requests can be merged.

### Documentation

- Update README.md for user-facing changes
- Update CLAUDE.md for architectural changes
- Include inline comments for complex code
- Keep examples current and accurate

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Assume good intentions

## Questions?

Open an issue for questions or discussions about contributing.
