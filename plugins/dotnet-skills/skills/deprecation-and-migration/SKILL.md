---
name: deprecation-and-migration
description: Manages deprecation and migration for .NET/C# systems — removing NuGet packages, retiring controllers/endpoints, sunsetting features, migrating EF Core schemas. Use when removing old code, migrating users from one implementation to another, or deciding whether to maintain or sunset existing code.
version: 0.3.0
source: vendor/agent-skills/skills/deprecation-and-migration/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Deprecation and Migration

## Overview

Code is a liability, not an asset. Every line of code has ongoing maintenance cost — bugs to fix, dependencies to update, security patches to apply, and new engineers to onboard. Deprecation is the discipline of removing code that no longer earns its keep, and migration is the process of moving users safely from the old to the new.

Most engineering organizations are good at building things. Few are good at removing them. This skill addresses that gap.

## When to Use

- Replacing an old system, API, or NuGet package with a new one
- Sunsetting a feature that's no longer needed
- Consolidating duplicate implementations (two services doing the same thing, two `DbContext`s, two controllers)
- Removing dead code that nobody owns but everybody depends on
- Planning the lifecycle of a new system (deprecation planning starts at design time)
- Deciding whether to maintain a legacy project in the solution or invest in migration

## Core Principles

### Code Is a Liability

Every line of code has ongoing cost: it needs tests, documentation, security patches, dependency updates, and mental overhead for anyone working nearby. The value of code is the functionality it provides, not the code itself. When the same functionality can be provided with less code, less complexity, or better abstractions — the old code should go.

### Hyrum's Law Makes Removal Hard

With enough users, every observable behavior becomes depended on — including bugs, timing quirks, and undocumented side effects. This is why deprecation requires active migration, not just announcement. Users can't "just switch" when they depend on behaviors the replacement doesn't replicate. For public NuGet packages and HTTP APIs this applies doubly — semantic versioning signals intent, but downstream callers bind to *observed* behavior regardless.

### Deprecation Planning Starts at Design Time

When building something new, ask: "How would we remove this in 3 years?" Systems designed with clean interfaces, feature flags, and minimal surface area are easier to deprecate than systems that leak implementation details everywhere. Mark internal types `internal` rather than `public` until a consumer outside the assembly actually needs them.

## The Deprecation Decision

Before deprecating anything, answer these questions:

```
1. Does this system still provide unique value?
   → If yes, maintain it. If no, proceed.

2. How many users/consumers depend on it?
   → Quantify the migration scope. For a public NuGet package, check NuGet download stats.
     For an internal API, check telemetry, reverse-proxy logs, or Application Insights.

3. Does a replacement exist?
   → If no, build the replacement first. Don't deprecate without an alternative.

4. What's the migration cost for each consumer?
   → If trivially automated (a Roslyn analyzer code fix, a sed pass), do it.
     If manual and high-effort, weigh against maintenance cost.

5. What's the ongoing maintenance cost of NOT deprecating?
   → Security risk (e.g. targeting an unsupported .NET version),
     engineer time, opportunity cost of complexity.
```

## Compulsory vs Advisory Deprecation

| Type | When to Use | Mechanism |
|------|-------------|-----------|
| **Advisory** | Migration is optional, old system is stable | `[Obsolete("Message", error: false)]`, documentation, nudges. Users migrate on their own timeline. |
| **Compulsory** | Old system has security issues, blocks progress (e.g. pins you to EOL .NET), or maintenance cost is unsustainable | `[Obsolete("Message", error: true)]`, hard deadline. Old system will be removed by date X. Provide migration tooling. |

**Default to advisory.** Use compulsory only when the maintenance cost or risk justifies forcing migration. Compulsory deprecation requires providing migration tooling, documentation, and support — you can't just announce a deadline.

## The Migration Process

### Step 1: Build the Replacement

Don't deprecate without a working alternative. The replacement must:

- Cover all critical use cases of the old system
- Have documentation and migration guides
- Be proven in production (not just "theoretically better")
- For NuGet packages: publish the replacement to the feed before marking the old one deprecated

