# Project Structure Recommendations

This reference provides detailed folder and project layouts for Avalonia applications based on project size.

## Small Projects (< 10 views, < 5 custom controls)

### Strategy

Reorganize folders within the existing project. Create `Theme/Tokens/` and `Theme/Styles/` folders while keeping Controls, Views, and ViewModels as separate folders.

### Recommended Structure

```
AppName/
├── App.axaml
├── App.axaml.cs
├── Program.cs
│
├── Theme/
│   ├── Tokens/
│   │   ├── Colors.axaml
│   │   ├── Typography.axaml
│   │   ├── Spacing.axaml
│   │   └── Elevation.axaml
│   │
│   └── Styles/
│       ├── TextStyles.axaml
│       ├── ButtonStyles.axaml
│       ├── CardStyles.axaml
│       └── ControlStyles.axaml
│
├── Controls/
│   ├── CustomButton.axaml
│   ├── CustomButton.axaml.cs
│   ├── LoadingSpinner.axaml
│   └── LoadingSpinner.axaml.cs
│
├── Views/
│   ├── MainView.axaml
│   ├── MainView.axaml.cs
│   ├── SettingsView.axaml
│   └── SettingsView.axaml.cs
│
├── ViewModels/
│   ├── MainViewModel.cs
│   ├── SettingsViewModel.cs
│   └── ViewModelBase.cs
│
├── Services/
│   ├── INavigationService.cs
│   └── NavigationService.cs
│
├── Models/
│   └── AppSettings.cs
│
└── Assets/
    ├── Icons/
    └── Fonts/
```

### Benefits

- Single project maintains simplicity
- Clear separation of concerns within folders
- Easy to navigate for small teams
- Low migration overhead

## Medium Projects (10-30 views, 5-15 custom controls)

### Strategy

Consider extracting theme into a separate folder structure but keep within the same project. Organize views by feature/module.

### Recommended Structure

```
AppName/
├── App.axaml
├── App.axaml.cs
├── Program.cs
│
├── Theme/
│   ├── Tokens/
│   │   ├── Colors.axaml
│   │   ├── Typography.axaml
│   │   ├── Spacing.axaml
│   │   └── Elevation.axaml
│   │
│   ├── Styles/
│   │   ├── Base/
│   │   │   ├── TextStyles.axaml
│   │   │   └── LayoutStyles.axaml
│   │   └── Components/
│   │       ├── ButtonStyles.axaml
│   │       ├── CardStyles.axaml
│   │       └── InputStyles.axaml
│   │
│   └── ThemeResources.axaml  # Combines all for easy import
│
├── Controls/
│   ├── Common/
│   │   ├── IconButton.axaml
│   │   └── LoadingOverlay.axaml
│   ├── Forms/
│   │   ├── ValidatedTextBox.axaml
│   │   └── FormField.axaml
│   └── Layout/
│       ├── PageHeader.axaml
│       └── SidePanel.axaml
│
├── Features/
│   ├── Dashboard/
│   │   ├── Views/
│   │   │   ├── DashboardView.axaml
│   │   │   └── DashboardView.axaml.cs
│   │   └── ViewModels/
│   │       └── DashboardViewModel.cs
│   │
│   ├── Settings/
│   │   ├── Views/
│   │   │   ├── SettingsView.axaml
│   │   │   └── SettingsView.axaml.cs
│   │   └── ViewModels/
│   │       └── SettingsViewModel.cs
│   │
│   └── Reports/
│       ├── Views/
│       │   ├── ReportsView.axaml
│       │   └── ReportDetailView.axaml
│       └── ViewModels/
│           ├── ReportsViewModel.cs
│           └── ReportDetailViewModel.cs
│
├── Services/
│   ├── Abstractions/
│   │   ├── INavigationService.cs
│   │   └── IDataService.cs
│   └── Implementations/
│       ├── NavigationService.cs
│       └── DataService.cs
│
├── Core/
│   ├── Models/
│   ├── Constants/
│   └── Extensions/
│
└── Assets/
    ├── Icons/
    ├── Fonts/
    └── Images/
```

### Benefits

- Feature-based organization scales better
- Related files are grouped together
- Easier to work on specific features
- Clear boundaries between modules

## Large Projects (30+ views, 15+ custom controls)

### Strategy

Extract into separate class library projects for clear ownership boundaries and potential reuse.

### Multi-Project Solution Structure

