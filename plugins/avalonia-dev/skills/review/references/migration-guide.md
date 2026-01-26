# Migration Guide

This reference provides step-by-step migration phases for reorganizing Avalonia project structure.

## Migration Principles

1. **Preserve functionality**: Migration must not break existing features
2. **Incremental approach**: Avoid big-bang refactoring; phase the changes
3. **Test after each phase**: Verify application works before proceeding
4. **Commit frequently**: Each phase should be a separate commit

## Phase Overview

| Phase | Risk | Impact | Description |
|-------|------|--------|-------------|
| 1. Token Extraction | Low | High | Extract colors, typography, spacing to token files |
| 2. Style Consolidation | Low | Medium | Move styles to centralized style files |
| 3. Control Isolation | Medium | Medium | Remove ViewModel dependencies from controls |
| 4. Project Splitting | High | Low | Extract into separate class libraries (optional) |

## Phase 1: Token Extraction

### Goal

Extract all hardcoded values into centralized token files.

### Steps

#### 1.1 Create Token Directory Structure

```bash
mkdir -p Theme/Tokens
touch Theme/Tokens/Colors.axaml
touch Theme/Tokens/Typography.axaml
touch Theme/Tokens/Spacing.axaml
```

#### 1.2 Audit Existing Colors

Search for hardcoded colors:

```bash
# Find all hex colors in AXAML files
grep -rn "#[0-9A-Fa-f]\{6,8\}" --include="*.axaml" .

# Find Color= attributes
grep -rn "Color=\"#" --include="*.axaml" .

# Find Background= with hardcoded values
grep -rn "Background=\"#" --include="*.axaml" .
```

#### 1.3 Create Colors.axaml

Start with Colors.axaml template from `references/design-tokens.md`:

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <!-- Add discovered colors here -->
    <Color x:Key="ColorPrimary">#4A90D9</Color>
    <!-- ... -->

    <SolidColorBrush x:Key="BrushPrimary" Color="{StaticResource ColorPrimary}"/>
    <!-- ... -->

</ResourceDictionary>
```

#### 1.4 Update App.axaml

Add token file reference:

```xml
<Application.Resources>
    <ResourceDictionary>
        <ResourceDictionary.MergedDictionaries>
            <ResourceInclude Source="avares://AppName/Theme/Tokens/Colors.axaml"/>
            <!-- Existing resources below -->
        </ResourceDictionary.MergedDictionaries>
    </ResourceDictionary>
</Application.Resources>
```

#### 1.5 Replace Hardcoded Colors

Replace each hardcoded color with StaticResource:

```xml
<!-- Before -->
<Border Background="#16161D">

<!-- After -->
<Border Background="{StaticResource BrushSurfaceBase}">
```

#### 1.6 Repeat for Typography and Spacing

Follow same process for:
- Font sizes, families, weights -> Typography.axaml
- Margins, paddings, corner radius -> Spacing.axaml

#### 1.7 Test

- Build application
- Verify all colors display correctly
- Check dark/light theme if applicable

### Commit

```bash
git add Theme/Tokens/
git add App.axaml
git commit -m "feat(theme): extract design tokens to centralized files"
```

## Phase 2: Style Consolidation

### Goal

Move scattered styles to centralized style files.

### Steps

#### 2.1 Create Styles Directory

```bash
mkdir -p Theme/Styles
touch Theme/Styles/TextStyles.axaml
touch Theme/Styles/ButtonStyles.axaml
touch Theme/Styles/CardStyles.axaml
```

#### 2.2 Audit Existing Styles

Find inline and scattered styles:

```bash
# Find Style definitions
grep -rn "<Style " --include="*.axaml" .

# Find inline setters that could be styles
grep -rn "FontSize=\"" --include="*.axaml" .
grep -rn "FontWeight=\"" --include="*.axaml" .
```

#### 2.3 Create Text Styles

Extract common text patterns:

```xml
<!-- Theme/Styles/TextStyles.axaml -->
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <Style Selector="TextBlock.h1">
        <Setter Property="FontSize" Value="{StaticResource FontSizeH1}"/>
        <Setter Property="FontWeight" Value="{StaticResource FontWeightBold}"/>
        <Setter Property="Foreground" Value="{StaticResource BrushTextPrimary}"/>
    </Style>

    <!-- ... more styles -->