### Step 2: Announce and Document

```markdown
## Deprecation Notice: MyApp.Legacy.TaskService

**Status:** Deprecated as of 2025-03-01
**Replacement:** MyApp.Core.ITaskService (see migration guide below)
**Removal date:** Advisory — no hard deadline yet (will revisit 2025-09-01)
**Reason:** MyApp.Legacy.TaskService uses a synchronous contract that
            blocks threads under load and lacks CancellationToken support.
            MyApp.Core.ITaskService is fully async with cancellation.

### Migration Guide
1. Replace `using MyApp.Legacy.Tasks;` with `using MyApp.Core.Tasks;`
2. Replace method calls:
   - `taskService.GetTask(id)` → `await taskService.GetTaskAsync(id, cancellationToken)`
3. Update DI registration:
   `services.AddScoped<ITaskService, LegacyTaskService>()`
   → `services.AddScoped<ITaskService, TaskService>()`
4. Run the migration analyzer we shipped: `dotnet build` will surface
   `MYAPP0042` diagnostics at every remaining call site; each has a code fix.
```

For ASP.NET Core HTTP APIs, pair the notice with a `Deprecation` and `Sunset` HTTP header on the old endpoint and an ADR describing the plan.

### Step 3: Migrate Incrementally

Migrate consumers one at a time, not all at once. For each consumer:

```
1. Identify all touchpoints with the deprecated system
   (grep for the namespace/type, check `dotnet list reference`)
2. Update to use the replacement
3. Verify behavior matches (xUnit/MSTest tests, integration checks via WebApplicationFactory)
4. Remove references to the old system
5. Confirm no regressions (`dotnet test`, manual smoke)
```

**The Churn Rule:** If you own the infrastructure being deprecated, you are responsible for migrating your users — or providing backward-compatible updates that require no migration. Don't announce deprecation and leave users to figure it out. For a shared solution, that means you migrate the consuming projects; for a NuGet package, that means you publish a compatible major with a clear `UPGRADE.md`.

### Step 4: Remove the Old System

Only after all consumers have migrated:

```
1. Verify zero active usage (Application Insights, structured logs, dependency analysis,
   `grep -r "LegacyTaskService" src/`)
2. Remove the code and the .csproj/project reference
3. Remove associated tests, documentation, and configuration
4. Remove the [Obsolete] attributes and deprecation notices
5. Unlist the old NuGet package version if applicable (don't delete — historical reproducibility)
6. Celebrate — removing code is an achievement
```

## Migration Patterns

### Strangler Pattern

Run old and new systems in parallel. Route traffic incrementally from old to new. When the old system handles 0% of traffic, remove it.

```
Phase 1: New system handles 0%, old handles 100%
Phase 2: New system handles 10% (canary, gated by IOptions flag or feature-flag provider)
Phase 3: New system handles 50%
Phase 4: New system handles 100%, old system idle
Phase 5: Remove old system
```

In ASP.NET Core the canary gate is often a middleware checking a header, user claim, or feature flag — the rest of the pipeline is unchanged.

### Adapter Pattern

Create an adapter that translates calls from the old interface to the new implementation. Consumers keep using the old interface while you migrate the backend:

```csharp
// Adapter: old interface, new implementation
public sealed class LegacyTaskServiceAdapter : IOldTaskApi
{
    private readonly ITaskService _newService;

    public LegacyTaskServiceAdapter(ITaskService newService)
    {
        _newService = newService;
    }

    // Old synchronous method signature, delegates to the new async one.
    //
    // DANGER: .GetAwaiter().GetResult() blocks the calling thread until the Task
    //   completes. In hosts that capture a SynchronizationContext — WPF, WinForms,
    //   .NET MAUI UI thread, Avalonia dispatcher, older ASP.NET-on-.NET-Framework —
    //   this DEADLOCKS if the inner Task tries to resume on that same captured
    //   context (the thread is blocked waiting, the continuation is waiting for
    //   the thread). Symptoms: the UI freezes and never recovers.
    //
    // This adapter is safe ONLY because:
    //   (a) it is registered in the composition root of a console-style worker
    //       or ASP.NET Core host (no captured SynchronizationContext), AND
    //   (b) the inner service intentionally doesn't .ConfigureAwait(false), AND
    //   (c) its whole purpose is to bridge legacy sync callers to the new async
    //       API — new callers should use ITaskService directly.
    //
    // Do not cargo-cult this pattern into WPF / WinForms / MAUI / Avalonia callers.
    // If an UI-thread caller needs to call async code from a sync signature, the
    // only correct options are: (1) make the signature async, (2) kick the work
    // onto the thread pool via Task.Run and show a busy state, or (3) make the
    // inner code ConfigureAwait(false) end-to-end and accept the deadlock risk
    // with eyes open.
    public OldTask GetTask(int id)
    {
        var task = _newService.GetTaskAsync(id.ToString(), CancellationToken.None)
            .GetAwaiter().GetResult();
        return ToOldFormat(task);
    }

    private static OldTask ToOldFormat(Task task) => new(/* ... */);
}
```

`.GetAwaiter().GetResult()` is a red flag in most code. It is acceptable **only** inside an adapter whose explicit purpose is to bridge a sync-to-async transition **and** whose host is proven not to capture a `SynchronizationContext`. Document both conditions in the code — a future contributor reading this class in isolation will not know either one is true. Never copy this pattern into code that might run on a UI thread without first making the inner chain `ConfigureAwait(false)`-clean end to end.

### Feature Flag Migration

Use feature flags to switch consumers from old to new system one at a time:

```csharp
public sealed class TaskServiceFactory
{
    private readonly IOptionsMonitor<FeatureOptions> _features;
    private readonly IServiceProvider _services;

    public TaskServiceFactory(IOptionsMonitor<FeatureOptions> features, IServiceProvider services)
    {
        _features = features;
        _services = services;
    }

    public ITaskService For(string userId)
    {
        return _features.CurrentValue.NewTaskService
            ? _services.GetRequiredService<TaskService>()
            : _services.GetRequiredService<LegacyTaskService>();
    }
}
```

For EF Core schema migrations that can't be rolled out in one shot, the same pattern applies: dual-write to both old and new columns behind a flag, backfill, then flip reads.

## Zombie Code

Zombie code is code that nobody owns but everybody depends on. It's not actively maintained, has no clear owner, and accumulates security vulnerabilities and compatibility issues. Signs:

