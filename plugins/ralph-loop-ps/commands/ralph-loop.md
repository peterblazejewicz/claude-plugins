---
description: "Start Ralph Loop in current session (PowerShell)"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Write", "Bash(pwsh -NoProfile -ExecutionPolicy Bypass -File *setup-ralph-loop.ps1)"]
hide-from-slash-command-tool: "true"
---

# Ralph Loop Command (PowerShell)

First, write the arguments to a temp file (this handles multiline prompts safely):

```!Write(.claude/ralph-loop-args.tmp)
$ARGUMENTS
```

Then execute the setup script (it reads arguments from the temp file):

```!
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.ps1"
```

Please work on the task. When you try to exit, the Ralph loop will feed the SAME PROMPT back to you for the next iteration. You'll see your previous work in files and git history, allowing you to iteratively improve.

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop, even if you think you're stuck.