# .NET Agent Skills — Claude Code Plugin

Agent skills for **.NET 8+ (LTS or newer)** development, adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills). Covers spec → plan → build → verify → review → ship with a .NET/C# focus: Avalonia UI first, then ASP.NET Core, Blazor, and .NET MAUI. Testing with xUnit and MSTest; data access with EF Core.

## Status

`1.0.3` — all 21 upstream skills ported (17 `modified`, 4 `rewritten`, 1 upstream helper `skipped`). `1.0.0` landed the meta skill `using-agent-skills`; `1.0.1` added an xUnit v3 + Microsoft.Testing.Platform patch to the testing skills; `1.0.2` cleaned up the plugin's installed surface; `1.0.3` addressed an external review with contrasting counter-examples where .NET semantics are easy to over-generalize (async unwrap, EF Core raw-SQL overload resolution, strongly-typed ID JSON shape, EF Core non-nullable migration, Avalonia v11/v12 compiled-bindings opt-in) plus host-model lens notes and library `ConfigureAwait(false)` guidance.

## Attribution

This plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani). It is **not** a GitHub fork — upstream content is adapted skill-by-skill into `skills/` with .NET/C# adaptations.

- Upstream license: MIT — see [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt)
- Attribution summary: [`NOTICE.md`](./NOTICE.md)

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

## Skills

21 ported skills grouped by development phase. Run `/dotnet-skills` for the current inventory with trigger examples.

| Phase | Skills |
|------|--------|
| Define | idea-refine, spec-driven-development |
| Plan | planning-and-task-breakdown |
| Build | incremental-implementation, api-and-interface-design, context-engineering, source-driven-development, frontend-ui-engineering-avalonia |
| Verify | debugging-and-error-recovery, test-driven-development, integration-testing-dotnet |
| Review | code-review-and-quality, code-simplification, security-and-hardening, performance-optimization-dotnet |
| Ship | git-workflow-and-versioning, ci-cd-and-automation, documentation-and-adrs, deprecation-and-migration, shipping-and-launch |
| Meta | using-agent-skills |

## Requirements

- [Claude Code](https://claude.ai/code) with plugin support
- Target workloads: .NET 8+ LTS, C# 12+, xUnit (v2 or v3) or MSTest, EF Core, Avalonia UI (ASP.NET Core, Blazor, MAUI covered by guidance; dedicated sibling UI skills are optional future work)

## License

MIT (this plugin). Upstream content is MIT © 2025 Addy Osmani — preserved verbatim in [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt).
