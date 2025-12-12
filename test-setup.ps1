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
} elseif (-not (Test-Path (Join-Path $ScriptDir "claudegents"))) {
    Write-Host "${RED}X FAIL${NC}: claudegents directory not found"
    $Failed++
} elseif (-not (Test-Path (Join-Path $ScriptDir "claude