# build-and-summarize

Automatically detects your build tool (Gradle or Maven) and runs it with full output captured to a timestamped log. Shows minimal live progress (task starts + final build/test summary), then asks the `build-logs-analyst` agent to produce structured artifacts from the log.

## Build Tool Detection

The command automatically detects:
- **Gradle**: Looks for `./gradlew` (defaults to `build` goal)
- **Maven**: Looks for `./mvnw` or `pom.xml` (defaults to `verify` goal)

## Usage
```bash
./.claude/commands/build-and-summarize [<build-args>...]