# Claude Plugins (PowerShell & Windows)

A curated collection of **PowerShell 7.x ports and Windows-compatible** Claude Code plugins.

## Purpose

This marketplace provides Windows-native versions of popular Claude Code plugins that typically require Bash/Unix environments. All plugins are designed to run natively on Windows using PowerShell 7.x without requiring WSL.

## Available Plugins

| Plugin | Description | Upstream |
|--------|-------------|----------|
| [ralph-loop-ps](./plugins/ralph-loop-ps/) | PowerShell port of Ralph Loop - iterative AI development loops | [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop) |

## Installation

### Add the Marketplace

```bash
claude plugins marketplace add peterblazejewicz/claude-plugins
```

### Install a Plugin

```bash
claude plugins install ralph-loop-ps
```

## Requirements

- **PowerShell 7.x** (cross-platform) - [Install PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- **Claude Code** with plugin support

### Verify PowerShell Version

```powershell
$PSVersionTable.PSVersion
# Should show 7.x.x
```

### Install PowerShell 7 on Windows

```powershell
winget install Microsoft.PowerShell
```

## Development

### Lint PowerShell Scripts

Run PSScriptAnalyzer on all PowerShell scripts in the repository:

```powershell
# From repository root
./scripts/powershell-lint.ps1
```

This runs the same linting used by the CI/CD pipeline.

## Upstream Synchronization

This repository monitors upstream sources for changes and ports them to PowerShell. When changes are detected in the original plugins, issues are created for review and porting.

### Tracked Upstreams

| Plugin | Upstream Repository | Path |
|--------|---------------------|------|
| ralph-loop-ps | anthropics/claude-plugins-official | plugins/ralph-loop |

## Contributing

Contributions are welcome! If you'd like to:

1. **Port another plugin** - Open an issue with the plugin you'd like ported
2. **Fix a bug** - Submit a PR with the fix
3. **Improve documentation** - PRs welcome

### Porting Guidelines

When porting Bash scripts to PowerShell:

| Bash | PowerShell |
|------|------------|
| `#!/bin/bash` | `#Requires -Version 7.0` |
| `set -euo pipefail` | `$ErrorActionPreference = 'Stop'` |
| `$(cat)` | `$input \| Out-String` |
| `jq` | `ConvertFrom-Json` / `ConvertTo-Json` |
| `sed`, `awk`, `grep` | PowerShell regex, `Select-String` |
| `perl` regex | `[regex]::Match()` |

## Troubleshooting

### "Bash command permission check failed" Error

If you see an error like:
```
Error: Bash command permission check failed for pattern "..."
This command uses shell operators that require approval for safety
```

This is **not** a PowerShell execution policy issue. It's Claude Code's internal permission pattern matching.

**Root Cause**: The `allowed-tools` pattern in command files must not contain escaped quotes (`\"`). Claude Code's pattern matching fails with embedded quotes, triggering stricter safety checks.

**Solution**: Use simple wildcard patterns without quotes:
```yaml
# ❌ Wrong - quotes break pattern matching
allowed-tools: ["Bash(pwsh -NoProfile -ExecutionPolicy Bypass -File \"*script.ps1\"*)"]

# ✅ Correct - no quotes in pattern
allowed-tools: ["Bash(pwsh -NoProfile -ExecutionPolicy Bypass -File *script.ps1*)"]
```

### PowerShell Execution Policy

Scripts use `-ExecutionPolicy Bypass` flag which overrides system policy for that session. You don't need to:
- Change your system execution policy
- Run elevated/as administrator
- Modify your PowerShell profile

## License

MIT License - See [LICENSE](./LICENSE)

## Credits

- **Original Ralph Loop**: [Geoffrey Huntley](https://ghuntley.com/ralph/)
- **Official Plugins**: [Anthropic](https://github.com/anthropics/claude-plugins-official)