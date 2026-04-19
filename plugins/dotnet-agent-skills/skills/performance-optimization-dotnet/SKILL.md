---
name: performance-optimization-dotnet
description: Optimizes .NET/C# application performance — measure first with BenchmarkDotNet / dotnet-counters / dotnet-trace / PerfView, then fix the specific bottleneck (EF Core N+1, sync-over-async, Gen2 GC pressure, thread-pool starvation, allocation hotspots, unbounded queries, missing pagination, Kestrel misconfiguration). Use when performance requirements exist, when latency / throughput / memory regresses, or when profiling reveals a bottleneck that needs fixing.
version: 0.5.0
source: rewritten from vendor/agent-skills/skills/performance-optimization/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). This is a STRUCTURAL REWRITE — upstream targets Core Web Vitals / Lighthouse / React render optimization / `<picture>`-based image optimization. This skill retargets the same goals (measure before optimizing, fix the actual bottleneck) to the .NET stack: BenchmarkDotNet, dotnet-counters, dotnet-trace, PerfView, EF Core N+1 triage, allocation discipline, Kestrel tuning. The five-step MEASURE → IDENTIFY → FIX → VERIFY → GUARD workflow and the "measure first" principle survive verbatim; every concrete tool and anti-pattern example is replaced. See the "Source & Modifications" footer for the full delta. -->

# Performance Optimization — .NET

## Overview

Measure before optimizing. Performance work without measurement is guessing — and guessing leads to premature optimization that adds complexity without improving what matters. Profile first, identify the actual bottleneck, fix it, measure again. Optimize only what measurements prove matters.

.NET gives you two advantages no amount of guessing replaces:

- **BenchmarkDotNet** for deterministic micro-benchmarks (with statistical analysis built in — if you see a delta smaller than the tool's noise floor, it isn't a real change)
- **dotnet-counters** / **dotnet-trace** / **PerfView** for live process observation without redeploying

Use them. The rest of this skill assumes you will.

## When to Use

- Performance requirements exist in the spec (latency SLAs, throughput targets, memory budgets)
- Users or monitoring (Application Insights, Prometheus, OpenTelemetry) report slow behavior
- p95 latency, Gen2 GC rate, thread-pool queue length, or allocated-bytes-per-request regresses
- You suspect a recent change introduced a regression
- Building features that handle large datasets or high traffic

**When NOT to use:** don't optimize before you have evidence of a problem. Premature optimization adds complexity that costs more than the performance it gains. Readable code beats 3% faster code.

## .NET Performance Targets

Set targets as part of the spec, not as an afterthought. Representative targets for an ASP.NET Core service:

| Signal | Good | Needs Improvement | Poor |
|---|---|---|---|
| **p95 request latency** | ≤ 100 ms | ≤ 300 ms | > 300 ms |
| **p99 request latency** | ≤ 300 ms | ≤ 1 s | > 1 s |
| **Throughput (RPS, single instance)** | ≥ 2 000 | 500–2 000 | < 500 |
| **Allocated bytes / request** | ≤ 10 KB | ≤ 100 KB | > 100 KB |
| **Gen2 collections / minute** | 0 sustained | Occasional | Sustained |
| **Thread-pool queue length** | 0 sustained | Brief spikes | Sustained > 0 |
| **Working set (container)** | Well below limit | Approaches limit | OOM or throttling |

Desktop-specific (Avalonia, MAUI, WPF):

| Signal | Good | Needs Improvement | Poor |
|---|---|---|---|
| **Cold start (launch → first interactive frame)** | ≤ 1.5 s | ≤ 3 s | > 3 s |
| **Steady-state UI frame time** | ≤ 16.7 ms (60 fps) | ≤ 33.3 ms | > 33.3 ms |
| **Session memory growth** | Flat | Slow leak | Visible growth |

These are **defaults**; adjust to your actual product constraints and enforce with CI checks (BenchmarkDotNet gates, Application Insights alerts).

## The Optimization Workflow

