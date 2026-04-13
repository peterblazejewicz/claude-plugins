# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

A Claude Code plugin marketplace providing the **avalonia-dev** plugin for Avalonia and .NET cross-platform UI development. This is a content-only repository with no build system — all files are markdown and JSON.

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

## Plugin: avalonia-dev

Avalonia/MAUI development guidance with version-specific checks for Avalonia 11.x and 12.x.

Key files:
- `plugins/avalonia-dev/commands/avalonia-review.md` — slash command entry point
- `plugins/avalonia-dev/skills/review/SKILL.md` — review skill logic
- `plugins/avalonia-dev/skills/review/references/design-tokens.md` — token patterns
- `plugins/avalonia-dev/skills/review/references/migration-guide.md` — phased migration + v12 API changes
- `plugins/avalonia-dev/skills/review/references/project-structure.md` — folder layouts
