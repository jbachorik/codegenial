@echo off
setlocal enabledelayedexpansion

:: Get script directory
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CONFIG_FILE=%SCRIPT_DIR%\tools.conf"

:: Parse command line arguments
if "%~1"=="" goto :usage
if /i "%~1"=="-h" goto :usage
if /i "%~1"=="--help" goto :usage
if /i "%~1"=="/?" goto :usage
if /i "%~1"=="list" goto :list_tools_main

if "%~2"=="" (
    call :print_error "Error: Invalid number of arguments"
    echo.
    goto :usage
)

set "TOOL_ID=%~1"
set "TARGET_DIR=%~2"

:: Resolve target directory to absolute path
pushd "%TARGET_DIR%" 2>nul
if errorlevel 1 (
    call :print_error "Error: Target directory does not exist: %TARGET_DIR%"
    exit /b 1
)
set "TARGET_DIR=%CD%"
popd

call :install_tool "%TOOL_ID%" "%TARGET_DIR%"
exit /b 0

:usage
echo Usage: %~nx0 ^<tool-id^> ^<target-directory^>
echo.
echo Install codegenial tools to your project.
echo.
echo Arguments:
echo   tool-id           Tool identifier from tools.conf (e.g., 'claude')
echo   target-directory  Project directory where tools will be installed
echo.
echo Examples:
echo   %~nx0 claude C:\my-project
echo   %~nx0 cursor .
echo.
echo Available tools:
call :list_tools
exit /b 1

:list_tools_main
echo Available tools:
call :list_tools
exit /b 0

:list_tools
if not exist "%CONFIG_FILE%" (
    call :print_error "Error: Configuration file not found: %CONFIG_FILE%"
    exit /b 1
)

set "in_tool=false"
set "tool_id="
set "tool_name="
set "tool_desc="

for /f "usebackq delims=" %%a in ("%CONFIG_FILE%") do (
    set "line=%%a"

    :: Skip empty lines
    if "!line!"=="" goto :continue_list

    :: Skip comments
    echo !line! | findstr /r "^[ 	]*#" >nul
    if not errorlevel 1 goto :continue_list

    :: Check for section header [tool-id]
    echo !line! | findstr /r "^\[.*\]$" >nul
    if not errorlevel 1 (
        :: Print previous tool if exists
        if "!in_tool!"=="true" if not "!tool_id!"=="" (
            call :print_tool "!tool_id!" "!tool_name!" "!tool_desc!"
        )

        :: Extract tool ID from [brackets]
        set "tool_id=!line:~1,-1!"
        set "in_tool=true"
        set "tool_name="
        set "tool_desc="
        goto :continue_list
    )

    :: Parse key=value pairs
    if "!in_tool!"=="true" (
        echo !line! | findstr /r "=" >nul
        if not errorlevel 1 (
            for /f "tokens=1,* delims==" %%b in ("!line!") do (
                set "key=%%b"
                set "value=%%c"

                :: Trim whitespace
                for /f "tokens=* delims= " %%d in ("!key!") do set "key=%%d"
                for /f "tokens=* delims= " %%d in ("!value!") do set "value=%%d"

                if "!key!"=="name" set "tool_name=!value!"
                if "!key!"=="description" set "tool_desc=!value!"
            )
        )
    )

    :continue_list
)

:: Print last tool
if "!in_tool!"=="true" if not "!tool_id!"=="" (
    call :print_tool "!tool_id!" "!tool_name!" "!tool_desc!"
)
exit /b 0

:parse_tool_config
set "search_tool_id=%~1"
set "in_tool=false"
set "found=false"
set "TOOL_NAME="
set "TOOL_DESC="
set "TOOL_SOURCE="
set "TOOL_TARGET="
set "TOOL_INSTRUCTIONS_FILE="

for /f "usebackq delims=" %%a in ("%CONFIG_FILE%") do (
    set "line=%%a"

    :: Skip comments
    echo !line! | findstr /r "^[ 	]*#" >nul
    if not errorlevel 1 goto :continue_parse

    :: Check for section header [tool-id]
    echo !line! | findstr /r "^\[.*\]$" >nul
    if not errorlevel 1 (
        if "!in_tool!"=="true" goto :done_parse

        :: Extract tool ID from [brackets]
        set "current_id=!line:~1,-1!"
        if "!current_id!"=="%search_tool_id%" (
            set "in_tool=true"
            set "found=true"
        )
        goto :continue_parse
    )

    :: Parse key=value pairs
    if "!in_tool!"=="true" (
        echo !line! | findstr /r "=" >nul
        if not errorlevel 1 (
            for /f "tokens=1,* delims==" %%b in ("!line!") do (
                set "key=%%b"
                set "value=%%c"

                :: Trim whitespace
                for /f "tokens=* delims= " %%d in ("!key!") do set "key=%%d"
                for /f "tokens=* delims= " %%d in ("!value!") do set "value=%%d"

                if "!key!"=="name" set "TOOL_NAME=!value!"
                if "!key!"=="description" set "TOOL_DESC=!value!"
                if "!key!"=="source" set "TOOL_SOURCE=!value!"
                if "!key!"=="target" set "TOOL_TARGET=!value!"
                if "!key!"=="instructions_file" set "TOOL_INSTRUCTIONS_FILE=!value!"
            )
        )
    )

    :continue_parse
)