```
1. MEASURE   → Establish baseline with real data
2. IDENTIFY  → Find the actual bottleneck (not assumed)
3. FIX       → Address the specific bottleneck
4. VERIFY    → Measure again, confirm improvement
5. GUARD     → Add monitoring or tests to prevent regression
```

### Step 1: Measure

Pick the tool that matches the symptom. You rarely need only one:

| Symptom | Tool | What you get |
|---|---|---|
| "Is this method allocating?" / "Which is faster, A or B?" | **BenchmarkDotNet** | Mean, allocated bytes, Gen0/1/2 collections, confidence intervals |
| "What is the live process doing right now?" | **dotnet-counters monitor -n MyApp** | Real-time GC rate, thread-pool stats, exceptions/sec, custom counters |
| "Where is time going?" (CPU profile) | **dotnet-trace collect --profile cpu-sampling -p <pid>** | SpeedScope / PerfView CPU-sampling profile |
| "What allocated all this memory?" (heap snapshot) | **dotnet-gcdump collect -p <pid>** | Heap dump viewable in PerfView / dotnet-gcdump analyze |
| "Deep ETW-level detail on Windows" | **PerfView** | CPU, GC, JIT, TPL, stackwalks |
| "Hot path in a library without a full trace" | **EventPipe** (via `EventListener`) | Lightweight in-process events |
| "End-to-end request shape in production" | **Application Insights** / **OpenTelemetry** | Distributed traces with dependency timings |
| "EF Core query shape" | `DbContextOptionsBuilder.LogTo(..., LogLevel.Information).EnableSensitiveDataLogging()` or **MiniProfiler** | Generated SQL, command duration |

A representative BenchmarkDotNet smoke test:

```csharp
[MemoryDiagnoser]                    // Tracks allocated bytes + GC collections
[SimpleJob(baseline: true)]           // Use multiple [SimpleJob] attributes to compare runtimes / args
public class TaskFormatBenchmarks
{
    private readonly TaskDto _task = new(/* ... */);

    [Benchmark(Baseline = true)]
    public string Interpolated() =>
        $"{_task.Title} ({_task.Status})";

    [Benchmark]
    public string Concatenated() =>
        _task.Title + " (" + _task.Status + ")";

    [Benchmark]
    public string StringBuilderBased()
    {
        var sb = new StringBuilder(_task.Title.Length + 16);
        sb.Append(_task.Title);
        sb.Append(" (");
        sb.Append(_task.Status);
        sb.Append(')');
        return sb.ToString();
    }
}
```

Run: `dotnet run -c Release --project bench/MyApp.Bench`. **Never** benchmark in Debug — the JIT is different, inlining is off, and `[Conditional("DEBUG")]` paths fire.

### Step 2: Identify the Bottleneck

Use the symptom to narrow the search:

```
What is slow?
├── Cold start
│   ├── Too many assemblies loaded? --> dotnet-trace with runtime events,
│   │   check Ready-to-Run / ReadyToRun compilation coverage
│   ├── Static initializers? --> dotnet-trace CPU sampling on first 3 seconds
│   ├── Large configuration graph? --> IOptions bindings with ValidateOnStart firing on every key
│   └── Avalonia / WPF: UI thread doing I/O? --> dotnet-trace + dispatcher profiling
├── Request latency
│   ├── Slow SQL? --> Enable EF Core query logging, capture execution plan,
│   │   check .Include() chains (cartesian explosion)
│   ├── Sync-over-async? --> Search for .Result / .Wait() / .GetAwaiter().GetResult() in the request path
│   ├── Missing AsNoTracking on read paths? --> Check DbContext tracking behavior
│   ├── Missing output caching on a stable endpoint? --> AddOutputCache() in ASP.NET Core 7+
│   └── HttpClient misuse? --> Not using IHttpClientFactory; socket exhaustion at scale
├── Throughput
│   ├── Thread-pool starvation? --> dotnet-counters: System.Runtime.threadpool-queue-length > 0 sustained
│   ├── Lock contention? --> dotnet-trace with contention events; check Parallel.ForEach over shared dict
│   └── Kestrel limits? --> Check MaxConcurrentConnections, MaxConcurrentUpgradedConnections
├── Memory growth
│   ├── Static caches? --> dotnet-gcdump, look for types with unexpected instance counts
│   ├── Event handlers not unsubscribed? --> Especially in Avalonia/WPF view-models
│   ├── Strings cached indefinitely? --> Bounded MemoryCache with size limits, not Dictionary<string, T>
│   └── IDisposable not disposed? --> Analyzer CA2000 / CA1816 off? Turn them on
└── UI frame drops (Avalonia / MAUI / WPF)
    ├── Big lists not virtualized? --> ListBox with VirtualizingStackPanel (Avalonia default)
    ├── Binding on hot path? --> Compiled bindings (x:DataType + x:CompileBindings)
    ├── Heavy work on UI thread? --> Move to Task.Run; marshal results back via Dispatcher.UIThread.InvokeAsync
    └── Excessive DynamicResource subscriptions? --> Use StaticResource where the value won't change
```

