---
name: using-agent-skills
description: Meta-skill — discovers and invokes the right .NET/C# agent skill from this marketplace for the task at hand. Use when starting a session, when a task doesn't obviously map to a single skill, or when you need a phase-by-phase map of what's available across Define / Plan / Build / Verify / Review / Ship. Governs how every other skill in `dotnet-agent-skills` is discovered and activated.
version: 1.0.0
source: rewritten from vendor/agent-skills/skills/using-agent-skills/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). This is a STRUCTURAL REWRITE targeted at the `dotnet-agent-skills` plugin in this marketplace. Upstream's skeleton (discovery tree + operating behaviors + failure modes + lifecycle + quick reference) is preserved; skill names are retargeted (integration-testing-dotnet, frontend-ui-engineering-avalonia, performance-optimization-dotnet); cross-cuts to the companion avalonia-dev plugin are added. Because upstream and downstream now have different skill inventories, future re-syncs of this specific file are NOT tracked — see SYNC.md. -->

# Using `dotnet-agent-skills`

## Overview

`dotnet-agent-skills` is a collection of 20 engineering workflow skills organized by development phase, targeted at modern .NET (8+ LTS, C# 12+). Each skill encodes a specific process with concrete `dotnet` CLI commands, NuGet-ecosystem tooling, and .NET-specific anti-patterns. This meta-skill helps you discover and apply the right skill for your current task.

The plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani) with targeted adaptations — see the plugin's [`README.md`](../../README.md) and [`NOTICE.md`](../../NOTICE.md). The companion [`avalonia-dev`](../../../avalonia-dev/README.md) plugin in this marketplace covers structural Avalonia/MAUI reviews (design tokens, project layout, phased migration) and pairs naturally with the `frontend-ui-engineering-avalonia` skill defined here.

## How Skills Activate

Two activation paths, both native to Claude Code plugins:

1. **Natural-language triggering** — Each skill's YAML `description` is keyword-dense with .NET vocabulary (`.NET 8`, `C# 12`, `xUnit`, `EF Core`, `Avalonia`, `dotnet test`, `FluentValidation`, `ProblemDetails`, …). When your prompt matches, Claude Code offers the skill. You don't type anything special — just describe what you want.
2. **Explicit listing** — Run `/dotnet-skills` to see every available skill grouped by phase, with natural-language trigger examples for each. Useful when you don't know the name yet, or when browsing what's possible.

Skills are workflows, not commands. Activation loads the skill's guidance into the agent's context; the agent follows the workflow and applies its verification steps.

## Skill Discovery

When a task arrives, identify the development phase and apply the corresponding skill:

```
Task arrives
    │
    ├── Vague idea, needs refinement? ─────────→ idea-refine
    │
    ├── New .NET project/feature, no spec? ───→ spec-driven-development
    │
    ├── Have a spec, need tasks? ──────────────→ planning-and-task-breakdown
    │
    ├── Implementing code?
    │   ├── Generic: thin vertical slices ────→ incremental-implementation
    │   ├── Avalonia UI work? ─────────────────→ frontend-ui-engineering-avalonia
    │   ├── HTTP / library contract design? ──→ api-and-interface-design
    │   ├── Agent drifting / inventing APIs? ─→ context-engineering
    │   └── Need doc-verified .NET code? ──────→ source-driven-development
    │
    ├── Testing?
    │   ├── Unit / Prove-It Pattern? ──────────→ test-driven-development
    │   └── HTTP / EF Core / Playwright /
    │       Avalonia.Headless integration? ───→ integration-testing-dotnet
    │
    ├── Something broke? ──────────────────────→ debugging-and-error-recovery
    │
    ├── Reviewing code?
    │   ├── Multi-axis quality review? ────────→ code-review-and-quality
    │   ├── Simplify without changing behavior?→ code-simplification
    │   ├── Security concerns? ────────────────→ security-and-hardening
    │   └── Perf concerns / measurable slow? ──→ performance-optimization-dotnet
    │
    ├── Shipping?
    │   ├── Committing/branching/pre-commit? ──→ git-workflow-and-versioning
    │   ├── CI/CD pipeline work? ──────────────→ ci-cd-and-automation
    │   ├── Writing docs/ADRs? ────────────────→ documentation-and-adrs
    │   ├── Retiring / sunsetting a system? ──→ deprecation-and-migration
    │   └── Deploying/launching? ──────────────→ shipping-and-launch
    │
    └── Meta / unsure which skill? ────────────→ this skill (using-agent-skills)
                                                  or run `/dotnet-skills`
```

