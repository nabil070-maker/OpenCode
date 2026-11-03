#requires -Version 5.1
<#
    OpenCode Portable - Windows setup script
    Downloads a portable Node.js runtime and installs OpenCode locally,
    with everything contained inside the portable folder.
    Safe to re-run: skips steps that are already satisfied.
#>

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"  # much faster Invoke-WebRequest on PS 5.1

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
$NodeVersion = "26.13.0"
$OpenCodePackage = "opencode-ai@latest"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$Root        = Split-Path -Parent $PSScriptRoot
$RuntimeDir  = Join-Path $Root "runtime\node"
$AppNpmDir   = Join-Path $Root "app\npm"
$CacheDir    = Join-Path $Root "cache\npm"
$ProfileDir  = Join-Path $Root "profile"
$ConfigHome  = Join-Path $ProfileDir ".config"
$DataHome    = Join-Path $ProfileDir ".local\share"
$CacheHome   = Join-Path $ProfileDir ".cache"
$TempDir     = Join-Path $Root "temp"
$WorkspaceDir = Join-Path $Root "workspace"

$NodeExe = Join-Path $RuntimeDir "node.exe"
$NpmCmd  = Join-Path $RuntimeDir "npm.cmd"
$OpenCodeCmd = Join-Path $AppNpmDir "opencode.cmd"

function Write-Info    { param($msg) Write-Host "[INFO] $msg" }
function Write-Ok      { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Step    { param($msg) Write-Host "[*] $msg" }
function Write-Err     { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# Ensure folder structure exists
# ---------------------------------------------------------------------------
$foldersToCreate = @(
    (Join-Path $Root "runtime"),
    $AppNpmDir,
    $CacheDir,
    $ConfigHome,
    $DataHome,
    $CacheHome,
    $TempDir,
    $WorkspaceDir
)
foreach ($folder in $foldersToCreate) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Portable environment (current process only)
# ---------------------------------------------------------------------------
$env:HOME             = $ProfileDir
$env:USERPROFILE      = $ProfileDir
$env:XDG_CONFIG_HOME  = $ConfigHome
$env:XDG_DATA_HOME    = $DataHome
$env:XDG_CACHE_HOME   = $CacheHome
$env:TEMP             = $TempDir
$env:TMP              = $TempDir
$env:NPM_CONFIG_PREFIX = $AppNpmDir
$env:NPM_CONFIG_CACHE  = $CacheDir
$env:OPENCODE_CONFIG_DIR = Join-Path $ConfigHome "opencode"
$env:Path = "$RuntimeDir;$env:Path"

# ---------------------------------------------------------------------------
# Step 1: Portable Node.js
# ---------------------------------------------------------------------------
$needNode = $true
if (Test-Path $NodeExe) {
    try {
        $installedVersion = (& $NodeExe --version) -replace "^v", ""
        if ($installedVersion -eq $NodeVersion) {
            Write-Ok "Node.js v$NodeVersion already installed."
            $needNode = $false
        } else {
            Write-Info "Found Node.js v$installedVersion, expected v$NodeVersion. Reinstalling."
        }
    } catch {
        Write-Info "Existing Node.js binary looks broken. Reinstalling."
    }
}

if ($needNode) {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq "ARM64") {
        $nodeArch = "arm64"
    } elseif ($arch -eq "AMD64") {
        $nodeArch = "x64"
    } else {
        Write-Err "Unsupported architecture: $arch. This setup supports x64 and arm64."
        exit 1
    }

    $zipName = "node-v$NodeVersion-win-$nodeArch.zip"
    $downloadUrl = "https://nodejs.org/dist/v$NodeVersion/$zipName"
    $zipPath = Join-Path $TempDir $zipName
    $extractDir = Join-Path $TempDir "node-extract"

    Write-Step "Downloading Node.js v$NodeVersion ($nodeArch)..."
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        Write-Err "Failed to download Node.js from $downloadUrl"
        Write-Err $_.Exception.Message
        exit 1
    }

    Write-Step "Extracting Node.js..."
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    } catch {
        Write-Err "Failed to extract Node.js archive."
        Write-Err $_.Exception.Message
        exit 1
    }

    $extractedNodeFolder = Join-Path $extractDir "node-v$NodeVersion-win-$nodeArch"
    if (-not (Test-Path $extractedNodeFolder)) {
        Write-Err "Expected extracted folder not found: $extractedNodeFolder"
        exit 1
    }

    if (Test-Path $RuntimeDir) { Remove-Item $RuntimeDir -Recurse -Force }
    Move-Item -Path $extractedNodeFolder -Destination $RuntimeDir -Force

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path $NodeExe)) {
        Write-Err "Node.js extraction did not produce node.exe at expected path: $NodeExe"
        exit 1
    }
    Write-Ok "Node.js v$NodeVersion installed to $RuntimeDir"
}

# ---------------------------------------------------------------------------
# Step 2: OpenCode (installed via the portable npm)
# ---------------------------------------------------------------------------
$needOpenCode = $true
if (Test-Path $OpenCodeCmd) {
    try {
        $ocVersion = & $OpenCodeCmd --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $ocVersion) {
            Write-Ok "OpenCode already installed (version: $ocVersion)."
            $needOpenCode = $false
        }
    } catch {
        Write-Info "Existing OpenCode install looks broken. Reinstalling."
    }
}

if ($needOpenCode) {
    Write-Step "Installing OpenCode ($OpenCodePackage) via portable npm..."
    & $NpmCmd install -g $OpenCodePackage --prefix $AppNpmDir --cache $CacheDir
    if ($LASTEXITCODE -ne 0) {
        Write-Err "npm install failed for $OpenCodePackage"
        exit 1
    }
    if (-not (Test-Path $OpenCodeCmd)) {
        Write-Err "Expected OpenCode executable not found at: $OpenCodeCmd"
        exit 1
    }
    Write-Ok "OpenCode installed to $AppNpmDir"
}

# ---------------------------------------------------------------------------
# Step 3: Verify
# ---------------------------------------------------------------------------
Write-Step "Verifying installation..."
$nodeV = & $NodeExe --version
$npmV  = & $NpmCmd --version
$ocV   = & $OpenCodeCmd --version

Write-Ok "node:     $nodeV"
Write-Ok "npm:      $npmV"
Write-Ok "opencode: $ocV"
Write-Ok "Setup complete."
