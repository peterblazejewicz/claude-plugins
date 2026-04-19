---
name: source-driven-development
description: Grounds every .NET/C# implementation decision in official documentation (Microsoft Learn, EF Core docs, ASP.NET Core docs, Avalonia docs, NuGet README). Use when you want authoritative, source-cited code free from outdated patterns. Use when building with any .NET framework or library where correctness depends on version-specific APIs.
version: 0.3.0
source: vendor/agent-skills/skills/source-driven-development/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Source-Driven Development

## Overview

Every framework-specific code decision must be backed by official documentation. Don't implement from memory — verify, cite, and let the user see your sources. Training data goes stale, APIs get deprecated, best practices evolve. In the .NET ecosystem this hits especially hard: EF Core, ASP.NET Core, and Avalonia ship material API changes between major versions, and a pattern that was correct in `net6.0` is often deprecated or removed in `net8.0`. This skill ensures the user gets code they can trust because every pattern traces back to an authoritative source they can check.

## When to Use

- The user wants code that follows current best practices for a given framework
- Building boilerplate, starter code, or patterns that will be copied across a solution
- The user explicitly asks for documented, verified, or "correct" implementation
- Implementing features where the framework's recommended approach matters (EF Core queries, ASP.NET Core middleware, Avalonia bindings, Blazor render modes, MAUI lifecycle)
- Reviewing or improving code that uses framework-specific patterns
- Any time you are about to write framework-specific code from memory

**When NOT to use:**

- Correctness does not depend on a specific version (renaming variables, fixing typos, moving files)
- Pure logic that works the same across all versions (loops, conditionals, `System.Collections.Generic`)
- The user explicitly wants speed over verification ("just do it quickly")

## The Process

```
DETECT ──→ FETCH ──→ IMPLEMENT ──→ CITE
  │          │           │            │
  ▼          ▼           ▼            ▼
 What       Get the    Follow the   Show your
 stack?     relevant   documented   sources
            docs       patterns
```

### Step 1: Detect Stack and Versions

Read the project's dependency files to identify exact versions:

| Read | For |
|------|-----|
| `global.json`                        | Pinned .NET SDK version |
| `Directory.Packages.props`           | Central NuGet package versions across the solution |
| Each project's `.csproj`             | `<TargetFramework>` (e.g. `net8.0`, `net9.0`) and per-project package references |
| `Directory.Build.props`              | Solution-wide MSBuild properties (nullable, analyzers, warning-as-errors) |

Check whether the project uses:
- **ASP.NET Core**: controllers vs Minimal APIs vs both
- **EF Core**: provider (Npgsql, SqlServer, Sqlite), version, migrations layout
- **UI framework**: Avalonia 11 vs 12, Blazor Server vs WebAssembly vs Hybrid, MAUI target frameworks
- **Testing**: xUnit (v2 or v3) vs MSTest vs NUnit; native assertions (`Xunit.Assert.X` / `MSTest.Assert.X`); VSTest runner vs Microsoft.Testing.Platform

State what you found explicitly:

```
STACK DETECTED:
- .NET 8.0 SDK (from global.json)
- Target framework net8.0 (from src/MyApp/MyApp.csproj)
- <Nullable>enable</Nullable>, <TreatWarningsAsErrors>true</TreatWarningsAsErrors> (Directory.Build.props)
- ASP.NET Core 8.0.3 (Minimal APIs)
- EF Core 8.0.3, Npgsql provider 8.0.2
- Avalonia 11.2.1 with CommunityToolkit.Mvvm 8.3.0
- Testing: xunit.v3 + Microsoft.Testing.Platform (native `Xunit.Assert`, no third-party assertion library)
→ Fetching official docs for the relevant patterns.
```

If versions are missing or ambiguous, **ask the user**. Don't guess — the version determines which patterns are correct. `AsyncEnumerable` in Minimal APIs behaves differently in .NET 7 vs .NET 8; EF Core 7's interceptors grew new methods in EF Core 8; Avalonia's styling API changed between 0.10 and 11.

### Step 2: Fetch Official Documentation

Fetch the specific documentation page for the feature you're implementing. Not the homepage, not the full docs — the relevant page.

**Source hierarchy (in order of authority for .NET):**

| Priority | Source | Example URLs |
|----------|--------|--------------|
| 1 | Microsoft Learn (official) | `learn.microsoft.com/dotnet/`, `learn.microsoft.com/aspnet/core/`, `learn.microsoft.com/ef/core/` |
| 1 | Official framework docs | `docs.avaloniaui.net`, `learn.microsoft.com/dotnet/maui/` |
| 1 | Official API reference | `learn.microsoft.com/dotnet/api/…` |
| 2 | Official changelogs / release notes | `github.com/dotnet/efcore/releases`, `github.com/AvaloniaUI/Avalonia/releases`, .NET "What's new" pages |
| 2 | Official repository READMEs and samples | `github.com/dotnet/aspnetcore`, `github.com/dotnet/efcore/tree/main/samples` |
| 3 | Web standards references | MDN (for Blazor rendering, Web APIs), web.dev |
| 4 | Runtime compatibility / lifecycle | `learn.microsoft.com/dotnet/core/releases-and-support`, `endoflife.date/dotnet` |

