# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

A Claude Code plugin marketplace providing the **avalonia-dev** plugin for Avalonia and .NET cross-platform UI development.

## Plugin Architecture

The marketplace structure:
```
.claude-plugin/marketplace.json    # Marketplace manifest listing all plugins
plugins/<plugin-name>/
  .claude-plugin/plugin.json       # Plugin metadata
  commands/*.md                    # Slash commands (markdown with YAML frontmatter)
  skills/<skill-name>/SKILL.md     # Skill definitions with references
  skills/<skill-name>/references/  # Skill reference files (patterns, guides)
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

## Plugin: avalonia-dev

Provides Avalonia/MAUI development guidance including project structure review, design token patterns, and theming systems. Supports Avalonia 11.x and 12.x with version-specific checks.

Key files:
- `commands/avalonia-review.md` - Command to trigger project review skill
- `skills/review/SKILL.md` - Review skill with structured guidance for architecture analysis
- `skills/review/references/*.md` - Reference files for design tokens, migration patterns, project structures

Skills architecture: Skills are markdown files with YAML frontmatter (`name`, `description`, `version`) that provide structured guidance. Skills reference additional files in `references/` subdirectory for detailed patterns. The `plugin.json` points to the skills directory via the `skills` field.
