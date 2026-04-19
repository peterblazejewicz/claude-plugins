---
name: code-review-and-quality
description: Conducts multi-axis code review for .NET/C# changes (correctness, readability, architecture, security, performance). Use before merging any change. Use when reviewing code written by yourself, another agent, or a human. Use when you need to assess code quality across multiple dimensions before it enters the main branch.
version: 0.2.0
source: vendor/agent-skills/skills/code-review-and-quality/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Code Review and Quality

## Overview

Multi-dimensional code review with quality gates. Every change gets reviewed before merge — no exceptions. Review covers five axes: correctness, readability, architecture, security, and performance.

**The approval standard:** Approve a change when it definitely improves overall code health, even if it isn't perfect. Perfect code doesn't exist — the goal is continuous improvement. Don't block a change because it isn't exactly how you would have written it. If it improves the codebase and follows the project's conventions, approve it.

## When to Use

- Before merging any PR or change
- After completing a feature implementation
- When another agent or model produced code you need to evaluate
- When refactoring existing code
- After any bug fix (review both the fix and the regression test)

## The Five-Axis Review

> **Host-model lens.** The five axes apply universally. Individual bullets sometimes anchor on a specific host model — **server-side (ASP.NET Core)** items like N+1 EF Core patterns, `FromSqlRaw`, antiforgery tokens, and `[Authorize]` policy checks won't apply to a pure Avalonia/MAUI client; **client-side (Avalonia / MAUI / Blazor WebAssembly)** items like dispatcher marshalling and `localStorage` discipline won't apply to an ASP.NET Core API. Where a bullet is host-specific, the host is named inline.

Every review evaluates code across these dimensions:

### 1. Correctness

Does the code do what it claims to do?

- Does it match the spec or task requirements?
- Are edge cases handled (null, empty, boundary values, `default(T)`)?
- Are error paths handled (not just the happy path)?
- Are `async` methods correctly awaited? No sync-over-async (`.Result` / `.Wait()`) on I/O paths?
- Does it pass all tests (`dotnet test`)? Are the tests actually testing the right things?
- Are there off-by-one errors, race conditions, or state inconsistencies?
- Is `CancellationToken` threaded through I/O methods?
- For **library** code (NuGet packages, class libraries that may be consumed from non-ASP.NET-Core hosts — WPF, WinForms, MAUI, Avalonia UI thread), do public `await` expressions use `.ConfigureAwait(false)` to avoid capturing the caller's `SynchronizationContext`? (Not needed for code that only runs under ASP.NET Core — it has no `SynchronizationContext` since .NET Core 2.1.)

### 2. Readability & Simplicity

Can another engineer (or agent) understand this code without the author explaining it?

