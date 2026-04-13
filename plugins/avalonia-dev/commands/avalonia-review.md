---
name: avalonia-review
description: Review Avalonia/MAUI project structure for design tokens, theming, and architecture improvements (supports Avalonia 11.x and 12.x)
---

# Avalonia Project Structure Review

Run a comprehensive, version-aware review of the current Avalonia or MAUI project structure.

## What This Command Does

1. **Detects** the project's Avalonia version (11.x or 12.x) from package references
2. **Analyzes** the project for hardcoded colors, fonts, and spacing values
3. **Identifies** design token extraction opportunities
4. **Evaluates** folder organization and separation of concerns
5. **Recommends** target structure based on project size
6. **Creates** a phased migration plan
7. **Applies** version-specific checks (compiled bindings, accessibility, navigation for v12; upgrade recommendation for v11)

## Usage

Run `/avalonia-review` in an Avalonia or MAUI project directory. The review auto-detects the Avalonia version and applies appropriate guidance.

## Invoke Skill

Use the `avalonia-dev:review` skill to perform this analysis.