Common bottlenecks by category:

**ASP.NET Core / general server:**

| Symptom | Likely Cause | Investigation |
|---|---|---|
| Slow endpoint | EF Core N+1, missing indexes, missing `AsNoTracking`, missing pagination | Enable EF Core logging; MiniProfiler; check execution plans |
| Gen2 spikes | Large object allocations (>85 KB), long-lived caches of short-lived data | `dotnet-counters` Gen2 rate; `dotnet-gcdump` for LOH tenants |
| Thread-pool starvation | Sync-over-async, blocking I/O, too-large `Parallel.ForEach` | `dotnet-counters` threadpool-queue-length; grep for `.Result` / `.Wait()` |
| HTTP socket exhaustion | New `HttpClient` per request | Replace with `IHttpClientFactory` + typed clients |
| High CPU on startup | R2R disabled, TieredCompilation disabled, heavy reflection | `dotnet-trace` CPU sampling; check `<PublishReadyToRun>` |
| Intermittent latency | GC STW pauses, lock contention | `dotnet-counters` gc-pause-duration; PerfView contention events |

**Avalonia / MAUI / WPF:**

| Symptom | Likely Cause | Investigation |
|---|---|---|
| Slow cold start | Many assemblies, no trimming/AOT, heavy constructors | `dotnet-trace StartupPerformance`; `<PublishTrimmed>` / `<PublishAot>` where supported |
| Frame drops on scroll | No virtualization, expensive `DataTemplate`, complex `LayoutTransform` | Avalonia `RendererDiagnostics`; check `VirtualizingStackPanel` in effect |
| Growing memory during session | Event handlers on singletons; closed-over captures in bindings | `dotnet-gcdump`; search for `+=` on static events without a matching `-=` |
| UI freeze | `Task.Wait`/`.Result` from the UI thread, or large synchronous computation | Profile the dispatcher; move work to a background `Task` and `await` |

### Step 3: Fix Common Anti-Patterns

#### EF Core N+1 Query

```csharp
// BAD: N+1 — one query per order for its lines
var orders = await db.Orders.Where(o => o.CustomerId == customerId).ToListAsync();
foreach (var order in orders)
{
    order.Lines = await db.OrderLines.Where(l => l.OrderId == order.Id).ToListAsync();  // N queries
}

// GOOD: Single query with Include (watch for cartesian explosion when two .Include siblings both have many rows)
var orders = await db.Orders
    .Where(o => o.CustomerId == customerId)
    .Include(o => o.Lines)
    .ToListAsync();

// GOOD: Split query when two Include chains would Cartesian-explode
var ordersWithEverything = await db.Orders
    .Where(o => o.CustomerId == customerId)
    .Include(o => o.Lines)
    .Include(o => o.Shipments)
    .AsSplitQuery()          // Issues 1 + N queries — faster than Cartesian when both sides have many rows
    .ToListAsync();

// GOOD: Project to a DTO for read paths — fetches only the columns you need
var summaries = await db.Orders
    .Where(o => o.CustomerId == customerId)
    .Select(o => new OrderSummaryDto(o.Id, o.CreatedAt, o.Lines.Count))
    .AsNoTracking()
    .ToListAsync();
```

