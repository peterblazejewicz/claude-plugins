---
name: review
description: Use when the user asks to "review Avalonia structure", "review XAML project", "improve theming", "add design tokens", "organize styles", or needs Avalonia/MAUI architecture guidance. Supports Avalonia 11.x and 12.x with version-specific checks.
version: 1.1.0
---

# Avalonia Project Structure Review

This skill provides structured guidance for reviewing and improving Avalonia (and MAUI) project architecture. Focus on design token extraction, separation of concerns, and scalable folder organization.

Supports **Avalonia 11.x** and **12.x** — version-specific guidance is applied based on the detected project version.

## Core Principles

### 1. Design Tokens First

Extract all hardcoded values (colors, typography, spacing) into centralized token files. This is the foundation for any theming system and provides immediate benefits with minimal risk.

### 2. Separation by Responsibility

| Layer | Purpose | Dependencies |
|-------|---------|--------------|
| Theme/Tokens | Raw design values (colors, spacing, fonts) | None |
| Theme/Styles | Reusable styles using tokens | Tokens |
| Controls | Shared UI components | Theme |
| Pages | Navigation destinations (Avalonia 12+) | Controls, Theme |
| Views | Feature-specific screens | Controls, Theme |
| ViewModels | Presentation logic | Core/Domain |

### 3. Dependency Direction

```
App (Host)
    |
Features/Views/Pages
    |
Controls <-> ViewModels
    |
Theme (Tokens + Styles)
    |
Core (Non-UI shared code)
```

Controls and Views consume theme tokens via `{StaticResource}` or `{DynamicResource}` references—they never define actual color/spacing values.

## Review Process

### Step 0: Detect Avalonia Version

Before reviewing, determine the project's Avalonia version:

1. Use Grep to search for Avalonia package references in project configuration files:
   - Search `Directory.Packages.props` and `Directory.Build.props` for `PackageReference.*Avalonia` or `<AvaloniaVersion>`
   - Search `*.csproj` files for `PackageReference.*Avalonia.*Version`
2. Parse the major version number (11 or 12)
3. If the version cannot be determined, ask the user which Avalonia version they are targeting

Record the detected version — it determines which version-specific checks apply in Step 5.

### Step 1: Analyze Current State

1. Identify where styles, colors, and sizes are defined
2. Note coupling between controls and app-specific code
3. Check for hardcoded values in AXAML files
4. Assess current folder organization
5. Review App.axaml for resource structure

Use search tools to find:
- Hardcoded color values: pattern `#[0-9A-Fa-f]{6,8}` in `*.axaml` files
- Inline styles: patterns `FontSize="[0-9]`, `Margin="[0-9]`, `Padding="[0-9]` in `*.axaml` files
- Missing StaticResource usage: pattern `Background="#` in `*.axaml` files

### Step 2: Identify Issues

Common problems to flag:

- **Hardcoded values**: Colors, fonts, spacing directly in views/controls
- **Duplicate styles**: Same style definitions in multiple files
- **Coupled controls**: Controls with dependencies on ViewModels or services
- **Missing theme variants**: No light/dark theme support
- **Inconsistent naming**: No conventions for tokens and styles
- **Scattered resources**: ResourceDictionaries spread without organization
- **(v12)** Missing `x:DataType` declarations on views/controls using bindings
- **(v12)** Missing accessibility properties on interactive controls

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

### Step 5: Version-Specific Review

#### If Avalonia 12.x

Perform these additional checks after the core review:

1. **Compiled Bindings**: Avalonia 12 enables compiled bindings by default. Check if views and controls declare `x:DataType` for type-safe bindings. Flag `{Binding}` usage without a corresponding `x:DataType` as a performance and type-safety issue. Search for `<UserControl`, `<Window`, and `<ContentPage` elements and verify they include `x:DataType` attributes.

2. **Accessibility**: Check for accessibility support:
   - `AutomationProperties.Name` on interactive controls (buttons, inputs, toggles)
   - Keyboard navigation support and focus traversal configuration
   - Use of the new public `FocusManager` API where custom focus behavior is needed

3. **Navigation Patterns**: If the app implements custom navigation, suggest evaluating Avalonia 12's built-in page-based navigation system:
   - `ContentPage` for simple page navigation
   - `DrawerPage` for drawer/sidebar navigation
   - `CarouselPage` for gesture-based page switching
   - `TabbedPage` via `TabView` for tabbed interfaces
   - `PipsPager` for visual page indicators

4. **New Token Opportunities**: Check for styling properties introduced in Avalonia 12:
   - `PlaceholderForeground` on TextBox, AutoCompleteBox, CalendarDatePicker, NumericUpDown
   - `LetterSpacing` on text elements (inherited attached property on TextElement)
   - Window decoration theming via themeable client-side decorations

