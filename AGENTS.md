# Agent instructions (cross-vendor)

This repository is a **plugin marketplace** consumed by both [Claude Code](https://claude.ai/code) and [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli). The full contributor guide lives in [`CLAUDE.md`](./CLAUDE.md) — read it first.

## What this repo publishes

Two plugins, declared in [`.claude-plugin/marketplace.json`](./.claude-plugin/marketplace.json):

- **avalonia-dev** — Avalonia / MAUI structural review (project layout, design tokens, theming, phased migration) for Avalonia 11.x and 12.x.
- **dotnet-skills** — 21 agent skills + 3 specialized subagents for .NET 8+ engineering (spec → plan → build → verify → review → ship). Indirect fork of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani).

Both plugins install via `claude plugins install <name>` (Claude Code) or `copilot plugin marketplace add <owner>/<repo>` + `/plugin install <name>` (Copilot CLI). Copilot CLI reads `.claude-plugin/marketplace.json` directly — the path is deliberate cross-tool compatibility.

## Two load-bearing invariants when changing `dotnet-skills`

A contributor can't learn these from the code alone — they're captured lessons from prior regressions.

1. **Version coupling.** Any user-visible change to `plugins/dotnet-skills/` requires bumping *both* `plugins/dotnet-skills/.claude-plugin/plugin.json` *and* the matching entry in `.claude-plugin/marketplace.json`. The plugin cache is version-keyed — `claude plugins marketplace update` won't refetch an already-cached version, so same-version republishes are invisible.
2. **Test-sample policy.** Native `Xunit.Assert.X` (xUnit) or `Microsoft.VisualStudio.TestTools.UnitTesting.Assert.X` (MSTest) only. Do not introduce FluentAssertions in new samples or prose — v8+ (January 2025) moved to the XCEED source-available license. xUnit v3 + Microsoft.Testing.Platform is canonical; v2 stays source-compatible for Avalonia 11.x (which only gained xUnit v3 headless support in Avalonia 12.0, April 2026).

See [`CLAUDE.md`](./CLAUDE.md) for the full invariant list including the strict `plugin.json` schema, "Source & Modifications" footer pattern, and external-version second-sourcing rule.

## Where to look for maintenance state

- [`sync-state/dotnet-skills/SYNC.md`](./sync-state/dotnet-skills/SYNC.md) — per-file port ledger against upstream addyosmani/agent-skills, with status (`as-is` / `modified` / `rewritten` / `skipped`) and the pinned SHA per file.
- [`sync-state/dotnet-skills/UPSTREAM.md`](./sync-state/dotnet-skills/UPSTREAM.md) — current upstream pin and sync log. Script-maintained by [`scripts/sync-agent-skills.ps1`](./scripts/sync-agent-skills.ps1).

## Per-tool surfaces

- **Claude Code** loads `plugins/<name>/commands/*.md`, `plugins/<name>/skills/<skill>/SKILL.md`, and `plugins/<name>/agents/<name>.md`. Slash commands are first-class.
- **GitHub Copilot CLI** loads `plugins/<name>/skills/<skill>/SKILL.md` (same format — cross-vendor standard) and `plugins/<name>/agents/<name>.agent.md`. Custom slash commands aren't a Copilot-CLI surface as of 2026-04 ([github/copilot-cli#618](https://github.com/github/copilot-cli/issues/618)); the three personas (`code-reviewer`, `security-auditor`, `test-engineer`) are exposed as `/agent <name>` instead.

When editing a persona, update *both* the `.md` (Claude) and `.agent.md` (Copilot) forms — the `.agent.md` footer links back to `.md` as canonical for upstream attribution, so bodies should stay in lockstep. Drift between the two is a review defect.