#### Sync-Over-Async

```csharp
// BAD: blocks a thread-pool thread; under load → thread-pool starvation
public IActionResult Get(Guid id)
{
    var order = _service.GetByIdAsync(id).Result;   // BLOCK
    return Ok(order);
}

// GOOD
public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken)
{
    var order = await _service.GetByIdAsync(id, cancellationToken);
    return Ok(order);
}
```

`.Result`, `.Wait()`, `.GetAwaiter().GetResult()` in request-handling or UI paths are a red flag. The only acceptable uses are in composition-root startup synchronization and in documented adapter shims (see `deprecation-and-migration`).

#### Unbounded Queries / Missing Pagination

```csharp
// BAD: returns everything
app.MapGet("/api/tasks", async (AppDbContext db) =>
    await db.Tasks.ToListAsync());

// GOOD: cap at the boundary, even if the client asks for more
app.MapGet("/api/tasks", async (int page, int pageSize, AppDbContext db) =>
{
    var size = Math.Clamp(pageSize, 1, 100);   // Never trust clients on page size
    var skip = Math.Max(0, page - 1) * size;

    var items = await db.Tasks
        .OrderByDescending(t => t.CreatedAt)
        .Skip(skip)
        .Take(size)
        .AsNoTracking()
        .ToListAsync();

    return Results.Ok(items);
});
```

#### Allocation Discipline in Hot Paths

```csharp
// BAD: repeated string concatenation in a loop allocates each step
string name = "";
foreach (var part in parts)
{
    name += part + " ";  // O(n^2) allocations
}

// GOOD: StringBuilder when the size is unknown
var sb = new StringBuilder(capacity: parts.Count * 8);
foreach (var part in parts)
{
    sb.Append(part);
    sb.Append(' ');
}
var name = sb.ToString();

// BETTER (when input types are known): interpolation + defined capacity
var name = string.Create(CultureInfo.InvariantCulture, stackalloc char[64],
    $"{first} {middle} {last}");

// Parsing: use Span<T> / ReadOnlySpan<char> to avoid substring allocations
ReadOnlySpan<char> input = s.AsSpan();
var commaIndex = input.IndexOf(',');
if (commaIndex < 0) return;
ReadOnlySpan<char> head = input[..commaIndex];
ReadOnlySpan<char> tail = input[(commaIndex + 1)..];

// Buffers that live beyond a stack frame: ArrayPool<T>.Shared
byte[] buffer = ArrayPool<byte>.Shared.Rent(4096);
try
{
    // use buffer
}
finally
{
    ArrayPool<byte>.Shared.Return(buffer);
}
```

Turn on `[MemoryDiagnoser]` on your BenchmarkDotNet runs so every change visibly moves the "Allocated" column. A "3% faster" change that allocates twice as many bytes is not a win.

#### `HttpClient` Misuse

```csharp
// BAD: creates a fresh socket pool every call → socket exhaustion under load
public async Task<UserDto> GetAsync(Guid id, CancellationToken cancellationToken)
{
    using var client = new HttpClient { BaseAddress = new Uri("https://api.example.com/") };
    return await client.GetFromJsonAsync<UserDto>($"/users/{id}", cancellationToken);
}

// GOOD: register once in the composition root
// Program.cs
builder.Services.AddHttpClient<IUserClient, UserClient>(c =>
    c.BaseAddress = new Uri("https://api.example.com/"));

public sealed class UserClient(HttpClient http) : IUserClient
{
    public Task<UserDto?> GetAsync(Guid id, CancellationToken cancellationToken) =>
        http.GetFromJsonAsync<UserDto>($"/users/{id}", cancellationToken);
}
```

#### Output Caching (ASP.NET Core 7+)

