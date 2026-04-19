---
description: Implement the next task incrementally in .NET — RED/GREEN/REFACTOR, `dotnet build`, `dotnet test`, commit
---

Invoke the `dotnet-skills:incremental-implementation` skill alongside `dotnet-skills:test-driven-development`.

Pick the next pending task from the plan. For each task:

1. Read the task's acceptance criteria
2. Load relevant context — existing C# code, project conventions, analyzer settings (`.editorconfig`, nullable reference-type mode), types in `MyApp.Contracts` / `MyApp.Core`
3. Write a failing xUnit or MSTest test for the expected behavior (RED)
4. Implement the minimum C# code to pass the test (GREEN)
5. Run the full test suite to check for regressions: `dotnet test`
6. Run the build with warnings-as-errors to verify compilation: `dotnet build -warnaserror`
7. Commit with a descriptive message
8. Mark the task complete and move to the next one

If any step fails, follow the `dotnet-skills:debugging-and-error-recovery` skill.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/build.md` at pinned SHA `44dac80`
- Status: modified (skill references retargeted to the `dotnet-skills:` prefix; context-loading step names `.editorconfig` / nullable mode / `MyApp.Contracts` as the .NET equivalents of "existing code, patterns, types"; test step names xUnit/MSTest; build/test steps use `dotnet build -warnaserror` / `dotnet test` instead of generic "run the build / run the test suite")
