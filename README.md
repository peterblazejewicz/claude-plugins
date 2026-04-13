# Avalonia Dev — Claude Code Plugin

A Claude Code plugin for reviewing and improving **Avalonia** and **MAUI** project architecture. Supports Avalonia 11.x and 12.x.

## What It Does

Run `/avalonia-review` in your project to get a structured review covering:

- **Design token extraction** — find hardcoded colors, fonts, spacing and organize them into token files
- **Theme architecture** — evaluate resource dictionaries, light/dark theme support, StaticResource vs DynamicResource usage
- **Project structure** — assess folder organization, separation of concerns, recommend target layouts
- **Migration planning** — phased approach with priorities and risk levels
- **Version-specific checks (v12)** — compiled bindings (`x:DataType`), accessibility properties, page-based navigation patterns, new styling APIs
- **Upgrade guidance (v11)** — key benefits and migration path to Avalonia 12

## Installation

```bash
claude plugins marketplace add peterblazejewicz/claude-plugins
claude plugins install avalonia-dev
```

## Usage

```
/avalonia-review
```

The review auto-detects your Avalonia version from package references and applies the appropriate guidance.

## Reference Material

The plugin includes detailed reference files for:

| Reference | Contents |
|-----------|----------|
| Design Tokens | Color, typography, spacing, elevation token patterns with AXAML examples |
| Project Structure | Folder layouts for small and large projects, dependency layering |
| Migration Guide | Phased migration steps, templates, Avalonia 12 API changes |

## Requirements

- [Claude Code](https://claude.ai/code) with plugin support

## License

MIT