**Not authoritative — never cite as primary sources:**

- Stack Overflow answers
- Blog posts or tutorials (even popular ones; even "official-looking" Microsoft community blogs)
- AI-generated documentation or summaries
- Your own training data (that is the whole point — verify it)

**Be precise with what you fetch:**

```
BAD:  Fetch the ASP.NET Core homepage
GOOD: Fetch learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/parameter-binding

BAD:  Search "ef core performance best practices"
GOOD: Fetch learn.microsoft.com/ef/core/performance/efficient-querying
```

After fetching, extract the key patterns and note any deprecation warnings or migration guidance. .NET docs often have version dropdowns (`/dotnet/core/`, `/ef/core/what-is-new/`) — fetch the URL for the exact version the project targets.

When official sources conflict with each other (e.g. a migration guide contradicts the API reference, or `learn.microsoft.com` differs from the source `github.com/dotnet/efcore` docs), surface the discrepancy to the user and verify which pattern actually works against the detected version.

### Step 3: Implement Following Documented Patterns

Write code that matches what the documentation shows:

- Use the API signatures from the docs, not from memory
- If the docs show a new way to do something (`AddDbContextPool`, `services.AddOptionsWithValidateOnStart`), use the new way
- If the docs deprecate a pattern (synchronous `DbContext` methods in hot paths, `BinaryFormatter`), don't use the deprecated version
- If the docs don't cover something, flag it as unverified
- Check analyzer diagnostics (`CAxxxx`, `EFxxxx`) — they're part of the executable documentation

**When docs conflict with existing project code:**

```
CONFLICT DETECTED:
The existing codebase uses synchronous DbContext methods in some
controllers (src/MyApp/Controllers/LegacyTasks.cs), but the EF Core
performance guide explicitly recommends async across the board.
(Source: learn.microsoft.com/ef/core/performance/efficient-querying#asynchronous-programming)

Options:
A) Use the modern pattern (async) — consistent with current docs
B) Match existing code (sync) — consistent with codebase but against guidance
→ Which approach do you prefer? (And should we file a ticket to migrate LegacyTasks.cs?)
```

Surface the conflict. Don't silently pick one.

### Step 4: Cite Your Sources

Every framework-specific pattern gets a citation. The user must be able to verify every decision.

**In code comments:**

```csharp
// EF Core 8 split-query to avoid cartesian explosion on multi-Include()
// Source: https://learn.microsoft.com/ef/core/querying/single-split-queries
var orders = await context.Orders
    .Include(o => o.LineItems)
    .Include(o => o.Shipments)
    .AsSplitQuery()
    .ToListAsync(cancellationToken);
```

**In conversation:**

```
I'm using AddDbContextPool instead of AddDbContext because this is a
high-throughput API and DbContext pooling reduces per-request allocations.

Source: https://learn.microsoft.com/ef/core/performance/advanced-performance-topics#dbcontext-pooling
"Using DbContext pooling has shown up to 20% improvement in throughput
for high-contention simple-query scenarios"
```

**Citation rules:**

- Full URLs, not shortened
- Prefer deep links with anchors where possible (e.g. `/efficient-querying#asynchronous-programming` over `/efficient-querying`) — anchors survive doc restructuring better than top-level pages
- Quote the relevant passage when it supports a non-obvious decision
- For version-specific docs, include the version in the URL path when it's parameterizable (`/dotnet/core/whats-new/dotnet-8`)
- Include framework support data when recommending newer APIs (some NuGet packages still target older frameworks — e.g. a library targeting `netstandard2.0` cannot use `Span<T>` overloads without polyfills)
- If you cannot find documentation for a pattern, say so explicitly:

```
UNVERIFIED: I could not find official documentation for this specific
EF Core + Npgsql JSONB update pattern against the 8.0.x provider.
This is based on training data and may reflect an older API surface.
Verify against your Npgsql version before merging.
```

Honesty about what you couldn't verify is more valuable than false confidence.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'm confident about this API" | Confidence is not evidence. Training data contains outdated patterns that look correct but break against current EF Core/ASP.NET Core versions. Verify. |
| "Fetching docs wastes tokens" | Hallucinating an API wastes more. The user debugs for an hour, then discovers `.AddDbContext` overload signatures changed in EF Core 8. One fetch prevents hours of rework. |
| "The docs won't have what I need" | If the docs don't cover it, that's valuable information — the pattern may not be officially recommended. |
| "I'll just mention it might be outdated" | A disclaimer doesn't help. Either verify and cite, or clearly flag it as unverified. Hedging is the worst option. |
| "This is a simple task, no need to check" | Simple tasks with wrong patterns become templates. The user copies your deprecated `UseDatabaseErrorPage()` setup into ten services before discovering `UseDeveloperExceptionPage` is the only current option. |
| "Microsoft Learn is just the same thing as my training data" | Microsoft Learn updates on every `/dotnet` release. Training data is frozen at a point in time. The difference matters most exactly when patterns are evolving. |

