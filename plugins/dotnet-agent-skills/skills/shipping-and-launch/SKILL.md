---
name: shipping-and-launch
description: Prepares production launches for .NET/C# systems — pre-launch checklist with `dotnet test` + `dotnet list package --vulnerable`, feature flags via `IOptions<T>`, staged rollout with Application Insights / OpenTelemetry monitoring, EF Core migration rollback, `dotnet ef database update` to previous migration. Use when deploying to production, preparing a release, setting up monitoring, planning a staged rollout, or needing a rollback strategy.
version: 0.3.0
source: vendor/agent-skills/skills/shipping-and-launch/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Shipping and Launch

## Overview

Ship with confidence. The goal is not just to deploy — it's to deploy safely, with monitoring in place, a rollback plan ready, and a clear understanding of what success looks like. Every launch should be reversible, observable, and incremental.

## When to Use

- Deploying a feature to production for the first time
- Releasing a significant change to users (ASP.NET Core service update, Blazor app revision, Avalonia/MAUI desktop release)
- Running an EF Core migration against a production database
- Publishing a new NuGet package version
- Opening a beta or early access program
- Any deployment that carries risk (all of them)

## The Pre-Launch Checklist

### Code Quality

- [ ] All tests pass (`dotnet test` unit + integration, plus E2E if present)
- [ ] `dotnet build -warnaserror` is clean (no analyzer diagnostics suppressed by accident)
- [ ] `dotnet format --verify-no-changes` is clean
- [ ] Code reviewed and approved
- [ ] No TODO comments that should be resolved before launch
- [ ] No `Debug.WriteLine` or stray `Console.WriteLine` debugging statements in production code paths (use `ILogger<T>` at the correct level)
- [ ] No `[Fact(Skip = "…")]` on tests that guard the behaviour you're shipping
- [ ] Error handling covers expected failure modes; `OperationCanceledException` is not swallowed

### Security

- [ ] No secrets in code, `appsettings.json`, or git history
- [ ] `dotnet list package --vulnerable --include-transitive` shows no Critical or High vulnerabilities (or documented allowlist entries with review dates)
- [ ] Input validation on all user-facing endpoints (FluentValidation / DataAnnotations / MediatR pipeline)
- [ ] `[Authorize]` / `RequireAuthorization()` on every endpoint except explicitly-public ones
- [ ] Security headers configured (CSP, HSTS, `X-Content-Type-Options`, `X-Frame-Options`)
- [ ] Rate limiting on authentication endpoints (`AddFixedWindowLimiter`)
- [ ] CORS configured to specific origins (not `AllowAnyOrigin()` with credentials)
- [ ] ASP.NET Core Data Protection key ring is persisted and shared across instances (Azure Key Vault, Redis, or file share)

### Performance

- [ ] Async all the way down — no `.Result` / `.Wait()` / `.GetAwaiter().GetResult()` on hot paths
- [ ] No N+1 EF Core queries (use `Include` / `AsSplitQuery` / `Select` projections appropriately)
- [ ] EF Core queries have `AsNoTracking()` on read-only paths
- [ ] Database indexes exist for every hot query path (check the execution plan for seeks vs scans)
- [ ] Caching configured where appropriate (`IMemoryCache`, `IDistributedCache` with Redis, output caching for ASP.NET Core)
- [ ] BenchmarkDotNet baseline captured for any hot path that's changed meaningfully
- [ ] For Blazor: bundle size within budget (`dotnet publish` output), Core Web Vitals within "Good" thresholds
- [ ] For Avalonia/MAUI: cold-start time measured and within target

### Accessibility

- [ ] Keyboard navigation works for all interactive elements (Tab order makes sense)
- [ ] Screen reader can convey page/window content and structure (for Blazor: semantic HTML; for Avalonia: `AutomationProperties`; for MAUI: `SemanticProperties`)
- [ ] Color contrast meets WCAG 2.1 AA (4.5:1 for text)
- [ ] Focus management correct for modals, dialogs, and dynamic content
- [ ] Error messages are descriptive and associated with form fields
- [ ] No accessibility warnings in `axe-core` (Blazor) or Accessibility Insights (Windows / Avalonia)

