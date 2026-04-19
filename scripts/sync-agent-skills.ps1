#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Sync addyosmani/agent-skills into plugins/dotnet-skills/vendor/agent-skills.

.DESCRIPTION
  Shallow-fetches the upstream repo at the requested ref, copies its tree (minus
  .git, .github, node_modules) into vendor/agent-skills/, writes a per-file
  SHA256 manifest, and rewrites the pin + sync log blocks in UPSTREAM.md.

  Never commits. Review `git status` and commit manually.

.PARAMETER UpstreamRef
  Branch, tag, or full SHA to pin. Defaults to the SHA currently recorded in
  UPSTREAM.md; if none, defaults to "main".

.PARAMETER Repo
  Upstream repository URL. Defaults to https://github.com/addyosmani/agent-skills.git.

.PARAMETER Verify
  Drift-check only. Recomputes SHA256 for every vendor file and compares against
  .sync-manifest.json. Exits 0 on clean, 2 on drift. Does not touch upstream.

.EXAMPLE
  pwsh scripts/sync-agent-skills.ps1

.EXAMPLE
  pwsh scripts/sync-agent-skills.ps1 -UpstreamRef main

.EXAMPLE
  pwsh scripts/sync-agent-skills.ps1 -Verify
#>

[CmdletBinding()]
param(
    [string]$UpstreamRef,
    [string]$Repo = 'https://github.com/addyosmani/agent-skills.git',
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot     = Split-Path -Parent $PSScriptRoot
# Sync infrastructure lives OUTSIDE the plugin directory so it isn't shipped
# to end users when the plugin is installed from the marketplace.
$syncState    = Join-Path $repoRoot 'sync-state/dotnet-skills'
$vendorRoot   = Join-Path $syncState 'vendor/agent-skills'
$manifestPath = Join-Path $vendorRoot '.sync-manifest.json'
$upstreamMd   = Join-Path $syncState 'UPSTREAM.md'
$readmeTxt    = Join-Path $vendorRoot 'README.txt'

$excludeDirs = @('.git', '.github', 'node_modules')

function Fail([string]$msg, [int]$code = 1) {
    Write-Error $msg
    exit $code
}

function Get-VendorFileHash([string]$fullPath) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash.ToLowerInvariant()
}

