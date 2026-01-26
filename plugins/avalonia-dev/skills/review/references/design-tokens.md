# Design Token Organization

This reference provides detailed guidance on organizing design tokens in Avalonia projects.

## Token File Structure

Organize tokens into separate files by category:

```
Theme/
└── Tokens/
    ├── Colors.axaml
    ├── Typography.axaml
    ├── Spacing.axaml
    └── Elevation.axaml
```

## Colors.axaml

### Template Structure

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <!-- Brand Colors -->
    <Color x:Key="ColorBrandPrimary">#4A90D9</Color>
    <Color x:Key="ColorBrandSecondary">#6B7280</Color>

    <!-- Semantic Colors -->
    <Color x:Key="ColorSuccess">#22C55E</Color>
    <Color x:Key="ColorWarning">#F59E0B</Color>
    <Color x:Key="ColorError">#EF4444</Color>
    <Color x:Key="ColorInfo">#3B82F6</Color>

    <!-- Surface Colors -->
    <Color x:Key="ColorSurfaceDark">#0F0F13</Color>
    <Color x:Key="ColorSurfaceBase">#16161D</Color>
    <Color x:Key="ColorSurfaceElevated">#1E1E24</Color>
    <Color x:Key="ColorSurfaceBorder">#303040</Color>

    <!-- Text Colors -->
    <Color x:Key="ColorTextPrimary">#FFFFFF</Color>
    <Color x:Key="ColorTextSecondary">#A0A0B0</Color>
    <Color x:Key="ColorTextDisabled">#606070</Color>

    <!-- Create SolidColorBrush resources -->
    <SolidColorBrush x:Key="BrushBrandPrimary" Color="{StaticResource ColorBrandPrimary}"/>
    <SolidColorBrush x:Key="BrushSuccess" Color="{StaticResource ColorSuccess}"/>
    <SolidColorBrush x:Key="BrushTextPrimary" Color="{StaticResource ColorTextPrimary}"/>
    <!-- ... etc -->

</ResourceDictionary>
```

### Theme Variants (Light/Dark)

For theme variant support, use ThemeDictionaries:

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <ResourceDictionary.ThemeDictionaries>
        <!-- Dark Theme -->
        <ResourceDictionary x:Key="Dark">
            <Color x:Key="ColorSurfaceBase">#16161D</Color>
            <Color x:Key="ColorTextPrimary">#FFFFFF</Color>
            <SolidColorBrush x:Key="BrushSurfaceBase" Color="{StaticResource ColorSurfaceBase}"/>
            <SolidColorBrush x:Key="BrushTextPrimary" Color="{StaticResource ColorTextPrimary}"/>
        </ResourceDictionary>

        <!-- Light Theme -->
        <ResourceDictionary x:Key="Light">
            <Color x:Key="ColorSurfaceBase">#FFFFFF</Color>
            <Color x:Key="ColorTextPrimary">#1F2937</Color>
            <SolidColorBrush x:Key="BrushSurfaceBase" Color="{StaticResource ColorSurfaceBase}"/>
            <SolidColorBrush x:Key="BrushTextPrimary" Color="{StaticResource ColorTextPrimary}"/>
        </ResourceDictionary>
    </ResourceDictionary.ThemeDictionaries>

</ResourceDictionary>
```

## Typography.axaml