**For structural Avalonia/MAUI reviews** (design-token audit, project layout, phased migration guidance for 11→12), delegate to the companion `avalonia-dev` plugin's `/avalonia-review` command — it complements `frontend-ui-engineering-avalonia` without duplicating it.

## Core Operating Behaviors

These behaviors apply at all times, across every skill. They are non-negotiable.

### 1. Surface Assumptions

Before implementing anything non-trivial, explicitly state your assumptions:

```
ASSUMPTIONS I'M MAKING:
1. This is an Avalonia 11 desktop app (not MAUI or WPF)
2. Target framework is net8.0 (LTS), <Nullable>enable</Nullable>
3. EF Core 8 against PostgreSQL for prod, SQLite for tests
4. Testing with xUnit + FluentAssertions
5. MVVM via CommunityToolkit.Mvvm source generators
→ Correct me now or I'll proceed with these.
```

Don't silently fill in ambiguous requirements. The most common failure mode is making wrong assumptions and running with them unchecked. Surface uncertainty early — it's cheaper than rework.

### 2. Manage Confusion Actively

When you encounter inconsistencies, conflicting requirements, or unclear specifications:

1. **STOP.** Do not proceed with a guess.
2. Name the specific confusion.
3. Present the tradeoff or ask the clarifying question.
4. Wait for resolution before continuing.

**Bad:** Silently picking one interpretation and hoping it's right.
**Good:** *"The spec calls for Minimal APIs, but `MyApp/Controllers/AuthController.cs` uses classic controllers. Which takes precedence — spec or existing convention?"*

### 3. Push Back When Warranted

You are not a yes-machine. When an approach has clear problems:

- Point out the issue directly
- Explain the concrete downside (quantify when possible — *"this `FromSqlRaw` with interpolation is a SQL-injection vector under the current request handler"*, not *"this might be unsafe"*)
- Propose an alternative (*"switch to `FromSqlInterpolated` — EF Core parameterizes automatically"*)
- Accept the human's decision if they override with full information

Sycophancy is a failure mode. *"Of course!"* followed by implementing a bad idea helps no one. Honest technical disagreement — grounded in specific observations from the codebase — is more valuable than false agreement.

### 4. Enforce Simplicity

Your natural tendency is to overcomplicate. Actively resist it.

Before finishing any implementation, ask:
- Can this be done in fewer lines?
- Are these abstractions earning their complexity?
- Would a staff .NET engineer look at this and say *"why didn't you just use `record` / `IOptions<T>` / pattern matching?"*
- Is a generic `IEventBus<T>` really better than one method call?

If you build 1000 lines of code and 100 would suffice, you have failed. Prefer the boring, obvious solution. Cleverness is expensive. See [`code-simplification`](../code-simplification/SKILL.md) for the detailed treatment.

### 5. Maintain Scope Discipline

Touch only what you're asked to touch.

Do NOT:
- Remove XML doc comments or code comments you don't fully understand
- "Clean up" code orthogonal to the task
- Reorder `using` directives in files you're not modifying
- Modernize syntax (primary constructors, collection expressions, `switch` expressions) in files you're only reading
- Refactor adjacent systems as a side effect
- Delete code that seems unused without explicit approval (check for reflection / analyzer-generated references first)
- Add features not in the spec because they "seem useful"

Your job is surgical precision, not unsolicited renovation.

### 6. Verify, Don't Assume

Every skill includes a verification step. A task is not complete until verification passes. *"Seems right"* is never sufficient — there must be evidence:

- `dotnet test` green, with visible test count
- `dotnet build -warnaserror` clean, with analyzer diagnostics resolved at source (not suppressed)
- `dotnet format --verify-no-changes` clean
- Manual UI check for visible features (Avalonia: headless test or screenshot; Blazor: Playwright assertion)
- Specific before/after numbers for performance work

## Failure Modes to Avoid

These are the subtle errors that look like productivity but create problems:

1. Making wrong assumptions without checking — especially about `TargetFramework`, `<Nullable>`, or whether a project uses CommunityToolkit.Mvvm vs ReactiveUI
2. Not managing your own confusion — plowing ahead when lost
3. Not surfacing inconsistencies you notice
4. Not presenting tradeoffs on non-obvious decisions
5. Being sycophantic (*"Of course!"*) to approaches with clear problems (`.Result` in a request path, `FromSqlRaw` with interpolation, `Microsoft.EntityFrameworkCore.InMemory` for integration tests)
6. Overcomplicating code and APIs — generic abstractions before the third use case demands them
7. Modifying code or comments orthogonal to the task
8. Removing things you don't fully understand (especially analyzer-driven or source-generated files)
9. Building without a spec because *"it's obvious"*
10. Skipping verification because *"it looks right"* — the JIT, analyzers, and runtime diagnostics find things your eyes don't

## Skill Rules

1. **Check for an applicable skill before starting work.** Skills encode processes that prevent common mistakes.

2. **Skills are workflows, not suggestions.** Follow the steps in order. Don't skip verification steps.

3. **Multiple skills can apply.** A feature implementation typically chains several — see the Lifecycle Sequence below.

4. **When in doubt, start with a spec.** If the task is non-trivial and there's no spec, begin with [`spec-driven-development`](../spec-driven-development/SKILL.md).

5. **Version-aware skills detect their target.** Skills that branch on framework version (currently `frontend-ui-engineering-avalonia` for Avalonia 11 vs 12) read `Directory.Packages.props` / `.csproj` before applying patterns. When the project's stack is unclear, [`source-driven-development`](../source-driven-development/SKILL.md) is the right first stop.

6. **Skipped upstream content is intentional.** Upstream's `scripts/idea-refine.sh` bash helper is deliberately not ported. `docs/ideas/` is treated as a path convention, nothing more.

## Lifecycle Sequence

For a complete .NET feature, the typical skill sequence is:

```
1.  idea-refine                         → Refine vague ideas into a "Not Doing" list
2.  spec-driven-development             → Define what we're building (with .NET 8 / C# 12 tech stack pinned)
3.  planning-and-task-breakdown         → Break into verifiable tasks with dotnet CLI verification
4.  context-engineering                 → Load CLAUDE.md + .editorconfig + the right source files
5.  source-driven-development           → Cite Microsoft Learn + framework docs at the pinned version
6.  incremental-implementation          → Build slice by slice, dotnet test between each
7.  frontend-ui-engineering-avalonia    → (If UI) Production-quality Avalonia view with compiled bindings
8.  api-and-interface-design            → (If HTTP/library) Stable DTOs in MyApp.Contracts
9.  test-driven-development             → Unit tests with xUnit/MSTest + TimeProvider for determinism
10. integration-testing-dotnet          → HTTP (WebApplicationFactory), DB (Testcontainers), browser (Playwright), desktop (Avalonia.Headless)
11. performance-optimization-dotnet     → (If perf-sensitive) Measure first with BenchmarkDotNet, fix the real bottleneck
12. code-review-and-quality             → Five-axis review with .NET-specific checks
13. code-simplification                 → Post-feature simplification pass
14. security-and-hardening               → Full .NET security sweep before merge
15. git-workflow-and-versioning         → Atomic commits, pre-commit via Husky.Net
16. ci-cd-and-automation                → GitHub Actions with setup-dotnet + gates
17. documentation-and-adrs              → XML doc comments on public API, ADR for non-obvious decisions
18. deprecation-and-migration           → (If replacing) [Obsolete] + strangler pattern
19. shipping-and-launch                 → Pre-launch checklist, staged rollout, rollback plan
```