### Infrastructure

- [ ] Environment configuration set in production (via env vars, Azure App Configuration, Key Vault)
- [ ] EF Core migrations applied (or ready to apply via `dotnet ef database update`, or via a migration bundle if you don't run EF tools in production)
- [ ] DNS and SSL/TLS configured (HSTS preloaded if applicable)
- [ ] CDN configured for static assets (for Blazor WebAssembly: the `_framework/` folder)
- [ ] `ILogger` output flows to the aggregation target (Serilog sink, `AddApplicationInsightsTelemetry`, OpenTelemetry exporter)
- [ ] Health check endpoint exists and responds (`AddHealthChecks()`, `/health` and `/health/ready`)
- [ ] `global.json` matches the SDK installed on the build/runtime environment

### Documentation

- [ ] README updated with any new setup requirements
- [ ] OpenAPI / XML doc comments current
- [ ] ADRs written for any architectural decisions (`docs/adr/`)
- [ ] CHANGELOG.md updated (especially for NuGet-package releases)
- [ ] User-facing documentation updated (if applicable)

## Feature Flag Strategy

Ship behind feature flags to decouple deployment from release. For .NET, the standard patterns are `IOptions<FeatureOptions>` backed by configuration, or `Microsoft.FeatureManagement`:

```csharp
// Program.cs — bind feature flags from appsettings / Azure App Configuration
builder.Services
    .AddOptions<FeatureOptions>()
    .Bind(builder.Configuration.GetSection("Features"))
    .ValidateDataAnnotations()
    .ValidateOnStart();

// Or, for runtime toggling without a restart, use Microsoft.FeatureManagement
builder.Services.AddFeatureManagement();
// Then inject IFeatureManager and call IsEnabledAsync("TaskSharing")

// Usage in a Blazor component / Razor page / endpoint
@inject IOptionsMonitor<FeatureOptions> Features

@if (Features.CurrentValue.EnableTaskSharing)
{
    <TaskSharingPanel Task="task" />
}
```

**Feature flag lifecycle:**

```
1. DEPLOY with flag OFF     → Code is in production but inactive
2. ENABLE for team/beta     → Internal testing in production environment
3. GRADUAL ROLLOUT          → 5% → 25% → 50% → 100% of users (Azure App Configuration feature filters support percentile + targeting)
4. MONITOR at each stage    → Watch error rates, latency, dependent business metrics
5. CLEAN UP                 → Remove flag and dead code path after full rollout
```

**Rules:**
- Every feature flag has an owner and an expiration date
- Clean up flags within 2 weeks of full rollout (enforce via an analyzer or a CI grep)
- Don't nest feature flags (creates exponential combinations)
- Test both flag states (on and off) in CI — parameterize the relevant integration tests

## Staged Rollout

### The Rollout Sequence

```
1. DEPLOY to staging
   └── dotnet test in staging (integration tests against real dependencies)
   └── Manual smoke test of critical flows
   └── EF Core migrations applied; verify schema shape matches expectation

2. DEPLOY to production (feature flag OFF)
   └── Verify deployment succeeded (/health returns Healthy)
   └── Check Application Insights / Serilog sink (no new error types)
   └── Run EF Core migrations with a separate approval gate if they're destructive

3. ENABLE for team (flag ON for internal users via user-targeting filter)
   └── Team uses the feature in production
   └── 24-hour monitoring window

4. CANARY rollout (flag ON for 5% of users)
   └── Monitor error rates, latency, user behavior
   └── Compare metrics: canary vs. baseline
   └── 24-48 hour monitoring window
   └── Advance only if all thresholds pass (see table below)

5. GRADUAL increase (25% → 50% → 100%)
   └── Same monitoring at each step
   └── Ability to roll back to previous percentage at any point (flip the flag, not the deploy)

6. FULL rollout (flag ON for all users)
   └── Monitor for 1 week
   └── Clean up feature flag + dead code path
```

### Rollout Decision Thresholds

Use these thresholds to decide whether to advance, hold, or roll back at each stage:

| Metric | Advance (green) | Hold and investigate (yellow) | Roll back (red) |
|--------|-----------------|-------------------------------|-----------------|
| HTTP 5xx / exceptions/min | Within 10% of baseline | 10–100% above baseline | >2× baseline |
| p95 request latency | Within 20% of baseline | 20–50% above baseline | >50% above baseline |
| Gen2 GC collections / min | No change | Modest increase, no memory growth | Sustained growth or memory leak pattern |
| Thread-pool queue length | Flat | Spikes on canary only | Sustained high on canary |
| Business metrics | Neutral or positive | Decline <5% (may be noise) | Decline >5% |

### When to Roll Back

Roll back immediately if:
- Error rate increases by more than 2× baseline
- p95 latency increases by more than 50%
- User-reported issues spike
- Data integrity issues detected (EF Core migration introduced a regression, dual-write logic diverged)
- Security vulnerability discovered
- Sustained memory growth that doesn't stabilize (likely a leak introduced by the change)

## Monitoring and Observability

### What to Monitor

```
Application metrics:
├── Request rate / error rate (total and by endpoint)
├── Response time (p50, p95, p99)
├── Exception counts by type (Application Insights "failures" blade)
├── Active users / concurrent connections
├── Dependency call rate + latency (SQL, HTTP, Service Bus)
└── Key business metrics (conversion, engagement)

Runtime / host metrics:
├── GC collections by generation (dotnet-counters: System.Runtime.gen-0-gc-count, gen-2-gc-count)
├── CPU and working set
├── Thread-pool queue length + completed work items
├── HTTP connection counts (Kestrel request-queue-length)
├── EF Core DbContext pool usage
└── Container / pod resource utilization (CPU throttling is a silent killer)

Client metrics (Blazor / Web):
├── Core Web Vitals (LCP, INP, CLS)
├── JavaScript / WebAssembly errors
├── SignalR connection churn (if applicable)
└── Page / route load time

Desktop metrics (Avalonia / MAUI):
├── Cold-start time
├── UI frame rate / freeze duration (via ETW on Windows)
├── Memory growth over a session
└── Exception rate from the `AppDomain.CurrentDomain.UnhandledException` sink
```

### Error Reporting

Use `ILogger<T>` with structured properties and plug in Application Insights, Seq, Elastic, or an OpenTelemetry exporter. ASP.NET Core's built-in exception handler keeps internal details out of the response:

```csharp
// Program.cs
builder.Services.AddOpenTelemetry()
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddRuntimeInstrumentation()
        .AddOtlpExporter());

// Production error handling — never leaks internals to the client
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

// Per-request logging with scopes
app.Use(async (context, next) =>
{
    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
    using var scope = logger.BeginScope(new Dictionary<string, object?>
    {
        ["TraceId"] = context.TraceIdentifier,
        ["UserId"] = context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value,
        ["Path"] = context.Request.Path.Value,
    });
    await next();
});
```

For Blazor Server / WebAssembly and Avalonia/MAUI, wire the UI-framework-specific unhandled exception hooks:

```csharp
// Avalonia (Program.cs)
AppDomain.CurrentDomain.UnhandledException += (_, e) =>
    Log.Error(e.ExceptionObject as Exception, "Unhandled exception");
TaskScheduler.UnobservedTaskException += (_, e) =>
{
    Log.Error(e.Exception, "Unobserved task exception");
    e.SetObserved(); // prevent process termination on unobserved Task exceptions (.NET 4.5+ default is to ignore)
};

// Blazor — add a top-level ErrorBoundary component
```

### Post-Launch Verification

In the first hour after launch:

```
1. /health returns Healthy (and /health/ready returns Ready)
2. Check error dashboard (Application Insights failures, Serilog dashboard) — no new exception types
3. Check latency dashboard (no regression on p95)
4. Test the critical user flow manually against production
5. Verify structured logs are flowing and include the expected scope properties
6. Confirm rollback mechanism works (dry run: can we flip the flag? Can we roll forward to a previous migration?)
```

## Rollback Strategy

Every deployment needs a rollback plan before it happens:

```markdown
## Rollback Plan for [Feature/Release]

### Trigger Conditions
- HTTP 5xx > 2× baseline for 5 consecutive minutes
- p95 latency > [X] ms for 5 consecutive minutes
- User reports of [specific issue]
- Data integrity check [name] fails

### Rollback Steps
1. Disable feature flag (if applicable) — via Azure App Configuration / feature management UI
   OR
1. Deploy previous image / swap deployment slot (Azure App Service slot swap is ~30s)
2. Verify rollback: /health Healthy, no new exceptions
3. Communicate: notify team + update status page

### Database Considerations
- Migration [20260419_AddTaskSharing]:
  - Rollback path: `dotnet ef database update <previous-migration-name> --project src/MyApp.Infrastructure --startup-project src/MyApp`
  - Destructive? [yes/no]  → If yes, the forward migration must be dual-write-compatible with the previous version (see `deprecation-and-migration` strangler pattern)
- Data inserted by new feature: [preserved / cleaned up by a follow-up migration / scrubbed manually]

### Time to Rollback
- Feature flag flip:           < 1 minute
- Deployment slot swap:         < 1 minute (Azure App Service)
- Container image rollback:     < 5 minutes (ACR + orchestrator)
- EF Core migration rollback:   < 15 minutes for reversible migrations; longer for destructive ones (prefer expand-contract pattern so you rarely need to)
```

**Expand-contract for schema changes:** never deploy a change that removes or renames a column in the same release as the code that uses the new shape. Expand first (add the new column, dual-write), release, then contract (drop the old column) in a later release.

## See Also

- Upstream pre-launch references (generic) at the pinned commit: [security-checklist](https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/references/security-checklist.md), [performance-checklist](https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/references/performance-checklist.md), [accessibility-checklist](https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/references/accessibility-checklist.md)
- ASP.NET Core production deployment: https://learn.microsoft.com/aspnet/core/host-and-deploy/
- EF Core migration bundles: https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying#bundles
- Azure App Service slot swap: https://learn.microsoft.com/azure/app-service/deploy-staging-slots

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It works in staging, it'll work in production" | Production has different data, traffic patterns, and edge cases. Monitor after deploy. |
| "We don't need feature flags for this" | Every feature benefits from a kill switch. Even "simple" changes can break things. `IOptions<T>` bound to config is effectively free. |
| "Monitoring is overhead" | Not having monitoring means you discover problems from user complaints instead of dashboards. `AddApplicationInsightsTelemetry()` + `AddOpenTelemetry()` takes minutes to wire up. |
| "We'll add monitoring later" | Add it before launch. You can't debug what you can't see. |
| "Rolling back is admitting failure" | Rolling back is responsible engineering. Shipping a broken feature is the failure. |
| "We don't need to rehearse rollback" | An untested rollback is a plan, not a capability. Dry-run it at least once per release train. |

## Red Flags

- Deploying without a rollback plan
- No structured logging, error reporting, or metrics in production
- Big-bang releases (everything at once, no staging, no canary)
- Feature flags with no expiration or owner
- No one monitoring the deploy for the first hour
- Production configuration (connection strings, API keys) set by memory or ad-hoc portal edits instead of IaC / configuration-as-code
- Destructive EF Core migrations deployed in the same release as the code that requires the new schema (violates expand-contract)
- "It's Friday afternoon, let's ship it"
- No `/health` / `/health/ready` endpoints

## Verification

Before deploying:

- [ ] Pre-launch checklist completed (all sections green)
- [ ] Feature flag configured (if applicable), documented with owner + expiration
- [ ] Rollback plan documented (with migration rollback path for schema changes)
- [ ] Monitoring dashboards set up (Application Insights / Serilog / OpenTelemetry)
- [ ] Team notified of deployment (and who is on-call)

After deploying:

- [ ] `/health` returns Healthy and `/health/ready` returns Ready
- [ ] Error rate is normal
- [ ] Latency is normal (p95 within 20% of baseline)
- [ ] GC / thread-pool metrics are stable (no sustained growth)
- [ ] Critical user flow works
- [ ] Logs are flowing with expected scope properties
- [ ] Rollback path tested or verified ready (flag flip or slot swap or migration-down dry-run)

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/shipping-and-launch/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - "When to Use" adds NuGet package releases and Avalonia/MAUI desktop releases
  - Pre-launch Code Quality checklist uses `dotnet test` / `dotnet build -warnaserror` / `dotnet format --verify-no-changes`, mentions `ILogger<T>` instead of `console.log`, `[Fact(Skip = "…")]` on guarded behaviour, `OperationCanceledException` not swallowed
  - Pre-launch Security checklist uses `dotnet list package --vulnerable`, FluentValidation/DataAnnotations/MediatR, `[Authorize]`/`RequireAuthorization()`, security headers, `AddFixedWindowLimiter`, CORS restrictions, Data Protection key ring
  - Pre-launch Performance checklist adds .NET-specific items: async discipline, EF Core N+1 / `AsNoTracking` / indexes, IMemoryCache/IDistributedCache/output caching, BenchmarkDotNet baseline, Blazor bundle + Core Web Vitals, Avalonia/MAUI cold-start
  - Accessibility bullets mention Avalonia `AutomationProperties`, MAUI `SemanticProperties`, Accessibility Insights, `axe-core` for Blazor
  - Infrastructure bullets use env vars / Azure App Configuration / Key Vault, `dotnet ef database update` / migration bundles, `_framework/` CDN for Blazor WASM, Serilog / Application Insights / OpenTelemetry, `AddHealthChecks()` with `/health` + `/health/ready`, `global.json`
  - Documentation bullets mention OpenAPI + XML doc comments, `docs/adr/`, CHANGELOG for NuGet
  - Feature-flag example rewritten with `IOptions<FeatureOptions>` + `ValidateDataAnnotations()` + `ValidateOnStart()`, plus `Microsoft.FeatureManagement` + `IFeatureManager` + Azure App Configuration feature filters; usage example in Blazor/Razor with `IOptionsMonitor`
  - Rollout sequence mentions EF Core migration approval gate, user-targeting filters, "flip the flag, not the deploy" rollback
  - Rollout decision thresholds table adds .NET-specific rows: HTTP 5xx / exceptions-per-minute, Gen2 GC collections per minute, thread-pool queue length
  - Rollback trigger list adds sustained memory growth signalling a leak
  - Monitoring list rewritten: runtime metrics from `dotnet-counters` (gen-2 GC, thread-pool queue), Kestrel request-queue-length, EF Core DbContext pool; client/desktop variants
  - Error reporting example replaced Express + React ErrorBoundary with `AddOpenTelemetry()` + `UseExceptionHandler("/Error")` + `ILogger` scopes + `AppDomain.CurrentDomain.UnhandledException` / `TaskScheduler.UnobservedTaskException` for Avalonia, Blazor `ErrorBoundary` note
  - Rollback plan example rewritten: Azure App Service slot swap, container image rollback, `dotnet ef database update <previous-migration>` with expand-contract commentary
  - Added "Expand-contract for schema changes" paragraph — the most important .NET production principle not in upstream
  - "See Also" section points at Microsoft Learn docs for production deployment, migration bundles, slot swap
  - Rationalizations table retargeted (`IOptions<T>` is free, `AddApplicationInsightsTelemetry`, untested-rollback bullet)
  - Red-flag list rewritten with .NET concerns (configuration-as-code, destructive migrations in the same release, missing `/health` endpoints)
  - Verification checklist adds flag owner/expiration, GC/thread-pool stability, migration-down dry-run
  - Preserved verbatim: pre-launch section headings (Code Quality / Security / Performance / Accessibility / Infrastructure / Documentation), rollout sequence frame (1–6), threshold-table three-tier schema (green/yellow/red), post-launch-verification structure, Common Rationalizations table frame
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
