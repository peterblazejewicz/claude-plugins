# .NET Agent Skills — Claude Code Plugin

Agent skills for **.NET 8+ (LTS or newer)** development, adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills). Covers spec → plan → build → verify → review → ship with a .NET/C# focus: Avalonia UI first, then ASP.NET Core, Blazor, and .NET MAUI. Testing with xUnit and MSTest; data access with EF Core.

## Status

`2.1.0` — **Adds 7 short slash-command wrappers** (`/spec`, `/plan`, `/build`, `/test`, `/review`, `/code-simplify`, `/ship`) adapted from the upstream `.claude/commands/` set. Backwards compatible: the original `/dotnet-skills` catalog command and all 21 skill `name:` fields are unchanged. See [Commands](#commands) below for the full mapping.

Prior releases: `2.0.0` renamed the plugin from `dotnet-agent-skills` to `dotnet-skills` (breaking). `1.0.0` landed the meta skill `using-agent-skills`; `1.0.1` added an xUnit v3 + Microsoft.Testing.Platform patch; `1.0.2` moved maintenance artifacts out of the installed plugin surface; `1.0.3` and `1.0.4` closed two rounds of external review with contrasting examples, host-model lens notes, library `ConfigureAwait(false)` guidance, EF Core raw-SQL overload clarifications, the `SynchronizationContext` deadlock warning on the Adapter Pattern, and the strongly-typed ID JSON converter.

## Attribution

This plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani). It is **not** a GitHub fork — upstream content is adapted skill-by-skill into `skills/` with .NET/C# adaptations.

- Upstream license: MIT — see [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt)
- Attribution summary: [`NOTICE.md`](./NOTICE.md)

Every ported skill carries a `Source & Modifications` footer linking back to the upstream file at the pinned commit.

## Installation

```bash
claude plugins marketplace add peterblazejewicz/claude-plugins
claude plugins install dotnet-skills
```

## Usage

```
/dotnet-skills
```

Lists available skills and their triggers. Individual skills activate from natural-language prompts (e.g. _"help me spec out a new C# service"_ triggers `spec-driven-development`).

## Commands

8 slash commands ship with this plugin. `/dotnet-skills` is the catalog command; the other 7 map to the development lifecycle and activate the right skills automatically — ported from the upstream [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) command set with .NET framing.

| What you're doing          | Command           | Key principle                                  |
| -------------------------- | ----------------- | ---------------------------------------------- |
| List skills and triggers   | `/dotnet-skills`  | Inventory before action                        |
| Define what to build       | `/spec`           | Spec before code                               |
| Plan how to build it       | `/plan`           | Small, atomic tasks with `dotnet` verification |
| Build incrementally        | `/build`          | One vertical slice at a time                   |
| Prove it works             | `/test`           | xUnit/MSTest as proof                          |
| Review before merge        | `/review`         | Five-axis review, `file.cs:line` findings      |
| Simplify the code          | `/code-simplify`  | Clarity over cleverness                        |
| Ship to production         | `/ship`           | Faster is safer, rollback first                |

Skills also activate automatically based on what you're doing — designing an API triggers `api-and-interface-design`, building an Avalonia view triggers `frontend-ui-engineering-avalonia`, and so on.

### What each command activates

| Command           | Skills it invokes                                                                                             |
| ----------------- | ------------------------------------------------------------------------------------------------------------- |
| `/spec`           | `spec-driven-development`                                                                                     |
| `/plan`           | `planning-and-task-breakdown`                                                                                 |
| `/build`          | `incremental-implementation` + `test-driven-development` (+ `debugging-and-error-recovery` on failure)        |
| `/test`           | `test-driven-development` (+ `integration-testing-dotnet` for HTTP / DB / browser / Avalonia boundaries)      |
| `/review`         | `code-review-and-quality` (+ `security-and-hardening` + `performance-optimization-dotnet`)                    |
| `/code-simplify`  | `code-simplification` (+ `code-review-and-quality` to review the result)                                      |
| `/ship`           | `shipping-and-launch`                                                                                         |

### Disambiguating when shadowed

If `/test` or `/review` collides with a personal command or another plugin in your setup, invoke the qualified form: `/dotnet-skills:test`, `/dotnet-skills:review`. The qualified form works for every command in this plugin.

## Skills

21 ported skills grouped by development phase — the commands above are the entry points; any skill can also be referenced directly by name. Run `/dotnet-skills` for the current inventory with trigger examples.

### Define — clarify what to build

| Skill                                                                  | What it does                                                                                 | Use when                                                                    |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [idea-refine](./skills/idea-refine/SKILL.md)                           | Divergent/convergent thinking to turn vague .NET ideas into a one-pager with MVP scope        | You have a rough concept (new Avalonia app, API, NuGet library) to explore  |
| [spec-driven-development](./skills/spec-driven-development/SKILL.md)   | PRD covering objective, `dotnet` CLI commands, project structure, code style, testing, bounds | Starting a new .NET project, feature, or significant change                 |

### Plan — break it down

| Skill                                                                              | What it does                                                                                                  | Use when                                            |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| [planning-and-task-breakdown](./skills/planning-and-task-breakdown/SKILL.md)       | Decompose specs into small tasks with `dotnet test --filter` / `dotnet build -warnaserror` verification steps | You have a spec and need implementable units       |

### Build — write the code