## Red Flags

- Writing framework-specific code without checking the docs for that target framework
- Using "I believe" or "I think" about an API instead of citing the source
- Implementing a pattern without knowing which `TargetFramework` and package version it applies to
- Citing Stack Overflow or blog posts instead of official documentation
- Using deprecated APIs because they appear in training data (`BinaryFormatter`, `WebHost.CreateDefaultBuilder` in modern ASP.NET Core, `DbContext.Database.EnsureCreated` in production)
- Not reading `global.json` / `Directory.Packages.props` / `.csproj` before implementing
- Delivering code without source citations for framework-specific decisions
- Fetching an entire docs site when only one page is relevant
- Silently picking the latest API when the project target is older (e.g. using primary-constructor syntax in a `netstandard2.0` class library without verifying C# language version)

## Verification

After implementing with source-driven development:

- [ ] .NET SDK and target framework were identified from `global.json` + `.csproj`
- [ ] NuGet package versions were identified from `Directory.Packages.props` / `.csproj`
- [ ] Official documentation was fetched for framework-specific patterns
- [ ] All sources are official documentation (Microsoft Learn, framework docs, release notes), not blog posts or training data
- [ ] Code follows the patterns shown in the current version's documentation
- [ ] Non-trivial decisions include source citations with full URLs and deep links where possible
- [ ] No deprecated APIs are used (checked against migration guides and analyzer diagnostics)
- [ ] Conflicts between docs and existing code were surfaced to the user
- [ ] Anything that could not be verified is explicitly flagged as unverified
- [ ] C# language features used fit the `<LangVersion>` and `<TargetFramework>` of the project

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/source-driven-development/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - Overview adds the .NET-specific version-drift problem (EF Core / ASP.NET Core / Avalonia API changes between majors; `net6.0`→`net8.0` removals)
  - "When to Use" examples retargeted to .NET framework decisions (EF Core queries, ASP.NET Core middleware, Avalonia bindings, Blazor render modes, MAUI lifecycle)
  - Step 1 detection table covers `global.json`, `Directory.Packages.props`, `.csproj`, `Directory.Build.props` instead of `package.json`/`composer.json`/etc.; sub-checks name ASP.NET Core host style, EF Core provider, UI framework, testing framework
  - Stack-detection output example rewritten for a real .NET solution (.NET 8 SDK, net8.0, `<Nullable>enable</Nullable>`, Avalonia 11.2.1, CommunityToolkit.Mvvm 8.3.0, xUnit 2.9.0)
  - "ask the user" paragraph adds concrete version-sensitive examples (AsyncEnumerable .NET 7 vs 8, EF Core interceptor additions, Avalonia 0.10→11 styling API)
  - Source hierarchy table replaced with .NET-authoritative sources: Microsoft Learn, `docs.avaloniaui.net`, API reference, EF Core/Avalonia release pages, `endoflife.date/dotnet` for lifecycle, `github.com/dotnet/*` samples
  - URL-precision examples use Microsoft Learn paths
  - Version-specific docs note mentions the .NET version dropdowns
  - Step 3 adds analyzer-diagnostic IDs (`CAxxxx`, `EFxxxx`) as executable documentation; deprecated-pattern examples use `BinaryFormatter` and synchronous EF Core methods
  - Conflict-with-existing-code example retargeted to async EF Core guidance
  - Step 4 code-comment example uses `.AsSplitQuery()` with a Microsoft Learn source link; conversational example uses `AddDbContextPool`
  - Citation-rules bullet mentions `netstandard2.0` polyfill considerations for `Span<T>`
  - "Unverified" example is an EF Core + Npgsql JSONB scenario
  - Rationalizations table retargeted to .NET (EF Core 8 API changes, `UseDeveloperExceptionPage`, "Microsoft Learn vs training data")
  - Red-flag list adds `BinaryFormatter`/`WebHost.CreateDefaultBuilder`/`EnsureCreated` in production, language features beyond `<LangVersion>`/`<TargetFramework>`
  - Verification checklist adds `global.json` / `Directory.Packages.props` reads, analyzer-diagnostic checking, and `<LangVersion>` conformance
  - Preserved verbatim: DETECT→FETCH→IMPLEMENT→CITE diagram, "not authoritative" source list frame, Common Rationalizations structure, "honesty about what you couldn't verify" principle
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
