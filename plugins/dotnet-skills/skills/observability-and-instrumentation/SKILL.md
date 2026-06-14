---
name: observability-and-instrumentation
description: Instruments .NET/C# code so production behavior is visible and diagnosable. Use when adding logging, metrics, tracing, or alerting to an ASP.NET Core / Blazor / worker / desktop app. Use when shipping any feature that runs in production and you need evidence it works. Use when production issues are reported but you can't tell what happened from the available data.
---

# Observability and Instrumentation

## Overview

Code you can't observe is code you can't operate. When a request hangs, a queue backs up, or a `TaskCanceledException` spikes at 2am, the only thing standing between you and a multi-hour investigation is the telemetry you added *while building the feature* — not after.

Instrumentation is a development responsibility, not a post-launch chore. .NET gives you first-class, vendor-neutral building blocks for all three signals — `ILogger` for structured logs, `System.Diagnostics.Metrics` for metrics, and `System.Diagnostics.Activity` + OpenTelemetry for traces — so there's no reason to defer it.

This skill is the bridge between [`debugging-and-error-recovery`](../debugging-and-error-recovery/SKILL.md) (dev-time diagnosis) and [`shipping-and-launch`](../shipping-and-launch/SKILL.md) (launch-day monitoring): instrument as you build so production behavior is visible before you need it.

## When to Use

- Shipping a feature that will run in production
- Adding a new service, background worker, or external integration (HTTP, EF Core, message queue)
- A production issue was reported but the existing data can't explain what happened
- Setting up or revising alerts
- Reviewing a PR that introduces I/O, retries, caching, or fan-out

## Process

### 1. Start from the questions, not the tools

Before instrumenting, write down the questions an on-call engineer will ask at 2am: *Is it the database or the API? Which tenant? Is it one endpoint or all of them? Did the retry storm start before or after the deploy?* Instrument to answer those questions — not to "add logging."

### 2. Match the signal to the question

- **Logs** answer *"why"* — the specific event, with context. Use `ILogger`.
- **Metrics** answer *"how often / how much"* — aggregates over time. Use `System.Diagnostics.Metrics`.
- **Traces** answer *"where"* — which hop in a distributed call chain. Use `Activity` / OpenTelemetry.

### 3. Structured logging with `ILogger`

Log structured events with stable names and typed fields — never interpolated strings. Prefer the `[LoggerMessage]` source generator (compile-time, allocation-free, structured) for hot paths:

```csharp
public static partial class Log
{
    [LoggerMessage(EventId = 2001, Level = LogLevel.Warning,
        Message = "Checkout failed for order {OrderId}: {Reason}")]
    public static partial void CheckoutFailed(this ILogger logger, Guid orderId, string reason);
}

// call site — OrderId and Reason are captured as structured fields, not baked into text
logger.CheckoutFailed(order.Id, "payment_declined");
```

- **Stable event identity:** a fixed `EventId` and message template let you query "all `CheckoutFailed` events" regardless of the parameter values.
- **Correlation IDs:** ASP.NET Core stamps a W3C `traceparent` and exposes `Activity.Current?.TraceId`. Use `ILogger.BeginScope` (or let OpenTelemetry log enrichment do it) so every log line in a request carries the same trace id — that's how you stitch a log to its trace.
- **Never log secrets or PII** (tokens, connection strings, full payloads). Project to DTOs and scrub before logging.
- Serilog is a fine alternative when you need sinks/enrichers beyond `Microsoft.Extensions.Logging`; the structured-event discipline is identical.

### 4. Metrics: RED for endpoints, USE for resources

Use the `System.Diagnostics.Metrics` API (designed in cooperation with OpenTelemetry, so it works with Prometheus/Grafana/Azure Monitor out of the box). ASP.NET Core, `HttpClient`, and EF Core already publish built-in metrics on .NET 8+ — subscribe to those before writing your own:

- Built-in `http.server.request.duration` (meter `Microsoft.AspNetCore.Hosting`) gives you **R**ate, **E**rrors, **D**uration for every endpoint for free.
- `System.Net.Http` and EF Core meters cover outbound HTTP and database query duration.

For domain metrics the framework can't know about, create a `Meter`:

