#Requires -Version 3.0

$ErrorActionPreference = "Stop"

# Colors for output
$GREEN = "`e[92m"
$RED = "`e[91m"
$BLUE = "`e[94m"
$NC = "`e[0m"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestDir = Join-Path $ScriptDir "test-install"
$Passed = 0
$Failed = 0

Write-Host "======================================"
Write-Host "  Setup Script Smoke Tests (Windows)"
Write-Host "======================================"
Write-Host ""

Set-Location $ScriptDir

# Test 1: Setup.ps1 exists
Write-Host "${BLUE}TEST:${NC} Setup.ps1 exists"
if (-not (Test-Path (Join-Path $ScriptDir "setup.ps1"))) {
    Write-Host "${RED}X FAIL${NC}: setup.ps1 not found"
    $Failed++
} else {
    Write-Host "${GREEN}/ PASS${NC}"
    $Passed++
}
Write-Host ""

# Test 2: Tools.conf exists
Write-Host "${BLUE}TEST:${NC} tools.conf exists"
if (-not (Test-Path (Join-Path $ScriptDir "tools.conf"))) {
    Write-Host "${RED}X FAIL${NC}: tools.conf not found"
    $Failed++
} else {
    Write-Host "${GREEN}/ PASS${NC}"
    $Passed++
}
Write-Host ""

# Test 3: Source directory exists
Write-Host "${BLUE}TEST:${NC} Source directory for claude tool exists"
if (-not (Test-Path (Join-Path $ScriptDir "claude"))) {
    Write-Host "${RED}X FAIL${NC}: claude directory not found"
    $Failed++
} elseif (-not (Test-Path (Join-Path $ScriptDir "claude\agents"))) {
    Write-Host "${RED}X FAIL${NC}: claude\agents directory not found"
    $Failed++
} elseif (-not (Test-Path (Join-Path $ScriptDir "claude\commands"))) {
    Write-Host "${RED}X FAIL${NC}: claude\commands directory not found"
    $Failed++
} else {
    Write-Host "${GREEN}/ PASS${NC}"
    $Passed++
}
Write-Host ""

# Test 4: Setup list command works
Write-Host "${BLUE}TEST:${NC} setup.ps1 list command works"
try {
    $output = & (Join-Path $ScriptDir "setup.ps1") list 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "list command failed with exit code $LASTEXITCODE"
    }
    Write-Host "${GREEN}/ PASS${NC}"
    $Passed++
} catch {
    Write-Host "${RED}X FAIL${NC}: $($_.Exception.Message)"
    $Failed++
}
Write-Host ""

# Test 5: Invalid tool name fails gracefully
Write-Host "${BLUE}TEST:${NC} Invalid tool name fails gracefully"
if (Test-Path $TestDir) {
    Remove-Item -Path $TestDir -Recurse -Force
}
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

try {
    $output = & (Join-Path $ScriptDir "setup.ps1") nonexistent "$TestDir" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "${RED}X FAIL${NC}: should have failed with invalid tool"
        $Failed++
    } else {
        Write-Host "${GREEN}/ PASS${NC}"
        $Passed++
    }
} catch {
    Write-Host "${GREEN}/ PASS${NC}"
    $Passed++
}
Write-Host ""

# Test 6: Missing target directory fails
Write-Host "${BLUE}TEST:${NC} Missing target directory fails gracefully"
try {
    $randomPath = "C:\nonexistent\path\$([System.Guid]::NewGuid())"
    $output = & (Join-Path $ScriptDir "setup.ps1") claude "$randomPath" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "${RED}X FAIL${NC}: should have failed with nonexistent directory"
        $Failed++
    } else {
        Write-Host "${GREEN}/ PASS${NC}"
        $Passed++
    }
} catch {
    Write-Host "${GREEN}/ PASS${NC}"
    $Passed++
}
Write-Host ""

# Test 7: Actual installation to temp directory
Write-Host "${BLUE}TEST:${NC} Actual installation to temporary directory"

# Clean and create test directory
if (Test-Path $TestDir) {
    Remove-Item -Path $TestDir -Recurse -Force
}
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

# Create required CLAUDE.md file (the claude tool requires this)
"# Test Instructions" | Out-File -FilePath (Join-Path $TestDir "CLAUDE.md")

# Run installation with -Force to skip prompts
try {
    $output = & (Join-Path $ScriptDir "setup.ps1") claude "$TestDir" -Force 2>&1

    # Check if installation succeeded
    if (-not (Test-Path (Join-Path $TestDir ".claude"))) {
        Write-Host "${RED}X FAIL${NC}: .claude directory was not created"
        $Failed++
    } elseif (-not (Test-Path (Join-Path $TestDir ".claude\agents"))) {
        Write-Host "${RED}X FAIL${NC}: agents directory was not copied"
        $Failed++
    } elseif (-not (Test-Path (Join-Path $TestDir ".claude\commands"))) {
        Write-Host "${RED}X FAIL${NC}: commands directory was not copied"
        $Failed++
    } elseif (-not (Test-Path (Join-Path $TestDir ".claude\agents\build-logs-analyst.md"))) {
        Write-Host "${RED}X FAIL${NC}: build-logs-analyst.md was not copied"
        $Failed++
    } elseif (-not (Test-Path (Join-Path $TestDir ".claude\commands\build-and-summarize"))) {
        Write-Host "${RED}X FAIL${NC}: build-and-summarize was not copied"
        $Failed++
    } else {
        Write-Host "${GREEN}/ PASS${NC}"
        $Passed++
    }
} catch {
    Write-Host "${RED}X FAIL${NC}: $($_.Exception.Message)"
    $Failed++
}
Write-Host ""

# Test 8: Overwrite detection
Write-Host "${BLUE}TEST:${NC} Overwrite prompt works for existing installation"

# Installation already exists from test 7
if (Test-Path (Join-Path $TestDir ".claude")) {
    # Create a marker file
    "test" | Out-File -FilePath (Join-Path $TestDir ".claude\marker.txt")

    # Try to install again without -Force (should prompt, but we can't answer)
    # So we'll just test with -Force which should overwrite
    try {
        # First verify marker exists before overwrite
        if (-not (Test-Path (Join-Path $TestDir ".claude\marker.txt"))) {
            Write-Host "${RED}X FAIL${NC}: marker file should exist before overwrite test"
            $Failed++
        } else {
            # Now overwrite with -Force
            $output = & (Join-Path $ScriptDir "setup.ps1") claude "$TestDir" -Force 2>&1

            # Marker should be gone (overwritten with -Force)
            if (Test-Path (Join-Path $TestDir ".claude\marker.txt")) {
                Write-Host "${RED}X FAIL${NC}: old installation should have been removed"
                $Failed++
            } else {
                Write-Host "${GREEN}/ PASS${NC}"
                $Passed++
            }
        }
    } catch {
        Write-Host "${RED}X FAIL${NC}: $($_.Exception.Message)"
        $Failed++
    }
} else {
    Write-Host "${RED}X FAIL${NC}: test directory doesn't exist"
    $Failed++
}
Write-Host ""

# Cleanup
if (Test-Path $TestDir) {
    Remove-Item -Path $TestDir -Recurse -Force
}

# Summary
Write-Host "======================================"
Write-Host "  Test Summary"
Write-Host "======================================"
Write-Host "${GREEN}Passed: $Passed${NC}"

if ($Failed -gt 0) {
    Write-Host "${RED}Failed: $Failed${NC}"
    Write-Host ""
    exit 1
} else {
    Write-Host "${GREEN}All tests passed!${NC}"
    Write-Host ""
    exit 0
}