- Are names descriptive and consistent with project conventions? (No `temp`, `data`, `result` without context)
- Is the control flow straightforward (avoid nested ternaries, deep LINQ chains)?
- Is the code organized logically (related code grouped, clear assembly boundaries)?
- Are there any "clever" tricks that should be simplified?
- **Could this be done in fewer lines?** (1000 lines where 100 suffice is a failure)
- **Are abstractions earning their complexity?** (Don't generalize until the third use case)
- Would XML doc comments help clarify non-obvious intent on public API? (But don't comment obvious code.)
- Are there dead-code artifacts: no-op variables, backwards-compat shims, or `// removed` comments?

### 3. Architecture

Does the change fit the system's design?

- Does it follow existing patterns or introduce a new one? If new, is it justified?
- Does it maintain clean project boundaries (no upward reference from `MyApp.Core` → host project)?
- Is there code duplication that should be shared?
- Are dependencies flowing in the right direction (no cycles in project references)?
- Is the abstraction level appropriate (not over-engineered, not too coupled)?
- Are DI registrations at the right lifetime (singleton vs scoped vs transient)?

### 4. Security

For detailed security guidance, see `security-and-hardening`. Does the change introduce vulnerabilities?

- Is user input validated and sanitized?
- Are secrets kept out of code, logs, and version control? (`dotnet user-secrets` for dev, Key Vault / environment for prod)
- Is authentication/authorization checked where needed? (`[Authorize]` attributes, policy checks)
- Are SQL queries parameterized? EF Core parameterizes by default; flag any `FromSqlRaw` with interpolation
- Are outputs encoded to prevent XSS in Razor/Blazor?
- Are dependencies from trusted sources with no known vulnerabilities? (`dotnet list package --vulnerable --include-transitive`)
- Is data from external sources (APIs, logs, user content, config files) treated as untrusted?
- Are external data flows validated at system boundaries before use in logic or rendering?

### 5. Performance

For detailed profiling and optimization, see `performance-optimization-dotnet`. Does the change introduce performance problems?

- Any N+1 EF Core query patterns? (Look for enumerated navigation properties inside a loop; use `Include`/`Select`/`AsSplitQuery` appropriately)
- Any unbounded loops or unconstrained queries? (Missing `Take`, missing `AsNoTracking` on read-only paths)
- Any synchronous operations that should be async? (`.Result`, `.Wait()`, `GetAwaiter().GetResult()`)
- Any unnecessary allocations in hot paths? (Avoid per-request `new` arrays where a pooled buffer works; `Span<T>` / `ReadOnlySpan<T>` on parsing paths)
- Any missing pagination on list endpoints?
- Any `async void` outside event handlers?

## Change Sizing

Small, focused changes are easier to review, faster to merge, and safer to deploy. Target these sizes:

```
~100 lines changed   → Good. Reviewable in one sitting.
~300 lines changed   → Acceptable if it's a single logical change.
~1000 lines changed  → Too large. Split it.
```

**What counts as "one change":** A single self-contained modification that addresses one thing, includes related tests, and keeps the system functional after submission. One part of a feature — not the whole feature.

**Splitting strategies when a change is too large:**

| Strategy | How | When |
|----------|-----|------|
| **Stack** | Submit a small change, start the next one based on it | Sequential dependencies |
| **By project** | Separate changes per project (Core, Infrastructure, Host) | Cross-cutting concerns |
| **Horizontal** | Create shared contracts / base classes first, then consumers | Layered architecture |
| **Vertical** | Break into smaller full-stack slices of the feature | Feature work |

**When large changes are acceptable:** Complete file deletions and automated refactoring (Roslyn analyzer fix-all, solution-wide rename) where the reviewer only needs to verify intent, not every line.

**Separate refactoring from feature work.** A change that refactors existing code and adds new behavior is two changes — submit them separately. Small cleanups (variable renaming) can be included at reviewer discretion.

## Change Descriptions

Every change needs a description that stands alone in version control history.

**First line:** Short, imperative, standalone. "Delete the legacy TaskService RPC" not "Deleting the legacy TaskService RPC." Must be informative enough that someone searching history can understand the change without reading the diff.

**Body:** What is changing and why. Include context, decisions, and reasoning not visible in the code itself. Link to bug numbers, benchmark results (include BenchmarkDotNet output where relevant), or ADRs. Acknowledge approach shortcomings when they exist.

**Anti-patterns:** "Fix bug," "Fix build," "Add patch," "Moving code from A to B," "Phase 1," "Add convenience methods."

## Review Process

### Step 1: Understand the Context

Before looking at code, understand the intent:

```
- What is this change trying to accomplish?
- What spec or task does it implement?
- What is the expected behavior change?
```

### Step 2: Review the Tests First

Tests reveal intent and coverage:

```
- Do tests exist for the change (xUnit or MSTest)?
- Do they test behavior (not implementation details)?
- Are edge cases covered?
- Do tests have descriptive names following the project convention (e.g., MethodUnderTest_Scenario_Expected)?
- Would the tests catch a regression if the code changed?
- Do integration tests use WebApplicationFactory / Testcontainers rather than mocking the world?
```

### Step 3: Review the Implementation

Walk through the code with the five axes in mind:

```
For each file changed:
1. Correctness: Does this code do what the test says it should?
2. Readability: Can I understand this without help?
3. Architecture: Does this fit the system?
4. Security: Any vulnerabilities?
5. Performance: Any bottlenecks?
```

### Step 4: Categorize Findings

Label every comment with its severity so the author knows what's required vs optional:

| Prefix | Meaning | Author Action |
|--------|---------|---------------|
| *(no prefix)* | Required change | Must address before merge |
| **Critical:** | Blocks merge | Security vulnerability, data loss, broken functionality |
| **Nit:** | Minor, optional | Author may ignore — formatting, style preferences |
| **Optional:** / **Consider:** | Suggestion | Worth considering but not required |
| **FYI** | Informational only | No action needed — context for future reference |

This prevents authors from treating all feedback as mandatory and wasting time on optional suggestions.

### Step 5: Verify the Verification

Check the author's verification story:

```
- What tests were run (`dotnet test` output attached or summarized)?
- Did the build pass (`dotnet build -warnaserror`)?
- Was the change tested manually (run against `dotnet run` or deployed preview)?
- Are there screenshots for UI changes (Avalonia/Blazor views)?
- Is there a before/after BenchmarkDotNet comparison for perf changes?
```

## Multi-Model Review Pattern

Use different models for different review perspectives:

```
Model A writes the code
    │
    ▼
Model B reviews for correctness and architecture
    │
    ▼
Model A addresses the feedback
    │
    ▼
Human makes the final call
```

This catches issues that a single model might miss — different models have different blind spots.

**Example prompt for a review agent:**
```
Review this code change for correctness, security, and adherence to
our project conventions. The spec says [X]. The change should [Y].
Flag any issues as Critical, Important, or Suggestion.
```

## Dead Code Hygiene

After any refactoring or implementation change, check for orphaned code:

1. Identify code that is now unreachable or unused (the IDE's "unused symbol" analyzer + `dotnet build -warnaserror` with IDE0051/IDE0052 enabled helps)
2. List it explicitly
3. **Ask before deleting:** "Should I remove these now-unused elements: [list]?"

Don't leave dead code lying around — it confuses future readers and agents. But don't silently delete things you're not sure about. When in doubt, ask.

```
DEAD CODE IDENTIFIED:
- FormatLegacyDate() in MyApp.Core/Formatting/DateFormatter.cs — replaced by FormatDate()
- OldTaskCard view in MyApp.Views/ — replaced by TaskCard.axaml
- LEGACY_API_URL constant in MyApp.Core/Configuration — no remaining references
→ Safe to remove these?
```

## Review Speed

Slow reviews block entire teams. The cost of context-switching to review is less than the waiting cost imposed on others.

- **Respond within one business day** — this is the maximum, not the target
- **Ideal cadence:** Respond shortly after a review request arrives, unless deep in focused coding. A typical change should complete multiple review rounds in a single day
- **Prioritize fast individual responses** over quick final approval. Quick feedback reduces frustration even if multiple rounds are needed
- **Large changes:** Ask the author to split them rather than reviewing one massive changeset

## Handling Disagreements

When resolving review disputes, apply this hierarchy:

1. **Technical facts and data** override opinions and preferences
2. **`.editorconfig` and the analyzer ruleset** are the absolute authority on style matters
3. **Software design** must be evaluated on engineering principles, not personal preference
4. **Codebase consistency** is acceptable if it doesn't degrade overall health

**Don't accept "I'll clean it up later."** Experience shows deferred cleanup rarely happens. Require cleanup before submission unless it's a genuine emergency. If surrounding issues can't be addressed in this change, require filing an issue with self-assignment.

## Honesty in Review

When reviewing code — whether written by you, another agent, or a human:

- **Don't rubber-stamp.** "LGTM" without evidence of review helps no one.
- **Don't soften real issues.** "This might be a minor concern" when it's a bug that will hit production is dishonest.
- **Quantify problems when possible.** "This N+1 query will add ~50ms per item in the list" is better than "this could be slow."
- **Push back on approaches with clear problems.** Sycophancy is a failure mode in reviews. If the implementation has issues, say so directly and propose alternatives.
- **Accept override gracefully.** If the author has full context and disagrees, defer to their judgment. Comment on code, not people — reframe personal critiques to focus on the code itself.

## Dependency Discipline

Part of code review is dependency review:

**Before adding any NuGet dependency:**
1. Does the existing stack solve this? (Often it does — .NET's BCL is broad.)
2. How large is the dependency and its transitive graph? (Check with `dotnet list package --include-transitive`)
3. Is it actively maintained? (Check last release, open issues, signed binaries)
4. Does it have known vulnerabilities? (`dotnet list package --vulnerable --include-transitive`)
5. What's the license? (Must be compatible with the project.)
6. Does it target the right frameworks (net8.0+, not netstandard2.0 if possible)?

**Rule:** Prefer the BCL and existing utilities over new dependencies. Every dependency is a liability. If the project uses Central Package Management (`Directory.Packages.props`), add versions there — not in individual `.csproj` files.

## The Review Checklist

```markdown
## Review: [PR/Change title]

### Context
- [ ] I understand what this change does and why

### Correctness
- [ ] Change matches spec/task requirements
- [ ] Edge cases handled (null, default(T), empty collections)
- [ ] Error paths handled
- [ ] Async is correct (no sync-over-async, CancellationToken threaded)
- [ ] Tests cover the change adequately

### Readability
- [ ] Names are clear and consistent with .editorconfig
- [ ] Logic is straightforward
- [ ] No unnecessary complexity

### Architecture
- [ ] Follows existing patterns
- [ ] No new cycles in project references
- [ ] Appropriate DI lifetime on new registrations
- [ ] Appropriate abstraction level

### Security
- [ ] No secrets in code
- [ ] Input validated at boundaries
- [ ] No `FromSqlRaw` with string interpolation
- [ ] Auth checks in place
- [ ] External data sources treated as untrusted

### Performance
- [ ] No N+1 EF Core patterns
- [ ] No unbounded queries
- [ ] Pagination on list endpoints
- [ ] No unnecessary allocations in hot paths

### Verification
- [ ] `dotnet test` passes
- [ ] `dotnet build -warnaserror` succeeds
- [ ] Manual verification done (if applicable)

### Verdict
- [ ] **Approve** — Ready to merge
- [ ] **Request changes** — Issues must be addressed
```

## See Also

- For detailed security review guidance, see the upstream reference at https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/references/security-checklist.md
- For performance review checks, see https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/references/performance-checklist.md — note these are generic; the `dotnet`-specific checklist lives in the `performance-optimization-dotnet` skill

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It works, that's good enough" | Working code that's unreadable, insecure, or architecturally wrong creates debt that compounds. |
| "I wrote it, so I know it's correct" | Authors are blind to their own assumptions. Every change benefits from another set of eyes. |
| "We'll clean it up later" | Later never comes. The review is the quality gate — use it. Require cleanup before merge, not after. |
| "AI-generated code is probably fine" | AI code needs more scrutiny, not less. It's confident and plausible, even when wrong. |
| "The tests pass, so it's good" | Tests are necessary but not sufficient. They don't catch architecture problems, security issues, or readability concerns. |

## Red Flags

- PRs merged without any review
- Review that only checks if tests pass (ignoring other axes)
- "LGTM" without evidence of actual review
- Security-sensitive changes without security-focused review
- Large PRs that are "too big to review properly" (split them)
- No regression tests with bug fix PRs
- Review comments without severity labels — makes it unclear what's required vs optional
- Accepting "I'll fix it later" — it never happens
- `FromSqlRaw` / `FromSqlInterpolated` added without a review comment explaining the safety boundary

## Verification

After review is complete:

- [ ] All Critical issues are resolved
- [ ] All Important issues are resolved or explicitly deferred with justification
- [ ] `dotnet test` passes
- [ ] `dotnet build -warnaserror` succeeds
- [ ] The verification story is documented (what changed, how it was verified)

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/code-review-and-quality/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - Five-axis review checks augmented with .NET-specific concerns: async correctness (`CancellationToken`, no sync-over-async), `default(T)` edge cases, DI registration lifetimes, project-reference cycles, `FromSqlRaw` flag, N+1 EF Core patterns, `Span<T>` on hot paths
  - Security bullets: `dotnet user-secrets` + Key Vault instead of `.env`, `dotnet list package --vulnerable` instead of `npm audit`, Razor/Blazor output encoding, `[Authorize]` policy checks
  - Style-authority pointer changed from "style guides" to "`.editorconfig` and the analyzer ruleset"
  - Splitting strategy renamed "By file group" → "By project" (Core / Infrastructure / Host) to match solution-level reviews
  - Test review bullets mention xUnit/MSTest, `WebApplicationFactory`, Testcontainers
  - Dependency-discipline bullets: `dotnet list package --include-transitive`, NuGet signing, Central Package Management (`Directory.Packages.props`)
  - Dead-code example paths updated for a Avalonia/.NET solution layout (`MyApp.Core/…`, `MyApp.Views/…`, `TaskCard.axaml`)
  - Review checklist reflects the .NET-specific sub-bullets
  - "See Also" section points at upstream vendored references temporarily, with a forward pointer to the Wave 3 `performance-optimization-dotnet` skill
  - Red-flag list adds `FromSqlRaw`/`FromSqlInterpolated` without review justification
  - Core structure, the five-axis frame, approval standard, honesty-in-review guidance, change-sizing thresholds, and the severity prefix table preserved from upstream verbatim
- **Downstream patches** (applied after the initial sync; not tracked against upstream):
  - **2026-04-19** (plugin v1.0.3) — Two additions:
    - **Host-model lens note** at the top of "The Five-Axis Review" clarifying that the five axes are universal but individual bullets sometimes anchor on a host model (server-side ASP.NET Core vs client-side Avalonia / MAUI / Blazor WebAssembly).
    - **`ConfigureAwait(false)` bullet** added to the Correctness axis — library code consumed from non-ASP.NET-Core hosts (WPF, WinForms, MAUI, Avalonia UI-thread) should use `.ConfigureAwait(false)` on public awaits to avoid `SynchronizationContext` capture. Called out as no-op under ASP.NET Core since .NET Core 2.1.
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