```csharp
public sealed class CheckoutMetrics
{
    private readonly Counter<long> _completed;
    private readonly Histogram<double> _settlementSeconds;

    public CheckoutMetrics(IMeterFactory meterFactory)
    {
        var meter = meterFactory.Create("MyApp.Checkout");
        _completed = meter.CreateCounter<long>("checkout.completed");
        _settlementSeconds = meter.CreateHistogram<double>("checkout.settlement.duration");
    }

    public void RecordCompleted(string channel) => _completed.Add(1, new KeyValuePair<string, object?>("channel", channel));
}
```

- **RED** (Rate, Errors, Duration) for request-driven work; **USE** (Utilization, Saturation, Errors) for resources (thread pool, connection pool, queue depth).
- Resolve meters through `IMeterFactory` (DI) so they're testable.
- **Cardinality discipline:** tag values must be a *bounded* set (channel, status, route template). Never tag with user IDs, order IDs, or raw URLs — unbounded tags blow up storage and get dropped by collectors.

### 5. Distributed tracing with OpenTelemetry

Register OpenTelemetry once and lean on auto-instrumentation; add custom spans only where the framework can't see:

```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddSource("MyApp.Checkout")          // your custom ActivitySource
        .AddOtlpExporter())                   // or .UseAzureMonitor() via Azure.Monitor.OpenTelemetry.AspNetCore
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddMeter("MyApp.Checkout")
        .AddOtlpExporter());
```

```csharp
private static readonly ActivitySource Source = new("MyApp.Checkout");

using var activity = Source.StartActivity("SettlePayment");
activity?.SetTag("checkout.channel", channel);   // bounded tags only
```

Auto-instrumentation propagates context across HTTP and (with the right instrumentation) queue boundaries, so a single trace id follows a request through every service.

### 6. Alert on symptoms, not causes

Alert on what the user feels — elevated `http.server.request.duration` p99, error-rate over threshold, queue age — not on infrastructure proxies like CPU. Every alert needs a **runbook**: what it means, what to check first, how to mitigate. Azure Monitor / Application Insights (via the `Azure.Monitor.OpenTelemetry.AspNetCore` distro) or any OTLP backend (Prometheus + Grafana + Alertmanager) all work.

### 7. Verify the telemetry actually works

Telemetry you never exercised is telemetry that silently fails when you need it. Trigger the error path and confirm the signal appears. Metrics are unit-testable without a backend using `MetricCollector<T>` (`Microsoft.Extensions.Diagnostics.Testing`) inside a `WebApplicationFactory<Program>` test:

```csharp
using var collector = new MetricCollector<double>(
    factory.Services.GetRequiredService<IMeterFactory>(),
    "Microsoft.AspNetCore.Hosting", "http.server.request.duration");

var response = await client.GetAsync("/checkout/health", cancellationToken);

var measurement = Assert.Single(collector.GetMeasurementSnapshot());
Assert.Equal(200, measurement.Tags["http.response.status_code"]);
```

Use `dotnet-counters monitor -n MyApp --counters Microsoft.AspNetCore.Hosting` for an ad-hoc live check that instrumentation is firing.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll add logging once it works" | The moment it stops working in production is exactly when you'll wish the logging already existed. Instrument as you build. |
| "`Console.WriteLine` is fine for now" | Unstructured text can't be queried, filtered, or correlated. Use `ILogger` with structured fields from the first line. |
| "We have CPU/memory dashboards, that's monitoring" | Resource graphs tell you the box is busy, not that checkout is failing for one tenant. Instrument user-visible symptoms. |
| "I'll just add a user-id tag to the metric" | Unbounded tag values explode cardinality and get dropped by the collector. Put high-cardinality data in logs/traces, not metric tags. |
| "OpenTelemetry is too much setup" | Built-in ASP.NET Core/HttpClient/EF Core instrumentation is a few lines in `Program.cs` and gives you RED metrics + traces for free. |

## Red Flags

- Logging interpolated strings (`$"order {id} failed"`) instead of structured templates — the fields can't be queried
- No correlation/trace id tying a request's logs together
- Metric tags with unbounded values (user IDs, order IDs, raw URLs, exception messages)
- Alerts on CPU/memory instead of user-visible symptoms; alerts with no runbook
- `Console.WriteLine` / `Debug.WriteLine` / `Trace.WriteLine` left in as "logging"
- Secrets, tokens, connection strings, or PII written to logs
- Telemetry added but never exercised on the error path
- Re-inventing `http.server.request.duration` or EF Core query metrics that the framework already publishes

