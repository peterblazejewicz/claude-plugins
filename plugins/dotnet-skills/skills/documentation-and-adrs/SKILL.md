---
name: documentation-and-adrs
description: Records architectural decisions and writes durable documentation for .NET/C# projects — ADRs, XML doc comments, OpenAPI/Swagger, README with dotnet CLI commands, CLAUDE.md pointers. Use when making architectural decisions, changing public APIs, shipping features, or recording context that future engineers and agents will need.
version: 0.3.0
source: vendor/agent-skills/skills/documentation-and-adrs/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Documentation and ADRs

## Overview

Document decisions, not just code. The most valuable documentation captures the *why* — the context, constraints, and trade-offs that led to a decision. Code shows *what* was built; documentation explains *why it was built this way* and *what alternatives were considered*. This context is essential for future humans and agents working in the codebase.

## When to Use

- Making a significant architectural decision
- Choosing between competing approaches (EF Core vs Dapper, controllers vs Minimal APIs, Avalonia vs MAUI for a new desktop app)
- Adding or changing a public API (HTTP endpoint, library entry point)
- Shipping a feature that changes user-facing behavior
- Onboarding new team members (or agents) to the project
- When you find yourself explaining the same thing repeatedly

**When NOT to use:** Don't document obvious code. Don't add XML doc comments that restate what the signature already says. Don't write docs for throwaway prototypes.

## Architecture Decision Records (ADRs)

ADRs capture the reasoning behind significant technical decisions. They're the highest-value documentation you can write.

### When to Write an ADR

- Choosing a framework, library, or major NuGet dependency (EF Core vs Dapper, MediatR adoption, FluentValidation vs DataAnnotations)
- Designing a data model or database schema
- Selecting an authentication strategy (cookie vs JWT bearer, ASP.NET Core Identity vs a third-party IdP)
- Deciding on an API architecture (REST controllers vs Minimal APIs vs gRPC)
- Choosing between Avalonia, Blazor, ASP.NET Core, and MAUI for a given workload
- Picking a hosting platform (App Service, Container Apps, AKS, self-hosted)
- Any decision that would be expensive to reverse

### ADR Template

Store ADRs in `docs/adr/` (or `docs/decisions/`) with sequential numbering:

```markdown
# ADR-001: Use PostgreSQL with EF Core for primary database

## Status
Accepted | Superseded by ADR-XXX | Deprecated

## Date
2025-01-15

## Context
We need a primary database for the task management application. Key requirements:
- Relational data model (users, tasks, teams with relationships)
- ACID transactions for task state changes
- Support for full-text search on task content
- Managed hosting available (for small team, limited ops capacity)
- Strong .NET tooling (EF Core, source generators, analyzers)

## Decision
Use PostgreSQL with EF Core 8 (Npgsql provider).

## Alternatives Considered

### Dapper on SQL Server
- Pros: Lightweight, close to the metal, excellent performance for read-heavy workloads
- Cons: Hand-written SQL for every query; migrations require separate tooling (DbUp, FluentMigrator)
- Rejected: Our team benefits more from EF Core's change tracking and `dotnet ef migrations` workflow than from Dapper's marginal perf edge

### SQL Server (EF Core)
- Pros: First-party Microsoft support, excellent local dev story (LocalDB)
- Cons: Licensing cost at scale; weaker JSONB story than PostgreSQL
- Rejected: PostgreSQL's JSONB + full-text search fits our feature requirements better

### SQLite (EF Core)
- Pros: Zero configuration, embedded, fast for reads, great for tests
- Cons: Limited concurrent write support, not suitable for multi-user production
- Rejected for production: Not suitable for multi-user web application.
  Accepted for integration tests (see ADR-007).

### MongoDB
- Pros: Flexible schema, easy to start with
- Cons: Our data is inherently relational; would need to manage relationships manually
- Rejected: Relational data in a document store leads to complex joins or data duplication

## Consequences
- EF Core provides type-safe database access and migration management (`dotnet ef migrations add`)
- We can use PostgreSQL's full-text search instead of adding Elasticsearch
- Npgsql is the official provider and covers the PostgreSQL-specific features we need (JSONB, arrays, UUID)
- Team needs PostgreSQL knowledge (standard skill, low risk)
- Hosting on managed service (Azure Database for PostgreSQL / Neon / Supabase / RDS)
- Integration tests use SQLite via `Microsoft.EntityFrameworkCore.Sqlite` to stay fast; accept that PostgreSQL-specific features (e.g., JSONB operators) will fail in test and are covered by a separate smoke suite against a Testcontainers PostgreSQL instance
```

### ADR Lifecycle

```
PROPOSED → ACCEPTED → (SUPERSEDED or DEPRECATED)
```

- **Don't delete old ADRs.** They capture historical context.
- When a decision changes, write a new ADR that references and supersedes the old one.

## Inline Documentation

### When to Comment

Comment the *why*, not the *what*:

```csharp
// BAD: Restates the code
// Increment counter by 1
counter += 1;

// GOOD: Explains non-obvious intent
// Rate limit uses a sliding window — reset counter at window boundary,
// not on a fixed schedule, to prevent burst attacks at window edges.
// See ADR-011 for the sliding-vs-fixed trade-off discussion.
if (now - windowStart > WindowSize)
{
    counter = 0;
    windowStart = now;
}
```

### When NOT to Comment

```csharp
// Don't comment self-explanatory code
public decimal CalculateTotal(IEnumerable<CartItem> items) =>
    items.Sum(item => item.Price * item.Quantity);

// Don't leave TODO comments for things you should just do now
// TODO: add error handling  ← Just add it, or file a tracked issue

// Don't leave commented-out code
// var oldImplementation = ...;  ← Delete it, git has history
```

### Document Known Gotchas

Use `<remarks>` in XML doc comments for non-obvious constraints, and keep the text short enough that it actually gets read:

```csharp
/// <summary>
/// Initializes the theme system. Must be called before the first Avalonia window is created.
/// </summary>
/// <remarks>
/// <para>
/// Calling this after <see cref="AppBuilder.StartWithClassicDesktopLifetime"/>
/// causes a flash of unstyled content because the theme resource dictionaries are
/// merged after the first render pass. See ADR-003 for the full design rationale.
/// </para>
/// </remarks>
public static void InitializeTheme(Theme theme) { /* ... */ }
```

## API Documentation

For public APIs (HTTP, library interfaces):

### XML Doc Comments for Library APIs

Generate them with `<GenerateDocumentationFile>true</GenerateDocumentationFile>` in the `.csproj` and let analyzers enforce completeness (`SA1600` StyleCop rule, or `CS1591` once doc files are on):

```csharp
/// <summary>
/// Creates a new task.
/// </summary>
/// <param name="input">Task creation data. Title is required; description is optional.</param>
/// <param name="cancellationToken">Token to cancel the operation.</param>
/// <returns>The created task with server-generated ID and timestamps.</returns>
/// <exception cref="ValidationException">
/// Thrown when the title is empty or exceeds 200 characters.
/// </exception>
/// <exception cref="UnauthorizedAccessException">
/// Thrown when the current principal is not authenticated.
/// </exception>
/// <example>
/// <code>
/// var task = await taskService.CreateTaskAsync(new CreateTaskInput("Buy groceries"));
/// Console.WriteLine(task.Id); // "task_abc123"
/// </code>
/// </example>
public async Task<TaskDto> CreateTaskAsync(
    CreateTaskInput input,
    CancellationToken cancellationToken = default)
{
    // ...
}
```

### OpenAPI / Swagger for ASP.NET Core HTTP APIs

Use Swashbuckle or the built-in OpenAPI support (.NET 9+):

```csharp
app.MapPost("/api/tasks", async (
    CreateTaskInput input,
    ITaskService service,
    CancellationToken cancellationToken) =>
{
    var task = await service.CreateTaskAsync(input, cancellationToken);
    return Results.Created($"/api/tasks/{task.Id}", task);
})
.WithName("CreateTask")
.WithSummary("Create a task")
.WithDescription("Creates a task owned by the current user. Title is required.")
.Produces<TaskDto>(StatusCodes.Status201Created)
.ProducesValidationProblem(StatusCodes.Status422UnprocessableEntity)
.WithOpenApi();
```

Commit the generated `swagger.json` / OpenAPI document when it's part of your contract with external consumers — treat it like any other public interface.

## README Structure

Every project should have a README that covers:

```markdown
# Project Name

One-paragraph description of what this project does.

## Quick Start
1. Clone the repo
2. Install the .NET SDK (see `global.json` for the exact version)
3. Restore: `dotnet restore`
4. Set up local secrets: `dotnet user-secrets init --project src/MyApp`
5. Run the host project: `dotnet run --project src/MyApp`

## Commands
| Command | Description |
|---------|-------------|
| `dotnet restore`                    | Restore NuGet dependencies |
| `dotnet build -warnaserror`         | Build the solution (warnings become errors) |
| `dotnet test`                       | Run all tests |
| `dotnet format --verify-no-changes` | Check formatting against `.editorconfig` |
| `dotnet run --project src/MyApp`    | Start the host project |
| `dotnet ef migrations add <Name>`   | Add a new EF Core migration (see CONTRIBUTING for required flags) |

## Architecture
Brief overview of the solution structure and key design decisions.
Link to ADRs for details.

```
src/MyApp/                 → host (Avalonia / ASP.NET Core / …)
src/MyApp.Core/            → domain types, use cases (no framework references)
src/MyApp.Infrastructure/  → EF Core, external integrations
src/MyApp.Contracts/       → shared DTOs
tests/…                    → test projects mirroring src/
docs/adr/                  → architecture decision records
```

## Contributing
How to contribute, coding standards, PR process. Points at `.editorconfig`,
analyzer ruleset, and `docs/adr/` for decisions that shape the codebase.
```

## Changelog Maintenance

For shipped features (especially when publishing NuGet packages):

