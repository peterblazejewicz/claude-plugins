# Avalonia Dev Plugin

Avalonia development tools for Claude Code, providing project structure review, theming guidance, and MVVM patterns for .NET cross-platform UI development.

## Features

- **Project Structure Review** - Analyze Avalonia/MAUI projects for architecture improvements
- **Design Token Extraction** - Identify hardcoded colors, fonts, and spacing for token extraction
- **Theme Organization** - Guidance on organizing themes with light/dark variant support
- **Migration Planning** - Phased migration plans with risk assessment

## Installation

### Via Plugin Directory

```bash
claude --plugin-dir "D:\develop\claude-plugins\plugins\avalonia-dev"
```

### Via Marketplace (when published)

```bash
claude /install avalonia-dev@blazejewicz-claude-plugins
```

## Usage

### Slash Command

Run a comprehensive project structure review:

```
/avalonia-review
```

### Natural Language

The skill triggers on queries like:

- "Review Avalonia structure"
- "Review XAML project"
- "Improve theming"
- "Add design tokens"
- "Organize styles"

## What It Analyzes

| Category | Checks |
|----------|--------|
| **Colors** | Hardcoded hex values, missing StaticResource usage |
| **Typography** | Inline FontSize, FontWeight, FontFamily |
| **Spacing** | Hardcoded Margin, Padding, CornerRadius |
| **Structure** | Folder organization, separation of concerns |
| **Coupling** | Control dependencies on ViewModels/services |

## Deliverables

When you run a review, you'll receive:

1. **Assessment Summary** - Current state analysis and identified issues
2. **Target Structure** - Recommended folder/project layout
3. **Migration Phases** - Ordered steps with priorities and risk levels
4. **File Templates** - Starter AXAML files for tokens
5. **App.axaml Updates** - Integration instructions

## Reference Documentation

The plugin includes detailed reference files:

| File | Contents |
|------|----------|
| `design-tokens.md` | Token file templates (Colors, Typography, Spacing, Elevation) |
| `project-structure.md` | Folder layouts for small, medium, and large projects |
| `migration-guide.md` | Step-by-step migration phases with rollback strategies |

## Project Size Recommendations

| Size | Views | Controls | Strategy |
|------|-------|----------|----------|
| Small | < 10 | < 5 | Reorganize folders within project |
| Medium | 10-30 | 5-15 | Feature-based organization |
| Large | 30+ | 15+ | Extract to separate class libraries |

## Example Token Structure

```
Theme/
├── Tokens/
│   ├── Colors.axaml
│   ├── Typography.axaml
│   ├── Spacing.axaml
│   └── Elevation.axaml
└── Styles/
    ├── TextStyles.axaml
    ├── ButtonStyles.axaml
    └── CardStyles.axaml
```

## Requirements

- Claude Code CLI
- Avalonia or MAUI project in the working directory

## Version History

| Version | Changes |
|---------|---------|
| 1.0.2 | Current release |
| 1.0.1 | Added migration guide references |
| 1.0.0 | Initial release with review skill and command |

## License

MIT