:done_parse
if "!found!"=="false" (
    call :print_error "Error: Tool '%search_tool_id%' not found in configuration"
    echo.
    echo Available tools:
    call :list_tools
    exit /b 1
)

:: Validate required fields
if "!TOOL_SOURCE!"=="" (
    call :print_error "Error: Invalid configuration for tool '%search_tool_id%'"
    echo Required fields: source, target
    exit /b 1
)
if "!TOOL_TARGET!"=="" (
    call :print_error "Error: Invalid configuration for tool '%search_tool_id%'"
    echo Required fields: source, target
    exit /b 1
)

exit /b 0

:install_tool
set "tool_id=%~1"
set "target_dir=%~2"

:: Parse configuration
call :parse_tool_config "%tool_id%"
if errorlevel 1 exit /b 1

call :print_blue "Installing: "
echo !TOOL_NAME!
call :print_blue "Description: "
echo !TOOL_DESC!
echo.

:: Resolve paths
set "source_path=%SCRIPT_DIR%\!TOOL_SOURCE!"
set "target_path=%target_dir%\!TOOL_TARGET!"

:: Validate source exists
if not exist "%source_path%" (
    call :print_error "Error: Source directory not found: %source_path%"
    exit /b 1
)

:: Validate instructions file exists if specified
if not "!TOOL_INSTRUCTIONS_FILE!"=="" (
    if not exist "%target_dir%\!TOOL_INSTRUCTIONS_FILE!" (
        call :print_error "Error: Instructions file not found: %target_dir%\!TOOL_INSTRUCTIONS_FILE!"
        echo The tool requires '!TOOL_INSTRUCTIONS_FILE!' to exist in the target directory.
        exit /b 1
    )
)

:: Check if target already exists
if exist "%target_path%" (
    call :print_yellow "Warning: Target directory already exists: %target_path%"
    set /p "confirm=Overwrite? (y/N): "
    if /i not "!confirm!"=="y" (
        echo Installation cancelled.
        exit /b 0
    )
    call :print_yellow "Removing existing directory..."
    rd /s /q "%target_path%" 2>nul
)

:: Create parent directory if needed
for %%i in ("%target_path%") do set "parent_dir=%%~dpi"
if not exist "%parent_dir%" mkdir "%parent_dir%"

:: Copy files (excluding files starting with '_')
call :print_blue "Copying files..."
echo   From: %source_path%
echo   To:   %target_path%

:: Copy all files except those starting with '_'
xcopy /E /I /Q /Y "%source_path%" "%target_path%" /EXCLUDE:%SCRIPT_DIR%\_exclude.tmp >nul 2>&1
if errorlevel 1 (
    :: If exclude file doesn't work, try manual filtering
    for /r "%source_path%" %%f in (*) do (
        set "fname=%%~nxf"
        if not "!fname:~0,1!"=="_" (
            set "relpath=%%f"
            set "relpath=!relpath:%source_path%=!"
            set "destfile=%target_path%!relpath!"
            for %%d in ("!destfile!") do if not exist "%%~dpd" mkdir "%%~dpd" 2>nul
            copy /Y "%%f" "!destfile!" >nul 2>&1
        )
    )
)

:: Remove any underscore files that might have been copied
for /r "%target_path%" %%f in (_*) do (
    if exist "%%f" del /q "%%f" 2>nul
)

:: Handle _add_instructions.md if it exists
if not "!TOOL_INSTRUCTIONS_FILE!"=="" (
    if exist "%source_path%\_add_instructions.md" (
        :: Check if already appended (idempotent)
        set "marker=<!-- codegenial:!TOOL_SOURCE!:added -->"
        findstr /C:"!marker!" "%target_dir%\!TOOL_INSTRUCTIONS_FILE!" >nul 2>&1
        if not errorlevel 1 (
            call :print_yellow "Additional instructions already present, skipping..."
        ) else (
            call :print_blue "Appending additional instructions..."
            echo. >> "%target_dir%\!TOOL_INSTRUCTIONS_FILE!"
            echo # Additional Tool Instructions >> "%target_dir%\!TOOL_INSTRUCTIONS_FILE!"
            echo. >> "%target_dir%\!TOOL_INSTRUCTIONS_FILE!"
            type "%source_path%\_add_instructions.md" >> "%target_dir%\!TOOL_INSTRUCTIONS_FILE!"
            echo. >> "%target_dir%\!TOOL_INSTRUCTIONS_FILE!"
            echo !marker! >> "%target_dir%\!TOOL_INSTRUCTIONS_FILE!"
        )
    )
)

echo.
call :print_green "√ Installation complete!"
echo.
echo Files installed to: %target_path%

:: Show next steps based on tool
if /i "%tool_id%"=="claude" (
    echo.
    echo Next steps:
    echo   1. Navigate to your project: cd %target_dir%
    echo   2. Run builds with log analysis: .\.claude\commands\build-and-summarize
    echo   3. View available agents: dir .claude\agents\
)

exit /b 0

:print_tool
echo [94m  %~1[0m %~2 - %~3
exit /b 0

:print_error
echo [91m%~1[0m
exit /b 0

:print_green
echo [92m%~1[0m
exit /b 0

:print_yellow
echo [93m%~1[0m
exit /b 0

:print_blue
echo [94m%~1[0m
exit /b 0