```
AppName.sln
│
├── src/
│   │
│   ├── AppName.Theme/                    # Design tokens and base styles
│   │   ├── AppName.Theme.csproj
│   │   ├── Tokens/
│   │   │   ├── Colors.axaml
│   │   │   ├── Typography.axaml
│   │   │   ├── Spacing.axaml
│   │   │   └── Elevation.axaml
│   │   ├── Styles/
│   │   │   ├── Base/
│   │   │   └── Components/
│   │   └── ThemeResources.axaml
│   │
│   ├── AppName.Controls/                 # Shared UI controls
│   │   ├── AppName.Controls.csproj       # References AppName.Theme
│   │   ├── Common/
│   │   ├── Forms/
│   │   ├── Layout/
│   │   └── Navigation/
│   │
│   ├── AppName.Core/                     # Non-UI shared code
│   │   ├── AppName.Core.csproj           # No UI dependencies
│   │   ├── Models/
│   │   ├── Interfaces/
│   │   ├── Constants/
│   │   └── Extensions/
│   │
│   ├── AppName.Infrastructure/           # External integrations
│   │   ├── AppName.Infrastructure.csproj # References Core
│   │   ├── Services/
│   │   └── Repositories/
│   │
│   └── AppName/                          # Main application
│       ├── AppName.csproj                # References all above
│       ├── App.axaml
│       ├── Program.cs
│       ├── Features/
│       │   ├── Dashboard/
│       │   ├── Settings/
│       │   └── Reports/
│       ├── Services/
│       └── Assets/
│
└── tests/
    ├── AppName.Tests/
    ├── AppName.Tests.UI/
    └── AppName.Controls.Tests/
```

### Project Reference Graph

```
AppName (Main App)
    |
AppName.Controls <-> AppName.Infrastructure
    |                    |
AppName.Theme        AppName.Core
    |                    ^
    └────────────────────┘
```

### Project Files

#### AppName.Theme.csproj

```xml
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

#### AppName.Controls.csproj

```xml
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

### Benefits of Multi-Project

- **Independent versioning**: Theme can be versioned separately
- **Reuse potential**: Controls/Theme can be shared across applications
- **Clear ownership**: Teams can own specific projects
- **Build optimization**: Only rebuild changed projects
- **Testing isolation**: Each project has its own test project

## Namespace Conventions

### Single Project

```csharp
namespace AppName.Theme.Tokens;
namespace AppName.Theme.Styles;
namespace AppName.Controls;
namespace AppName.Views;
namespace AppName.ViewModels;
namespace AppName.Services;
```

### Multi-Project

```csharp
// AppName.Theme
namespace AppName.Theme;
namespace AppName.Theme.Tokens;
namespace AppName.Theme.Styles;

// AppName.Controls
namespace AppName.Controls;
namespace AppName.Controls.Forms;
namespace AppName.Controls.Layout;

// AppName.Core
namespace AppName.Core;
namespace AppName.Core.Models;
namespace AppName.Core.Interfaces;

// AppName (main app)
namespace AppName;
namespace AppName.Features.Dashboard;
namespace AppName.Features.Settings;
```

## ViewLocator Pattern

For MVVM with automatic View resolution:

```csharp
// ViewLocator.cs
public class ViewLocator : IDataTemplate
{
    public Control Build(object? data)
    {
        if (data is null) return new TextBlock { Text = "No Data" };

        var name = data.GetType().FullName!
            .Replace(".ViewModels.", ".Views.")
            .Replace("ViewModel", "View");

        var type = Type.GetType(name);

        if (type != null)
            return (Control)Activator.CreateInstance(type)!;

        return new TextBlock { Text = $"Not Found: {name}" };
    }

    public bool Match(object? data) => data is ViewModelBase;
}
```

### Feature-Based ViewLocator

For feature-organized projects:

```csharp
public Control Build(object? data)
{
    // Handles: AppName.Features.Dashboard.ViewModels.DashboardViewModel
    // Returns: AppName.Features.Dashboard.Views.DashboardView

    var name = data.GetType().FullName!
        .Replace(".ViewModels.", ".Views.")
        .Replace("ViewModel", "View");
    // ...
}
```

## Migration Decision Matrix

| Factor | Single Project | Multi-Project |
|--------|---------------|---------------|
| Views | < 30 | 30+ |
| Custom Controls | < 15 | 15+ |
| Team Size | 1-3 | 4+ |
| Multiple Apps | No | Yes/Planned |
| Design System Sharing | No | Yes |
| Independent Releases | Not needed | Required |
