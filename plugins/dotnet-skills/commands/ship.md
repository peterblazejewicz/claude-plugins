---
description: Run the .NET pre-launch checklist via parallel fan-out to specialist personas, then synthesize a go/no-go decision with rollback in place
---

Invoke the `dotnet-skills:shipping-and-launch` skill.

`/ship` is a **fan-out orchestrator**. It runs three specialist personas in parallel against the current change, then merges their reports into a single go/no-go decision with a rollback plan. The personas operate independently — no shared state, no ordering — which is what makes parallel execution safe and useful here.

## Phase A — Parallel fan-out

Spawn three subagents concurrently using the Agent tool. **Issue all three Agent tool calls in a single assistant turn so they execute in parallel** — sequential calls defeat the purpose of this command.

In Claude Code, each call passes `subagent_type` matching the persona's `name` field:

1. **`code-reviewer`** — Run a five-axis review (correctness, readability, architecture, security, performance) on the staged changes or recent commits. Ground findings in .NET specifics: nullable-reference-type honesty, `async`/`await` correctness (no `.Result` / `.Wait()` on I/O paths), `CancellationToken` threading, DI lifetime correctness, EF Core N+1, `MyApp.Core` / `MyApp.Infrastructure` / `MyApp.Contracts` layering. Output the standard review template with `file.cs:line` references.
2. **`security-auditor`** — Run a vulnerability and threat-model pass. Check OWASP Top 10 translated to ASP.NET Core / EF Core / Blazor equivalents, secrets handling (`dotnet user-secrets` / Key Vault / env), auth + policy-based authz (`[Authorize]`, `RequireAuthorization()`, per-resource IDOR checks), `FromSqlRaw` injection, and dependency CVEs (`dotnet list package --vulnerable --include-transitive`). Output the standard audit report.
3. **`test-engineer`** — Analyze test coverage for the change. Identify gaps in happy path, edge cases, error paths, cancellation, and concurrency scenarios — framed around the xUnit / MSTest runner the project uses and the relevant integration boundary (`WebApplicationFactory<Program>`, Testcontainers, `Microsoft.Playwright`, `Avalonia.Headless.XUnit`). Output the standard coverage analysis.

In other harnesses without an Agent tool, invoke each persona's system prompt sequentially and treat their outputs as if returned in parallel — the merge phase still works.

