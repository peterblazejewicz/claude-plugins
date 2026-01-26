# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Claude Code plugin marketplace providing PowerShell 7.x ports and Windows-compatible Claude Code plugins. Plugins run natively on Windows without requiring WSL.

## Development Commands

### Lint PowerShell scripts
```powershell
# Install PSScriptAnalyzer (once)
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser

# Run linter on all scripts (recommended - uses same settings as CI)
./scripts/powershell-lint.ps1

# Lint a single file
Invoke-ScriptAnalyzer -Path plugins/ralph-loop-ps/hooks/stop-hook.ps1 -Settings ./PSScriptAnalyzerSettings.psd1
```

### Syntax check a script
```powershell
pwsh -NoProfile -Command "& { `$null = [System.Management.Automation.Language.Parser]::ParseFile('script.ps1', [ref]`$null, [ref]`$null) }"
```

## Plugin Architecture

The marketplace structure:
```
.claude-plugin/marketplace.json    # Marketplace manifest listing all plugins
plugins/<plugin-name>/
  .claude-plugin/plugin.json       # Plugin metadata
  commands/*.md                    # Slash commands (markdown with YAML frontmatter)
  skills/<skill-name>/SKILL.md     # Skill definitions with references
  skills/<skill-name>/references/  # Skill reference files (patterns, guides)
  hooks/hooks.json                 # Hook definitions (optional)
  hooks/*.ps1                      # PowerShell hook implementations (optional)
  scripts/*.ps1                    # Supporting PowerShell scripts (optional)
```

### Command Files

Commands are markdown files with YAML frontmatter. Key frontmatter fields:
- `description`: Command description shown in help
- `argument-hint`: Usage hint for arguments
- `allowed-tools`: Array of Bash patterns the command can execute
- `hide-from-slash-command-tool`: Whether to hide from tool listing

### allowed-tools Pattern Syntax

Claude Code uses pattern matching to validate Bash commands. **Important**: Avoid escaped quotes in patterns as they break matching.

```yaml
# ✅ Correct patterns
allowed-tools: ["Bash(pwsh -NoProfile -ExecutionPolicy Bypass -File *script.ps1*)"]
allowed-tools: ["Bash(pwsh *)"]
allowed-tools: ["Bash(pwsh -NoProfile -ExecutionPolicy Bypass *)"]

# ❌ Wrong - escaped quotes break pattern matching
allowed-tools: ["Bash(pwsh -File \"*script.ps1\"*)"]
```

Pattern types:
- `Bash(exact command)` - Exact match
- `Bash(prefix *)` - Wildcard at end
- `Bash(* suffix)` - Wildcard at start
- `Bash(start * end)` - Wildcard in middle

When patterns fail to match, Claude Code triggers shell operator safety checks which block execution with error: "This command uses shell operators that require approval for safety"

### Handling Multiline Arguments

When command arguments may contain newlines (e.g., multiline prompts), Claude Code's security model rejects commands containing newlines with: "Command contains newlines that could separate multiple commands".

**Recommended approach: Instruction-based commands (no bash execution)**

The most reliable solution is to avoid bash execution entirely in the command file. Instead, provide instructions for Claude to use its Write tool directly:

```yaml
allowed-tools: ["Write"]
```

```markdown
Parse arguments from: $ARGUMENTS

Create the state file `.claude/my-state.local.md` using your Write tool with this format:
...
```

This approach:
- Completely avoids the newline security check
- Works regardless of argument content
- Is more robust than bash-based alternatives

**Alternative: Temp file approach (if bash execution is required)**

If you must use bash execution, write arguments to a temp file first:

```yaml
allowed-tools: ["Write", "Bash(pwsh -NoProfile -ExecutionPolicy Bypass -File *script.ps1)"]
```

**Note:** The ` ```!Write() ` and ` ```! ` auto-execute syntax has bugs with permission checking. Use instruction-based approaches instead.

**Why not stdin/echo?** The `echo "$ARGUMENTS" | ...` approach fails because `$ARGUMENTS` is expanded *before* the command runs, putting newlines directly in the command string.

### Hooks

Hooks intercept Claude events. Defined in `hooks/hooks.json`:
```json
{
  "hooks": {
    "Stop": [{ "hooks": [{ "type": "command", "command": "pwsh ... script.ps1" }] }]
  }
}
```

Hook scripts receive input via stdin, output JSON decisions (e.g., `{"decision": "block", "reason": "..."}`).

## Plugin: ralph-loop-ps

PowerShell port of the Ralph Loop iterative development technique. Uses a Stop hook to intercept exit and feed the same prompt back, creating self-referential loops.

Key files:
- `commands/ralph-loop.md` - Instruction-based command that directs Claude to create state file
- `hooks/stop-hook.ps1` - Intercepts stop, checks completion promise, continues loop
- `scripts/setup-ralph-loop.ps1` - Standalone script for direct invocation/testing (not called by command)

State file location: `.claude/ralph-loop.local.md` in the user's project directory. Format is Markdown with YAML frontmatter containing `iteration`, `max_iterations`, `completion_promise`, and `prompt`.

Note: The command uses an instruction-based approach (Claude creates the state file directly) rather than calling the setup script. This avoids Claude Code's newline security restrictions when prompts contain multiple lines.

## Plugin: avalonia-dev

Provides Avalonia/MAUI development guidance including project structure review, design token patterns, and theming systems.

Key files:
- `commands/avalonia-review.md` - Command to trigger project review skill
- `skills/review/SKILL.md` - Review skill with structured guidance for architecture analysis
- `skills/review/references/*.md` - Reference files for design tokens, migration patterns, project structures

Skills architecture: Skills are markdown files with YAML frontmatter (`name`, `description`, `version`) that provide structured guidance. Skills reference additional files in `references/` subdirectory for detailed patterns. The `plugin.json` points to the skills directory via the `skills` field.

## PowerShell Requirements

All scripts require PowerShell 7.x (`#Requires -Version 7.0`). Key porting patterns from Bash:

| Bash | PowerShell |
|------|------------|
| `#!/bin/bash` | `#Requires -Version 7.0` |
| `set -euo pipefail` | `$ErrorActionPreference = 'Stop'` |
| `$(cat)` / stdin | `$input | Out-String` |
| `jq` | `ConvertFrom-Json` / `ConvertTo-Json` |
| `sed`, `grep` | PowerShell regex, `Select-String` |

Scripts invoked with: `pwsh -NoProfile -ExecutionPolicy Bypass -File "script.ps1"`

For comprehensive porting patterns, see `.github/copilot-instructions.md`.

## Upstream Tracking

This repo ports plugins from `anthropics/claude-plugins-official`. The ralph-loop-ps plugin is a 1:1 functional port of the original ralph-loop bash plugin.

A GitHub Actions workflow (`.github/workflows/watch-upstream.yml`) runs daily at 6 AM UTC to detect changes. When changes are detected:
1. Creates/updates an issue with `upstream-sync` label
2. Creates a branch `upstream-sync/ralph-loop` with sync marker
3. Opens a PR for porting the changes

After syncing, update `.upstream-sync/ralph-loop-commit` with the upstream commit SHA to mark sync complete.
