---
name: dotnet-skills
description: List the .NET skills, subagents, and lifecycle commands shipped by this plugin (adapted from addyosmani/agent-skills — spec-driven development, TDD, code review, security audit, test engineering, and more with .NET 8+, C# 12+, xUnit/MSTest, EF Core, Avalonia framing)
---

# .NET Agent Skills

Adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani) with .NET/C# framing. See the plugin [`README.md`](../README.md) and [`NOTICE.md`](../NOTICE.md) for attribution details.

## What This Command Does

Lists the skills currently available in this plugin and the natural-language prompts that trigger them. Skills activate automatically when your request matches their description — you rarely invoke them by hand.

## Related commands

7 short lifecycle wrappers ship alongside this catalog — ported from the upstream `.claude/commands/` set with .NET framing. See the plugin [`README.md`](../README.md#commands) for the full mapping.

| What you're doing          | Command           | Key principle                                  |
| -------------------------- | ----------------- | ---------------------------------------------- |
| Define what to build       | `/spec`           | Spec before code                               |
| Plan how to build it       | `/plan`           | Small, atomic tasks with `dotnet` verification |
| Build incrementally        | `/build`          | One vertical slice at a time                   |
| Prove it works             | `/test`           | xUnit/MSTest as proof                          |
| Review before merge        | `/review`         | Five-axis review, `file.cs:line` findings      |
| Simplify the code          | `/code-simplify`  | Clarity over cleverness                        |
| Ship to production         | `/ship`           | Parallel fan-out → merge → rollback plan       |

If `/test` or `/review` is shadowed by another command in your setup, use the qualified form: `/dotnet-skills:test`, `/dotnet-skills:review`.

## Agents

3 .NET-adapted subagents ship alongside the commands and skills — reusable personas for deeper single-purpose work, ported from the upstream `agents/` set. Launch them with the `Agent` tool and `subagent_type: dotnet-skills:<name>` (they're not slash commands). Claude Code auto-namespaces plugin-provided subagents, so they coexist with built-in and sibling-plugin agents of the same short name.

`/ship` is the canonical parallel-fan-out entry point — it spawns all three personas concurrently, then the main agent synthesizes their reports against the .NET pre-launch checklist into a go/no-go decision with a `dotnet ef database update <PreviousMigration>` rollback plan. For the full composition model (the user or a slash command is always the orchestrator; personas never call each other), see [`agents/README.md`](../agents/README.md) for the decision matrix and [`references/orchestration-patterns.md`](../references/orchestration-patterns.md) for the pattern catalog, Claude Code subagent/Agent-Teams interop, and a `TaskCanceledException` competing-hypothesis worked example.

- **code-reviewer** — Staff-engineer persona conducting a five-axis code review (correctness, readability, architecture, security, performance) with .NET-specific checks: nullable-reference-type honesty, `CancellationToken` threading, DI lifetime correctness, EF Core N+1 / `FromSqlRaw` flagging, `IHttpClientFactory` vs per-call `HttpClient`, Avalonia/Blazor UI-thread marshalling. Emits `file.cs:line`-anchored findings categorized Critical / Important / Suggestion. Triggers: *"review this PR as a Staff Engineer"*, *"give me a thorough five-axis review"*.
- **security-auditor** — Security-engineer persona running an OWASP-aligned audit of the ASP.NET Core / Blazor / MAUI stack: FluentValidation + `FromSqlInterpolated` for input; Identity + JWT bearer + policy-based authz for authN/authZ; Data Protection + Key Vault + PII scrubs for data protection; security-header middleware + CORS + `dotnet list package --vulnerable` for infrastructure; HMAC webhook verification + OAuth PKCE for third-party. Emits Critical / High / Medium / Low findings with proof-of-concept and a .NET-API-grounded fix. Triggers: *"security audit this service"*, *"check this endpoint for OWASP Top 10"*.
- **test-engineer** — QA-engineer persona designing test suites, writing tests, and analyzing coverage gaps: xUnit v3 (or v2) or MSTest with native `Assert.X`, `WebApplicationFactory<Program>` for HTTP, Testcontainers for DB (not `EntityFrameworkCore.InMemory`), `Microsoft.Playwright` for Blazor/Razor, `Avalonia.Headless.XUnit` for Avalonia; `TimeProvider` + `FakeTimeProvider` for time-dependent tests; Prove-It Pattern for bug fixes. Triggers: *"plan the test suite for this feature"*, *"write a failing test for this bug"*, *"analyze test coverage gaps"*.

## Meta

- **using-agent-skills** — Discovers and invokes the right skill from this plugin for the task at hand; governs how every other skill activates. Triggers: *"which skill should I use for X?"*, *"start a new .NET session"*, *"give me a phase-by-phase map"*.

## Skills available now

**Define** — figure out what to build:
- **idea-refine** — Refines raw ideas through divergent/convergent thinking; produces a one-pager with MVP scope and a "Not Doing" list. Triggers: *"help me refine this idea"*, *"ideate on X"*, *"stress-test my plan"*.
- **spec-driven-development** — Creates specs before coding for .NET projects. Triggers: *"help me spec out a new C# service"*, *"write a spec for this Avalonia app"*.

**Plan** — decompose the work:
- **planning-and-task-breakdown** — Breaks .NET/C# work into ordered, verifiable tasks with `dotnet` CLI verification. Triggers: *"break this feature into tasks"*, *"how should I sequence this?"*.

**Build** — execute with discipline:
- **incremental-implementation** — Thin vertical slices with `dotnet test` + `dotnet build -warnaserror` between each. Triggers: *"this feels too big to land in one step"*, *"let's ship this in pieces"*.
- **api-and-interface-design** — Stable HTTP / library surface design with C# records, ProblemDetails, FluentValidation, strongly-typed IDs, pattern-matching unions. Triggers: *"design this API"*, *"what should the DTO shape be?"*.
- **context-engineering** — Optimizes CLAUDE.md, `.editorconfig`, and conversation management for .NET projects. Triggers: *"the agent keeps hallucinating APIs"*, *"set up CLAUDE.md for this Avalonia project"*.
- **source-driven-development** — Cites Microsoft Learn and official docs for every framework-specific decision; detects stack from `global.json` / `Directory.Packages.props`. Triggers: *"verify this EF Core pattern against the docs"*, *"I want cited code"*.
- **frontend-ui-engineering-avalonia** — Production-quality Avalonia 11/12 UIs: CommunityToolkit.Mvvm view-models, compiled bindings, `FluentTheme` + `ThemeVariant`, `AutomationProperties`, adaptive layouts. Triggers: *"build this Avalonia view"*, *"fix binding errors"*, *"add dark mode support"*.

**Verify** — catch bugs:
- **debugging-and-error-recovery** — Systematic root-cause debugging for `dotnet test` failures, `NullReferenceException`, DbContext concurrency, missing DI registrations, cancellation surprises. Triggers: *"this test is failing"*, *"why is this breaking?"*.
- **test-driven-development** — RED/GREEN/REFACTOR with xUnit v3 (or v2) or MSTest using native `Assert.X`, the Prove-It Pattern for bug fixes, `TimeProvider`/`FakeTimeProvider` for deterministic time. Triggers: *"let's write the test first"*, *"how do I test this?"*.
- **integration-testing-dotnet** — Tests the four .NET integration boundaries: HTTP (`WebApplicationFactory<T>`), DB (Testcontainers with real providers), browser (`Microsoft.Playwright`), Avalonia desktop (`Avalonia.Headless.XUnit`). Triggers: *"test this endpoint end-to-end"*, *"verify the EF Core query against Postgres"*, *"write a Playwright test for this Blazor page"*.

**Review** — hold the bar:
- **code-review-and-quality** — Five-axis review (correctness, readability, architecture, security, performance) with .NET checks (async correctness, DI lifetimes, EF Core N+1). Triggers: *"review this PR"*, *"is this ready to merge?"*.
- **code-simplification** — Reduces C# complexity while preserving behavior. Covers null-coalescing, `switch` expressions, `record struct`, LINQ tradeoffs. Triggers: *"simplify this code"*, *"this method is too long"*.
- **security-and-hardening** — Full .NET security pass: FluentValidation, EF Core parameterization, ASP.NET Core Identity / JWT bearer, policy-based authz, Data Protection, antiforgery, `dotnet list package --vulnerable`, rate limiting. Triggers: *"review this for security"*, *"is this endpoint safe?"*.
- **performance-optimization-dotnet** — Measure-first workflow with BenchmarkDotNet (`[MemoryDiagnoser]`), dotnet-counters, dotnet-trace, PerfView; fixes EF Core N+1 / sync-over-async / Gen2 GC pressure / thread-pool starvation / `HttpClient` misuse; tunes Kestrel and `AddOutputCache`. Triggers: *"this is slow"*, *"profile this endpoint"*, *"reduce allocations"*, *"fix cold start"*.

**Ship** — release safely:
- **git-workflow-and-versioning** — Trunk-based branches, atomic commits, Husky.Net pre-commit hooks running `dotnet test` / `dotnet format` / `dotnet build -warnaserror`. Triggers: *"what's a good commit message?"*, *"should I split this PR?"*.
- **ci-cd-and-automation** — GitHub Actions / Azure DevOps with `setup-dotnet`, quality gates, Testcontainers in CI, Playwright.NET E2E, NuGet publish on tags, slot-per-PR preview deploys. Triggers: *"set up CI"*, *"why is the pipeline failing?"*, *"add a deployment workflow"*.
- **documentation-and-adrs** — ADRs for EF Core / Dapper / UI-framework decisions, XML doc comments on public APIs, Swashbuckle OpenAPI metadata, README with `dotnet` CLI commands. Triggers: *"write an ADR for this"*, *"document this API"*.
- **deprecation-and-migration** — Retires `[Obsolete]` types, strangler pattern for migrations, `IOptionsMonitor` feature flags, NuGet unlist, Roslyn analyzer code-fix migration tooling. Triggers: *"how do we deprecate this?"*, *"retire the legacy service"*.
- **shipping-and-launch** — Pre-launch checklist, `IOptions<FeatureOptions>` / `Microsoft.FeatureManagement`, Application Insights / OpenTelemetry monitoring, EF Core migration rollback, expand-contract schema pattern. Triggers: *"are we ready to ship?"*, *"write a rollback plan"*.

