# Ralph Loop PowerShell Plugin

> **Windows-compatible PowerShell 7.x port** of the official [ralph-loop](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop) plugin.

Implementation of the Ralph Wiggum technique for iterative, self-referential AI development loops in Claude Code - now running natively on Windows!

## What is Ralph Loop?

Ralph Loop is a development methodology based on continuous AI agent loops.  As Geoffrey Huntley describes it:  **"Ralph is a Bash loop"** - a simple `while true` that repeatedly feeds an AI agent a prompt until completion.

This PowerShell port brings the same functionality to Windows users without requiring WSL.

### Core Concept

This plugin implements Ralph using a **Stop hook** that intercepts Claude's exit attempts:

```powershell
# You run ONCE: 
/ralph-loop "Your task description" --completion-promise "DONE"

# Then Claude Code automatically: 
# 1. Works on the task
# 2. Tries to exit
# 3. Stop hook blocks exit
# 4. Stop hook feeds the SAME prompt back
# 5. Repeat until completion
```

## Quick Start

```bash
/ralph-loop "Build a REST API for todos.  Requirements:  CRUD operations, input validation, tests.  Output <promise>COMPLETE</promise> when done." --completion-promise "COMPLETE" --max-iterations 50
```

Claude will:
- Implement the API iteratively
- Run tests and see failures
- Fix bugs based on test output
- Iterate until all requirements met
- Output the completion promise when done

## Commands

### /ralph-loop

Start a Ralph loop in your current session.

**Usage:**
```bash
/ralph-loop "<prompt>" --max-iterations <n> --completion-promise "<text>"
```

**Options:**
- `--max-iterations <n>` - Stop after N iterations (default: unlimited)
- `--completion-promise <text>` - Phrase that signals completion

### /cancel-ralph

Cancel the active Ralph loop.

**Usage:**
```bash
/cancel-ralph
```

## Requirements

- **PowerShell 7.x** (cross-platform)

```powershell
# Verify version
$PSVersionTable.PSVersion

# Install on Windows
winget install Microsoft.PowerShell
```

## Differences from Bash Version

This is a **1:1 functional port** with these implementation differences:

| Aspect | Bash Version | PowerShell Version |
|--------|--------------|-------------------|
| Shell | `#!/bin/bash` | `#Requires -Version 7.0` |
| JSON parsing | `jq` | `ConvertFrom-Json` (native) |
| Regex | `sed`, `perl` | PowerShell regex |
| File ops | Unix commands | PowerShell cmdlets |

## Learn More

- Original technique: https://ghuntley.com/ralph/
- Original plugin: https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop
- Ralph Orchestrator: https://github.com/mikeyobrien/ralph-orchestrator