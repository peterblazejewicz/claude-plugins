# .NET Agent Skills — Claude Code Plugin

Agent skills for **.NET 8+ (LTS or newer)** development, adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills). Covers spec → plan → build → verify → review → ship with a .NET/C# focus: Avalonia UI first, then ASP.NET Core, Blazor, and .NET MAUI. Testing with xUnit and MSTest; data access with EF Core.

## Status

Pre-release (`0.5.0`). Waves 0–3 complete — 20 of 21 skills ported. Wave 3 added two .NET-specific rewrites: `frontend-ui-engineering-avalonia` (Avalonia 11/12 + CommunityToolkit.Mvvm + compiled bindings + theming + `AutomationProperties`) and `performance-optimization-dotnet` (BenchmarkDotNet + dotnet-counters + dotnet-trace + PerfView + EF Core/Kestrel/GC/allocation triage). One skill (the meta `using-agent-skills`, Wave 4) remains pending.

## Attribution

This plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani). It is **not** a GitHub fork — upstream content is vendored as a pinned snapshot under [`vendor/agent-skills/`](./vendor/agent-skills) and ported skill-by-skill into `skills/` with .NET/C# adaptations.

- Upstream license: MIT — see [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt)
- Attribution summary: [`NOTICE.md`](./NOTICE.md)
- Sync pin + instructions: [`UPSTREAM.md`](./UPSTREAM.md)
- Per-skill port status: [`SYNC.md`](./SYNC.md)

Every ported skill carries a `Source & Modifications` footer linking back to the upstream file at the pinned commit.

## Installation

```bash
claude plugins marketplace add peterblazejewicz/claude-plugins
claude plugins install dotnet-agent-skills
```

## Usage

```
/dotnet-skills
```

Lists available skills and their triggers. Individual skills activate from natural-language prompts (e.g. *"help me spec out a new C# service"* triggers `spec-driven-development`).

## Skill inventory

21 upstream skills grouped into porting waves. Only `spec-driven-development` is ported today; the rest are `pending` in [`SYNC.md`](./SYNC.md).

| Wave | Skills | Status |
|------|--------|--------|
| 0 (sample) | spec-driven-development | ✅ ported |
| 1A (core execution) | planning-and-task-breakdown, incremental-implementation, code-review-and-quality, code-simplification, debugging-and-error-recovery, context-engineering | ✅ ported |
| 1B (remaining agnostic) | idea-refine (+ 3 references), api-and-interface-design, security-and-hardening, git-workflow-and-versioning, deprecation-and-migration, documentation-and-adrs, source-driven-development, shipping-and-launch | ✅ ported |
| 2 (testing/CI) | test-driven-development, ci-cd-and-automation, integration-testing-dotnet (rewritten from browser-testing-with-devtools) | ✅ ported |
| 3 (.NET rewrites) | frontend-ui-engineering-avalonia, performance-optimization-dotnet | ✅ ported |
| 4 (meta) | using-agent-skills | pending |

## Syncing upstream

```powershell
pwsh scripts/sync-agent-skills.ps1                     # re-sync to current pin
pwsh scripts/sync-agent-skills.ps1 -UpstreamRef main   # bump to latest main
pwsh scripts/sync-agent-skills.ps1 -Verify             # drift check against manifest
```

The script writes into `vendor/agent-skills/` (read-only by convention) and rewrites `UPSTREAM.md` with the new pin. It never commits — review and commit manually.

## Requirements

- [Claude Code](https://claude.ai/code) with plugin support
- Target workloads: .NET 8+ LTS, C# 12+, xUnit or MSTest, EF Core, Avalonia UI (ASP.NET Core, Blazor, MAUI as waves land)

## License

MIT (this plugin). Upstream content is MIT © 2025 Addy Osmani — preserved verbatim in [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt).
