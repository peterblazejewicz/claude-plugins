---
name: review
description: Use when the user asks to "review Avalonia structure", "review XAML project", "improve theming", "add design tokens", "organize styles", or needs Avalonia/MAUI architecture guidance.
version: 1.0.0
---

# Avalonia Project Structure Review

This skill provides structured guidance for reviewing and improving Avalonia (and MAUI) project architecture. Focus on design token extraction, separation of concerns, and scalable folder organization.

## Core Principles

### 1. Design Tokens First

Extract all hardcoded values (colors, typography, spacing) into centralized token files. This is the foundation for any theming system and provides immediate benefits with minimal risk.

### 2. Separation by Responsibility

| Layer | Purpose | Dependencies |
|-------|---------|--------------|
| Theme/Tokens | Raw design values (colors, spacing, fonts) | None |
| Theme/Styles | Reusable styles using tokens | Tokens |
| Controls | Shared UI components | Theme |
| Views | Feature-specific screens | Controls, Theme |
| ViewModels | Presentation logic | Core/Domain |

### 3. Dependency Direction

```
App (Host)
    |
Features/Views
    |
Controls <-> ViewModels
    |
Theme (Tokens + Styles)
    |
Core (Non-UI shared code)
```

Controls and Views consume theme tokens via `{StaticResource}` references—they never define actual color/spacing values.

## Review Process

When reviewing an Avalonia project, follow these steps in order:

### Step 1: Analyze Current State

1. Identify where styles, colors, and sizes are defined
2. Note coupling between controls and app-specific code
3. Check for hardcoded values in AXAML files
4. Assess current folder organization
5. Review App.axaml for resource structure

Use Grep and Glob tools to find:
- Hardcoded color values: `#[0-9A-Fa-f]{6,8}` in `.axaml` files
- Inline styles: `FontSize=`, `Margin=`, `Padding=` with literal values
- Missing StaticResource usage

### Step 2: Identify Issues

Common problems to flag:

- **Hardcoded values**: Colors, fonts, spacing directly in views/controls
- **Duplicate styles**: Same style definitions in multiple files
- **Coupled controls**: Controls with dependencies on ViewModels or services
- **Missing theme variants**: No light/dark theme support
- **Inconsistent naming**: No conventions for tokens and styles
- **Scattered resources**: ResourceDictionaries spread without organization

### Step 3: Propose Target Structure

Recommend folder/project organization based on project size:

**Small Projects (< 10 views, < 5 custom controls):**
Reorganize folders within existing project. See `references/project-structure.md` for details.

**Medium/Large Projects (10+ views, 5+ custom controls):**
Extract into separate class library projects. See `references/project-structure.md` for multi-project layouts.

### Step 4: Create Migration Plan

Prioritize phases by risk and impact:

1. **Phase 1**: Token extraction (lowest risk, highest impact)
2. **Phase 2**: Style consolidation
3. **Phase 3**: Control isolation
4. **Phase 4**: Project splitting (if applicable)

See `references/migration-guide.md` for detailed phased approach.

## Key Deliverables

When completing a review, provide these deliverables:

| Deliverable | Description |
|-------------|-------------|
| Assessment Summary | Current state analysis and identified issues |
| Target Structure | Recommended folder/project layout diagram |
| Migration Phases | Ordered steps with priorities and risk levels |
| File Templates | Starter AXAML files for tokens |
| App.axaml Updates | Integration instructions for new theme system |

## Design Token Categories

Recommend organizing tokens into these files:

| File | Contents |
|------|----------|
| `Colors.axaml` | Brand colors, semantic colors, neutral palette, theme variants |
| `Typography.axaml` | Font families, sizes, weights, line heights |
| `Spacing.axaml` | Spacing scale, padding presets, margins, corner radius, borders |
| `Elevation.axaml` | Box shadows, z-index values (if applicable) |

See `references/design-tokens.md` for complete token organization patterns.

## Important Considerations

- **Preserve functionality**: Migration must not break existing features
- **Incremental approach**: Avoid big-bang refactoring; phase the changes
- **Semantic naming**: Use `ColorSuccess` over `Green500` where appropriate
- **Theme variants**: Structure tokens to support light/dark from the start using ThemeDictionaries
- **Resource references**: All controls and views use `{StaticResource TokenName}` not hardcoded values

## Out of Scope for Initial Review

The initial review focuses on structure and strategy. Defer to follow-up tasks:

- Specific control templates
- Complete style definitions
- Code-behind changes
- ViewModel refactoring

## Quick Reference Commands

```bash
# Find hardcoded colors in AXAML
grep -r "#[0-9A-Fa-f]\{6,8\}" --include="*.axaml" .

# Find inline font sizes
grep -r "FontSize=\"[0-9]" --include="*.axaml" .

# Find missing StaticResource usage
grep -r "Background=\"#" --include="*.axaml" .

# List all ResourceDictionary files
find . -name "*.axaml" -exec grep -l "ResourceDictionary" {} \;
```

## Additional Resources

### Reference Files

For detailed patterns and implementation guidance, consult:

- **`references/design-tokens.md`** — Complete token organization with AXAML examples
- **`references/project-structure.md`** — Detailed folder layouts for small and large projects
- **`references/migration-guide.md`** — Step-by-step migration phases with templates

### External Resources

- [Avalonia Styling Documentation](https://docs.avaloniaui.net/docs/basics/user-interface/styling)
- [Avalonia Themes](https://docs.avaloniaui.net/docs/basics/user-interface/styling/themes/)
- [ResourceDictionary Reference](https://docs.avaloniaui.net/docs/guides/styles-and-resources/resources)
