---
name: dotnet-skills
description: List and invoke .NET agent skills adapted from addyosmani/agent-skills (spec-driven development, TDD, code review, and more — with .NET 8+, C# 12+, xUnit/MSTest, EF Core, Avalonia framing)
---

# .NET Agent Skills

Adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani) with .NET/C# framing. See the plugin [`README.md`](../README.md) and [`NOTICE.md`](../NOTICE.md) for attribution details.

## What This Command Does

Lists the skills currently available in this plugin and the natural-language prompts that trigger them. Skills activate automatically when your request matches their description — you rarely invoke them by hand.

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
- **test-driven-development** — RED/GREEN/REFACTOR with xUnit or MSTest + FluentAssertions, the Prove-It Pattern for bug fixes, `TimeProvider`/`FakeTimeProvider` for deterministic time. Triggers: *"let's write the test first"*, *"how do I test this?"*.
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

## Skills coming in later waves

Full inventory — with wave assignments and port status — lives in the plugin's [`SYNC.md`](../SYNC.md). Run `/dotnet-skills` after each sync to see which skills have moved from `pending` to ported.

## Syncing upstream

The plugin tracks upstream via a pinned-commit snapshot under [`vendor/agent-skills/`](../vendor/agent-skills). Re-sync with:

```powershell
pwsh scripts/sync-agent-skills.ps1
```

See [`UPSTREAM.md`](../UPSTREAM.md) for the current pin and sync log.
