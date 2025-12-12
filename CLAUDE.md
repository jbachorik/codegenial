# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Codegenial** is a collection of reusable Claude Code agents and commands designed to enhance development workflows, particularly for build automation and log analysis.

## Installation

Use the `setup` script (or `setup.bat` on Windows) to install tools into your target project:

```bash
# Linux/macOS
./setup list
./setup claude /path/to/your/project
./setup claude .

# Windows
setup.bat list
setup.bat claude C:\path\to\your\project
setup.bat claude .
```

The setup script:
- Reads tool configurations from `tools.conf`
- Copies tool files to the appropriate location (e.g., `.claude/` for Claude Code)
- Makes command scripts executable (Unix-like systems)
- Prompts before overwriting existing installations
- Available for both Unix-like systems (`setup`) and Windows (`setup.bat`)

### Tools Configuration

Tool definitions are stored in `tools.conf` with this format:

```ini
[tool-id]
name = Display Name
description = Short description
source = Source directory in this repo
target = Target subdirectory in the destination project
instructions_file = INSTRUCTIONS.md (optional)
```

**Special Handling:**

1. **Underscore Files**: Files starting with `_` are excluded from installation
   - Useful for keeping internal/development files in the source
   - Example: `_add_instructions.md`, `_notes.txt`

2. **Instructions Append**: If a tool specifies `instructions_file`:
   - The setup script validates the file exists in target directory
   - If `_add_instructions.md` exists in source, its content is appended to the instructions file
   - **Idempotent**: A marker comment is added to prevent duplicate appends
   - Useful for adding tool-specific guidance to project instructions

3. **Validation**: Setup scripts check that required files exist before proceeding

## Repository Structure

```
codegenial/
├── setup               # Unix/Linux/macOS installation script
├── setup.bat           # Windows installation script
├── tools.conf          # Tool configuration definitions
├── claude/             # Claude Code tools
│   ├── agents/         # Custom agent definitions
│   │   └── build-logs-analyst.md
│   └── commands/       # Executable commands
│       └── build-and-summarize
└── README.md           # User documentation
```

## Key Components

### Build Logs Analyst Agent

Located at `claude/agents/build-logs-analyst.md`, this agent:
- Parses Gradle and Maven build logs automatically
- Detects build tool from log signatures
- Extracts test results, failures, warnings, and performance data
- Outputs structured analysis to:
  - `build/reports/claude/build-summary.md` (human-readable)
  - `build/reports/claude/build-summary.json` (machine-readable)

The agent is designed to minimize chat output and write details to files instead.

### Build and Summarize Command

The `claude/commands/build-and-summarize` script:
- Automatically detects build tool (Gradle via `./gradlew` or Maven via `./mvnw`/`pom.xml`)
- Runs build with specified arguments (defaults: `build` for Gradle, `verify` for Maven)
- Captures full build output to timestamped logs in `build/logs/`
- Shows minimal live progress (task/module starts, final status, test summaries)
- Automatically invokes the build-logs-analyst agent to produce structured reports
- Usage: `./.claude/commands/build-and-summarize [build-args...]`

## Architecture Notes

### Build Workflow Integration

The build workflow follows this pattern:
1. Build tool detection (Gradle via `gradlew`, Maven via `mvnw` or `pom.xml`)
2. Command script captures full build output to `build/logs/${TIMESTAMP}-${TASK}.log`
3. Live console shows only critical information (task/module execution, build status, test counts)
4. After completion, the analyst agent parses the log file
5. Structured artifacts are generated in `build/reports/claude/`

This design keeps the Claude Code session output minimal while preserving full details in files.

### Log Analysis Strategy

The build-logs-analyst agent uses tool detection to differentiate between Gradle and Maven:
- **Gradle indicators**: `> Task :`, `BUILD SUCCESSFUL`, `BUILD FAILED`, Gradle Daemon messages, configuration cache notes
- **Maven indicators (primary)**: `[INFO]`/`[ERROR]`/`[WARNING]` line prefixes, `BUILD SUCCESS`, `BUILD FAILURE`, `[INFO] Reactor Summary`, `Failed to execute goal`
- **Maven indicators (optional)**: `maven-surefire-plugin`, `maven-failsafe-plugin` (only when tests are configured)

Detection prioritizes Gradle-specific patterns first, then falls back to Maven patterns. The `[INFO]` prefix frequency is a strong Maven indicator.

The agent extracts:
- Build status and total time
- Failing tasks/goals with exception headlines
- Test summaries per task/module with top failing tests
- Performance data (slowest tasks for Gradle, module timings for Maven)
- Dependency/network issues (timeouts, 401/403 errors, checksum mismatches)

### JSON Schema

The generated `build-summary.json` has this structure:
```json
{
  "status": "SUCCESS|FAILED|UNKNOWN",
  "totalTime": "string|null",
  "failedTasks": [],
  "warnings": [],
  "tests": {
    "total": null,
    "failed": null,
    "skipped": null,
    "modules": []
  },
  "slowTasks": [],
  "depIssues": [],
  "actions": []
}
```

## Development Notes

- This is a meta-repository containing Claude Code customizations
- The build-and-summarize command auto-detects Gradle or Maven projects
- Build artifacts are written to `build/` directory following Gradle conventions
- Maven projects will also use the `build/` directory for logs and reports
- Agent definitions use YAML frontmatter for metadata (name, description)
- Commands should be executable bash scripts placed in `claude/commands/`

### Platform Support

- **Installation**: Both Unix/Linux/macOS (`setup`) and Windows (`setup.bat`)
- **Build commands**: The `build-and-summarize` command is a bash script
  - Works natively on Unix/Linux/macOS
  - On Windows, requires WSL, Git Bash, or Cygwin
- **Build-logs-analyst agent**: Platform-agnostic (works everywhere Claude Code runs)
