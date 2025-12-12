#Requires -Version 3.0

param(
    [Parameter(Position=0)]
    [string]$ToolId,
    
    [Parameter(Position=1)]
    [string]$TargetDirectory
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "tools.conf"

function Parse-ConfigFile {
    param([string]$FilePath, [string]$SearchToolId)
    
    $inTool = $false
    $found = $false
    $tool = @{}
    
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ($line -eq "" -or $line.StartsWith("#")) {
            return
        }
        
        # Check for section header [tool-id]
        if ($line -match '^\[(.+)\]$') {
            if ($inTool) {
                # Finished reading our tool section
                return
            }
            
            $currentId = $matches[1]
            if ($currentId -eq $SearchToolId) {
                $inTool = $true
                $found = $true
            }
            return
        }
        
        # Parse key=value pairs
        if ($inTool -and $line -match '^([^=]+)=(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $tool[$key] = $value
        }
    }
    
    if (-not $found) {
        return $null
    }
    
    return $tool
}

function List-Tools {
    if (-not (Test-Path $ConfigFile)) {
        Write-Host ('Error: Configuration file not found: {0}' -f $ConfigFile) -ForegroundColor Red
        return
    }
    
    $currentTool = $null
    
    Get-Content $ConfigFile | ForEach-Object {
        $line = $_.Trim()
        
        # Skip empty lines and comments
        if ($line -eq "" -or $line.StartsWith("#")) {
            return
        }
        
        # Check for section header
        if ($line -match '^\[(.+)\]$') {
            # Print previous tool if exists
            if ($currentTool) {
                $id = $currentTool.id.PadRight(12)
                Write-Host "  " -NoNewline
                Write-Host $id -ForegroundColor Blue -NoNewline
                Write-Host " $($currentTool.name) - $($currentTool.description)"
            }
            
            $currentTool = @{
                id = $matches[1]
                name = ""
                description = ""
            }
            return
        }
        
        # Parse key=value pairs
        if ($currentTool -and $line -match '^([^=]+)=(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            if ($key -eq "name") {
                $currentTool.name = $value
            } elseif ($key -eq "description") {
                $currentTool.description = $value
            }
        }
    }
    
    # Print last tool
    if ($currentTool) {
        $id = $currentTool.id.PadRight(12)
        Write-Host "  " -NoNewline
        Write-Host $id -ForegroundColor Blue -NoNewline
        Write-Host " $($currentTool.name) - $($currentTool.description)"
    }
}

function Show-Usage {
    Write-Host "Usage: setup.ps1 <tool-id> <target-directory>"
    Write-Host ""
    Write-Host "Install codegenial tools to your project."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  tool-id           Tool identifier from tools.conf (e.g., 'claude')"
    Write-Host "  target-directory  Project directory where tools will be installed"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\setup.ps1 claude C:\my-project"
    Write-Host "  .\setup.ps1 cursor ."
    Write-Host ""
    Write-Host "Available tools:"
    List-Tools
}

# Main script logic
if (-not $ToolId -or $ToolId -eq "-h" -or $ToolId -eq "--help" -or $ToolId -eq "/?") {
    Show-Usage
    exit 1
}

if ($ToolId -eq "list") {
    Write-Host "Available tools:"
    List-Tools
    exit 0
}

if (-not $TargetDirectory) {
    Write-Error "Error: Invalid number of arguments"
    Write-Host ""
    Show-Usage
    exit 1
}

# Resolve target directory
if (-not (Test-Path $TargetDirectory)) {
    Write-Host ('Error: Target directory does not exist: {0}' -f $TargetDirectory) -ForegroundColor Red
    exit 1
}

$TargetDirectory = Resolve-Path $TargetDirectory

# Parse configuration
$tool = Parse-ConfigFile -FilePath $ConfigFile -SearchToolId $ToolId

if (-not $tool) {
    Write-Error "Error: Tool '$ToolId' not found in configuration"
    Write-Host ""
    Write-Host "Available tools:"
    List-Tools
    exit 1
}