Not every task needs every skill. A bug fix might only need:
```
debugging-and-error-recovery  →  test-driven-development  →  code-review-and-quality
```

A performance hotfix:
```
performance-optimization-dotnet  →  integration-testing-dotnet  →  code-review-and-quality
```

A schema migration:
```
spec-driven-development  →  deprecation-and-migration  →  integration-testing-dotnet  →  shipping-and-launch
```

## Quick Reference

| Phase | Skill | One-Line Summary |
|-------|-------|-----------------|
| Define | [idea-refine](../idea-refine/SKILL.md) | Refine ideas through structured divergent and convergent thinking |
| Define | [spec-driven-development](../spec-driven-development/SKILL.md) | Requirements and acceptance criteria before code, with a .NET-flavored template |
| Plan | [planning-and-task-breakdown](../planning-and-task-breakdown/SKILL.md) | Decompose into small tasks with `dotnet` CLI verification |
| Build | [incremental-implementation](../incremental-implementation/SKILL.md) | Thin vertical slices; `dotnet test` + `dotnet build -warnaserror` between each |
| Build | [source-driven-development](../source-driven-development/SKILL.md) | Cite Microsoft Learn / framework docs for every framework-specific decision |
| Build | [context-engineering](../context-engineering/SKILL.md) | Right CLAUDE.md + `.editorconfig` + source files at the right time |
| Build | [frontend-ui-engineering-avalonia](../frontend-ui-engineering-avalonia/SKILL.md) | Production-quality Avalonia 11/12 UIs with compiled bindings + theming + accessibility |
| Build | [api-and-interface-design](../api-and-interface-design/SKILL.md) | Stable HTTP/library contracts with C# records + ProblemDetails + FluentValidation |
| Verify | [test-driven-development](../test-driven-development/SKILL.md) | Failing test first, then GREEN; dual xUnit + MSTest, `TimeProvider`/`FakeTimeProvider` |
| Verify | [integration-testing-dotnet](../integration-testing-dotnet/SKILL.md) | `WebApplicationFactory<T>`, Testcontainers, `Microsoft.Playwright`, `Avalonia.Headless.XUnit` |
| Verify | [debugging-and-error-recovery](../debugging-and-error-recovery/SKILL.md) | Reproduce → localize → fix → guard; `dotnet test --filter` + EF Core `LogTo` |
| Review | [code-review-and-quality](../code-review-and-quality/SKILL.md) | Five-axis review with async correctness, DI lifetimes, EF Core N+1 checks |
| Review | [code-simplification](../code-simplification/SKILL.md) | Reduce C# complexity without changing behavior; `switch` expressions, records, LINQ discipline |
| Review | [security-and-hardening](../security-and-hardening/SKILL.md) | Full .NET security: FluentValidation + EF Core + ASP.NET Core Identity / JWT + Data Protection + rate limiting |
| Review | [performance-optimization-dotnet](../performance-optimization-dotnet/SKILL.md) | Measure first with BenchmarkDotNet; fix EF Core N+1, sync-over-async, Gen2 pressure, `HttpClient` misuse |
| Ship | [git-workflow-and-versioning](../git-workflow-and-versioning/SKILL.md) | Atomic commits, Husky.Net pre-commit, `.gitignore` for `bin/obj/.vs` |
| Ship | [ci-cd-and-automation](../ci-cd-and-automation/SKILL.md) | GitHub Actions / Azure DevOps with `setup-dotnet`, quality gates, NuGet publish |
| Ship | [documentation-and-adrs](../documentation-and-adrs/SKILL.md) | XML doc comments + Swashbuckle OpenAPI + ADRs for EF Core / framework decisions |
| Ship | [deprecation-and-migration](../deprecation-and-migration/SKILL.md) | `[Obsolete]`, strangler pattern, `IOptionsMonitor` feature flags, NuGet unlist |
| Ship | [shipping-and-launch](../shipping-and-launch/SKILL.md) | Pre-launch checklist, `IOptions<FeatureOptions>`, Application Insights, EF Core migration rollback |

## Pointers Out

