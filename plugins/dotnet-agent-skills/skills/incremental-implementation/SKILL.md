---
name: incremental-implementation
description: Delivers .NET/C# changes incrementally — thin vertical slices with dotnet build + dotnet test verification between each. Use when implementing any feature that touches more than one project or assembly. Use when you're about to write a large amount of code at once, or when a task feels too big to land in one step.
version: 0.2.0
source: vendor/agent-skills/skills/incremental-implementation/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Incremental Implementation

## Overview

Build in thin vertical slices — implement one piece, test it, verify it, then expand. Avoid implementing an entire feature in one pass. Each increment should leave the system in a working, testable state. This is the execution discipline that makes large features manageable.

## When to Use

- Implementing any multi-file change
- Building a new feature from a task breakdown
- Refactoring existing code
- Any time you're tempted to write more than ~100 lines before testing

**When NOT to use:** Single-file, single-method changes where the scope is already minimal.

## The Increment Cycle

```
┌──────────────────────────────────────┐
│                                      │
│   Implement ──→ Test ──→ Verify ──┐  │
│       ▲                           │  │
│       └───── Commit ◄─────────────┘  │
│              │                       │
│              ▼                       │
│          Next slice                  │
│                                      │
└──────────────────────────────────────┘
```

For each slice:

1. **Implement** the smallest complete piece of functionality
2. **Test** — run `dotnet test` (or write a test if none exists)
3. **Verify** — confirm the slice works as expected (tests pass, `dotnet build -warnaserror` is clean, manual check)
4. **Commit** -- save your progress with a descriptive message (see `git-workflow-and-versioning` for atomic commit guidance)
5. **Move to the next slice** — carry forward, don't restart

## Slicing Strategies

### Vertical Slices (Preferred)

Build one complete path through the stack:

```
Slice 1: Create a task (EF Core entity + migration + endpoint + basic view)
    → dotnet test passes, user can create a task via the UI

Slice 2: List tasks (query + endpoint + list view with bindings)
    → dotnet test passes, user can see their tasks

Slice 3: Edit a task (update command + endpoint + edit view)
    → dotnet test passes, user can modify tasks

Slice 4: Delete a task (delete command + endpoint + UI + confirmation)
    → dotnet test passes, full CRUD complete
```

Each slice delivers working end-to-end functionality.

### Contract-First Slicing

When backend and frontend need to develop in parallel:

```
Slice 0: Define the contract in MyApp.Contracts (DTOs, request/response types, OpenAPI via Swashbuckle)
Slice 1a: Implement backend against the contract + integration tests (WebApplicationFactory)
Slice 1b: Implement frontend against mock data matching the contract
Slice 2: Integrate and test end-to-end
```

### Risk-First Slicing

Tackle the riskiest or most uncertain piece first:

```
Slice 1: Prove the SignalR hub + client reconnection (highest risk)
Slice 2: Build real-time task updates on the proven connection
Slice 3: Add offline queue and reconnection storm handling
```

If Slice 1 fails, you discover it before investing in Slices 2 and 3.

## Implementation Rules

### Rule 0: Simplicity First

Before writing any code, ask: "What is the simplest thing that could work?"

After writing code, review it against these checks:
- Can this be done in fewer lines?
- Are these abstractions earning their complexity?
- Would a staff engineer look at this and say "why didn't you just..."?
- Am I building for hypothetical future requirements, or the current task?

```
SIMPLICITY CHECK:
✗ Generic IEventBus<T> with middleware pipeline for one notification
✓ Direct method call on a service

✗ Abstract factory pattern for two similar ViewModels
✓ Two straightforward ViewModels with a shared base class

✗ Config-driven form builder for three Avalonia forms
✓ Three straightforward Avalonia views
```

Three similar lines of code is better than a premature abstraction. Implement the naive, obviously-correct version first. Optimize only after correctness is proven with tests.

### Rule 0.5: Scope Discipline

Touch only what the task requires.

Do NOT:
- "Clean up" code adjacent to your change
- Reorder `using` directives in files you're not modifying
- Remove comments you don't fully understand
- Add features not in the spec because they "seem useful"
- Modernize syntax (primary constructors, collection expressions) in files you're only reading

If you notice something worth improving outside your task scope, note it — don't fix it:

```
NOTICED BUT NOT TOUCHING:
- MyApp.Core/Utilities/FormatHelper.cs has an unused using (unrelated to this task)
- The auth handler could use better error messages (separate task)
→ Want me to create tasks for these?
```

### Rule 1: One Thing at a Time

Each increment changes one logical thing. Don't mix concerns:

**Bad:** One commit that adds a new view, refactors an existing ViewModel, and updates `Directory.Packages.props`.

**Good:** Three separate commits — one for each change.

### Rule 2: Keep It Compilable

After each increment, `dotnet build -warnaserror` must succeed and `dotnet test` must pass. Don't leave the solution in a broken state between slices.

### Rule 3: Feature Flags for Incomplete Features

If a feature isn't ready for users but you need to merge increments:

```csharp
// appsettings.json:  "Features": { "EnableTaskSharing": false }
public sealed class FeatureOptions
{
    public bool EnableTaskSharing { get; init; }
}

// In the composition root:
builder.Services.Configure<FeatureOptions>(builder.Configuration.GetSection("Features"));

// At the call site:
if (_features.Value.EnableTaskSharing)
{
    // New sharing flow
}
```

This lets you merge small increments to the main branch without exposing incomplete work. For Avalonia/MAUI apps, the same pattern works with `IOptions<FeatureOptions>` injected into view models.

### Rule 4: Safe Defaults

New code should default to safe, conservative behavior:

```csharp
// Safe: opt-in, nullable input, explicit default
public sealed record TaskInput(string Title, string? Description = null);
public sealed record TaskOptions(bool Notify = false);

public Task<TaskId> CreateTaskAsync(
    TaskInput input,
    TaskOptions? options = null,
    CancellationToken cancellationToken = default)
{
    options ??= new TaskOptions();
    // ...
}
```

Nullable reference types enabled (`<Nullable>enable</Nullable>`) and explicit defaults keep safe behavior visible at the call site.

### Rule 5: Rollback-Friendly

Each increment should be independently revertable:

- Additive changes (new files, new methods) are easy to revert
- Modifications to existing code should be minimal and focused
- EF Core migrations should have a matching `Down` method (generated by `dotnet ef migrations add`); never hand-edit a migration after it has been applied to a shared environment
- Avoid deleting something in one commit and replacing it in the same commit — separate them

## Working with Agents

When directing an agent to implement incrementally:

```
"Let's implement Task 3 from the plan.

Start with just the EF Core entity + migration (run `dotnet ef migrations add`).
Don't touch the UI yet — we'll do that in the next increment.

After implementing, run `dotnet test` and `dotnet build -warnaserror` to verify
nothing is broken."
```

Be explicit about what's in scope and what's NOT in scope for each increment.

## Increment Checklist

After each increment, verify:

- [ ] The change does one thing and does it completely
- [ ] All existing tests still pass (`dotnet test`)
- [ ] The solution builds with warnings-as-errors (`dotnet build -warnaserror`)
- [ ] Formatting is clean (`dotnet format --verify-no-changes`)
- [ ] The new functionality works as expected
- [ ] The change is committed with a descriptive message

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll test it all at the end" | Bugs compound. A bug in Slice 1 makes Slices 2-5 wrong. Test each slice. |
| "It's faster to do it all at once" | It *feels* faster until something breaks and you can't find which of 500 changed lines caused it. |
| "These changes are too small to commit separately" | Small commits are free. Large commits hide bugs and make rollbacks painful. |
| "I'll add the feature flag later" | If the feature isn't complete, it shouldn't be user-visible. Add the flag now. |
| "This refactor is small enough to include" | Refactors mixed with features make both harder to review and debug. Separate them. |

## Red Flags

- More than 100 lines of code written without running `dotnet test`
- Multiple unrelated changes in a single increment
- "Let me just quickly add this too" scope expansion
- Skipping the test/verify step to move faster
- Build or tests broken between increments
- Large uncommitted changes accumulating
- Building abstractions before the third use case demands it
- Touching files outside the task scope "while I'm here"
- Creating new utility projects for one-time operations
- Editing an already-applied EF Core migration by hand

## Verification

After completing all increments for a task:

- [ ] Each increment was individually tested and committed
- [ ] The full test suite passes (`dotnet test`)
- [ ] The solution builds clean (`dotnet build -warnaserror`)
- [ ] The feature works end-to-end as specified
- [ ] No uncommitted changes remain

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/incremental-implementation/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - Vertical/contract-first/risk-first slice examples retargeted: EF Core entities + migrations, SignalR hub reconnection, `MyApp.Contracts` + Swashbuckle as the contract surface, `WebApplicationFactory` for integration tests
  - Simplicity-check examples swapped to .NET scenarios (generic `IEventBus<T>`, abstract factory for ViewModels, Avalonia forms)
  - Scope-discipline examples mention `using` directives, primary constructors, and collection expressions instead of JS/TS imports and modernization
  - Feature-flag example rewritten as `IOptions<FeatureOptions>` + `appsettings.json` (works identically in ASP.NET Core, Avalonia, and MAUI via `Microsoft.Extensions.Options`)
  - Safe-defaults example rewritten as a C# record + `CancellationToken` parameter with `Nullable` enabled
  - Rollback-Friendly section: database-migration guidance retargeted to EF Core `dotnet ef migrations add` + `Down` method, with the explicit rule not to hand-edit already-applied migrations
  - Agent-direction example uses `dotnet ef migrations add`, `dotnet test`, `dotnet build -warnaserror`
  - Increment Checklist replaces `npm test` / `npm run build` / `npx tsc --noEmit` / `npm run lint` with `dotnet test` / `dotnet build -warnaserror` / `dotnet format --verify-no-changes` (type check is subsumed by `dotnet build`)
  - Red-flag list adds "editing an already-applied EF Core migration by hand"
  - All structural sections, rationalizations, and rule ordering preserved from upstream verbatim
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