</ResourceDictionary>
```

#### 2.4 Update App.axaml

Add style files after tokens:

```xml
<ResourceDictionary.MergedDictionaries>
    <!-- Tokens first -->
    <ResourceInclude Source="avares://AppName/Theme/Tokens/Colors.axaml"/>
    <ResourceInclude Source="avares://AppName/Theme/Tokens/Typography.axaml"/>
    <ResourceInclude Source="avares://AppName/Theme/Tokens/Spacing.axaml"/>

    <!-- Styles second -->
    <ResourceInclude Source="avares://AppName/Theme/Styles/TextStyles.axaml"/>
    <ResourceInclude Source="avares://AppName/Theme/Styles/ButtonStyles.axaml"/>
</ResourceDictionary.MergedDictionaries>
```

#### 2.5 Apply Styles to Views

Replace inline styles with class-based styles:

```xml
<!-- Before -->
<TextBlock FontSize="28" FontWeight="Bold" Text="Title"/>

<!-- After -->
<TextBlock Classes="h1" Text="Title"/>
```

#### 2.6 Test

- Build application
- Verify styling is consistent
- Check that all text/buttons render correctly

### Commit

```bash
git add Theme/Styles/
git commit -m "feat(theme): consolidate styles into centralized style files"
```

## Phase 3: Control Isolation

### Goal

Ensure controls have no dependencies on ViewModels or app-specific services.

### Steps

#### 3.1 Audit Control Dependencies

Check each control for:

```bash
# Find ViewModel references in Controls
grep -rn "ViewModel" Controls/ --include="*.cs"

# Find service dependencies
grep -rn "IService\|Service" Controls/ --include="*.cs"

# Find app-specific namespaces
grep -rn "using.*ViewModels" Controls/ --include="*.cs"
```

#### 3.2 Identify Coupling Patterns

Common issues:
- Control directly references ViewModel type
- Control calls service methods
- Control uses app-specific models

#### 3.3 Refactor to Dependency Properties

Replace ViewModel dependencies with bindable properties:

```csharp
// Before - tightly coupled
public partial class UserCard : UserControl
{
    public UserViewModel ViewModel => (UserViewModel)DataContext;

    private void OnClick()
    {
        ViewModel.NavigateToProfile();
    }
}

// After - loosely coupled
public partial class UserCard : UserControl
{
    public static readonly StyledProperty<string> UserNameProperty =
        AvaloniaProperty.Register<UserCard, string>(nameof(UserName));

    public static readonly StyledProperty<ICommand> ProfileCommandProperty =
        AvaloniaProperty.Register<UserCard, ICommand>(nameof(ProfileCommand));

    public string UserName
    {
        get => GetValue(UserNameProperty);
        set => SetValue(UserNameProperty, value);
    }

    public ICommand ProfileCommand
    {
        get => GetValue(ProfileCommandProperty);
        set => SetValue(ProfileCommandProperty, value);
    }
}
```

#### 3.4 Update Control AXAML

Bind to own properties instead of DataContext:

```xml
<!-- Before -->
<TextBlock Text="{Binding ViewModel.UserName}"/>

<!-- After -->
<TextBlock Text="{Binding UserName, RelativeSource={RelativeSource Self}}"/>
```

#### 3.5 Update View Usage

Pass data through properties:

```xml
<!-- In View -->
<controls:UserCard
    UserName="{Binding CurrentUser.Name}"
    ProfileCommand="{Binding NavigateToProfileCommand}"/>
```

#### 3.6 Test

- Build application
- Verify controls function correctly
- Test all interactions

### Commit

```bash
git add Controls/
git commit -m "refactor(controls): remove ViewModel dependencies from controls"
```

## Phase 4: Project Splitting (Optional)

### Goal

Extract theme and controls into separate class library projects.

### When to Apply

Only proceed if:
- Project has 30+ views or 15+ controls
- Multiple applications will share theme/controls
- Team wants independent versioning
- Build times are becoming problematic

### Steps

#### 4.1 Create Solution Structure

```bash
mkdir -p src/AppName.Theme
mkdir -p src/AppName.Controls
```

#### 4.2 Create Theme Project

```xml
<!-- src/AppName.Theme/AppName.Theme.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <EnableDefaultItems>false</EnableDefaultItems>
  </PropertyGroup>

  <ItemGroup>
    <AvaloniaResource Include="**\*.axaml" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Avalonia" Version="11.*" />
  </ItemGroup>
