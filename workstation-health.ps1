<# 
  workstation-health.ps1
  Quick health check for the hedglen workstation layout and core tooling.
  Safe to run often; uses -DryRun for heavy installers.
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

function Step  { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function OK    { param([string]$Msg) Write-Host "   OK  $Msg" -ForegroundColor Green }
function Warn  { param([string]$Msg) Write-Host "   !!  $Msg" -ForegroundColor Yellow }
function Fail  { param([string]$Msg) Write-Host "   XX  $Msg" -ForegroundColor Red }

$root   = "C:\Users\rjh\workstation"
$errors = @()

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   hedglen workstation — health check" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""

Step "Validating canonical layout"

if (-not (Test-Path $root)) {
    Fail "Canonical root not found at $root"
    $errors += "RootMissing"
} else {
    OK "Root exists: $root"
}

$expectedDirs = @(
    "dotfiles",
    "scripts",
    "tools",
    "projects",
    "docs",
    "hedglen-profile",
    "mpv-config",
    "assets",
    "notes"
)

foreach ($d in $expectedDirs) {
    $p = Join-Path $root $d
    if (Test-Path $p) {
        OK "$d present"
    } else {
        Warn "$d missing (optional or not yet created)"
    }
}

Step "Checking compatibility junctions"

$compatTools = Join-Path $env:USERPROFILE "tools"
if (Test-Path $compatTools) {
    try {
        $item = Get-Item $compatTools -ErrorAction Stop
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $target = (Get-Item $compatTools).Target
            if ($target -eq "$root\tools") {
                OK "%USERPROFILE%\tools is a junction → $root\tools"
            } else {
                Warn "%USERPROFILE%\tools points to '$target' (expected $root\tools)"
            }
        } else {
            Warn "%USERPROFILE%\tools exists but is not a junction"
        }
    } catch {
        Warn "Unable to inspect %USERPROFILE%\tools: $_"
    }
} else {
    Warn "%USERPROFILE%\tools not present (compat junction optional)"
}

Step "Checking core tools on PATH"

$commands = @("git", "winget", "code", "pwsh", "AutoHotkey.exe")
foreach ($c in $commands) {
    if (Get-Command $c -ErrorAction SilentlyContinue) {
        OK "$c found"
    } else {
        Warn "$c not found"
        if ($c -in @("git", "winget")) {
            $errors += "Missing:$c"
        }
    }
}

Step "Dry-run: dotfiles/install.ps1"

$dotfilesDir = Join-Path $root "dotfiles"
$dotfilesScript = Join-Path $dotfilesDir "install.ps1"
if (Test-Path $dotfilesScript) {
    try {
        Push-Location $dotfilesDir
        if ($Verbose) {
            .\install.ps1 -DryRun
        } else {
            .\install.ps1 -DryRun | Out-Null
        }
        OK "dotfiles/install.ps1 -DryRun completed"
    } catch {
        Fail "dotfiles/install.ps1 -DryRun failed: $_"
        $errors += "DotfilesDryRunFailed"
    } finally {
        Pop-Location
    }
} else {
    Fail "dotfiles/install.ps1 not found at $dotfilesScript"
    $errors += "DotfilesMissing"
}

Step "Dry-run: mpv-config/install.ps1"

$mpvConfigDir = Join-Path $root "mpv-config"
$mpvConfigScript = Join-Path $mpvConfigDir "install.ps1"
$mpvInstallDir = "$env:USERPROFILE\workstation\tools\mpv"

if (Test-Path $mpvConfigScript) {
    try {
        Push-Location $mpvConfigDir
        if ($Verbose) {
            .\install.ps1 -DryRun -InstallDir $mpvInstallDir
        } else {
            .\install.ps1 -DryRun -InstallDir $mpvInstallDir | Out-Null
        }
        OK "mpv-config/install.ps1 -DryRun completed"
    } catch {
        Warn "mpv-config/install.ps1 -DryRun failed: $_"
        $errors += "MpvDryRunFailed"
    } finally {
        Pop-Location
    }
} else {
    Warn "mpv-config/install.ps1 not found at $mpvConfigScript (mpv stack not yet installed)"
}

Step "Spot-check key configs"

$checks = @(
    @{
        desc = "PowerShell profile"
        path = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    },
    @{
        desc = "VS Code settings"
        path = "$HOME\AppData\Roaming\Code\User\settings.json"
    },
    @{
        desc = "Windows Terminal settings"
        path = "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    }
)

foreach ($c in $checks) {
    if (Test-Path $c.path) {
        $item = Get-Item $c.path
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            OK "$($c.desc): present (symlink)"
        } else {
            OK "$($c.desc): present"
        }
    } else {
        Warn "$($c.desc): not found"
    }
}

Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "   Health check PASSED" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "   Health check completed with issues" -ForegroundColor Red
    Write-Host "   Details: $($errors -join ', ')" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    exit 1
}

