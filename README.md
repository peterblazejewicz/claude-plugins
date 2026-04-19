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

Production-grade engineering skills adapted for .NET 8+ (LTS or newer), C# 12+, xUnit (v2 or v3) and MSTest, EF Core, and Avalonia UI (with ASP.NET Core, Blazor, and .NET MAUI covered by guidance). Currently at `2.1.0` — all 21 upstream skills ported across Define/Plan/Build/Verify/Review/Ship, plus a meta-skill for discovery. `2.1.0` adds the 7 upstream lifecycle slash-command wrappers: `/spec`, `/plan`, `/build`, `/test`, `/review`, `/code-simplify`, `/ship`. Earlier, `2.0.0` renamed the plugin from `dotnet-agent-skills` to `dotnet-skills` (breaking); existing installs must uninstall + reinstall under the new name.

Run `/dotnet-skills` to list available skills, or jump straight to a lifecycle phase with `/spec`, `/plan`, `/build`, `/test`, `/review`, `/code-simplify`, `/ship`. Plugin details: [`plugins/dotnet-skills/README.md`](./plugins/dotnet-skills/README.md).

## Installation

```bash
claude plugins marketplace add peterblazejewicz/claude-plugins
claude plugins install avalonia-dev
claude plugins install dotnet-skills
```

## Credits

The `dotnet-skills` plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) by Addy Osmani, used under the **MIT License** (© 2025 Addy Osmani). Upstream content is ported skill-by-skill with .NET/C# adaptations; the upstream LICENSE is preserved verbatim at [`plugins/dotnet-skills/LICENSES/agent-skills-MIT.txt`](./plugins/dotnet-skills/LICENSES/agent-skills-MIT.txt) and per-skill provenance is recorded in the "Source & Modifications" footer of every ported `SKILL.md`.

Maintenance artifacts (pinned upstream snapshot, per-skill port ledger, re-sync script) live outside the installed plugin at [`sync-state/dotnet-skills/`](./sync-state/dotnet-skills) and [`scripts/sync-agent-skills.ps1`](./scripts/sync-agent-skills.ps1) — so end users installing `dotnet-skills` from the marketplace don't receive them.

## Requirements

- [Claude Code](https://claude.ai/code) with plugin support

## License

MIT for this marketplace's original content. Third-party content retains its original license — see the "Credits" section above and per-plugin `NOTICE.md` files.
