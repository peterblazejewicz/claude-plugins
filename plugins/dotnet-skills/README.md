# .NET Agent Skills — Claude Code Plugin

Agent skills for **.NET 8+ (LTS or newer)** development, adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills). Covers spec → plan → build → verify → review → ship with a .NET/C# focus: Avalonia UI first, then ASP.NET Core, Blazor, and .NET MAUI. Testing with xUnit and MSTest; data access with EF Core.

## Status

`2.0.0` — **Breaking: plugin renamed from `dotnet-agent-skills` to `dotnet-skills`.** Existing installs see the old slug as missing after a marketplace refresh; re-install under the new name (see Installation below). No content regressions — the 21 ported skills and every skill's frontmatter `name:` field are unchanged; only the plugin prefix on qualified invocations changes (e.g. `dotnet-skills:spec-driven-development` instead of `dotnet-agent-skills:spec-driven-development`), saving 6 characters on every qualified reference.

Prior content history: `1.0.0` landed the meta skill `using-agent-skills`; `1.0.1` added an xUnit v3 + Microsoft.Testing.Platform patch; `1.0.2` moved maintenance artifacts out of the installed plugin surface; `1.0.3` and `1.0.4` closed two rounds of external review with contrasting examples, host-model lens notes, library `ConfigureAwait(false)` guidance, EF Core raw-SQL overload clarifications, the `SynchronizationContext` deadlock warning on the Adapter Pattern, and the strongly-typed ID JSON converter.

## Attribution

This plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani). It is **not** a GitHub fork — upstream content is adapted skill-by-skill into `skills/` with .NET/C# adaptations.

- Upstream license: MIT — see [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt)
- Attribution summary: [`NOTICE.md`](./NOTICE.md)

Every ported skill carries a `Source & Modifications` footer linking back to the upstream file at the pinned commit.

## Installation

**New install:**

```bash
claude plugins marketplace add peterblazejewicz/claude-plugins
claude plugins install dotnet-skills
```

**Migrating from `dotnet-agent-skills` (any 1.x):**

```bash
claude plugins uninstall dotnet-agent-skills
claude plugins marketplace update peterblazejewicz/claude-plugins
claude plugins install dotnet-skills
```

After reinstall, qualified skill references use the new prefix (`dotnet-skills:spec-driven-development`, etc.). The unqualified `/dotnet-skills` slash command continues to work unchanged.

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