- Plugin README: [`../../README.md`](../../README.md)
- Attribution + license: [`../../NOTICE.md`](../../NOTICE.md), [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
- Per-skill upstream provenance: the "Source & Modifications" footer on every ported `SKILL.md` in this plugin
- Upstream repository (authoritative for re-sync status): https://github.com/addyosmani/agent-skills
- Companion plugin for structural Avalonia reviews: [`../../../avalonia-dev/README.md`](../../../avalonia-dev/README.md) (`/avalonia-review`)

## Verification

This is a meta-skill — its "verification" is that the other skills activate cleanly:

- [ ] `/dotnet-skills` lists every skill in the plugin, grouped by phase, with trigger examples
- [ ] A natural-language prompt matching a skill's `description` (e.g. *"help me spec out a new C# service"*) activates the right skill
- [ ] The discovery tree above maps every reasonable task type to at least one skill
- [ ] No dangling references to upstream skill names that were renamed in this plugin (`frontend-ui-engineering` → `frontend-ui-engineering-avalonia`; `browser-testing-with-devtools` → `integration-testing-dotnet`; `performance-optimization` → `performance-optimization-dotnet`)
- [ ] The Lifecycle Sequence matches the actual set of ported skills in `skills/`

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/using-agent-skills/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `rewritten` — upstream and downstream now have different skill inventories (we renamed three skills and skipped one upstream helper script), so re-syncing this specific file against upstream no longer produces useful deltas. Per-skill re-syncs for the other 20 skills remain worthwhile; this file's upstream will be re-read on major upstream changes but not line-diffed.
- **Rationale**: the meta skill's job is to reflect *our* marketplace's skill inventory, not upstream's. As long as the names, phases, and activation story diverge, a faithful port of upstream's prose would actively mislead readers. Preserving the skeleton (discovery tree, core operating behaviors, failure modes, lifecycle sequence, quick reference) keeps the conceptual continuity with upstream readers; the content fills in our specifics.
- **What changed**:
  - Plugin-specific overview: names this plugin (`dotnet-agent-skills`), credits Addy Osmani upstream, cross-references the companion `avalonia-dev` plugin
  - New "How Skills Activate" section explaining Claude Code's two activation paths (natural-language description matching + `/dotnet-skills` explicit listing)
  - Discovery tree retargeted: renames three skills (`integration-testing-dotnet`, `frontend-ui-engineering-avalonia`, `performance-optimization-dotnet`), adds `code-simplification` / `deprecation-and-migration` branches (upstream omits them from its tree), directs structural Avalonia reviews to the companion `avalonia-dev` plugin
  - Core Operating Behaviors preserved as the six-section spine with .NET-flavored examples throughout (Avalonia/EF Core assumptions, `FromSqlRaw` push-back, `IOptions<T>` simplicity call-out, `using` directive + source-generated file scope discipline)
  - Added a "Skill Rules" rule about version-aware skills (`frontend-ui-engineering-avalonia` branches on Avalonia 11 vs 12 by reading `Directory.Packages.props`)
  - Added a "Skill Rules" rule about the deliberately-skipped upstream `scripts/idea-refine.sh`
  - Lifecycle Sequence rewritten as a 19-step flow covering every Wave-0-through-Wave-3 skill by our naming, with three realistic short-flow examples (bug fix, perf hotfix, schema migration)
  - Quick Reference table rewritten row-by-row with our skill names, our one-line .NET-flavored summaries, and markdown links to each skill's SKILL.md
  - New "Pointers Out" section linking to README, SYNC.md, UPSTREAM.md, NOTICE.md, LICENSES, and the companion avalonia-dev plugin
  - Verification checklist rewritten as five meta-checks (including "no dangling references to renamed upstream skills")
  - All references to upstream-only concerns (Chrome DevTools MCP as the implicit browser-testing activation path) removed
- **Preserved from upstream**: six Core Operating Behaviors structure (Surface Assumptions / Manage Confusion / Push Back / Enforce Simplicity / Maintain Scope / Verify), the ten-item Failure Modes list shape, the Skill Rules numbered format, the Phase → Skill → Summary table shape, the overall section ordering
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