### Template Structure

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <!-- Font Families -->
    <FontFamily x:Key="FontFamilyDefault">Inter, Segoe UI, sans-serif</FontFamily>
    <FontFamily x:Key="FontFamilyMono">JetBrains Mono, Consolas, monospace</FontFamily>

    <!-- Font Sizes -->
    <x:Double x:Key="FontSizeH1">28</x:Double>
    <x:Double x:Key="FontSizeH2">22</x:Double>
    <x:Double x:Key="FontSizeH3">18</x:Double>
    <x:Double x:Key="FontSizeBody">16</x:Double>
    <x:Double x:Key="FontSizeLabel">14</x:Double>
    <x:Double x:Key="FontSizeCaption">13</x:Double>
    <x:Double x:Key="FontSizeMono">14</x:Double>

    <!-- Font Weights -->
    <FontWeight x:Key="FontWeightRegular">Regular</FontWeight>
    <FontWeight x:Key="FontWeightMedium">Medium</FontWeight>
    <FontWeight x:Key="FontWeightSemiBold">SemiBold</FontWeight>
    <FontWeight x:Key="FontWeightBold">Bold</FontWeight>

    <!-- Line Heights (as multipliers) -->
    <x:Double x:Key="LineHeightTight">1.2</x:Double>
    <x:Double x:Key="LineHeightNormal">1.5</x:Double>
    <x:Double x:Key="LineHeightRelaxed">1.75</x:Double>

</ResourceDictionary>
```

### Typography Styles

Create reusable text styles that reference tokens:

```xml
<!-- In Theme/Styles/TextStyles.axaml -->
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <Style Selector="TextBlock.h1">
        <Setter Property="FontFamily" Value="{StaticResource FontFamilyDefault}"/>
        <Setter Property="FontSize" Value="{StaticResource FontSizeH1}"/>
        <Setter Property="FontWeight" Value="{StaticResource FontWeightBold}"/>
        <Setter Property="Foreground" Value="{StaticResource BrushTextPrimary}"/>
    </Style>

    <Style Selector="TextBlock.body">
        <Setter Property="FontFamily" Value="{StaticResource FontFamilyDefault}"/>
        <Setter Property="FontSize" Value="{StaticResource FontSizeBody}"/>
        <Setter Property="FontWeight" Value="{StaticResource FontWeightRegular}"/>
        <Setter Property="Foreground" Value="{StaticResource BrushTextPrimary}"/>
    </Style>

    <Style Selector="TextBlock.mono">
        <Setter Property="FontFamily" Value="{StaticResource FontFamilyMono}"/>
        <Setter Property="FontSize" Value="{StaticResource FontSizeMono}"/>
        <Setter Property="Foreground" Value="{StaticResource BrushTextSecondary}"/>
    </Style>

</ResourceDictionary>
```

## Spacing.axaml

### Template Structure

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <!-- Spacing Scale (4px base) -->
    <x:Double x:Key="SpacingXs">4</x:Double>
    <x:Double x:Key="SpacingSm">8</x:Double>
    <x:Double x:Key="SpacingMd">16</x:Double>
    <x:Double x:Key="SpacingLg">24</x:Double>
    <x:Double x:Key="SpacingXl">32</x:Double>
    <x:Double x:Key="Spacing2Xl">48</x:Double>

    <!-- Thickness Presets (for Margin/Padding) -->
    <Thickness x:Key="PaddingNone">0</Thickness>
    <Thickness x:Key="PaddingSm">8</Thickness>
    <Thickness x:Key="PaddingMd">16</Thickness>
    <Thickness x:Key="PaddingLg">24</Thickness>

    <!-- Asymmetric Padding -->
    <Thickness x:Key="PaddingCardContent">16,12</Thickness>
    <Thickness x:Key="PaddingButtonContent">16,8</Thickness>

    <!-- Corner Radius -->
    <CornerRadius x:Key="RadiusNone">0</CornerRadius>
    <CornerRadius x:Key="RadiusSm">4</CornerRadius>
    <CornerRadius x:Key="RadiusMd">8</CornerRadius>
    <CornerRadius x:Key="RadiusLg">12</CornerRadius>
    <CornerRadius x:Key="RadiusFull">9999</CornerRadius>

    <!-- Border Widths -->
    <x:Double x:Key="BorderWidthThin">1</x:Double>
    <x:Double x:Key="BorderWidthMedium">2</x:Double>
    <x:Double x:Key="BorderWidthThick">4</x:Double>

    <!-- Touch Target Sizes -->
    <x:Double x:Key="TouchTargetMin">48</x:Double>
    <x:Double x:Key="TouchTargetPrimary">60</x:Double>

</ResourceDictionary>
```

