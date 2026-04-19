---
name: spec-driven-development
description: Creates specs before coding a .NET/C# project. Use when starting a new .NET 8+ solution, feature, or significant change and no specification exists yet. Use when requirements are unclear, ambiguous, or only exist as a vague idea. Frames examples for Avalonia, ASP.NET Core, Blazor, .NET MAUI, EF Core, xUnit, and MSTest.
version: 0.1.0
source: vendor/agent-skills/skills/spec-driven-development/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Spec-Driven Development

## Overview

Write a structured specification before writing any code. The spec is the shared source of truth between you and the human engineer — it defines what we're building, why, and how we'll know it's done. Code without a spec is guessing.

## When to Use

- Starting a new .NET solution or feature
- Requirements are ambiguous or incomplete
- The change touches multiple projects or assemblies in the solution
- You're about to make an architectural decision (hosting model, persistence layer, UI framework)
- The task would take more than 30 minutes to implement

**When NOT to use:** Single-line fixes, typo corrections, or changes where requirements are unambiguous and self-contained.

## The Gated Workflow

Spec-driven development has four phases. Do not advance to the next phase until the current one is validated.

```
SPECIFY ──→ PLAN ──→ TASKS ──→ IMPLEMENT
   │          │        │          │
   ▼          ▼        ▼          ▼
 Human      Human    Human      Human
 reviews    reviews  reviews    reviews
```

### Phase 1: Specify

Start with a high-level vision. Ask the human clarifying questions until requirements are concrete.

**Surface assumptions immediately.** Before writing any spec content, list what you're assuming:

```
ASSUMPTIONS I'M MAKING:
1. This is an Avalonia 11 desktop app (not MAUI or WPF)
2. Target framework is .NET 8 (LTS), C# 12 language features
3. Persistence is EF Core 8 against SQLite for dev, PostgreSQL for prod
4. Testing with xUnit v3 + native `Xunit.Assert` (MSTest with its native `Assert` is acceptable per team standard)
5. MVVM via CommunityToolkit.Mvvm source generators
→ Correct me now or I'll proceed with these.
```

Don't silently fill in ambiguous requirements. The spec's entire purpose is to surface misunderstandings *before* code gets written — assumptions are the most dangerous form of misunderstanding.

**Write a spec document covering these six core areas:**

1. **Objective** — What are we building and why? Who is the user? What does success look like?

2. **Commands** — Full executable commands with flags, not just tool names.
   ```
   Restore:   dotnet restore
   Build:     dotnet build --configuration Release
   Test:      dotnet test --collect:"XPlat Code Coverage"
   Format:    dotnet format --verify-no-changes
   Run:       dotnet run --project src/MyApp
   Publish:   dotnet publish src/MyApp -c Release -r win-x64 --self-contained false
   ```

3. **Project Structure** — Where source code lives, where tests go, where docs belong.
   ```
   MyApp.sln
   src/
     MyApp/                 → Main application (Avalonia / ASP.NET Core / Blazor / MAUI host)
     MyApp.Core/            → Domain types, use cases, pure logic
     MyApp.Infrastructure/  → EF Core DbContext, external integrations
     MyApp.Contracts/       → DTOs and API contracts (shared by server + clients)
   tests/
     MyApp.Core.Tests/          → Unit tests (xUnit)
     MyApp.Infrastructure.Tests/→ Integration tests (EF Core in-memory or Testcontainers)
     MyApp.EndToEnd.Tests/      → E2E (Playwright.NET for web, Avalonia.Headless for desktop)
   docs/                    → ADRs, specs, contributor guides
   ```

4. **Code Style** — One real code snippet showing your style beats three paragraphs describing it. Include naming conventions, formatting rules, and examples of good output.

5. **Testing Strategy** — What framework, where tests live, coverage expectations, which test levels for which concerns. Call out xUnit vs MSTest explicitly; list analyzers (`Microsoft.CodeAnalysis.NetAnalyzers`, `StyleCop.Analyzers`) and whether `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` is on.

6. **Boundaries** — Three-tier system:
   - **Always do:** Run `dotnet test` before commits, follow the project's `.editorconfig`, validate inputs at public API boundaries, nullable reference types on
   - **Ask first:** EF Core migrations, adding NuGet dependencies, changing target framework, changing CI config
   - **Never do:** Commit secrets (`user-secrets` for dev, Key Vault / environment variables for prod), edit `vendor/` directories, remove failing tests without approval, disable nullable warnings globally

**Spec template:**

```markdown
# Spec: [Project/Feature Name]

## Objective
[What we're building and why. User stories or acceptance criteria.]

## Tech Stack
[.NET version (e.g. .NET 8), language (C# 12), key NuGet packages with versions,
 UI framework (Avalonia 11 / Blazor / ASP.NET Core / MAUI), data layer (EF Core 8),
 testing framework (xUnit or MSTest)]

## Commands
[Restore, build, test, format, run, publish — full dotnet CLI commands]

## Project Structure
[Solution layout with project responsibilities]

## Code Style
[Example snippet + .editorconfig highlights + analyzer set]

## Testing Strategy
[Framework, test project locations, coverage targets, which level covers what]

## Boundaries
- Always: [...]
- Ask first: [...]
- Never: [...]

## Success Criteria
[How we'll know this is done — specific, testable conditions]

## Open Questions
[Anything unresolved that needs human input]
```

