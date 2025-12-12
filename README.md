# Codegenial

[![Tests](https://github.com/jbachorik/codegenial/workflows/Tests/badge.svg)](https://github.com/jbachorik/codegenial/actions)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

A collection of reusable AI code assistant tools and agents designed to enhance development workflows.

## Features

- **Build automation with intelligent log analysis**
- **Support for both Gradle and Maven projects**
- **Structured output reports (Markdown + JSON)**
- **Minimal console output, detailed file logs**

## Quick Start

### Installation

1. Clone this repository:
   ```bash
   git clone <repo-url>
   cd codegenial
   ```

2. List available tools:
   ```bash
   # Linux/macOS
   ./setup list

   # Windows (PowerShell)
   .\setup.ps1 list
   ```

3. Install a tool to your project:
   ```bash
   # Linux/macOS
   ./setup claude /path/to/your/project

   # Windows (PowerShell)
   .\setup.ps1 claude C:\path\to\your\project
   ```

   **Windows Requirements**: PowerShell 3.0 or later (available on Windows 7+ with updates, built-in on Windows 8+)

### Usage

After installing the Claude Code tools, navigate to your project and use the build command:

```bash
cd /path/to/your/project
./.claude/commands/build-and-summarize
```

**Note for Windows users**: The `build-and-summarize` command is a bash script. You'll need:
- WSL (Windows Subsystem for Linux), or
- Git Bash, or
- Cygwin

to run it on Windows.

The command will:
- Auto-detect your build tool (Gradle or Maven)
- Run the build with full logging
- Show minimal console output
- Generate detailed analysis reports in `build/reports/claude/`

## Available Tools

### Claude Code

Provides Claude Code agents and commands for build automation:

- **build-logs-analyst** agent: Parses Gradle/Maven build logs and extracts structured information
- **build-and-summarize** command: Runs builds with log capture and automated analysis

**Outputs:**
- `build/logs/` - Timestamped build logs
- `build/reports/claude/build-summary.md` - Human-readable summary
- `build/reports/claude/build-summary.json` - Machine-readable structured data

## Configuration

Tool definitions are stored in `tools.conf`:

```ini
[tool-id]
name = Display Name
description = Short description
source = Source directory in this repo
target = Target subdirectory in the destination project
instructions_file = INSTRUCTIONS.md (optional)
```

**Special Features:**
- **Underscore files exclusion**: Files starting with `_` in the source directory are not copied
- **Instructions append**: If `_add_instructions.md` exists in source and `instructions_file` is specified, its contents are appended to the target instructions file (idempotent - won't duplicate on reinstall)
- **Instructions validation**: If `instructions_file` is specified, it must exist in the target directory before installation

### Adding New Tools

1. Create a directory for your tool (e.g., `cursor/`)
2. Add your tool's files (agents, commands, etc.)
3. Add a tool definition to `tools.conf`
4. Test with `./setup list` and `./setup <tool-id> <target-dir>`

## Architecture

### Build Workflow

1. **Detection**: Auto-detect Gradle (via `gradlew`) or Maven (via `mvnw`/`pom.xml`)
2. **Execution**: Run build with appropriate flags
3. **Logging**: Capture full output to timestamped log files
4. **Analysis**: Parse logs using specialized agents
5. **Reporting**: Generate structured artifacts (MD + JSON)

### Log Analysis

The build-logs-analyst agent detects build tools by signatures:

- **Gradle**: `> Task :`, `BUILD SUCCESSFUL`, `BUILD FAILED`, Gradle Daemon messages
- **Maven**: `[INFO]`/`[ERROR]`/`[WARNING]` line prefixes, `BUILD SUCCESS`, `BUILD FAILURE`, `[INFO] Reactor Summary`

Extracted information includes:
- Build status and duration
- Failing tasks/goals with exceptions
- Test results per module
- Performance metrics (slowest tasks)
- Dependency and network issues

## Development

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation and development guidelines.

### Testing

Run the automated smoke tests to verify the setup script works correctly:

```bash
# Linux/macOS
./test-setup.sh

# Windows (PowerShell)
.\test-setup.ps1
```

This will test installation, error handling, and basic functionality without modifying your system (uses a temporary directory).

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Reporting issues
- Submitting changes
- Adding new tools
- Coding standards

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details.
