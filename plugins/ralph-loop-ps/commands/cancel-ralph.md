---
description: "Cancel active Ralph Loop"
allowed-tools: ["Bash(pwsh -Command \"if (Test-Path .claude/ralph-loop.local.md) { 'EXISTS' } else { 'NOT_FOUND' }\")", "Bash(pwsh -Command \"Remove-Item .claude/ralph-loop.local.md -Force\")", "Read(.claude/ralph-loop.local.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

To cancel the Ralph loop:

1. Check if `.claude/ralph-loop.local.md` exists using PowerShell: `pwsh -Command "if (Test-Path .claude/ralph-loop.local.md) { 'EXISTS' } else { 'NOT_FOUND' }"`

2. **If NOT_FOUND**: Say "No active Ralph loop found."

3. **If EXISTS**:
   - Read `.claude/ralph-loop.local.md` to get the current iteration number from the `iteration:` field
   - Remove the file using PowerShell: `pwsh -Command "Remove-Item .claude/ralph-loop.local.md -Force"`
   - Report: "Cancelled Ralph loop (was at iteration N)" where N is the iteration value