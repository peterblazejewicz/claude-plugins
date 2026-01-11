#Requires -Version 7.0
<#
.SYNOPSIS
    Runs PSScriptAnalyzer on all PowerShell scripts in the repository.

.DESCRIPTION
    This script scans all .ps1 files in the repository using PSScriptAnalyzer
    with the settings defined in PSScriptAnalyzerSettings.psd1.

    Used by GitHub Actions workflow and can be run locally for development.

.PARAMETER SettingsPath
    Path to the PSScriptAnalyzer settings file. Defaults to ./PSScriptAnalyzerSettings.psd1

.EXAMPLE
    ./scripts/powershell-lint.ps1

    Runs PSScriptAnalyzer on all PowerShell scripts using default settings.

.EXAMPLE
    ./scripts/powershell-lint.ps1 -SettingsPath "./custom-settings.psd1"

    Runs PSScriptAnalyzer using a custom settings file.

.NOTES
    Exit codes:
    0 - No issues found
    1 - Issues found or settings file not found
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SettingsPath = './PSScriptAnalyzerSettings.psd1'
)

$ErrorActionPreference = 'Stop'

# Get repository root (parent of scripts directory)
$repoRoot = Split-Path -Parent $PSScriptRoot

# Resolve to absolute path from repository root
if (-not [System.IO.Path]::IsPathRooted($SettingsPath)) {
    $SettingsPath = Join-Path $repoRoot $SettingsPath
}

if (-not (Test-Path $SettingsPath)) {
    Write-Host "ERROR: Settings file not found at $SettingsPath" -ForegroundColor Red
    exit 1
}

Write-Host "Running PSScriptAnalyzer with settings from: $SettingsPath"
Write-Host ""

# Find all PowerShell script files
$scripts = Get-ChildItem -Path $repoRoot -Include '*.ps1' -Recurse

if ($scripts.Count -eq 0) {
    Write-Host "No PowerShell scripts (.ps1) found to scan." -ForegroundColor Yellow
    exit 0
}

Write-Host "Scanning $($scripts.Count) PowerShell file(s)..."
Write-Host ""

# Run analyzer on all scripts
$results = $scripts | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings $SettingsPath }

if ($results) {
    Write-Host "PSScriptAnalyzer found issues:" -ForegroundColor Yellow
    Write-Host ""
    $results | Format-Table -Property RuleName, Severity, ScriptName, Line, Message -AutoSize -Wrap
    Write-Host ""
    Write-Host "Total issues: $($results.Count)" -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host "PSScriptAnalyzer: No issues found in $($scripts.Count) file(s)" -ForegroundColor Green
    exit 0
}
