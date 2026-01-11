# Copilot Instructions: Porting Bash Plugins to PowerShell

This document provides instructions for GitHub Copilot when automatically porting upstream bash plugin changes to PowerShell 7.x equivalents.

## Repository Context

This repository (`peterblazejewicz/claude-plugins`) provides Windows-native PowerShell 7.x ports of Claude Code plugins from `anthropics/claude-plugins-official`.

## File Mapping

When porting changes from upstream `plugins/ralph-loop/`, map files as follows:

| Upstream (Bash) | This Repo (PowerShell) |
|-----------------|------------------------|
| `hooks/stop-hook.sh` | `plugins/ralph-loop-ps/hooks/stop-hook.ps1` |
| `scripts/setup-ralph-loop.sh` | `plugins/ralph-loop-ps/scripts/setup-ralph-loop.ps1` |
| `commands/*.md` | `plugins/ralph-loop-ps/commands/*.md` |
| `hooks/hooks.json` | `plugins/ralph-loop-ps/hooks/hooks.json` |
| `.claude-plugin/plugin.json` | `plugins/ralph-loop-ps/.claude-plugin/plugin.json` |

## Bash to PowerShell Porting Patterns

### Script Header

```bash
# Bash
#!/bin/bash
set -euo pipefail
```

```powershell
# PowerShell
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
```

### Reading stdin

```bash
# Bash
INPUT=$(cat)
```

```powershell
# PowerShell
$Input = $input | Out-String
```

### JSON Parsing

```bash
# Bash (using jq)
VALUE=$(echo "$JSON" | jq -r '.key')
NESTED=$(echo "$JSON" | jq -r '.message.content[] | select(.type == "text") | .text')
```

```powershell
# PowerShell (native)
$data = $JSON | ConvertFrom-Json
$value = $data.key
$nested = $data.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }
```

### JSON Output

```bash
# Bash (using jq)
jq -n --arg key "$VALUE" '{"key": $key}'
```

```powershell
# PowerShell (native)
@{ key = $VALUE } | ConvertTo-Json -Compress
```

### String Matching / Regex

```bash
# Bash
if [[ "$VAR" =~ ^[0-9]+$ ]]; then
if echo "$TEXT" | grep -q "pattern"; then
EXTRACTED=$(echo "$TEXT" | sed 's/pattern/replacement/')
MATCH=$(echo "$TEXT" | perl -0777 -pe 's/.*?<tag>(.*?)<\/tag>.*/$1/s')
```

```powershell
# PowerShell
if ($VAR -match '^\d+$') {
if ($TEXT -match 'pattern') {
$extracted = $TEXT -replace 'pattern', 'replacement'
if ($TEXT -match '<tag>(.*?)</tag>') { $match = $Matches[1] }
```

### File Operations

```bash
# Bash
if [[ -f "$FILE" ]]; then
CONTENT=$(cat "$FILE")
echo "$CONTENT" > "$FILE"
rm "$FILE"
```

```powershell
# PowerShell
if (Test-Path $FILE) {
$content = Get-Content $FILE -Raw
Set-Content -Path $FILE -Value $content -NoNewline
Remove-Item $FILE -Force
```

### Error Output

```bash
# Bash
echo "Error message" >&2
```

```powershell
# PowerShell
Write-Error "Error message"
# Or for non-terminating:
Write-Host "Error message" -ForegroundColor Red
```

### Environment Variables

```bash
# Bash
VALUE="$ENV_VAR"
```

```powershell
# PowerShell
$value = $env:ENV_VAR
```

### Conditionals

```bash
# Bash
if [[ -z "$VAR" ]]; then    # empty check
if [[ -n "$VAR" ]]; then    # non-empty check
if [[ "$A" = "$B" ]]; then  # string equality
if [[ $NUM -gt 0 ]]; then   # numeric comparison
```

```powershell
# PowerShell
if (-not $VAR) {            # empty/null check
if ($VAR) {                 # non-empty check
if ($A -eq $B) {            # string equality
if ($NUM -gt 0) {           # numeric comparison
```

### Arrays and Loops

```bash
# Bash
for item in "${array[@]}"; do
  echo "$item"
done
```

```powershell
# PowerShell
foreach ($item in $array) {
    Write-Output $item
}
# Or pipeline:
$array | ForEach-Object { Write-Output $_ }
```

## hooks.json Configuration

When updating `hooks/hooks.json`, change the command invocation:

```json
// Upstream (Bash)
{
  "command": "bash \"$CLAUDE_PLUGIN_ROOT/hooks/stop-hook.sh\""
}

// This repo (PowerShell)
{
  "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File \"$CLAUDE_PLUGIN_ROOT/hooks/stop-hook.ps1\""
}
```

## Testing Requirements

After porting:

1. **Syntax check**: Run `pwsh -NoProfile -Command "& { $null = [System.Management.Automation.Language.Parser]::ParseFile('script.ps1', [ref]$null, [ref]$null) }"`
2. **PSScriptAnalyzer**: Ensure no errors from the linter (CI will check this)
3. **Functional test**: Verify the ported script behaves identically to bash version

## Version Updates

When changes are ported, update version in:
- `plugins/ralph-loop-ps/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

## PR Description Template

When creating a PR for upstream sync, include:

```markdown
## Upstream Sync

Ports changes from upstream commit `{SHA}` in `anthropics/claude-plugins-official`.

### Changes Ported
- [ ] List specific changes from upstream

### Files Modified
- [ ] List files changed

### Testing
- [ ] PSScriptAnalyzer passes
- [ ] Functional testing on Windows with PowerShell 7.x
```

## Important Notes

- All scripts must start with `#Requires -Version 7.0`
- Use `$ErrorActionPreference = 'Stop'` for fail-fast behavior
- Prefer native PowerShell over external tools (no `jq`, `sed`, `grep`)
- Maintain 1:1 functional parity with upstream bash version
- Keep error messages and user-facing output identical to upstream
