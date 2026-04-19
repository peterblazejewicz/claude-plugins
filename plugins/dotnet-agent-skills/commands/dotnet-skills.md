---
name: dotnet-skills
description: List and invoke .NET agent skills adapted from addyosmani/agent-skills (spec-driven development, TDD, code review, and more — with .NET 8+, C# 12+, xUnit/MSTest, EF Core, Avalonia framing)
---

# .NET Agent Skills

Adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani) with .NET/C# framing. See the plugin [`README.md`](../README.md) and [`NOTICE.md`](../NOTICE.md) for attribution details.

## What This Command Does

Lists the skills currently available in this plugin and the natural-language prompts that trigger them. Skills activate automatically when your request matches their description — you rarely invoke them by hand.

## Skills available now

- **spec-driven-development** — Creates specs before coding for .NET projects. Triggers: *"help me spec out a new C# service"*, *"write a spec for this Avalonia app before we build it"*, *"I need a specification for this feature"*.

## Skills coming in later waves

Full inventory — with wave assignments and port status — lives in the plugin's [`SYNC.md`](../SYNC.md). Run `/dotnet-skills` after each sync to see which skills have moved from `pending` to ported.

## Syncing upstream

The plugin tracks upstream via a pinned-commit snapshot under [`vendor/agent-skills/`](../vendor/agent-skills). Re-sync with:

```powershell
pwsh scripts/sync-agent-skills.ps1
```

See [`UPSTREAM.md`](../UPSTREAM.md) for the current pin and sync log.