```markdown
# Changelog

## [1.2.0] - 2026-01-20
### Added
- Task sharing: users can share tasks with team members (#123)
- Email notifications for task assignments (#124)

### Fixed
- Duplicate tasks appearing when rapidly clicking the Create button (#125)

### Changed
- Task list now loads 50 items per page (was 20) for better UX (#126)
- Bumped `Microsoft.EntityFrameworkCore` from 8.0.0 to 8.0.3
```

For library packages, match the `<Version>` (or `<PackageVersion>`) in the `.csproj` and consider using `MinVer` or `Nerdbank.GitVersioning` to derive it from git tags — keeps the changelog and the package in lock-step.

## Documentation for Agents

Special consideration for AI agent context:

- **CLAUDE.md / rules files** — Document project conventions so agents follow them (see the `context-engineering` skill)
- **Spec files** — Keep specs updated so agents build the right thing
- **ADRs** — Help agents understand why past decisions were made (prevents re-deciding; agents rarely re-litigate a documented decision, but freely re-litigate an undocumented one)
- **Inline gotchas** — Prevent agents from falling into known traps
- **`.editorconfig` + analyzer ruleset** — The executable half of your style guide; agents learn from compiler errors faster than from prose

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The code is self-documenting" | Code shows what. It doesn't show why, what alternatives were rejected, or what constraints apply. |
| "We'll write docs when the API stabilizes" | APIs stabilize faster when you document them. The doc is the first test of the design. |
| "Nobody reads docs" | Agents do. Future engineers do. Your 3-months-later self does. |
| "ADRs are overhead" | A 10-minute ADR prevents a 2-hour debate about the same decision six months later. |
| "Comments get outdated" | Comments on *why* are stable. Comments on *what* get outdated — that's why you only write the former. |
| "XML doc comments are busywork" | On internal helpers, maybe. On public APIs crossing an assembly boundary, they're the contract your consumers (and IntelliSense) see first. |

## Red Flags

- Architectural decisions with no written rationale
- Public APIs with no XML doc comments or OpenAPI metadata
- README that doesn't explain how to run the project (missing `dotnet` commands, missing `global.json` note, missing user-secrets setup)
- Commented-out code instead of deletion
- TODO comments that have been there for weeks with no linked issue
- No ADRs in a project with significant architectural choices
- Documentation that restates the code instead of explaining intent
- `<remarks>` sections so long nobody reads them (keep them to a paragraph; link to an ADR for depth)

## Verification

After documenting:

- [ ] ADRs exist for all significant architectural decisions
- [ ] README covers quick start (including `global.json` / SDK version), commands, and architecture overview
- [ ] Public API types/methods have XML doc comments with `<summary>`, parameters, return value, and exceptions
- [ ] Known gotchas are documented inline where they matter
- [ ] No commented-out code remains
- [ ] CLAUDE.md and `.editorconfig` reflect the current conventions
- [ ] CHANGELOG is up to date for any release that ships externally (NuGet package, API deployment)

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/documentation-and-adrs/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - "When to Use" examples retargeted to .NET decisions (EF Core vs Dapper, controllers vs Minimal APIs, Avalonia vs MAUI)
  - ADR example rewritten: PostgreSQL + EF Core + Npgsql with alternatives (Dapper on SQL Server, SQL Server/EF Core, SQLite, MongoDB) and a `Consequences` bullet about Testcontainers for integration tests
  - Inline-comment good/bad examples converted to C# (expression-bodied method, `DateTimeOffset` windowing)
  - Known-gotcha example uses XML doc comments with `<summary>`/`<remarks>`/`<see cref>`, references Avalonia `AppBuilder.StartWithClassicDesktopLifetime`
  - API docs section replaced JSDoc with XML doc comments + `<GenerateDocumentationFile>` and `SA1600`/`CS1591` analyzers
  - OpenAPI example replaced YAML-by-hand with Minimal API + Swashbuckle metadata (`.WithName`, `.WithSummary`, `.Produces`, `.ProducesValidationProblem`, `.WithOpenApi`)
  - README template swaps `npm install`/`npm run dev`/`npm test` for `dotnet` CLI commands, adds `global.json`, `dotnet user-secrets init`, and solution-layout ASCII tree
  - Changelog section adds NuGet-specific guidance (MinVer / Nerdbank.GitVersioning for git-tag-driven versions)
  - "Documentation for Agents" bullet adds `.editorconfig` + analyzer ruleset as the executable half of the style guide
  - Rationalizations table adds a row on XML doc comments as the first IntelliSense experience for consumers
  - Red-flag list adds missing XML doc comments on public APIs, missing `global.json`/user-secrets notes in README, over-long `<remarks>`
  - Verification checklist items reflect .NET conventions (SDK version, XML docs, CLAUDE.md + `.editorconfig`, CHANGELOG for NuGet/API releases)
  - Preserved verbatim: ADR lifecycle (PROPOSED → ACCEPTED → SUPERSEDED), when-to-comment vs when-not-to-comment framing, Changelog structure, Common Rationalizations table frame
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
