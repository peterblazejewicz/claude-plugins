---
description: Simplify C# code for clarity and maintainability — reduce complexity without changing behavior
---

Invoke the `dotnet-skills:code-simplification` skill.

Simplify recently changed code (or the specified scope) while preserving exact behavior:

1. Read `CLAUDE.md` and study project conventions — `.editorconfig`, analyzer severity, naming conventions, layering rules
2. Identify the target code — recent changes unless a broader scope is specified
3. Understand the code's purpose, callers, edge cases, and test coverage before touching it
4. Scan for C#-specific simplification opportunities:
   - Deep nesting → guard clauses or extracted helpers
   - Long methods → split by responsibility
   - Nested ternaries → `switch` expressions or if/else
   - Generic names → descriptive names aligned with `.editorconfig`
   - Manual null checks → `??`, `?.`, pattern-matching (`is { } x`), or `ArgumentNullException.ThrowIfNull`
   - `async void` and sync-over-async → proper `Task`/`ValueTask` with `CancellationToken`
   - Mutable DTOs → `record` / `record struct`
   - Duplicated logic → shared methods, extension methods, or `required` properties
   - Dead code → remove after confirming with callers and tests
5. Apply each simplification incrementally — run `dotnet test` and `dotnet build -warnaserror` after each change
6. Verify all tests pass, the build succeeds warning-free, `dotnet format --verify-no-changes` is clean, and the diff is tight

If tests fail after a simplification, revert that change and reconsider. Use `dotnet-skills:code-review-and-quality` to review the result.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/code-simplify.md` at pinned SHA `44dac80`
- Status: modified (skill references retargeted to the `dotnet-skills:` prefix; convention-sources list adds `.editorconfig` / analyzer severity / layering rules; simplification scan gains C#-idiomatic opportunities — null-coalescing, pattern-matching, `ArgumentNullException.ThrowIfNull`, async correctness, `record`/`record struct`; verification commands are `dotnet test`, `dotnet build -warnaserror`, `dotnet format --verify-no-changes`)
