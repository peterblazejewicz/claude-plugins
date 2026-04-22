# Claude Code Plugins — .NET / Avalonia

A Claude Code plugin marketplace focused on .NET and cross-platform UI development.

## Plugins

### `avalonia-dev` — Avalonia / MAUI project review

Supports Avalonia 11.x and 12.x. Run `/avalonia-review` in your project to get a structured review covering:

- **Design token extraction** — find hardcoded colors, fonts, spacing and organize them into token files
- **Theme architecture** — evaluate resource dictionaries, light/dark theme support, StaticResource vs DynamicResource usage
- **Project structure** — assess folder organization, separation of concerns, recommend target layouts
- **Migration planning** — phased approach with priorities and risk levels
- **Version-specific checks (v12)** — compiled bindings (`x:DataType`), accessibility properties, page-based navigation patterns, new styling APIs
- **Upgrade guidance (v11)** — key benefits and migration path to Avalonia 12

Plugin details: [`plugins/avalonia-dev/README.md`](./plugins/avalonia-dev/README.md).

### `dotnet-skills` — .NET/C# agent skills (indirect fork of addyosmani/agent-skills)

Production-grade engineering skills adapted for .NET 8+ (LTS or newer), C# 12+, xUnit (v2 or v3) and MSTest, EF Core, and Avalonia UI (with ASP.NET Core, Blazor, and .NET MAUI covered by guidance).

Run `/dotnet-skills` to list available skills, or jump straight to a lifecycle phase with `/spec`, `/plan`, `/build`, `/test`, `/review`, `/code-simplify`, `/ship`. Plugin details: [`plugins/dotnet-skills/README.md`](./plugins/dotnet-skills/README.md).

```bash
/dotnet-skills

● ★ Insight ─────────────────────────────────────
  - The /dotnet-skills:dotnet-skills command is a catalog command — unlike the other 7 lifecycle wrappers (/spec, /plan, /build, etc.), it has no upstream counterpart and carries no "Source &
  Modifications" footer (per CLAUDE.md line discussing the dotnet-skills command file).
  - Notice the three-tier taxonomy: 21 skills (auto-triggered by prompt matching), 7 slash commands (manual invocation for lifecycle phases), and 3 subagents (launched via the Agent tool with
  subagent_type: dotnet-skills:<name>). They coexist because Claude Code auto-namespaces plugin-provided subagents.
  - The Define → Plan → Build → Verify → Review → Ship flow mirrors a classic SDLC — but the skills activate on prompt match, so you get them for free by describing work naturally rather than
  memorizing slash commands.
  ─────────────────────────────────────────────────

  The /dotnet-skills:dotnet-skills catalog has rendered successfully — it's the skill inventory for the dotnet-skills plugin (v2.2.1). No action needed unless you want to dive into a specific skill,
   command, or subagent.

  What would you like to do next? A few natural entry points:
  - Start a new .NET feature — describe it and the right skill (likely spec-driven-development or idea-refine) will activate.
  - Review recent changes — invoke /dotnet-skills:review or launch the code-reviewer subagent.
  - Audit the plugin itself — e.g., verify sync-state/dotnet-skills/SYNC.md still matches the shipped content after 2.2.1.
```

## Installation

### Claude Code

```bash
claude plugins marketplace add peterblazejewicz/claude-plugins
claude plugins install avalonia-dev
claude plugins install dotnet-skills
```

### GitHub Copilot CLI

```bash
copilot plugin marketplace add peterblazejewicz/claude-plugins
# then inside copilot:
/plugin install avalonia-dev@blazejewicz-claude-plugins
/plugin install dotnet-skills@blazejewicz-claude-plugins
```

Copilot CLI reads the same `.claude-plugin/marketplace.json` — no second manifest. `dotnet-skills` exposes three personas on Copilot CLI (`/agent code-reviewer`, `/agent security-auditor`, `/agent test-engineer`); the 21 skills activate automatically by description-match. See [`plugins/dotnet-skills/README.md`](./plugins/dotnet-skills/README.md#github-copilot-cli) for the full Copilot setup (including per-repo install and VS Code Chat invocation).

## Credits

The `dotnet-skills` plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) by Addy Osmani, used under the **MIT License** (© 2025 Addy Osmani). Upstream content is ported skill-by-skill with .NET/C# adaptations; the upstream LICENSE is preserved verbatim at [`plugins/dotnet-skills/LICENSES/agent-skills-MIT.txt`](./plugins/dotnet-skills/LICENSES/agent-skills-MIT.txt) and per-skill provenance is recorded in the "Source & Modifications" footer of every ported `SKILL.md`.

Maintenance artifacts (pinned upstream snapshot, per-skill port ledger, re-sync script) live outside the installed plugin at [`sync-state/dotnet-skills/`](./sync-state/dotnet-skills) and [`scripts/sync-agent-skills.ps1`](./scripts/sync-agent-skills.ps1) — so end users installing `dotnet-skills` from the marketplace don't receive them.

## Requirements

- [Claude Code](https://claude.ai/code) with plugin support

## License

MIT for this marketplace's original content. Third-party content retains its original license — see the "Credits" section above and per-plugin `NOTICE.md` files.