```csharp
// Program.cs
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(policy => policy.Expire(TimeSpan.FromSeconds(30)));
});

app.UseOutputCache();

app.MapGet("/api/catalog", async (ICatalogService svc, CancellationToken ct) =>
    await svc.ListAsync(ct))
   .CacheOutput(policy => policy.Expire(TimeSpan.FromMinutes(1)).SetVaryByQuery("category"));
```

Use output caching for endpoints whose response is safe to serve stale for a short window; use response caching + `[ResponseCache]` attributes for CDN-friendly caching.

#### Regex

```csharp
// BAD: compiled-at-runtime on every call
if (Regex.IsMatch(input, @"\b[A-Z]{2,}\b")) { … }

// GOOD (.NET 7+): source-generated regex — zero startup cost, typed
[GeneratedRegex(@"\b[A-Z]{2,}\b")]
private static partial Regex AllCapsToken();

if (AllCapsToken().IsMatch(input)) { … }
```

#### Avalonia-Specific

- Keep `VirtualizingStackPanel` as the items panel for lists of >50 items (Avalonia's `ListBox` default — don't replace with `StackPanel`)
- Turn on `x:CompileBindings="True"` with `x:DataType="..."` — makes bindings type-checked **and** faster
- Prefer `StaticResource` for values that don't change at runtime (spacing, icon geometry); reserve `DynamicResource` for theme-sensitive brushes
- Avoid deep visual trees — `DockPanel` / `Grid` usually replaces nested `StackPanel` stacks

#### Kestrel & Hosting

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxRequestBodySize = 10 * 1024 * 1024;  // 10 MB — don't let random uploads dictate memory
    options.Limits.MaxConcurrentConnections = 10_000;       // Tune to container memory
    options.AddServerHeader = false;                         // Reduce fingerprinting
});
```

Set `<ServerGarbageCollection>true</ServerGarbageCollection>` in the host's `.csproj` (on by default for ASP.NET Core, but re-check for worker services).

### Step 4: Verify

Re-run the same measurement you started with. Record the delta — specific numbers, not "feels faster":

```
BEFORE                           AFTER
p95 request latency   420 ms  →  95 ms
Allocations/request   180 KB  →  22 KB
Gen2/min              3       →  0
BenchmarkDotNet       Mean    2450 µs ± 140 µs  →  310 µs ± 18 µs
```

If the delta is inside the tool's noise floor, the change isn't real.

### Step 5: Guard

Prevent regression:

- Commit the BenchmarkDotNet project to the repo; run it in CI on tag/release with a threshold check
- Add Application Insights / OpenTelemetry alerts on the metrics you care about (p95 latency, Gen2 rate, thread-pool queue)
- Add an analyzer rule if the fix was structural (e.g. Roslyn analyzer for `.Result` in a code path that must stay async)
- Document the fix in an ADR if the reasoning was non-obvious

## Performance Budget

Set budgets and enforce them in CI:

```
p95 request latency   ≤ 100 ms        (per endpoint tag)
Allocated bytes/req   ≤ 10 KB          (measured via BenchmarkDotNet on the hot path)
Gen2/min              0 sustained      (alert fires on > 0 over 10 min)
Cold start (desktop)  ≤ 1.5 s
Startup memory        ≤ 150 MB working set
Throughput            ≥ 2 000 RPS single instance
```

A CI step for the allocation budget:

```yaml
- name: BenchmarkDotNet — hot path allocation budget
  run: dotnet run -c Release --project bench/MyApp.Bench -- --filter *HotPath* --exporters json
- name: Enforce budget
  run: pwsh scripts/check-benchmark-budget.ps1 -Path BenchmarkDotNet.Artifacts/results -MaxBytesPerOp 10240