## Verification

- [ ] The on-call questions were written down first, and each signal maps to one of them
- [ ] Logs are structured (`ILogger` + templates / `[LoggerMessage]`), carry a correlation/trace id, and contain no secrets or PII
- [ ] RED metrics cover request paths (built-in or custom `Meter`); USE metrics cover constrained resources
- [ ] Metric tag values are a bounded set — no user/order IDs or raw URLs
- [ ] OpenTelemetry tracing is registered with the relevant auto-instrumentation; custom `ActivitySource` spans exist where the framework can't see
- [ ] Alerts fire on user-visible symptoms and each has a runbook
- [ ] The error path was exercised and the expected log/metric/trace was confirmed (a `MetricCollector<T>` test or `dotnet-counters` check counts)

## See Also

- [Metrics in .NET](https://learn.microsoft.com/dotnet/core/diagnostics/metrics) and [built-in metrics](https://learn.microsoft.com/dotnet/core/diagnostics/built-in-metrics)
- [ASP.NET Core metrics](https://learn.microsoft.com/aspnet/core/log-mon/metrics/metrics) and [.NET distributed tracing / OpenTelemetry](https://learn.microsoft.com/dotnet/core/diagnostics/distributed-tracing)
- [`dotnet-counters`](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-counters)
- Companion skills: [`debugging-and-error-recovery`](../debugging-and-error-recovery/SKILL.md), [`performance-optimization-dotnet`](../performance-optimization-dotnet/SKILL.md), [`shipping-and-launch`](../shipping-and-launch/SKILL.md)

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/3a6fc6392823e31e2362091bd4e3cddf5b77af14/skills/observability-and-instrumentation/SKILL.md
- **Pinned commit**: `3a6fc6392823e31e2362091bd4e3cddf5b77af14` (synced 2026-06-14)
- **Status**: `modified` (retargeted from the generic/Node-flavored upstream to .NET; upstream anatomy — Overview, When to Use, Process, Rationalizations, Red Flags, Verification — and the questions-first / signal-matching / RED+USE / symptom-based-alerting / verify-the-telemetry process preserved)
- **Changes**:
  - Structured logging rewritten around `Microsoft.Extensions.Logging` `ILogger` + the `[LoggerMessage]` source generator with stable `EventId`s; correlation via `Activity.Current?.TraceId` (W3C TraceContext) + `ILogger.BeginScope`; Serilog named as the sink-rich alternative
  - Metrics rewritten around `System.Diagnostics.Metrics` (`Meter`/`Counter<T>`/`Histogram<T>` via `IMeterFactory`); notes the built-in ASP.NET Core `http.server.request.duration` (meter `Microsoft.AspNetCore.Hosting`), `System.Net.Http`, and EF Core meters as the free RED baseline (all .NET 8+)
  - Tracing rewritten around OpenTelemetry .NET (`AddOpenTelemetry().WithTracing()/.WithMetrics()`, `AddAspNetCoreInstrumentation`/`AddHttpClientInstrumentation`/`AddEntityFrameworkCoreInstrumentation`, custom `ActivitySource`, OTLP / `UseAzureMonitor` exporters)
  - Alerting section names Azure Monitor / Application Insights and the OTLP→Prometheus/Grafana path
  - Verification uses `MetricCollector<T>` (`Microsoft.Extensions.Diagnostics.Testing`) inside `WebApplicationFactory<Program>` with **native `Xunit.Assert.X`** (no FluentAssertions — repo policy) and `dotnet-counters monitor`
  - Cardinality and "never log secrets/PII" guidance kept and grounded in .NET tag/DTO-projection practice; `Console.WriteLine`/`Debug.WriteLine`/`Trace.WriteLine` named as the .NET "this isn't logging" red flag
  - Cross-links added to companion skills (`debugging-and-error-recovery`, `performance-optimization-dotnet`, `shipping-and-launch`) and Microsoft Learn
  - Version anchors (built-in ASP.NET Core/`System.Net`/EF Core metrics = .NET 8+) verified against Microsoft Learn at sync time
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
