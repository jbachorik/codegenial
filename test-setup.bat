@echo off
setlocal enabledelayedexpansion

:: Colors for output (using ANSI escape codes)
set "GREEN=[92m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "TEST_DIR=%SCRIPT_DIR%\test-install"
set "PASSED=0"
set "FAILED=0"

echo ======================================
echo   Setup Script Smoke Tests (Windows)
echo ======================================
echo.

cd /d "%SCRIPT_DIR%"

:: Test 1: Setup.bat exists
echo %BLUE%TEST:%NC% Setup.bat exists
if not exist "%SCRIPT_DIR%\setup.bat" (
    echo %RED%X FAIL%NC%: setup.bat not found
    set /a FAILED+=1
) else (
    echo %GREEN%/ PASS%NC%
    set /a PASSED+=1
)
echo.

:: Test 2: Tools.conf exists
echo %BLUE%TEST:%NC% tools.conf exists
if not exist "%SCRIPT_DIR%\tools.conf" (
    echo %RED%X FAIL%NC%: tools.conf not found
    set /a FAILED+=1
) else (
    echo %GREEN%/ PASS%NC%
    set /a PASSED+=1
)
echo.

:: Test 3: Source directory exists
echo %BLUE%TEST:%NC% Source directory for claude tool exists
if not exist "%SCRIPT_DIR%\claude" (
    echo %RED%X FAIL%NC%: claude directory not found
    set /a FAILED+=1
    goto :skip_source_checks
)
if not exist "%SCRIPT_DIR%\claude\agents" (
    echo %RED%X FAIL%NC%: claude\agents directory not found
    set /a FAILED+=1
    goto :skip_source_checks
)
if not exist "%SCRIPT_DIR%\claude\commands" (
    echo %RED%X FAIL%NC%: claude\commands directory not found
    set /a FAILED+=1
    goto :skip_source_checks
)
echo %GREEN%/ PASS%NC%
set /a PASSED+=1
:skip_source_checks
echo.

:: Test 4: Setup list command works
echo %BLUE%TEST:%NC% setup.bat list command works
echo === DEBUG OUTPUT START ===
call "%SCRIPT_DIR%\setup.bat" list >nul
echo === DEBUG OUTPUT END ===
if errorlevel 1 (
    echo %RED%X FAIL%NC%: list command failed with errorlevel %errorlevel%
    set /a FAILED+=1
) else (
    echo %GREEN%/ PASS%NC%
    set /a PASSED+=1
)
echo.

:: Test 5: Invalid tool name fails gracefully
echo %BLUE%TEST:%NC% Invalid tool name fails gracefully
if exist "%TEST_DIR%" rd /s /q "%TEST_DIR%" 2>nul
mkdir "%TEST_DIR%"
echo === DEBUG OUTPUT START (invalid tool test) ===
call "%SCRIPT_DIR%\setup.bat" nonexistent "%TEST_DIR%" >nul
echo === DEBUG OUTPUT END ===
if errorlevel 1 (
    echo %GREEN%/ PASS%NC%
    set /a PASSED+=1
) else (
    echo %RED%X FAIL%NC%: should have failed with invalid tool
    set /a FAILED+=1
)
echo.

:: Test 6: Missing target directory fails
echo %BLUE%TEST:%NC% Missing target directory fails gracefully
call "%SCRIPT_DIR%\setup.bat" claude "C:\nonexistent\path\%RANDOM%" >nul 2>&1
if errorlevel 1 (
    echo %GREEN%/ PASS%NC%
    set /a PASSED+=1
) else (
    echo %RED%X FAIL%NC%: should have failed with nonexistent directory
    set /a FAILED+=1
)
echo.

:: Test 7: Actual installation to temp directory
echo %BLUE%TEST:%NC% Actual installation to temporary directory

:: Clean and create test directory
if exist "%TEST_DIR%" rd /s /q "%TEST_DIR%" 2>nul
mkdir "%TEST_DIR%"

:: Run installation (automatically answer 'y' if prompted)
echo === DEBUG OUTPUT START (installation test) ===
echo y| call "%SCRIPT_DIR%\setup.bat" claude "%TEST_DIR%" >nul
echo === DEBUG OUTPUT END ===

:: Check if installation succeeded
if not exist "%TEST_DIR%\.claude" (
    echo %RED%X FAIL%NC%: .claude directory was not created
    set /a FAILED+=1
    goto :cleanup_test7
)

if not exist "%TEST_DIR%\.claude\agents" (
    echo %RED%X FAIL%NC%: agents directory was not copied
    set /a FAILED+=1
    goto :cleanup_test7
)

if not exist "%TEST_DIR%\.claude\commands" (
    echo %RED%X FAIL%NC%: commands directory was not copied
    set /a FAILED+=1
    goto :cleanup_test7
)

if not exist "%TEST_DIR%\.claude\agents\build-logs-analyst.md" (
    echo %RED%X FAIL%NC%: build-logs-analyst.md was not copied
    set /a FAILED+=1
    goto :cleanup_test7
)

if not exist "%TEST_DIR%\.claude\commands\build-and-summarize" (
    echo %RED%X FAIL%NC%: build-and-summarize was not copied
    set /a FAILED+=1
    goto :cleanup_test7
)

echo %GREEN%/ PASS%NC%
set /a PASSED+=1

:cleanup_test7
echo.

:: Test 8: Overwrite detection
echo %BLUE%TEST:%NC% Overwrite prompt works for existing installation

:: Installation already exists from test 7
if exist "%TEST_DIR%\.claude" (
    :: Create a marker file
    echo test > "%TEST_DIR%\.claude\marker.txt"

    :: Try to install again, answer 'n' to overwrite prompt
    echo n| call "%SCRIPT_DIR%\setup.bat" claude "%TEST_DIR%" >nul 2>&1

    :: Marker should still exist (we said no)
    if exist "%TEST_DIR%\.claude\marker.txt" (
        :: Now try with 'y'
        echo y| call "%SCRIPT_DIR%\setup.bat" claude "%TEST_DIR%" >nul 2>&1

        :: Marker should be gone (we said yes)
        if exist "%TEST_DIR%\.claude\marker.txt" (
            echo %RED%X FAIL%NC%: old installation should have been removed
            set /a FAILED+=1
        ) else (
            echo %GREEN%/ PASS%NC%
            set /a PASSED+=1
        )
    ) else (
        echo %RED%X FAIL%NC%: installation should have been cancelled
        set /a FAILED+=1
    )
) else (
    echo %RED%X FAIL%NC%: test directory doesn't exist
    set /a FAILED+=1
)
echo.

:: Cleanup
if exist "%TEST_DIR%" rd /s /q "%TEST_DIR%" 2>nul

:: Summary
echo ======================================
echo   Test Summary
echo ======================================
echo %GREEN%Passed: %PASSED%%NC%

if %FAILED% gtr 0 (
    echo %RED%Failed: %FAILED%%NC%
    echo.
    exit /b 1
) else (
    echo %GREEN%All tests passed!%NC%
    echo.
    exit /b 0
)