Constraints (from Claude Code's subagent model):
- Subagents cannot spawn other subagents — do not let one persona delegate to another.
- Each subagent gets its own context window and returns only its report to this main session.
- If you need teammates that talk to each other instead of just reporting back, use Claude Code Agent Teams and reference these personas as teammate types (see [`../references/orchestration-patterns.md`](../references/orchestration-patterns.md)).

**Persona resolution.** If you've defined your own `code-reviewer`, `security-auditor`, or `test-engineer` in `.claude/agents/` or `~/.claude/agents/`, those take precedence over this plugin's versions — `/ship` picks up your customizations automatically. This is intentional: plugin subagents sit at the bottom of Claude Code's scope priority table, so user-level definitions win by design.

## Phase B — Merge in main context

Once all three reports are back, the main agent (not a sub-persona) synthesizes them against the .NET pre-launch checklist:

1. **Code Quality** — Aggregate Critical/Important findings from `code-reviewer` and verify directly: `dotnet test` passes, `dotnet build -warnaserror` clean, `dotnet format --verify-no-changes` clean, no stray `Console.WriteLine` / `Debug.WriteLine` / `Trace.WriteLine`, no `TODO` / `FIXME` left unresolved, nullable annotations honest. Resolve duplicates between reviewers.
2. **Security** — Promote any Critical/High `security-auditor` findings to launch blockers. Cross-reference with `code-reviewer`'s security axis. Verify directly: `dotnet list package --vulnerable --include-transitive` clean, no secrets in code (`dotnet user-secrets` in dev; Azure Key Vault / AWS Secrets Manager in prod), auth + policy-based authz in place, security response headers configured (HSTS, CSP, X-Content-Type-Options), antiforgery for server-rendered forms.
3. **Performance** — Pull from `code-reviewer`'s performance axis. Verify directly: no EF Core N+1 in hot paths, no unbounded `.ToListAsync()` without pagination, `IHttpClientFactory` used for outbound calls, `AddOutputCache` / `AddResponseCompression` configured where applicable. **For ASP.NET Core / Blazor Server / Blazor WebAssembly**, also cross-check Core Web Vitals, bundle size, and image optimization.
4. **Accessibility** — Not covered by the three personas — verify directly. Keyboard nav works; for Avalonia/MAUI views, `AutomationProperties` populated; for Blazor/Razor, ARIA + semantic HTML correct, color contrast adequate.
5. **Infrastructure** — Verify directly. Connection strings / env vars set in target environment, EF Core migrations ready (`dotnet ef migrations list`) and reversible, feature flags (`IOptions<FeatureOptions>` / `Microsoft.FeatureManagement`) default-off for the risky path, monitoring wired (Application Insights / OpenTelemetry / dotnet-counters).
6. **Documentation** — Verify directly. `README.md` current with the deployed state, ADRs written for architectural decisions, changelog updated, API docs (Swashbuckle OpenAPI / XML docs) regenerated.

## Phase C — Decision and rollback

Produce a single output:

```markdown
## Ship Decision: GO | NO-GO

### Blockers (must fix before ship)
- [Source persona: Critical finding + `file.cs:line`]

### Recommended fixes (should fix before ship)
- [Source persona: Important finding + `file.cs:line`]

### Acknowledged risks (shipping anyway)
- [Risk + mitigation]

### Rollback plan
- Trigger conditions: [what signals would prompt rollback]
- Rollback procedure: [exact steps — for EF Core schema changes, apply the expand-contract pattern and verify `dotnet ef database update <PreviousMigration>` works]
- Recovery time objective: [target]

### Specialist reports (full)
- [code-reviewer report]
- [security-auditor report]
- [test-engineer report]
```

## Rules

1. The three Phase A personas run in parallel — never sequentially.
2. Personas do not call each other. The main agent merges in Phase B.
3. The rollback plan is mandatory before any GO decision. For schema changes, always verify `dotnet ef database update <PreviousMigration>` succeeds against a restored snapshot before declaring GO.
4. If any persona returns a Critical finding, the default verdict is NO-GO unless the user explicitly accepts the risk.
5. **Skip the fan-out only if all of the following are true:** the change touches 2 files or fewer, the diff is under 50 lines, and it does not touch auth, EF Core migrations, payments, data access, feature-flag gates, or config/env. Otherwise, default to fan-out. `/ship` is designed for production-bound changes — when the blast radius is non-trivial, run the parallel review even if the diff looks small.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/ship.md` at pinned SHA `1f66d57`
- Status: modified (structurally ported — Phase A / B / C fan-out-plus-merge shape preserved from upstream; skill reference retargeted to `dotnet-skills:shipping-and-launch`; Phase A persona prompts grounded in .NET specifics — nullable-RT honesty, async correctness, `CancellationToken` threading, DI lifetimes, EF Core N+1, `MyApp.*` layering for `code-reviewer`; OWASP→ASP.NET Core/EF Core translation, `[Authorize]` / `RequireAuthorization()`, `FromSqlRaw`, `dotnet list package --vulnerable --include-transitive` for `security-auditor`; xUnit/MSTest + `WebApplicationFactory` / Testcontainers / `Microsoft.Playwright` / `Avalonia.Headless.XUnit` boundaries for `test-engineer`; Phase B merge checklist retains the pre-1f66d57 .NET items — `dotnet test` / `dotnet build -warnaserror` / `dotnet format --verify-no-changes` / no stray `Console.WriteLine` for Code Quality; `dotnet user-secrets` / Key Vault / antiforgery / security headers for Security; EF Core N+1 / `IHttpClientFactory` / `AddOutputCache` / conditional Core Web Vitals for Performance; `AutomationProperties` for Avalonia/MAUI Accessibility; `dotnet ef migrations list` + `IOptions<FeatureOptions>` + App Insights / OpenTelemetry for Infrastructure; Swashbuckle / XML docs for Documentation; rollback step names `dotnet ef database update <PreviousMigration>` and the expand-contract pattern; `file:line` → `file.cs:line` convention; Rule 5 skip-list extended with EF Core migrations and feature-flag gates; link to sibling orchestration reference uses the downstream path `../references/orchestration-patterns.md`)