# Validate required fields
if (-not $tool.source -or -not $tool.target) {
    Write-Error "Error: Invalid configuration for tool '$ToolId'"
    Write-Host "Required fields: source, target"
    exit 1
}

Write-Host "Installing: " -NoNewline -ForegroundColor Blue
Write-Host $tool.name
Write-Host "Description: " -NoNewline -ForegroundColor Blue
Write-Host $tool.description
Write-Host ""

# Resolve paths
$sourcePath = Join-Path $ScriptDir $tool.source
$targetPath = Join-Path $TargetDirectory $tool.target

# Validate source exists
if (-not (Test-Path $sourcePath)) {
    Write-Host ('Error: Source directory not found: {0}' -f $sourcePath) -ForegroundColor Red
    exit 1
}

# Validate instructions file if specified
if ($tool.instructions_file) {
    $instructionsPath = Join-Path $TargetDirectory $tool.instructions_file
    if (-not (Test-Path $instructionsPath)) {
        Write-Host ('Error: Instructions file not found: {0}' -f $instructionsPath) -ForegroundColor Red
        Write-Host ("The tool requires '{0}' to exist in the target directory." -f $tool.instructions_file)
        exit 1
    }
}

# Check if target already exists
if (Test-Path $targetPath) {
    Write-Host ('Warning: Target directory already exists: {0}' -f $targetPath) -ForegroundColor Yellow
    $response = Read-Host "Overwrite? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Installation cancelled."
        exit 0
    }
    Write-Host "Removing existing directory..." -ForegroundColor Yellow
    Remove-Item -Path $targetPath -Recurse -Force
}

# Copy files (excluding files starting with '_')
Write-Host "Copying files..." -ForegroundColor Blue
Write-Host ('  From: {0}' -f $sourcePath)
Write-Host ('  To:   {0}' -f $targetPath)

# Create target directory
New-Item -ItemType Directory -Path $targetPath -Force | Out-Null

# Copy all files except those starting with '_'
Get-ChildItem -Path $sourcePath -Recurse | Where-Object {
    -not $_.Name.StartsWith("_")
} | ForEach-Object {
    $relativePath = $_.FullName.Substring($sourcePath.Length + 1)
    $destPath = Join-Path $targetPath $relativePath
    
    if ($_.PSIsContainer) {
        New-Item -ItemType Directory -Path $destPath -Force | Out-Null
    } else {
        $destDir = Split-Path -Parent $destPath
        if ($destDir -and -not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $_.FullName -Destination $destPath -Force
    }
}

# Handle _add_instructions.md if it exists
if ($tool.instructions_file) {
    $addInstructionsFile = Join-Path $sourcePath "_add_instructions.md"
    if (Test-Path $addInstructionsFile) {
        $instructionsPath = Join-Path $TargetDirectory $tool.instructions_file
        $marker = "<!-- codegenial:$($tool.source):added -->"
        
        $content = Get-Content $instructionsPath -Raw
        if ($content -notmatch [regex]::Escape($marker)) {
            Write-Host "Appending additional instructions..." -ForegroundColor Blue
            Add-Content -Path $instructionsPath -Value ""
            Add-Content -Path $instructionsPath -Value "# Additional Tool Instructions"
            Add-Content -Path $instructionsPath -Value ""
            Get-Content $addInstructionsFile | Add-Content -Path $instructionsPath
            Add-Content -Path $instructionsPath -Value ""
            Add-Content -Path $instructionsPath -Value $marker
        } else {
            Write-Host "Additional instructions already present, skipping..." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host ('Files installed to: {0}' -f $targetPath)

# Show next steps based on tool
if ($ToolId -eq "claude") {
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host ('  1. Navigate to your project: cd {0}' -f $TargetDirectory)
    Write-Host '  2. Run builds with log analysis: .\.claude\commands\build-and-summarize'
    Write-Host '  3. View available agents: dir .claude\agents\'
}