function Get-RelativePath([string]$base, [string]$fullPath) {
    $baseNorm = [System.IO.Path]::GetFullPath($base).TrimEnd([char]'\', [char]'/')
    $full     = [System.IO.Path]::GetFullPath($fullPath)
    $rel      = $full.Substring($baseNorm.Length).TrimStart([char]'\', [char]'/')
    return $rel -replace '\\', '/'
}

function Read-PriorPin([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $content = Get-Content -Raw -LiteralPath $path
    if ($content -match '\|\s*Pinned commit SHA\s*\|\s*`([0-9a-f]{7,40})`') {
        return $Matches[1]
    }
    return $null
}

function Invoke-Git {
    param([string[]]$GitArgs, [string]$Cwd)
    $out = & git -C $Cwd @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail "git $($GitArgs -join ' ') failed in ${Cwd}:`n$out"
    }
    return ($out | Out-String).Trim()
}

function Test-DirExcluded([string]$dirName) {
    return $excludeDirs -contains $dirName
}

function Copy-UpstreamTree {
    param([string]$Source, [string]$Destination)
    Get-ChildItem -LiteralPath $Source -Force -Recurse -File | ForEach-Object {
        $rel = Get-RelativePath $Source $_.FullName
        # exclude files whose path descends from any excluded directory
        $segments = $rel -split '/'
        foreach ($seg in $segments) {
            if (Test-DirExcluded $seg) { return }
        }
        $destFile = Join-Path $Destination $rel
        $destDir  = Split-Path -Parent $destFile
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $_.FullName -Destination $destFile -Force
    }
}

function New-Manifest {
    param([string]$RootDir, [string]$UpstreamUrl, [string]$Sha, [string]$CommitDate)
    $files = @()
    Get-ChildItem -LiteralPath $RootDir -Force -Recurse -File | Sort-Object FullName | ForEach-Object {
        $rel = Get-RelativePath $RootDir $_.FullName
        # don't record the manifest or our own README in itself
        if ($rel -in @('.sync-manifest.json', 'README.txt')) { return }
        $files += [ordered]@{
            path   = $rel
            sha256 = Get-VendorFileHash $_.FullName
            bytes  = [int64]$_.Length
        }
    }
    return [ordered]@{
        upstream   = $UpstreamUrl
        ref        = $Sha
        commitDate = $CommitDate
        syncedAt   = (Get-Date).ToUniversalTime().ToString('o')
        files      = $files
    }
}

function Compare-Manifests {
    param([object]$Prev, [object]$Curr)
    $prevMap = @{}; $currMap = @{}
    if ($Prev -and $Prev.files) { foreach ($f in $Prev.files) { $prevMap[$f.path] = $f.sha256 } }
    if ($Curr -and $Curr.files) { foreach ($f in $Curr.files) { $currMap[$f.path] = $f.sha256 } }
    $added    = @($currMap.Keys | Where-Object { -not $prevMap.ContainsKey($_) })
    $removed  = @($prevMap.Keys | Where-Object { -not $currMap.ContainsKey($_) })
    $modified = @($currMap.Keys | Where-Object { $prevMap.ContainsKey($_) -and $prevMap[$_] -ne $currMap[$_] })
    return [pscustomobject]@{
        Added    = $added    | Sort-Object
        Removed  = $removed  | Sort-Object
        Modified = $modified | Sort-Object
    }
}

function Format-ChangeSummary([object]$diff) {
    $parts = @()
    if ($diff.Added)    { $parts += "$($diff.Added.Count) added" }
    if ($diff.Removed)  { $parts += "$($diff.Removed.Count) removed" }
    if ($diff.Modified) { $parts += "$($diff.Modified.Count) modified" }
    if (-not $parts)    { return 'no changes' }
    return ($parts -join ', ')
}

function Update-UpstreamMd {
    param(
        [string]$PriorSha,
        [string]$NewSha,
        [string]$SyncDate,
        [string]$ChangeSummary,
        [string]$LogLine
    )
    $shortNew = $NewSha.Substring(0, 7)
    $priorDisplay = if ($PriorSha) { "``$($PriorSha.Substring(0, 7))``" } else { '_(none — initial sync)_' }

    $pinBlock = @"
<!-- sync:pin:begin -->
| Field | Value |
|-------|-------|
| Upstream repository | https://github.com/addyosmani/agent-skills |
| Upstream license | MIT (© 2025 Addy Osmani) |
| Pinned commit SHA | ``$NewSha`` |
| Pinned commit (short) | ``$shortNew`` |
| Synced on | $SyncDate |
| Prior pin | $priorDisplay |
| Changed since prior pin | $ChangeSummary |
<!-- sync:pin:end -->
"@

    $content = Get-Content -Raw -LiteralPath $upstreamMd
    $pinPattern = '(?s)<!-- sync:pin:begin -->.*?<!-- sync:pin:end -->'
    $content = [regex]::Replace($content, $pinPattern, { param($m) $pinBlock })

    # Prepend new log entry inside the log markers
    $logPattern = '(?s)(<!-- sync:log:begin -->\r?\n)(.*?)(\r?\n<!-- sync:log:end -->)'
    $content = [regex]::Replace($content, $logPattern, {
        param($m)
        $head = $m.Groups[1].Value
        $body = $m.Groups[2].Value
        $tail = $m.Groups[3].Value
        return "$head$LogLine`r`n$body$tail"
    })

    Set-Content -LiteralPath $upstreamMd -Value $content -NoNewline
}

# --- Verify mode -----------------------------------------------------------

if ($Verify) {
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Fail "No manifest at $manifestPath. Run a sync first." 2
    }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json

    $expected = @{}
    foreach ($f in $manifest.files) { $expected[$f.path] = $f.sha256 }

    $actual = @{}
    Get-ChildItem -LiteralPath $vendorRoot -Force -Recurse -File | ForEach-Object {
        $rel = Get-RelativePath $vendorRoot $_.FullName
        if ($rel -in @('.sync-manifest.json', 'README.txt')) { return }
        $actual[$rel] = Get-VendorFileHash $_.FullName
    }

    $added    = @($actual.Keys   | Where-Object { -not $expected.ContainsKey($_) })
    $removed  = @($expected.Keys | Where-Object { -not $actual.ContainsKey($_)   })
    $modified = @($actual.Keys   | Where-Object { $expected.ContainsKey($_) -and $expected[$_] -ne $actual[$_] })

    Write-Host "Verify against $($manifest.ref):" -ForegroundColor Cyan
    if ($added)    { Write-Host "  added    : $($added.Count)"    -ForegroundColor Yellow; $added    | ForEach-Object { Write-Host "    + $_" } }
    if ($removed)  { Write-Host "  removed  : $($removed.Count)"  -ForegroundColor Yellow; $removed  | ForEach-Object { Write-Host "    - $_" } }
    if ($modified) { Write-Host "  modified : $($modified.Count)" -ForegroundColor Yellow; $modified | ForEach-Object { Write-Host "    ~ $_" } }
    if (-not ($added -or $removed -or $modified)) {
        Write-Host '  clean — vendor tree matches manifest.' -ForegroundColor Green
        exit 0
    }
    exit 2
}

# --- Sync mode -------------------------------------------------------------

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail 'git not found in PATH.'
}

