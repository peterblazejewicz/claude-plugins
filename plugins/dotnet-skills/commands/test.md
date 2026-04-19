---
description: Run .NET TDD workflow — write failing xUnit/MSTest tests, implement, verify. For bugs, use the Prove-It pattern.
---

Invoke the `dotnet-skills:test-driven-development` skill.

For new features:

1. Write xUnit or MSTest tests that describe the expected behavior (they should FAIL)
2. Implement the C# code to make them pass
3. Refactor while keeping tests green — run `dotnet test` after each change

For bug fixes (Prove-It pattern):

1. Write a test that reproduces the bug (must FAIL)
2. Confirm the test fails: `dotnet test --filter FullyQualifiedName~<NewTest>`
3. Implement the fix
4. Confirm the test passes
5. Run the full test suite for regressions: `dotnet test`

For integration-boundary issues — HTTP endpoints, EF Core queries against a real database, Blazor/Razor pages in a real browser, or Avalonia views — also invoke `dotnet-skills:integration-testing-dotnet` to cover `WebApplicationFactory<T>`, Testcontainers, `Microsoft.Playwright`, and `Avalonia.Headless.XUnit`.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/test.md` at pinned SHA `44dac80`
- Status: modified (skill references retargeted to the `dotnet-skills:` prefix; **critical substitution**: upstream's `agent-skills:browser-testing-with-devtools` does not exist downstream — rewritten as `dotnet-skills:integration-testing-dotnet`, which covers the four .NET integration boundaries; framework labels changed from generic "tests" to "xUnit or MSTest tests"; commands use `dotnet test --filter FullyQualifiedName~...` for single-test runs)