| Skill                                                                                                | What it does                                                                                                       | Use when                                                                |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| [incremental-implementation](./skills/incremental-implementation/SKILL.md)                           | Thin vertical slices — `dotnet test` + `dotnet build -warnaserror` between each. `IOptions<FeatureOptions>` flags   | Any change touching more than one project                               |
| [api-and-interface-design](./skills/api-and-interface-design/SKILL.md)                               | Contract-first design with C# records, ProblemDetails, FluentValidation, strongly-typed IDs, pattern-matching      | Designing APIs, module boundaries, or public interfaces                 |
| [context-engineering](./skills/context-engineering/SKILL.md)                                         | CLAUDE.md / `.editorconfig` / analyzer setup for .NET projects                                                     | Starting a session, switching stacks, or when output quality drops      |
| [source-driven-development](./skills/source-driven-development/SKILL.md)                             | Ground decisions in Microsoft Learn + framework docs + analyzer diagnostics                                        | You want authoritative, source-cited code for any .NET framework        |
| [frontend-ui-engineering-avalonia](./skills/frontend-ui-engineering-avalonia/SKILL.md)               | Avalonia 11/12 with CommunityToolkit.Mvvm, compiled bindings, `FluentTheme` + `ThemeVariant`, `AutomationProperties` | Building or modifying Avalonia UI                                       |
| [test-driven-development](./skills/test-driven-development/SKILL.md)                                 | RED/GREEN/REFACTOR with xUnit (v2/v3) or MSTest + FluentAssertions, Prove-It Pattern, `TimeProvider`                | Implementing logic, fixing bugs, or changing behavior                   |

### Verify — prove it works

| Skill                                                                                  | What it does                                                                                                            | Use when                                                      |
| -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [integration-testing-dotnet](./skills/integration-testing-dotnet/SKILL.md)             | `WebApplicationFactory<T>` (HTTP), Testcontainers (DB), `Microsoft.Playwright` (Blazor), `Avalonia.Headless.XUnit` (UI) | Building or debugging anything that crosses a boundary        |
| [debugging-and-error-recovery](./skills/debugging-and-error-recovery/SKILL.md)         | Systematic root-cause triage for `dotnet test` failures, DI issues, cancellation, DbContext concurrency                 | Tests fail, builds break, or behavior is unexpected          |

### Review — quality gates before merge

| Skill                                                                                  | What it does                                                                                                                 | Use when                                                         |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| [code-review-and-quality](./skills/code-review-and-quality/SKILL.md)                   | Five-axis review with .NET-specific checks (async correctness, DI lifetimes, EF Core N+1, nullable annotations)              | Before merging any change                                        |
| [code-simplification](./skills/code-simplification/SKILL.md)                           | Reduce C# complexity — null-coalescing, `switch` expressions, `record struct`, pattern-matching — while preserving behavior  | Code works but is harder to read or maintain than it should be   |
| [security-and-hardening](./skills/security-and-hardening/SKILL.md)                     | FluentValidation, EF Core parameterization, Identity/JWT, policy-based authz, `dotnet list package --vulnerable`             | Handling user input, auth, data storage, or external integrations |
| [performance-optimization-dotnet](./skills/performance-optimization-dotnet/SKILL.md)   | Measure-first with BenchmarkDotNet, dotnet-counters, dotnet-trace, PerfView; fixes N+1 / sync-over-async / GC pressure        | Performance requirements exist or a regression is suspected      |

### Ship — deploy with confidence

| Skill                                                                              | What it does                                                                                              | Use when                                                        |
| ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| [git-workflow-and-versioning](./skills/git-workflow-and-versioning/SKILL.md)       | Trunk-based branches, atomic commits, Husky.Net pre-commit with `dotnet test` / `format` / `build`        | Making any code change (always)                                 |
| [ci-cd-and-automation](./skills/ci-cd-and-automation/SKILL.md)                     | GitHub Actions / Azure DevOps with `setup-dotnet`, quality gates, Testcontainers, Playwright.NET E2E      | Setting up or modifying build and deploy pipelines              |
| [documentation-and-adrs](./skills/documentation-and-adrs/SKILL.md)                 | ADRs, XML doc comments, Swashbuckle OpenAPI metadata, README with `dotnet` CLI commands                   | Making architectural decisions, changing APIs, shipping features |
| [deprecation-and-migration](./skills/deprecation-and-migration/SKILL.md)           | `[Obsolete]`, strangler pattern, `IOptionsMonitor` feature flags, NuGet unlist, Roslyn analyzer code fixes | Removing old systems, migrating users, or sunsetting features   |
| [shipping-and-launch](./skills/shipping-and-launch/SKILL.md)                       | Pre-launch checklist, `Microsoft.FeatureManagement`, Application Insights / OpenTelemetry, migration rollback | Preparing to deploy to production                              |

### Meta — how to use this pack

| Skill                                                                  | What it does                                                                                        | Use when                                                     |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| [using-agent-skills](./skills/using-agent-skills/SKILL.md)             | Discovers and invokes the right skill for the task; phase-by-phase map of what's available         | Starting a session or when a task doesn't map to one skill   |

## Requirements

- [Claude Code](https://claude.ai/code) with plugin support
- Target workloads: .NET 8+ LTS, C# 12+, xUnit (v2 or v3) or MSTest, EF Core, Avalonia UI (ASP.NET Core, Blazor, MAUI covered by guidance; dedicated sibling UI skills are optional future work)

## License

MIT (this plugin). Upstream content is MIT © 2025 Addy Osmani — preserved verbatim in [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt).