## Elevation.axaml

### Template Structure

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <!-- Box Shadows -->
    <BoxShadows x:Key="ElevationNone">0 0 0 0 Transparent</BoxShadows>
    <BoxShadows x:Key="ElevationSm">0 1 2 0 #1A000000</BoxShadows>
    <BoxShadows x:Key="ElevationMd">0 4 6 -1 #1A000000, 0 2 4 -1 #0D000000</BoxShadows>
    <BoxShadows x:Key="ElevationLg">0 10 15 -3 #1A000000, 0 4 6 -2 #0D000000</BoxShadows>
    <BoxShadows x:Key="ElevationXl">0 20 25 -5 #1A000000, 0 10 10 -5 #0D000000</BoxShadows>

    <!-- Focus Ring -->
    <BoxShadows x:Key="FocusRing">0 0 0 3 #664A90D9</BoxShadows>

</ResourceDictionary>
```

## Naming Conventions

### Token Naming Pattern

Use semantic names over literal values:

| Pattern | Example | Avoid |
|---------|---------|-------|
| `Color{Purpose}` | `ColorSuccess` | `ColorGreen500` |
| `Color{Surface}{Variant}` | `ColorSurfaceElevated` | `ColorGray800` |
| `Brush{Purpose}` | `BrushTextPrimary` | `BrushWhite` |
| `FontSize{Scale}` | `FontSizeH1` | `FontSize28` |
| `Spacing{Scale}` | `SpacingMd` | `Spacing16` |
| `Radius{Scale}` | `RadiusMd` | `Radius8` |

### When to Use Literal Names

Literal names are acceptable for:

- Brand-specific palette colors (`ColorBrand500`)
- Neutral palette scales (`ColorNeutral100`, `ColorNeutral900`)
- Reference values that map to semantic tokens

## Integration in App.axaml

### Loading Order

Load tokens before styles that depend on them:

```xml
<Application.Resources>
    <ResourceDictionary>
        <ResourceDictionary.MergedDictionaries>
            <!-- 1. Tokens (no dependencies) -->
            <ResourceInclude Source="avares://AppName/Theme/Tokens/Colors.axaml"/>
            <ResourceInclude Source="avares://AppName/Theme/Tokens/Typography.axaml"/>
            <ResourceInclude Source="avares://AppName/Theme/Tokens/Spacing.axaml"/>
            <ResourceInclude Source="avares://AppName/Theme/Tokens/Elevation.axaml"/>

            <!-- 2. Styles (depend on tokens) -->
            <ResourceInclude Source="avares://AppName/Theme/Styles/TextStyles.axaml"/>
            <ResourceInclude Source="avares://AppName/Theme/Styles/ButtonStyles.axaml"/>
            <ResourceInclude Source="avares://AppName/Theme/Styles/CardStyles.axaml"/>
        </ResourceDictionary.MergedDictionaries>
    </ResourceDictionary>
</Application.Resources>
```

## Usage in Views

### Correct Usage

```xml
<Border Background="{StaticResource BrushSurfaceBase}"
        CornerRadius="{StaticResource RadiusMd}"
        Padding="{StaticResource PaddingMd}">
    <TextBlock Classes="h2" Text="Section Title"/>
</Border>
```

### Incorrect Usage (Avoid)

```xml
<!-- Hardcoded values - BAD -->
<Border Background="#16161D"
        CornerRadius="8"
        Padding="16">
    <TextBlock FontSize="22" FontWeight="SemiBold" Text="Section Title"/>
</Border>
```

## Dynamic vs Static Resources

| Use Case | Resource Type |
|----------|--------------|
| Theme-aware colors | `{DynamicResource}` |
| Fixed values (spacing, radius) | `{StaticResource}` |
| Performance-critical | `{StaticResource}` |
| Values that change at runtime | `{DynamicResource}` |

For theme switching support, colors should use `{DynamicResource}`:

```xml
<TextBlock Foreground="{DynamicResource BrushTextPrimary}"/>
```