$priorPin = Read-PriorPin $upstreamMd
if (-not $UpstreamRef) {
    $UpstreamRef = if ($priorPin) { $priorPin } else { 'main' }
    Write-Host "UpstreamRef not provided — using $UpstreamRef" -ForegroundColor DarkGray
}

$prevManifest = $null
if (Test-Path -LiteralPath $manifestPath) {
    $prevManifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-skills-sync-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    Write-Host "Fetching $Repo @ $UpstreamRef into $tempDir ..." -ForegroundColor Cyan
    Invoke-Git -GitArgs @('init', '-q') -Cwd $tempDir
    Invoke-Git -GitArgs @('remote', 'add', 'origin', $Repo) -Cwd $tempDir
    Invoke-Git -GitArgs @('fetch', '--depth', '1', 'origin', $UpstreamRef) -Cwd $tempDir
    Invoke-Git -GitArgs @('checkout', '-q', 'FETCH_HEAD') -Cwd $tempDir

    $resolvedSha = Invoke-Git -GitArgs @('rev-parse', 'HEAD') -Cwd $tempDir
    $commitDate  = Invoke-Git -GitArgs @('log', '-1', '--format=%cI', 'HEAD') -Cwd $tempDir
    $syncDate    = (Get-Date).ToString('yyyy-MM-dd')

    Write-Host "Resolved $UpstreamRef -> $resolvedSha (committed $commitDate)" -ForegroundColor Green

    # Clear vendor tree (preserve our README.txt warning)
    if (Test-Path -LiteralPath $vendorRoot) {
        Get-ChildItem -LiteralPath $vendorRoot -Force | Where-Object { $_.Name -notin @('README.txt') } | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
        }
    } else {
        New-Item -ItemType Directory -Path $vendorRoot -Force | Out-Null
    }

    Write-Host "Copying upstream tree -> $vendorRoot ..." -ForegroundColor Cyan
    Copy-UpstreamTree -Source $tempDir -Destination $vendorRoot

    Write-Host 'Computing manifest ...' -ForegroundColor Cyan
    $manifest = New-Manifest -RootDir $vendorRoot -UpstreamUrl $Repo -Sha $resolvedSha -CommitDate $commitDate
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    $diff = Compare-Manifests -Prev $prevManifest -Curr $manifest
    $summary = Format-ChangeSummary $diff

    $logLine = "- **$syncDate** — Synced to ``$($resolvedSha.Substring(0,7))`` ($summary)."
    Update-UpstreamMd -PriorSha $priorPin -NewSha $resolvedSha -SyncDate $syncDate -ChangeSummary $summary -LogLine $logLine

    Write-Host ''
    Write-Host '--- Summary ---' -ForegroundColor Cyan
    Write-Host "  Pin:     $resolvedSha" -ForegroundColor Green
    Write-Host "  Prior:   $(if ($priorPin) { $priorPin } else { '(none)' })"
    Write-Host "  Changed: $summary"
    if ($diff.Added)    { Write-Host '  Added:';    $diff.Added    | ForEach-Object { Write-Host "    + $_" } }
    if ($diff.Removed)  { Write-Host '  Removed:';  $diff.Removed  | ForEach-Object { Write-Host "    - $_" } }
    if ($diff.Modified) { Write-Host '  Modified:'; $diff.Modified | ForEach-Object { Write-Host "    ~ $_" } }
    Write-Host ''
    Write-Host 'Review `git status` and commit the result manually.' -ForegroundColor Yellow
} finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