**Reframe instructions as success criteria.** When receiving vague requirements, translate them into concrete conditions:

```
REQUIREMENT: "Make the app faster"

REFRAMED SUCCESS CRITERIA (Avalonia desktop app):
- Cold-start time from launch to main window visible < 1.2s on Windows 11 / Ryzen 5
- List view with 10k items scrolls at 60 FPS (measured via PerfView ETW trace)
- Background data refresh completes in < 500ms at the 95th percentile

REFRAMED SUCCESS CRITERIA (ASP.NET Core API):
- p95 request latency < 120ms for GET /api/orders under 200 RPS
- No Gen2 GC collections observed during 10-minute soak at target load
→ Are these the right targets?
```

This lets you loop, retry, and problem-solve toward a clear goal rather than guessing what "faster" means.

### Phase 2: Plan

With the validated spec, generate a technical implementation plan:

1. Identify the major components and their dependencies (which projects gain new code, which `DbContext` changes, which DI registrations move)
2. Determine the implementation order (contracts and migrations first, then infrastructure, then UI)
3. Note risks and mitigation strategies (breaking migration, async deadlocks, package version conflicts)
4. Identify what can be built in parallel vs. what must be sequential
5. Define verification checkpoints between phases (each milestone green on `dotnet test`)

The plan should be reviewable: the human should be able to read it and say "yes, that's the right approach" or "no, change X."

### Phase 3: Tasks

Break the plan into discrete, implementable tasks:

- Each task should be completable in a single focused session
- Each task has explicit acceptance criteria
- Each task includes a verification step (test, build, manual check)
- Tasks are ordered by dependency, not by perceived importance
- No task should require changing more than ~5 files

**Task template:**
```markdown
- [ ] Task: [Description]
  - Acceptance: [What must be true when done]
  - Verify: [How to confirm — e.g. `dotnet test tests/MyApp.Core.Tests`, `dotnet build -warnaserror`, manual smoke]
  - Files: [Which files will be touched]
```

### Phase 4: Implement

Execute tasks one at a time following `incremental-implementation` and `test-driven-development` skills. Use `context-engineering` to load the right spec sections and source files at each step rather than flooding the agent with the entire spec.

## Keeping the Spec Alive

The spec is a living document, not a one-time artifact:

- **Update when decisions change** — If you discover the domain model needs to change, update the spec first, then generate the EF Core migration.
- **Update when scope changes** — Features added or cut should be reflected in the spec.
- **Commit the spec** — The spec belongs in version control alongside the code (`docs/specs/` is a common home).
- **Reference the spec in PRs** — Link back to the spec section that each PR implements.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This is simple, I don't need a spec" | Simple tasks don't need *long* specs, but they still need acceptance criteria. A two-line spec is fine. |
| "I'll write the spec after I code it" | That's documentation, not specification. The spec's value is in forcing clarity *before* code. |
| "The spec will slow us down" | A 15-minute spec prevents hours of rework. Waterfall in 15 minutes beats debugging in 15 hours. |
| "Requirements will change anyway" | That's why the spec is a living document. An outdated spec is still better than no spec. |
| "The user knows what they want" | Even clear requests have implicit assumptions. The spec surfaces those assumptions. |

## Red Flags

- Starting to write code without any written requirements
- Asking "should I just start building?" before clarifying what "done" means
- Implementing features not mentioned in any spec or task list
- Making architectural decisions without documenting them (no ADR under `docs/adr/`)
- Skipping the spec because "it's obvious what to build"

## Verification

Before proceeding to implementation, confirm:

- [ ] The spec covers all six core areas
- [ ] The human has reviewed and approved the spec
- [ ] Success criteria are specific and testable
- [ ] Boundaries (Always/Ask First/Never) are defined
- [ ] The spec is saved to a file in the repository (`docs/specs/<name>.md` recommended)

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/spec-driven-development/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - Assumption examples retargeted from web app / session cookies / Prisma to Avalonia / .NET 8 / EF Core / xUnit / CommunityToolkit.Mvvm
  - `Commands` block replaced `npm run ...` with full `dotnet` CLI invocations (restore, build, test, format, run, publish)
  - `Project Structure` replaced `src/components → React components` layout with a `MyApp.sln` multi-project solution (Core / Infrastructure / Contracts + matching test projects)
  - `Testing Strategy` guidance calls out xUnit vs MSTest and mentions `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` and the standard analyzer pack
  - `Boundaries` swapped `npm`/generic web guidance for `user-secrets`, Key Vault, nullable reference types, and EF Core migration caution
  - `Reframe` block replaced the web Core Web Vitals example with two .NET-flavored success-criteria examples (Avalonia cold start, ASP.NET Core p95 latency + GC)
  - `Tech Stack` section in the spec template explicitly enumerates UI framework choices (Avalonia 11 / Blazor / ASP.NET Core / MAUI) and the EF Core data layer
  - `Task template` verify command updated to `dotnet test`/`dotnet build -warnaserror`
  - `Keeping the Spec Alive` references EF Core migration in the "decisions change" bullet; recommends `docs/specs/` and `docs/adr/` as canonical locations
  - All structural sections, phase gates, workflow, rationalization table, and red-flag list preserved from upstream verbatim
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
