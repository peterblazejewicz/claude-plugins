---
description: Conduct a five-axis code review for .NET/C# changes — correctness, readability, architecture, security, performance
---

Invoke the `dotnet-skills:code-review-and-quality` skill.

Review the current changes (staged, unstaged, or recent commits) across all five axes:

1. **Correctness** — Does it match the spec? Edge cases handled? xUnit/MSTest coverage adequate? `dotnet test` passes? Nullable-reference-type annotations honest?
2. **Readability** — Clear names? Straightforward logic? `.editorconfig` / analyzer diagnostics clean? Pattern-matching used where it helps, not for its own sake?
3. **Architecture** — Follows existing patterns (Minimal APIs vs controllers, handler vs. service, DI lifetimes)? Clean boundaries between `MyApp.Core` / `MyApp.Infrastructure` / `MyApp.Contracts`? Right abstraction level?
4. **Security** — Input validated at boundaries (FluentValidation)? No raw-SQL concatenation? Secrets out of source? Authz policies applied? (Use `dotnet-skills:security-and-hardening`)
5. **Performance** — No EF Core N+1? No unbounded `.ToListAsync()`? No sync-over-async? No `HttpClient` allocated per-call? (Use `dotnet-skills:performance-optimization-dotnet`)

Categorize findings as **Critical**, **Important**, or **Suggestion**. Output a structured review with specific `file.cs:line` references and fix recommendations.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/review.md` at pinned SHA `44dac80`
- Status: modified (skill references retargeted to the `dotnet-skills:` prefix and to the renamed skill `performance-optimization-dotnet`; each axis gains .NET-specific checks — nullable annotations, `.editorconfig`/analyzers, DI lifetimes, `MyApp.Core`/`Infrastructure`/`Contracts` layering, FluentValidation, EF Core N+1, sync-over-async, `HttpClient` reuse; `file:line` references use `file.cs:line` format)
