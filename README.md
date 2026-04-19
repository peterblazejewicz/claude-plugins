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

### `dotnet-agent-skills` — .NET/C# agent skills (indirect fork of addyosmani/agent-skills)

Production-grade engineering skills adapted for .NET 8+ (LTS or newer), C# 12+, xUnit and MSTest, EF Core, and Avalonia UI (with ASP.NET Core, Blazor, and .NET MAUI targets planned). Currently at `0.1.0` — Wave 0 scaffolding with one sample skill (`spec-driven-development`); 20 more skills tracked as `pending` in the port ledger.

Run `/dotnet-skills` to list available skills. Plugin details: [`plugins/dotnet-agent-skills/README.md`](./plugins/dotnet-agent-skills/README.md).

## Installation

```bash
claude plugins marketplace add peterblazejewicz/claude-plugins
claude plugins install avalonia-dev
claude plugins install dotnet-agent-skills
```

## Credits

The `dotnet-agent-skills` plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) by Addy Osmani, used under the **MIT License** (© 2025 Addy Osmani). Upstream content is vendored as a pinned snapshot under [`plugins/dotnet-agent-skills/vendor/agent-skills/`](./plugins/dotnet-agent-skills/vendor/agent-skills) and ported skill-by-skill with .NET/C# adaptations. Per-skill provenance lives in [`plugins/dotnet-agent-skills/SYNC.md`](./plugins/dotnet-agent-skills/SYNC.md); the upstream LICENSE is preserved verbatim at [`plugins/dotnet-agent-skills/LICENSES/agent-skills-MIT.txt`](./plugins/dotnet-agent-skills/LICENSES/agent-skills-MIT.txt).

## Requirements

- [Claude Code](https://claude.ai/code) with plugin support

## License

MIT for this marketplace's original content. Third-party content retains its original license — see the "Credits" section above and per-plugin `NOTICE.md` files.
