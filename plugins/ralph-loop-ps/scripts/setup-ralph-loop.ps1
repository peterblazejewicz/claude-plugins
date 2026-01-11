#Requires -Version 7.0
<#
.SYNOPSIS
    Ralph Loop Setup Script - PowerShell 7.x Port
.DESCRIPTION
    Creates state file for in-session Ralph loop.
.NOTES
    Port of: anthropics/claude-plugins-official/plugins/ralph-loop/scripts/setup-ralph-loop.sh
.EXAMPLE
    ./setup-ralph-loop.ps1 "Build a REST API" --max-iterations 20 --completion-promise "DONE"
#>

param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'

# Parse arguments
$promptParts = @()
$maxIterations = 0
$completionPromise = "null"
$showHelp = $false

$i = 0
while ($i -lt $Arguments.Count) {
    $arg = $Arguments[$i]

    switch -Regex ($arg) {
        '^(-h|--help)$' {
            $showHelp = $true
            $i++
        }
        '^--max-iterations$' {
            if ($i + 1 -ge $Arguments.Count -or $Arguments[$i + 1] -match '^--') {
                Write-Error "❌ Error: --max-iterations requires a number argument"
                Write-Error ""
                Write-Error "   Valid examples:"
                Write-Error "     --max-iterations 10"
                Write-Error "     --max-iterations 50"
                Write-Error "     --max-iterations 0  (unlimited)"
                Write-Error ""
                Write-Error "   You provided: --max-iterations (with no number)"
                exit 1
            }
            $nextArg = $Arguments[$i + 1]
            if ($nextArg -notmatch '^\d+$') {
                Write-Error "❌ Error: --max-iterations must be a positive integer or 0, got: $nextArg"
                Write-Error ""
                Write-Error "   Valid examples:"
                Write-Error "     --max-iterations 10"
                Write-Error "     --max-iterations 50"
                Write-Error "     --max-iterations 0  (unlimited)"
                Write-Error ""
                Write-Error "   Invalid: decimals (10.5), negative numbers (-5), text"
                exit 1
            }
            $maxIterations = [int]$nextArg
            $i += 2
        }
        '^--completion-promise$' {
            if ($i + 1 -ge $Arguments.Count -or $Arguments[$i + 1] -match '^--') {
                Write-Error "❌ Error: --completion-promise requires a text argument"
                Write-Error ""
                Write-Error "   Valid examples:"
                Write-Error "     --completion-promise 'DONE'"
                Write-Error "     --completion-promise 'TASK COMPLETE'"
                Write-Error "     --completion-promise 'All tests passing'"
                Write-Error ""
                Write-Error "   You provided: --completion-promise (with no text)"
                Write-Error ""
                Write-Error "   Note: Multi-word promises must be quoted!"
                exit 1
            }
            $completionPromise = $Arguments[$i + 1]
            $i += 2
        }
        default {
            $promptParts += $arg
            $i++
        }
    }
}

# Show help if requested
if ($showHelp) {
    @"
Ralph Loop - Interactive self-referential development loop (PowerShell 7.x)

USAGE:
  /ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (USE QUOTES for multi-word)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

  To signal completion, you must output: <promise>YOUR_PHRASE</promise>

  Use this for:
  - Interactive iteration where you want to see progress
  - Tasks requiring self-correction and refinement
  - Learning how Ralph works

EXAMPLES:
  /ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop Refactor cache layer  (runs forever)
  /ralph-loop --completion-promise 'TASK COMPLETE' Create a REST API

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  No manual stop - Ralph runs infinitely by default!

MONITORING:
  # View current iteration (PowerShell):
  Get-Content .claude/ralph-loop.local.md | Select-String '^iteration:'

  # View full state:
  Get-Content .claude/ralph-loop.local.md | Select-Object -First 10
"@
    exit 0
}

# Join all prompt parts with spaces
$prompt = $promptParts -join ' '

# Validate prompt is non-empty
if (-not $prompt) {
    Write-Error "❌ Error: No prompt provided"
    Write-Error ""
    Write-Error "   Ralph needs a task description to work on."
    Write-Error ""
    Write-Error "   Examples:"
    Write-Error "     /ralph-loop Build a REST API for todos"
    Write-Error "     /ralph-loop Fix the auth bug --max-iterations 20"
    Write-Error "     /ralph-loop --completion-promise 'DONE' Refactor code"
    Write-Error ""
    Write-Error "   For all options: /ralph-loop --help"
    exit 1
}

# Create state file for stop hook (markdown with YAML frontmatter)
$claudeDir = ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# Quote completion promise for YAML if it contains special chars or is not null
if ($completionPromise -and $completionPromise -ne "null") {
    $completionPromiseYaml = "`"$completionPromise`""
}
else {
    $completionPromiseYaml = "null"
}

# Get UTC timestamp in ISO 8601 format
$startedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Create state file content
$stateContent = @"
---
active: true
iteration: 1
max_iterations: $maxIterations
completion_promise: $completionPromiseYaml
started_at: "$startedAt"
---

$prompt
"@

Set-Content -Path ".claude/ralph-loop.local.md" -Value $stateContent

# Output setup message
$maxIterDisplay = if ($maxIterations -gt 0) { $maxIterations } else { "unlimited" }
$promiseDisplay = if ($completionPromise -ne "null") { "$completionPromise (ONLY output when TRUE - do not lie!)" } else { "none (runs forever)" }

@"
🔄 Ralph loop activated in this session!

Iteration: 1
Max iterations: $maxIterDisplay
Completion promise: $promiseDisplay

The stop hook is now active. When you try to exit, the SAME PROMPT will be
fed back to you. You'll see your previous work in files, creating a
self-referential loop where you iteratively improve on the same task.

To monitor: Get-Content .claude/ralph-loop.local.md | Select-Object -First 10

⚠️  WARNING: This loop cannot be stopped manually! It will run infinitely
    unless you set --max-iterations or --completion-promise.

🔄
"@

# Output the initial prompt if provided
if ($prompt) {
    Write-Host ""
    Write-Host $prompt
}

# Display completion promise requirements if set
if ($completionPromise -ne "null") {
    @"

═══════════════════════════════════════════════════════════
CRITICAL - Ralph Loop Completion Promise
═══════════════════════════════════════════════════════════

To complete this loop, output this EXACT text:
  <promise>$completionPromise</promise>

STRICT REQUIREMENTS (DO NOT VIOLATE):
  ✓ Use <promise> XML tags EXACTLY as shown above
  ✓ The statement MUST be completely and unequivocally TRUE
  ✓ Do NOT output false statements to exit the loop
  ✓ Do NOT lie even if you think you should exit

IMPORTANT - Do not circumvent the loop:
  Even if you believe you're stuck, the task is impossible,
  or you've been running too long - you MUST NOT output a
  false promise statement. The loop is designed to continue
  until the promise is GENUINELY TRUE. Trust the process.

  If the loop should stop, the promise statement will become
  true naturally. Do not force it by lying.
═══════════════════════════════════════════════════════════
"@
}
