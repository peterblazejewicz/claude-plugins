# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

A Claude Code plugin marketplace providing two plugins: **avalonia-dev** (Avalonia / MAUI structural review) and **dotnet-skills** (.NET/C# engineering workflow skills, indirect fork of addyosmani/agent-skills). This is a content-only repository with no build system — all files are markdown and JSON.

## Plugin Architecture

The marketplace structure:
```
.claude-plugin/marketplace.json       # Marketplace manifest listing all plugins
plugins/<plugin-name>/                # INSTALLED to user machines — keep it lean
  .claude-plugin/plugin.json          # Plugin metadata
  commands/*.md                       # Slash commands (markdown with YAML frontmatter)
  skills/<skill-name>/SKILL.md        # Skill definitions with references
  skills/<skill-name>/references/     # Skill reference files (patterns, guides)
  LICENSES/                           # Third-party license texts (MIT must travel with content)
  NOTICE.md, README.md                # Attribution + user-facing plugin docs
sync-state/<plugin-name>/             # NOT installed to users — maintainer artifacts only
  vendor/<upstream>/                  # Pristine upstream snapshot (for indirect-fork plugins)
  UPSTREAM.md, SYNC.md                # Pinned commit + per-skill port ledger
scripts/sync-agent-skills.ps1         # Maintainer-only re-sync tool
```

**Invariant**: `plugins/<name>/` contains only what end users need at runtime. Anything that exists to help maintainers keep the plugin in sync with an upstream source belongs in `sync-state/<name>/` and is never published via the marketplace. The `source` field in `marketplace.json` points at `plugins/<name>/`, so everything under that path gets installed when a user runs `claude plugins install <name>`.

**Version coupling**: when bumping a plugin's `version`, update *both* `plugins/<name>/.claude-plugin/plugin.json` *and* the matching entry in `.claude-plugin/marketplace.json`. Users pulling via `claude plugins marketplace update` won't see the new version unless both are in sync.

**`plugin.json` manifest schema is strict.** Valid top-level fields used by this repo: `name`, `version`, `description`, `skills`, `commands`. Other directories Claude Code reads from a plugin — `agents/`, `hooks/`, `.mcp.json` — are **auto-discovered by convention**; do NOT add them as manifest keys (e.g. `"agents": "./agents/"`) or install fails with "invalid manifest file". 2.2.0 shipped broken for this reason; 2.2.1 hotfixed by removing the key.

**Plugin cache is version-keyed.** `claude plugins marketplace update` stores installs at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` and won't refetch an already-cached version. Any user-visible fix (even a one-line manifest correction) requires a patch bump in both manifests to propagate — same-version republishes are invisible.

**Second-source external version claims.** Release dates and version numbers for upstream projects (Avalonia, EF Core, xUnit, etc.) that land in shipped skill content must be verified against a primary source (GitHub release page, NuGet, official docs) — not taken from a single research agent. 2.3.0 shipped with "Avalonia 12.0 (Feb 2026)" based on an unverified agent claim; the actual release was April 2026, and a followup commit was needed to correct it. Wrong anchor dates erode trust in the whole versioning section for agents that rely on it.

### Command Files

Commands are markdown files with YAML frontmatter. Key frontmatter fields:
- `description`: Command description shown in help
- `argument-hint`: Usage hint for arguments
- `allowed-tools`: Array of Bash patterns the command can execute
- `hide-from-slash-command-tool`: Whether to hide from tool listing

## Plugin: avalonia-dev

Avalonia/MAUI structural review with version-specific checks for Avalonia 11.x and 12.x. Complements the `frontend-ui-engineering-avalonia` skill in the `dotnet-skills` plugin — avalonia-dev focuses on solution-level structure (design tokens, project layout, phased migration); the sibling skill covers per-view engineering (MVVM, compiled bindings, theming, accessibility).

Key files:
- `plugins/avalonia-dev/commands/avalonia-review.md` — slash command entry point
- `plugins/avalonia-dev/skills/review/SKILL.md` — review skill logic
- `plugins/avalonia-dev/skills/review/references/design-tokens.md` — token patterns
- `plugins/avalonia-dev/skills/review/references/migration-guide.md` — phased migration + v12 API changes
- `plugins/avalonia-dev/skills/review/references/project-structure.md` — folder layouts

## Plugin: dotnet-skills

21 engineering workflow skills + 3 .NET-adapted subagents for .NET/C# development (spec → plan → build → verify → review → ship, plus a meta skill). Indirect fork of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani).

Key files:
- `plugins/dotnet-skills/commands/dotnet-skills.md` — slash command (skill + agent + command inventory)
- `plugins/dotnet-skills/commands/{spec,plan,build,test,review,code-simplify,ship}.md` — 7 lifecycle wrappers ported from upstream `.claude/commands/` (added in 2.1.0)
- `plugins/dotnet-skills/skills/<name>/SKILL.md` — 21 ported skills
- `plugins/dotnet-skills/agents/{code-reviewer,security-auditor,test-engineer}.md` — 3 ported subagents (added in 2.2.0)
- `plugins/dotnet-skills/NOTICE.md`, `LICENSES/agent-skills-MIT.txt` — attribution + MIT license
- `sync-state/dotnet-skills/SYNC.md` — per-skill + per-command + per-agent port ledger (status: modified / rewritten / skipped)
- `sync-state/dotnet-skills/UPSTREAM.md` — pinned upstream commit + sync log (script-maintained)
- `sync-state/dotnet-skills/vendor/agent-skills/` — pristine upstream snapshot; regenerated by the sync script
- `scripts/sync-agent-skills.ps1` — PowerShell re-sync tool; supports `-UpstreamRef <sha|branch>` and `-Verify` (drift check)

When editing any ported `SKILL.md`, `commands/*.md`, or `agents/*.md`, preserve the "Source & Modifications" footer — it records upstream SHA, status, and the specific `.NET`-targeted changes so re-syncs stay coherent. Downstream-only patches (where the .NET ecosystem moves faster than upstream) go in a dated "Downstream patches" subsection of the same footer. The `dotnet-skills` command file does not carry a footer (it has no upstream counterpart — it's a catalog command).

Downstream skill renames (use these names in any new cross-reference — upstream names produce broken links):
- `browser-testing-with-devtools` → `integration-testing-dotnet` (rewritten for the 4 .NET integration boundaries)
- `frontend-ui-engineering` → `frontend-ui-engineering-avalonia` (rewritten for Avalonia)
- `performance-optimization` → `performance-optimization-dotnet` (rewritten for BenchmarkDotNet / dotnet-counters / PerfView)

**Test-sample policy (since 2.3.0).** Use native `Xunit.Assert.X` (xUnit) or `Microsoft.VisualStudio.TestTools.UnitTesting.Assert.X` (MSTest) only. Do not introduce FluentAssertions in any new sample or prose — v8+ (Jan 2025) moved from Apache 2.0 to the XCEED source-available license; v7.x is the last OSS-compatible line. xUnit v3 + Microsoft.Testing.Platform is canonical; v2 stays source-compatible and is covered by the `test-driven-development` Version Awareness table. `Avalonia.Headless.XUnit` gained xUnit v3 support only in Avalonia 12.0 (April 2026) — 11.x projects must stay on xUnit v2 for headless UI tests.
