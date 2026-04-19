---
description: Run the .NET pre-launch checklist and prepare a production deployment with rollback in place
---

Invoke the `dotnet-skills:shipping-and-launch` skill.

Run through the complete pre-launch checklist:

1. **Code Quality** — `dotnet test` passes, `dotnet build -warnaserror` clean, `dotnet format --verify-no-changes` clean, no stray `Console.WriteLine` / `Debug.WriteLine` / `Trace.WriteLine`, no `TODO`/`FIXME` left unresolved, nullable annotations honest
2. **Security** — `dotnet list package --vulnerable --include-transitive` clean, no secrets in code (use `dotnet user-secrets` in dev, Azure Key Vault / AWS Secrets Manager in prod), auth + policy-based authz in place, security response headers configured (HSTS, CSP, X-Content-Type-Options), antiforgery for server-rendered forms
3. **Performance** — No EF Core N+1 in hot paths, no unbounded `.ToListAsync()` without pagination, `IHttpClientFactory` used for outbound calls, `AddOutputCache` / `AddResponseCompression` configured where applicable; **for ASP.NET Core / Blazor Server / Blazor WebAssembly** also check Core Web Vitals, bundle size, and image optimization
4. **Accessibility** — Keyboard nav works; for Avalonia/MAUI views, `AutomationProperties` populated; for Blazor/Razor, ARIA + semantic HTML correct, color contrast adequate
5. **Infrastructure** — Connection strings / env vars set in target environment, EF Core migrations ready (`dotnet ef migrations list`) and reversible, feature flags (`IOptions<FeatureOptions>` / `Microsoft.FeatureManagement`) default-off for the risky path, monitoring wired (Application Insights / OpenTelemetry / dotnet-counters)
6. **Documentation** — `README.md` current with the deployed state, ADRs written for architectural decisions, changelog updated, API docs (Swashbuckle OpenAPI / XML docs) regenerated

Report any failing checks and help resolve them before deployment. **Define the rollback plan before proceeding** — for schema changes, apply the expand-contract pattern and verify `dotnet ef database update <PreviousMigration>` works.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/ship.md` at pinned SHA `44dac80`
- Status: modified (skill reference retargeted to the `dotnet-skills:` prefix; **Code Quality** swaps `console.logs` → stray `Console.WriteLine` / `Debug.WriteLine` / `Trace.WriteLine`; **Security** swaps `npm audit` → `dotnet list package --vulnerable --include-transitive` and adds `dotnet user-secrets` / Key Vault / antiforgery; **Performance** reframed around EF Core N+1, `IHttpClientFactory`, `AddOutputCache`, with Core Web Vitals made conditional on ASP.NET Core/Blazor context; **Accessibility** adds `AutomationProperties` for Avalonia/MAUI; **Infrastructure** names EF Core migrations and `IOptions<FeatureOptions>`/`Microsoft.FeatureManagement` feature flags and Application Insights/OpenTelemetry monitoring; rollback step names `dotnet ef database update <Migration>` and the expand-contract pattern)
