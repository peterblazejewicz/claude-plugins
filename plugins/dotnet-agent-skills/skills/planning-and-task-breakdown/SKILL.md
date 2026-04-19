---
name: planning-and-task-breakdown
description: Breaks .NET/C# work into ordered, verifiable tasks. Use when you have a spec or clear requirements and need to decompose work into implementable units with dotnet CLI verification steps. Use when a task feels too large to start, when you need to estimate scope across a multi-project solution, or when parallel work is possible.
version: 0.2.0
source: vendor/agent-skills/skills/planning-and-task-breakdown/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Planning and Task Breakdown

## Overview

Decompose work into small, verifiable tasks with explicit acceptance criteria. Good task breakdown is the difference between an agent that completes work reliably and one that produces a tangled mess. Every task should be small enough to implement, test, and verify in a single focused session.

## When to Use

- You have a spec and need to break it into implementable units
- A task feels too large or vague to start
- Work needs to be parallelized across multiple agents or sessions
- You need to communicate scope to a human
- The implementation order isn't obvious

**When NOT to use:** Single-file changes with obvious scope, or when the spec already contains well-defined tasks.

## The Planning Process

### Step 1: Enter Plan Mode

Before writing any code, operate in read-only mode:

- Read the spec and relevant codebase sections
- Identify existing patterns and conventions
- Map dependencies between projects and assemblies
- Note risks and unknowns

**Do NOT write code during planning.** The output is a plan document, not implementation.

### Step 2: Identify the Dependency Graph

Map what depends on what:

```
Database schema / EF Core entities
    │
    ├── DTOs / contracts
    │       │
    │       ├── API endpoints or service methods
    │       │       │
    │       │       └── UI bindings (Avalonia / Blazor / MAUI)
    │       │               │
    │       │               └── Views and view models
    │       │
    │       └── Validation logic (FluentValidation, DataAnnotations)
    │
    └── Seed data / migrations (EF Core `dotnet ef migrations`)
```

Implementation order follows the dependency graph bottom-up: build foundations first. Within a .NET solution, that usually means `MyApp.Core` → `MyApp.Infrastructure` → `MyApp.Contracts` → `MyApp` (host project).

### Step 3: Slice Vertically

Instead of building all the database, then all the API, then all the UI — build one complete feature path at a time:

**Bad (horizontal slicing):**
```
Task 1: Build entire EF Core model
Task 2: Build all controllers / service methods
Task 3: Build all views
Task 4: Connect everything
```

**Good (vertical slicing):**
```
Task 1: User can create an account (entity + migration + endpoint + UI)
Task 2: User can log in (auth scheme + endpoint + UI)
Task 3: User can create a task (entity + migration + endpoint + UI)
Task 4: User can view task list (query + endpoint + UI list view)
```

Each vertical slice delivers working, testable functionality.

### Step 4: Write Tasks

Each task follows this structure:

```markdown
## Task [N]: [Short descriptive title]

**Description:** One paragraph explaining what this task accomplishes.

**Acceptance criteria:**
- [ ] [Specific, testable condition]
- [ ] [Specific, testable condition]

**Verification:**
- [ ] Tests pass: `dotnet test --filter "FullyQualifiedName~FeatureName"`
- [ ] Build succeeds: `dotnet build -warnaserror`
- [ ] Format clean: `dotnet format --verify-no-changes`
- [ ] Manual check: [description of what to verify]

**Dependencies:** [Task numbers this depends on, or "None"]

**Files likely touched:**
- `src/MyApp.Core/Feature/Thing.cs`
- `tests/MyApp.Core.Tests/Feature/ThingTests.cs`

**Estimated scope:** [Small: 1-2 files | Medium: 3-5 files | Large: 5+ files]
```

### Step 5: Order and Checkpoint

Arrange tasks so that:

1. Dependencies are satisfied (build foundation first)
2. Each task leaves the system in a working state
3. Verification checkpoints occur after every 2-3 tasks
4. High-risk tasks are early (fail fast)

Add explicit checkpoints:

```markdown
## Checkpoint: After Tasks 1-3
- [ ] All tests pass (`dotnet test`)
- [ ] Solution builds without warnings (`dotnet build -warnaserror`)
- [ ] Core user flow works end-to-end
- [ ] Review with human before proceeding
```

## Task Sizing Guidelines