</Project>
```

#### 4.3 Move Theme Files

```bash
mv Theme/Tokens src/AppName.Theme/Tokens
mv Theme/Styles src/AppName.Theme/Styles
```

#### 4.4 Create Controls Project

```xml
<!-- src/AppName.Controls/AppName.Controls.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\AppName.Theme\AppName.Theme.csproj" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Avalonia" Version="11.*" />
  </ItemGroup>
</Project>
```

#### 4.5 Move Control Files

```bash
mv Controls/* src/AppName.Controls/
```

#### 4.6 Update Main Project References

```xml
<!-- src/AppName/AppName.csproj -->
<ItemGroup>
  <ProjectReference Include="..\AppName.Theme\AppName.Theme.csproj" />
  <ProjectReference Include="..\AppName.Controls\AppName.Controls.csproj" />
</ItemGroup>
```

#### 4.7 Update Resource Paths

Change `avares://` paths to reference new assemblies:

```xml
<!-- Before -->
<ResourceInclude Source="avares://AppName/Theme/Tokens/Colors.axaml"/>

<!-- After -->
<ResourceInclude Source="avares://AppName.Theme/Tokens/Colors.axaml"/>
```

#### 4.8 Update Namespaces

Update all namespace declarations:

```csharp
// Before
namespace AppName.Controls;

// After
namespace AppName.Controls;  // Same, but in new project
```

#### 4.9 Test

- Build entire solution
- Run all tests
- Verify application functions correctly

### Commit

```bash
git add src/
git commit -m "refactor(architecture): extract theme and controls into separate projects"
```

## Rollback Strategy

If issues occur during migration:

### Phase 1-2 Rollback

Simple file reverts:

```bash
git checkout HEAD~1 -- Theme/
git checkout HEAD~1 -- App.axaml
```

### Phase 3 Rollback

Revert control changes:

```bash
git revert HEAD  # Revert last commit
```

### Phase 4 Rollback

More complex - restore original project structure:

```bash
git revert HEAD  # Revert project split
# Manual cleanup may be required
```

## Validation Checklist

After each phase, verify:

- [ ] Application builds without errors
- [ ] All views render correctly
- [ ] Theme colors display as expected
- [ ] Dark/light theme switching works (if applicable)
- [ ] All controls function properly
- [ ] Unit tests pass
- [ ] UI tests pass

## File Templates

### ThemeResources.axaml (Convenience Aggregator)

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <ResourceDictionary.MergedDictionaries>
        <!-- Tokens -->
        <ResourceInclude Source="avares://AppName.Theme/Tokens/Colors.axaml"/>
        <ResourceInclude Source="avares://AppName.Theme/Tokens/Typography.axaml"/>
        <ResourceInclude Source="avares://AppName.Theme/Tokens/Spacing.axaml"/>
        <ResourceInclude Source="avares://AppName.Theme/Tokens/Elevation.axaml"/>

        <!-- Styles -->
        <ResourceInclude Source="avares://AppName.Theme/Styles/TextStyles.axaml"/>
        <ResourceInclude Source="avares://AppName.Theme/Styles/ButtonStyles.axaml"/>
        <ResourceInclude Source="avares://AppName.Theme/Styles/CardStyles.axaml"/>
        <ResourceInclude Source="avares://AppName.Theme/Styles/InputStyles.axaml"/>
    </ResourceDictionary.MergedDictionaries>
</ResourceDictionary>
```

Usage in App.axaml:

```xml
<ResourceDictionary.MergedDictionaries>
    <ResourceInclude Source="avares://AppName.Theme/ThemeResources.axaml"/>
</ResourceDictionary.MergedDictionaries>
```
