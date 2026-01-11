#Requires -Version 7.0
<#
.SYNOPSIS
    Ralph Loop Stop Hook - PowerShell 7.x Port
.DESCRIPTION
    Prevents session exit when a ralph-loop is active.
    Feeds Claude's output back as input to continue the loop.
.NOTES
    Port of: anthropics/claude-plugins-official/plugins/ralph-loop/hooks/stop-hook.sh
#>

$ErrorActionPreference = 'Stop'

# Read hook input from stdin (advanced stop hook API)
$HookInput = $input | Out-String

# Check if ralph-loop is active
$RalphStateFile = ".claude/ralph-loop.local.md"

if (-not (Test-Path $RalphStateFile)) {
    # No active loop - allow exit
    exit 0
}

# Read state file content
$stateContent = Get-Content $RalphStateFile -Raw

# Parse markdown frontmatter (YAML between --- markers)
if ($stateContent -notmatch '(?s)^---\r?\n(.+?)\r?\n---\r?\n(.*)$') {
    Write-Error "⚠️  Ralph loop: State file corrupted - invalid frontmatter format"
    Write-Error "   File: $RalphStateFile"
    Write-Error "   Ralph loop is stopping. Run /ralph-loop again to start fresh."
    Remove-Item $RalphStateFile -Force
    exit 0
}

$frontmatter = $Matches[1]
$promptText = $Matches[2].Trim()

# Parse frontmatter values
$iteration = 0
$maxIterations = 0
$completionPromise = $null

foreach ($line in $frontmatter -split '\r?\n') {
    if ($line -match '^iteration:\s*(\d+)') {
        $iteration = [int]$Matches[1]
    }
    elseif ($line -match '^max_iterations:\s*(\d+)') {
        $maxIterations = [int]$Matches[1]
    }
    elseif ($line -match '^completion_promise:\s*"?([^"]*)"?') {
        $completionPromise = $Matches[1]
        if ($completionPromise -eq 'null') { $completionPromise = $null }
    }
}

# Validate numeric fields
if ($iteration -lt 0) {
    Write-Error "⚠️  Ralph loop: State file corrupted"
    Write-Error "   File: $RalphStateFile"
    Write-Error "   Problem: 'iteration' field is not a valid number (got: '$iteration')"
    Write-Error ""
    Write-Error "   This usually means the state file was manually edited or corrupted."
    Write-Error "   Ralph loop is stopping. Run /ralph-loop again to start fresh."
    Remove-Item $RalphStateFile -Force
    exit 0
}

# Check if max iterations reached
if ($maxIterations -gt 0 -and $iteration -ge $maxIterations) {
    Write-Host "🛑 Ralph loop: Max iterations ($maxIterations) reached."
    Remove-Item $RalphStateFile -Force
    exit 0
}

# Get transcript path from hook input
try {
    $hookData = $HookInput | ConvertFrom-Json
    $transcriptPath = $hookData.transcript_path
}
catch {
    Write-Error "⚠️  Ralph loop: Failed to parse hook input JSON"
    Write-Error "   Error: $_"
    Write-Error "   Ralph loop is stopping."
    Remove-Item $RalphStateFile -Force
    exit 0
}

if (-not (Test-Path $transcriptPath)) {
    Write-Error "⚠️  Ralph loop: Transcript file not found"
    Write-Error "   Expected: $transcriptPath"
    Write-Error "   This is unusual and may indicate a Claude Code internal issue."
    Write-Error "   Ralph loop is stopping."
    Remove-Item $RalphStateFile -Force
    exit 0
}

# Read transcript and find last assistant message (JSONL format)
$transcriptLines = Get-Content $transcriptPath
$assistantLines = $transcriptLines | Where-Object { $_ -match '"role":"assistant"' }

if (-not $assistantLines) {
    Write-Error "⚠️  Ralph loop: No assistant messages found in transcript"
    Write-Error "   Transcript: $transcriptPath"
    Write-Error "   This is unusual and may indicate a transcript format issue"
    Write-Error "   Ralph loop is stopping."
    Remove-Item $RalphStateFile -Force
    exit 0
}

# Get the last assistant message
$lastLine = $assistantLines | Select-Object -Last 1

if (-not $lastLine) {
    Write-Error "⚠️  Ralph loop: Failed to extract last assistant message"
    Write-Error "   Ralph loop is stopping."
    Remove-Item $RalphStateFile -Force
    exit 0
}

# Parse JSON and extract text content
try {
    $messageJson = $lastLine | ConvertFrom-Json
    $textContents = $messageJson.message.content |
        Where-Object { $_.type -eq 'text' } |
        ForEach-Object { $_.text }
    $lastOutput = $textContents -join "`n"
}
catch {
    Write-Error "⚠️  Ralph loop: Failed to parse assistant message JSON"
    Write-Error "   Error: $_"
    Write-Error "   This may indicate a transcript format issue"
    Write-Error "   Ralph loop is stopping."
    Remove-Item $RalphStateFile -Force
    exit 0
}

if (-not $lastOutput) {
    Write-Error "⚠️  Ralph loop: Assistant message contained no text content"
    Write-Error "   Ralph loop is stopping."
    Remove-Item $RalphStateFile -Force
    exit 0
}

# Check for completion promise (only if set)
if ($completionPromise) {
    # Extract text from <promise>...</promise> tags
    if ($lastOutput -match '<promise>(.*?)</promise>') {
        $promiseText = $Matches[1].Trim() -replace '\s+', ' '

        # Use exact string comparison (not pattern matching)
        if ($promiseText -eq $completionPromise) {
            Write-Host "✅ Ralph loop: Detected <promise>$completionPromise</promise>"
            Remove-Item $RalphStateFile -Force
            exit 0
        }
    }
}

# Not complete - continue loop with SAME PROMPT
$nextIteration = $iteration + 1

# Validate prompt text exists
if (-not $promptText) {
    Write-Error "⚠️  Ralph loop: State file corrupted or incomplete"
    Write-Error "   File: $RalphStateFile"
    Write-Error "   Problem: No prompt text found"
    Write-Error ""
    Write-Error "   This usually means:"
    Write-Error "     * State file was manually edited"
    Write-Error "     * File was corrupted during writing"
    Write-Error ""
    Write-Error "   Ralph loop is stopping. Run /ralph-loop again to start fresh."
    Remove-Item $RalphStateFile -Force
    exit 0
}

# Update iteration in state file
$updatedContent = $stateContent -replace 'iteration:\s*\d+', "iteration: $nextIteration"
Set-Content -Path $RalphStateFile -Value $updatedContent -NoNewline

# Build system message with iteration count and completion promise info
if ($completionPromise) {
    $systemMsg = "🔄 Ralph iteration $nextIteration | To stop: output <promise>$completionPromise</promise> (ONLY when statement is TRUE - do not lie to exit!)"
}
else {
    $systemMsg = "🔄 Ralph iteration $nextIteration | No completion promise set - loop runs infinitely"
}

# Output JSON to block the stop and feed prompt back
$output = @{
    decision = "block"
    reason = $promptText
    systemMessage = $systemMsg
} | ConvertTo-Json -Compress

Write-Output $output

# Exit 0 for successful hook execution
exit 0