| Size | Files | Scope | Example |
|------|-------|-------|---------|
| **XS** | 1 | Single method or config change | Add a validation attribute |
| **S** | 1-2 | One class or endpoint | Add a new controller action |
| **M** | 3-5 | One feature slice | User registration flow (entity + migration + endpoint + view) |
| **L** | 5-8 | Multi-component feature | Search with filtering and pagination across UI + API + query |
| **XL** | 8+ | **Too large — break it down further** | — |

If a task is L or larger, it should be broken into smaller tasks. An agent performs best on S and M tasks.

**When to break a task down further:**
- It would take more than one focused session (roughly 2+ hours of agent work)
- You cannot describe the acceptance criteria in 3 or fewer bullet points
- It touches two or more independent projects in the solution (e.g., `MyApp.Core` and `MyApp.Payments`)
- You find yourself writing "and" in the task title (a sign it is two tasks)

## Plan Document Template

```markdown
# Implementation Plan: [Feature/Project Name]

## Overview
[One paragraph summary of what we're building]

## Architecture Decisions
- [Key decision 1 and rationale — e.g., "Use EF Core 8 with owned entity types for value objects"]
- [Key decision 2 and rationale — e.g., "Wire MediatR for CQRS at the ASP.NET Core boundary"]

## Task List

### Phase 1: Foundation
- [ ] Task 1: ...
- [ ] Task 2: ...

### Checkpoint: Foundation
- [ ] `dotnet test` green, `dotnet build -warnaserror` clean

### Phase 2: Core Features
- [ ] Task 3: ...
- [ ] Task 4: ...

### Checkpoint: Core Features
- [ ] End-to-end flow works (run host project, exercise the slice)

### Phase 3: Polish
- [ ] Task 5: ...
- [ ] Task 6: ...

### Checkpoint: Complete
- [ ] All acceptance criteria met
- [ ] Ready for review

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk] | [High/Med/Low] | [Strategy] |

## Open Questions
- [Question needing human input]
```

## Parallelization Opportunities

When multiple agents or sessions are available:

- **Safe to parallelize:** Independent feature slices, tests for already-implemented features, documentation
- **Must be sequential:** EF Core migrations, shared `DbContext` changes, dependency chains, anything that touches `.csproj` references
- **Needs coordination:** Features that share a DTO or API contract (define the contract in `MyApp.Contracts` first, then parallelize)

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll figure it out as I go" | That's how you end up with a tangled mess and rework. 10 minutes of planning saves hours. |
| "The tasks are obvious" | Write them down anyway. Explicit tasks surface hidden dependencies and forgotten edge cases. |
| "Planning is overhead" | Planning is the task. Implementation without a plan is just typing. |
| "I can hold it all in my head" | Context windows are finite. Written plans survive session boundaries and compaction. |

## Red Flags

- Starting implementation without a written task list
- Tasks that say "implement the feature" without acceptance criteria
- No verification steps in the plan
- All tasks are XL-sized
- No checkpoints between tasks
- Dependency order isn't considered
- A task that spans more than two projects in the solution

## Verification

Before starting implementation, confirm:

- [ ] Every task has acceptance criteria
- [ ] Every task has a verification step (concrete `dotnet` command or manual check)
- [ ] Task dependencies are identified and ordered correctly
- [ ] No task touches more than ~5 files
- [ ] Checkpoints exist between major phases
- [ ] The human has reviewed and approved the plan

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/planning-and-task-breakdown/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - Dependency graph relabeled for .NET: EF Core entities, DTOs/contracts, Avalonia/Blazor/MAUI bindings; added hint about EF Core migration commands
  - Project layout references explicitly named (`MyApp.Core`, `MyApp.Infrastructure`, `MyApp.Contracts`, host project)
  - Task verification block uses `dotnet test --filter`, `dotnet build -warnaserror`, `dotnet format --verify-no-changes` instead of `npm` commands
  - File-path examples use `.cs` extensions and `src/MyApp.Core/…`, `tests/MyApp.Core.Tests/…` layout
  - Task sizing table example text retargeted for .NET (validation attribute, controller action, multi-project solution)
  - Parallelization guidance: EF Core migrations + `DbContext` + `.csproj` references called out as sequential; `MyApp.Contracts` identified as the coordination point for parallel work
  - Architecture decisions example uses EF Core 8 + MediatR rather than generic wording
  - Checkpoint commands use `dotnet test` / `dotnet build -warnaserror`
  - Added "spans more than two projects" to the red-flag list
  - All structural sections, rationalization table, and planning workflow preserved from upstream verbatim
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