- No commits in 6+ months but active consumers exist
- No assigned maintainer or team
- Failing tests that nobody fixes (or `[Fact(Skip = "…")]` that's been there for a year)
- NuGet dependencies with known vulnerabilities that nobody updates (`dotnet list package --vulnerable` shows criticals)
- Documentation that references systems that no longer exist
- A project still targeting `net6.0` (or older) after the framework reached EOL

**Response:** Either assign an owner and maintain it properly, or deprecate it with a concrete migration plan. Zombie code cannot stay in limbo — it either gets investment or removal.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It still works, why remove it?" | Working code that nobody maintains accumulates security debt and complexity. Maintenance cost grows silently — and an EOL `TargetFramework` is a compliance risk. |
| "Someone might need it later" | If it's needed later, it can be rebuilt. Keeping unused code "just in case" costs more than rebuilding. Git history preserves the code anyway. |
| "The migration is too expensive" | Compare migration cost to ongoing maintenance cost over 2-3 years. Migration is usually cheaper long-term. |
| "We'll deprecate it after we finish the new system" | Deprecation planning starts at design time. By the time the new system is done, you'll have new priorities. Plan now. Add the `[Obsolete]` attribute the day the replacement ships. |
| "Users will migrate on their own" | They won't. Provide tooling (a Roslyn analyzer code fix, a migration script, an `UPGRADE.md`) — or do the migration yourself (the Churn Rule). |
| "We can maintain both systems indefinitely" | Two systems doing the same thing is double the maintenance, testing, documentation, and onboarding cost. |

## Red Flags

- Deprecated systems with no replacement available
- Deprecation announcements with no migration tooling or documentation
- "Soft" deprecation that's been advisory for years with no progress
- Zombie code with no owner and active consumers
- New features added to a deprecated system (invest in the replacement instead)
- Deprecation without measuring current usage (no Application Insights query, no grep of dependent solutions)
- Removing code without verifying zero active consumers
- `[Obsolete]` attributes without a `UrlFormat` or message pointing at the migration guide

## Verification

After completing a deprecation:

- [ ] Replacement is production-proven and covers all critical use cases
- [ ] Migration guide exists with concrete steps and examples
- [ ] All active consumers have been migrated (verified by telemetry, logs, or `grep -r` against internal solutions)
- [ ] Old code, tests, documentation, project references, and DI registrations are fully removed
- [ ] No `[Obsolete]` attributes or deprecation notices remain in source
- [ ] Deprecated NuGet package versions are unlisted (not deleted)
- [ ] The removed code left no orphaned `appsettings` keys or environment variables

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/deprecation-and-migration/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - "When to Use" mentions NuGet packages, controllers/endpoints, duplicate `DbContext`s
  - Hyrum's Law paragraph adds the NuGet + HTTP API angle (semantic versioning vs observed behaviour)
  - Design-time guidance adds `internal` vs `public` type visibility
  - "The Deprecation Decision" Q&A adds NuGet download stats, Application Insights, and Roslyn analyzer code-fix automation as usage/migration-cost signals
  - Compulsory-vs-advisory table uses `[Obsolete]` attributes (`error: false` vs `error: true`) as the mechanism
  - "Announce and Document" example rewritten for a .NET type (`MyApp.Legacy.TaskService` → `MyApp.Core.ITaskService`), migration guide uses `using` directives, DI registration, a shipped analyzer diagnostic (`MYAPP0042`); mentions `Deprecation`/`Sunset` HTTP headers for HTTP APIs
  - "Migrate Incrementally" step 1 names `grep`, `dotnet list reference`; step 3 names xUnit/MSTest + WebApplicationFactory
  - Churn Rule expanded to NuGet packages (publish a compatible major with `UPGRADE.md`)
  - Removal step adds `dotnet list reference` sweep and NuGet unlist (not delete) practice
  - Strangler canary example references `IOptions` and ASP.NET Core middleware
  - Adapter example fully rewritten as a C# class with `IOptionsMonitor` and a documented `GetAwaiter().GetResult()` bridging comment
  - Feature-flag example uses `IOptionsMonitor<FeatureOptions>` + `IServiceProvider` factory and adds the EF Core dual-write pattern behind a flag
  - Zombie-code signals include `[Fact(Skip = "…")]`, `dotnet list package --vulnerable`, EOL `TargetFramework`
  - Rationalizations table mentions `TargetFramework` compliance risk, Roslyn analyzer code fixes, and git history preserving removed code
  - Red-flag list adds `[Obsolete]` attributes without `UrlFormat` or migration-guide message
  - Verification checklist adds NuGet unlist step and orphaned-config cleanup
  - Preserved verbatim: Code Is a Liability framing, four-step migration process, strangler phase diagram, rationalizations table frame, "removing code is an achievement" emphasis
- **Downstream patches** (applied after the initial sync; not tracked against upstream):
  - **2026-04-19** (plugin v1.0.4) — Strengthened the warning around the Adapter Pattern's `.GetAwaiter().GetResult()` example. Inline comment now spells out the `SynchronizationContext` deadlock mechanism by name (WPF / WinForms / MAUI / Avalonia dispatcher / older ASP.NET-on-.NET-Framework), lists the three conditions that make this specific adapter safe, and enumerates the three correct alternatives for UI-thread callers (make signature async, `Task.Run` with busy state, or `ConfigureAwait(false)` end-to-end). Prevents agents from cargo-culting the pattern into deadlock-prone UI code.
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