```

The script (a few lines of PowerShell) parses the JSON and fails the build when any benchmark exceeds the budget. Tune the numbers to your actual SLAs.

## See Also

- Upstream performance-checklist reference (generic, pre-dates this adaptation): [`../../vendor/agent-skills/references/performance-checklist.md`](../../vendor/agent-skills/references/performance-checklist.md)
- [`integration-testing-dotnet`](../integration-testing-dotnet/SKILL.md) — the testing harness you'll layer performance assertions into
- [`shipping-and-launch`](../shipping-and-launch/SKILL.md) — the rollout thresholds table that consumes these metrics
- .NET performance docs: https://learn.microsoft.com/dotnet/core/diagnostics/
- BenchmarkDotNet: https://benchmarkdotnet.org/
- EF Core performance: https://learn.microsoft.com/ef/core/performance/
- Kestrel tuning: https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/options

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We'll optimize later" | Performance debt compounds. Fix obvious anti-patterns (N+1, sync-over-async, unbounded queries) now; defer micro-optimizations until profiling justifies them. |
| "It's fast on my machine" | Your machine isn't the user's. Profile on representative hardware, and in a container with the same resource limits as production. |
| "This optimization is obvious" | If you didn't measure, you don't know. Profile first. BenchmarkDotNet exists for a reason. |
| "The framework handles performance" | ASP.NET Core / EF Core / Avalonia prevent some issues but can't fix your N+1, your `.Result`, or your unbounded query. |
| "A 3% improvement is great" | Is it real, or within noise? BenchmarkDotNet's confidence intervals answer that. 3% with a ±5% CI is zero. |
| "I'll just `Task.Run` it" | `Task.Run` from an already-pool thread is free overhead (and makes it harder to debug). Use it only when you need to move CPU work off the current thread. |
| "Allocating is fine, GC handles it" | The GC handles it at the cost of pauses. Gen2 pauses block the thread-pool, which breaks throughput. Track allocations. |
| "I'll figure out why cold start is slow when we ship" | Cold start is a product decision. Measure it in CI with a dotnet-trace run on the first 3 seconds of startup. |

## Red Flags

- Optimization without before/after measurements
- `.Result` / `.Wait()` / `.GetAwaiter().GetResult()` in request-handling or UI paths
- EF Core N+1 patterns (loops that call `DbSet` inside)
- `Include` chains where both sides have many rows (cartesian explosion) without `AsSplitQuery()`
- List endpoints without pagination or without a server-enforced `PageSize` cap
- `new HttpClient()` per-request
- Benchmarks run in Debug (invalid) or missing `[MemoryDiagnoser]`
- BenchmarkDotNet results without confidence intervals (single-run numbers)
- No monitoring on p95 latency, Gen2 rate, thread-pool queue length
- Manual string concatenation in loops; missing `StringBuilder` / `Span<T>` / `ArrayPool<T>` in hot paths
- Non-virtualized lists in Avalonia / WPF / MAUI
- `Regex` with runtime-compiled patterns in hot paths on .NET 7+ (use `[GeneratedRegex]`)

## Verification

After any performance-related change:

- [ ] Before and after measurements exist (specific numbers with tool-reported variance)
- [ ] The specific bottleneck was identified from a profile, not guessed
- [ ] The fix addresses the identified bottleneck, not a symptom elsewhere
- [ ] No N+1 patterns in new data-access code; all list endpoints paginate with a `PageSize` cap
- [ ] No `.Result` / `.Wait()` introduced in request-handling or UI paths
- [ ] BenchmarkDotNet run was in Release mode with `[MemoryDiagnoser]`
- [ ] Confidence intervals in BenchmarkDotNet output show the delta is outside the noise floor
- [ ] Monitoring dashboards reflect the new baseline (p95 latency, allocation rate, GC rate)
- [ ] Existing tests still pass (`dotnet test`) — optimization didn't break behavior
- [ ] Performance budget in CI still passes

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/performance-optimization/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `rewritten`
- **Rationale**: upstream's concrete tooling is JS/web-specific (Lighthouse, web-vitals RUM library, Core Web Vitals, `<picture>` responsive images, React `useMemo`/`memo`, bundle size, webpack/Vite tree-shaking). The equivalent .NET surface is entirely different (BenchmarkDotNet, dotnet-counters, dotnet-trace, PerfView, GC generations, EF Core, Kestrel, `Span<T>`/`ArrayPool<T>`). The five-step workflow and the "measure before optimizing" principle are preserved; everything else is retargeted.
- **What changed (almost everything)**:
  - New skill name (`performance-optimization-dotnet`)
  - "Core Web Vitals Targets" table replaced with ".NET Performance Targets" — two tables (ASP.NET Core server + desktop UI) covering p95/p99 latency, throughput, allocations/request, Gen2 rate, thread-pool queue, working set, cold start, frame time, session memory growth
  - Step 1 "Measure" rewritten as a tool-matrix table (BenchmarkDotNet, dotnet-counters, dotnet-trace, dotnet-gcdump, PerfView, EventPipe, Application Insights/OpenTelemetry, EF Core logging / MiniProfiler); added a representative BenchmarkDotNet smoke test with `[MemoryDiagnoser]` + `[SimpleJob(baseline: true)]`; added the "never benchmark in Debug" warning
  - "Where to Start Measuring" decision tree fully rewritten for .NET symptoms (cold start → `dotnet-trace StartupPerformance`, request latency → EF Core logging / sync-over-async search, throughput → thread-pool counters / Kestrel limits, memory growth → `dotnet-gcdump` / event-handler leaks, UI frame drops → virtualization / compiled bindings)
  - Step 2 bottleneck tables split into ASP.NET Core / Avalonia-MAUI-WPF
  - Step 3 anti-pattern examples fully rewritten:
    - N+1 → EF Core `Include` / `AsSplitQuery` / projection to DTO + `AsNoTracking`
    - Sync-over-async (upstream had no equivalent)
    - Unbounded query → `Math.Clamp(pageSize, 1, 100)` + `Skip`/`Take` + `AsNoTracking`
    - Allocation discipline → `StringBuilder`, `string.Create` + `stackalloc`, `ReadOnlySpan<char>`, `ArrayPool<T>.Shared`
    - HttpClient misuse → `IHttpClientFactory` + typed client
    - Output Caching (ASP.NET Core 7+ `AddOutputCache`) — no upstream analog
    - Regex → `[GeneratedRegex]` (source-generated, .NET 7+)
    - Avalonia-specific → virtualization, compiled bindings, StaticResource vs DynamicResource, visual-tree depth
    - Kestrel / hosting → `ConfigureKestrel`, `<ServerGarbageCollection>`
  - Removed entirely: upstream's `<picture>` / `srcset` / AVIF/WebP image-optimization section, React re-render / `memo` / `useMemo` section, bundle-size / code-splitting / `Suspense` section, Lighthouse/Web Vitals measurement examples — none apply to .NET
  - Step 4 "Verify" adds an explicit before/after table format and a "noise floor" warning
  - New Step 5 "Guard" — BenchmarkDotNet in CI, Application Insights alerts, Roslyn analyzer rules, ADRs — expands upstream's one-line "add monitoring or tests"
  - "Performance Budget" fully rewritten with .NET-representative numbers and a PowerShell CI step parsing BenchmarkDotNet JSON
  - "See Also" adds links to Microsoft Learn diagnostics, BenchmarkDotNet docs, EF Core perf, Kestrel tuning
  - Common Rationalizations table adds: noise-vs-real improvements, `Task.Run` abuse, Gen2 pause costs, cold-start measurability
  - Red Flags list rewritten around .NET smells (`.Result`/`.Wait()`, cartesian `Include`, Debug-mode benchmarks, per-request `HttpClient`, runtime-compiled `Regex`, non-virtualized lists, missing `[MemoryDiagnoser]`)
  - Verification checklist adds noise-floor check, `[MemoryDiagnoser]` requirement, monitoring dashboard reflection, CI budget pass
- **What was preserved conceptually** (principles, not content): "measure before optimizing" framing, the MEASURE → IDENTIFY → FIX → VERIFY → GUARD 5-step workflow (added GUARD as a proper step where upstream had it as a sub-bullet), the anti-pattern-fix-example structure, the "Performance Budget + CI enforcement" closing section, Common Rationalizations and Red Flags table shape
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