5. **API Modernization**: Flag deprecated or renamed patterns:
   - `SystemDecorations` → `WindowDecorations`
   - `PropertyPath` usage (removed in v12)
   - `FuncMultiValueConverter` parameter change (`IEnumerable` → `IList`)

#### If Avalonia 11.x

After completing the core review (Steps 1-4), present an upgrade recommendation:

> **Upgrade Recommendation**: Avalonia 12 is now available with significant improvements:
> - Up to 1,867% rendering performance improvement in complex scenes
> - Compiled bindings enabled by default (better performance + type safety)
> - Built-in page-based navigation system (ContentPage, DrawerPage, CarouselPage)
> - Native Linux accessibility (AT-SPI2) — first .NET framework with this support
> - Themeable client-side window decorations
> - New threading model with Dispatcher.CurrentDispatcher and AvaloniaObject.Dispatcher
> - Hundreds of bug fixes across all platforms
>
> The migration is designed to be completed within a sprint. Most teams report only minor code changes needed.

If the user indicates they are not ready to upgrade ("not at this time", "not now", "we'll do that later"), acknowledge their decision and do not repeat the recommendation in this session. Continue providing v11-appropriate guidance.

## Key Deliverables

When completing a review, provide these deliverables:

| Deliverable | Description |
|-------------|-------------|
| Avalonia Version | Detected version and version-specific notes |
| Assessment Summary | Current state analysis and identified issues |
| Target Structure | Recommended folder/project layout diagram |
| Migration Phases | Ordered steps with priorities and risk levels |
| File Templates | Starter AXAML files for tokens |
| App.axaml Updates | Integration instructions for new theme system |
| Upgrade Path (v11 only) | Key benefits and migration guidance for Avalonia 12 |

## Design Token Categories

Recommend organizing tokens into these files:

| File | Contents |
|------|----------|
| `Colors.axaml` | Brand colors, semantic colors, neutral palette, theme variants |
| `Typography.axaml` | Font families, sizes, weights, line heights, letter spacing (v12+) |
| `Spacing.axaml` | Spacing scale, padding presets, margins, corner radius, borders |
| `Elevation.axaml` | Box shadows, z-index values (if applicable) |

See `references/design-tokens.md` for complete token organization patterns.

## Important Considerations

- **Preserve functionality**: Migration must not break existing features
- **Incremental approach**: Avoid big-bang refactoring; phase the changes
- **Semantic naming**: Use `ColorSuccess` over `Green500` where appropriate
- **Theme variants**: Structure tokens to support light/dark from the start using ThemeDictionaries
- **Resource references**: Theme-aware values (colors that change between light/dark) use `{DynamicResource}`; fixed values (spacing, radius) use `{StaticResource}`
- **(v12) Compiled bindings**: Avalonia 12 enables compiled bindings by default — add `x:DataType` to views and controls for type-safe, performant bindings
- **(v12) Accessibility**: Review interactive controls for `AutomationProperties.Name` and keyboard/focus support

## Out of Scope for Initial Review

The initial review focuses on structure and strategy. Defer to follow-up tasks:

- Specific control templates
- Complete style definitions
- Code-behind changes
- ViewModel refactoring

## Quick Reference Searches

Use your search tools to find common issues:

| What to Find | Search Pattern | File Type |
|---|---|---|
| Hardcoded colors | `#[0-9A-Fa-f]{6,8}` | `*.axaml` |
| Inline font sizes | `FontSize="[0-9]` | `*.axaml` |
| Hardcoded backgrounds | `Background="#` | `*.axaml` |
| ResourceDictionary files | `ResourceDictionary` | `*.axaml` |
| Avalonia version | `PackageReference.*Avalonia` | `*.csproj`, `*.props` |
| Missing x:DataType (v12) | `<UserControl` or `<Window` without `x:DataType` | `*.axaml` |
| ViewModel coupling | `ViewModel` | `*.cs` in Controls/ |
| Accessibility gaps | `AutomationProperties` | `*.axaml` |
| Custom navigation (v12) | `INavigationService\|NavigationService` | `*.cs` |

## Additional Resources

### Reference Files

For detailed patterns and implementation guidance, consult:

- **`references/design-tokens.md`** — Complete token organization with AXAML examples (v11 and v12)
- **`references/project-structure.md`** — Detailed folder layouts for small and large projects
- **`references/migration-guide.md`** — Step-by-step migration phases with templates and v12 API changes

### External Resources

- [Avalonia Styling Documentation](https://docs.avaloniaui.net/docs/basics/user-interface/styling)
- [Avalonia Themes](https://docs.avaloniaui.net/docs/basics/user-interface/styling/themes/)
- [ResourceDictionary Reference](https://docs.avaloniaui.net/docs/guides/styles-and-resources/resources)
- [Avalonia 12 Release Blog](https://avaloniaui.net/blog/avalonia-12/)
