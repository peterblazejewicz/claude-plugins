---
name: test-driven-development
description: Drives .NET/C# development with tests — RED/GREEN/REFACTOR with xUnit or MSTest, the Prove-It Pattern for bug fixes, the test pyramid with `WebApplicationFactory` for integration and `Playwright`/`Avalonia.Headless` for E2E. Use when implementing any logic, fixing any bug, or changing any behavior.
version: 0.4.0
source: vendor/agent-skills/skills/test-driven-development/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Test-Driven Development

## Overview

Write a failing test before writing the code that makes it pass. For bug fixes, reproduce the bug with a test before attempting a fix. Tests are proof — "seems right" is not done. A codebase with good tests is an AI agent's superpower; a codebase without tests is a liability.

## When to Use

- Implementing any new logic or behavior
- Fixing any bug (the Prove-It Pattern)
- Modifying existing functionality
- Adding edge case handling
- Any change that could break existing behavior

**When NOT to use:** Pure configuration changes, documentation updates, or static content changes that have no behavioral impact.

**Related:** For HTTP and UI integration, combine TDD with `integration-testing-dotnet` — that skill covers `WebApplicationFactory<T>`, Testcontainers, `Microsoft.Playwright`, and `Avalonia.Headless` for Blazor / ASP.NET Core / Avalonia tests respectively.

## The TDD Cycle

```
    RED                GREEN              REFACTOR
 Write a test    Write minimal code    Clean up the
 that fails  ──→  to make it pass  ──→  implementation  ──→  (repeat)
      │                  │                    │
      ▼                  ▼                    ▼
   Test FAILS        Test PASSES         Tests still PASS
```

### Step 1: RED — Write a Failing Test

Write the test first. It must fail. A test that passes immediately proves nothing.

Both xUnit and MSTest are first-class in the .NET world; pick one per project and stick to it. Examples below are shown in both.

```csharp
// xUnit
public sealed class TaskServiceTests
{
    private readonly TaskService _service = new();

    [Fact]
    public async Task CreateTaskAsync_WithTitle_ReturnsTaskWithDefaultStatus()
    {
        // RED: This test fails because CreateTaskAsync doesn't exist yet
        var task = await _service.CreateTaskAsync(new CreateTaskInput("Buy groceries"));

        Assert.NotEqual(default, task.Id);
        Assert.Equal("Buy groceries", task.Title);
        Assert.Equal(TaskStatus.Pending, task.Status);
        Assert.True(task.CreatedAt <= DateTimeOffset.UtcNow);
    }
}
```

```csharp
// MSTest
[TestClass]
public sealed class TaskServiceTests
{
    private readonly TaskService _service = new();

    [TestMethod]
    public async Task CreateTaskAsync_WithTitle_ReturnsTaskWithDefaultStatus()
    {
        // RED
        var task = await _service.CreateTaskAsync(new CreateTaskInput("Buy groceries"));

        Assert.AreNotEqual(default, task.Id);
        Assert.AreEqual("Buy groceries", task.Title);
        Assert.AreEqual(TaskStatus.Pending, task.Status);
        Assert.IsTrue(task.CreatedAt <= DateTimeOffset.UtcNow);
    }
}
```

FluentAssertions (works with both xUnit and MSTest) makes assertions more readable; pair with xUnit for the most common .NET convention:

```csharp
task.Id.Should().NotBe(default(TaskId));
task.Title.Should().Be("Buy groceries");
task.Status.Should().Be(TaskStatus.Pending);
task.CreatedAt.Should().BeOnOrBefore(DateTimeOffset.UtcNow);
```

### Step 2: GREEN — Make It Pass

Write the minimum code to make the test pass. Don't over-engineer:

```csharp
public sealed class TaskService
{
    public Task<TaskDto> CreateTaskAsync(CreateTaskInput input, CancellationToken cancellationToken = default)
    {
        var task = new TaskDto(
            Id: TaskId.New(),
            Title: input.Title,
            Status: TaskStatus.Pending,
            CreatedAt: DateTimeOffset.UtcNow);

        // Persist via DbContext in a later slice; minimal is "it compiles and passes the test."
        return Task.FromResult(task);
    }
}

public readonly record struct TaskId(Guid Value)
{
    public static TaskId New() => new(Guid.NewGuid());
}

public sealed record CreateTaskInput(string Title);
public sealed record TaskDto(TaskId Id, string Title, TaskStatus Status, DateTimeOffset CreatedAt);
public enum TaskStatus { Pending, InProgress, Completed, Cancelled }
```

### Step 3: REFACTOR — Clean Up

With tests green, improve the code without changing behavior:

- Extract shared logic into private methods or helpers
- Improve naming
- Remove duplication
- Swap `DateTimeOffset.UtcNow` for an injected `TimeProvider` so time-dependent tests aren't flaky
- Optimize if `BenchmarkDotNet` measurements justify it

Run `dotnet test` after every refactor step to confirm nothing broke.

## The Prove-It Pattern (Bug Fixes)

When a bug is reported, **do not start by trying to fix it.** Start by writing a test that reproduces it.

```
Bug report arrives
       │
       ▼
  Write a test that demonstrates the bug
       │
       ▼
  Test FAILS (confirming the bug exists)
       │
       ▼
  Implement the fix
       │
       ▼
  Test PASSES (proving the fix works)
       │
       ▼
  Run full test suite (no regressions): `dotnet test`
```

**Example:**

```csharp
// Bug: "Completing a task doesn't update the CompletedAt timestamp"

// Step 1: Write the reproduction test (it should FAIL)
[Fact]
public async Task CompleteTaskAsync_SetsCompletedAtTimestamp()
{
    var created = await _service.CreateTaskAsync(new CreateTaskInput("Test"));

    var completed = await _service.CompleteTaskAsync(created.Id);

    completed.Status.Should().Be(TaskStatus.Completed);
    completed.CompletedAt.Should().NotBeNull();  // This fails → bug confirmed
}

// Step 2: Fix the bug
public async Task<TaskDto> CompleteTaskAsync(TaskId id, CancellationToken cancellationToken = default)
{
    var task = await _repository.GetByIdAsync(id, cancellationToken);
    var completed = task with
    {
        Status = TaskStatus.Completed,
        CompletedAt = _timeProvider.GetUtcNow(),  // This was missing
    };
    await _repository.UpdateAsync(completed, cancellationToken);
    return completed;
}

// Step 3: Test passes → bug fixed, regression guarded
```

## The Test Pyramid

Invest testing effort according to the pyramid — most tests should be small and fast, with progressively fewer tests at higher levels:

```
          ╱╲
         ╱  ╲         E2E Tests (~5%)
        ╱    ╲        Full user flows:
       ╱──────╲         Blazor/Razor → Microsoft.Playwright
      ╱        ╲        Avalonia     → Avalonia.Headless.XUnit
     ╱          ╲     Integration Tests (~15%)
    ╱            ╲      API boundary → WebApplicationFactory<TEntryPoint>
   ╱──────────────╲     DB           → Testcontainers (Postgres/MSSQL/Redis)
  ╱                ╲   Unit Tests (~80%)
 ╱                  ╲   Pure logic, isolated, milliseconds each
╱────────────────────╲  xUnit / MSTest + FluentAssertions
```

**The Beyonce Rule:** If you liked it, you should have put a test on it. Infrastructure changes, refactoring, and migrations are not responsible for catching your bugs — your tests are. If a change breaks your code and you didn't have a test for it, that's on you.

### Test Sizes (Resource Model)

Beyond the pyramid levels, classify tests by what resources they consume:

| Size | Constraints | Speed | Example in .NET |
|------|------------|-------|-----------------|
| **Small** | Single process, no I/O, no network, no database | Milliseconds | Pure domain tests in `MyApp.Core.Tests`, value-type tests |
| **Medium** | Multi-process OK, localhost only, no external services | Seconds | `WebApplicationFactory` HTTP tests with SQLite or Testcontainers; `Avalonia.Headless` UI tests |
| **Large** | Multi-machine OK, external services allowed | Minutes | Full `Microsoft.Playwright` E2E runs against a staged deployment; BenchmarkDotNet perf suites |

Small tests should make up the vast majority of your suite. They're fast, reliable, and easy to debug when they fail.

### Decision Guide

```
Is it pure logic with no side effects?
  → Unit test (xUnit/MSTest in MyApp.Core.Tests)

Does it cross a boundary (HTTP, EF Core, file system, message bus)?
  → Integration test (WebApplicationFactory + Testcontainers in MyApp.Integration.Tests)

Is it a critical user flow that must work end-to-end in a real browser or UI?
  → E2E test (Playwright.NET or Avalonia.Headless) — limit these to critical paths
```

## Writing Good Tests

### Test State, Not Interactions

Assert on the *outcome* of an operation, not on which methods were called internally. Tests that verify method-call sequences break when you refactor, even if the behavior is unchanged.

```csharp
// Good: Tests what the service does (state-based)
[Fact]
public async Task ListTasks_SortedByCreationDate_NewestFirst()
{
    var tasks = await _service.ListAsync(new ListTasksParams(SortBy: "createdAt", SortOrder: "desc"));

    tasks.Data.Should().BeInDescendingOrder(t => t.CreatedAt);
}

// Bad: Tests how the service works internally (interaction-based using Moq/NSubstitute)
[Fact]
public async Task ListTasks_CallsDbContextWithOrderByDesc()
{
    await _service.ListAsync(new ListTasksParams(SortBy: "createdAt", SortOrder: "desc"));

    _dbContextMock.Verify(db => db.Tasks.OrderByDescending(It.IsAny<Expression<Func<Task, DateTimeOffset>>>()),
                          Times.Once);
}
```

### DAMP Over DRY in Tests

In production code, DRY (Don't Repeat Yourself) is usually right. In tests, **DAMP (Descriptive And Meaningful Phrases)** is better. A test should read like a specification — each test should tell a complete story without requiring the reader to trace through shared helpers.

```csharp
// DAMP: Each test is self-contained and readable
[Fact]
public void CreateTask_WithEmptyTitle_Throws()
{
    var input = new CreateTaskInput("");
    Action act = () => _service.Create(input);
    act.Should().Throw<ValidationException>().WithMessage("*Title is required*");
}

[Fact]
public void CreateTask_TrimsWhitespaceFromTitle()
{
    var input = new CreateTaskInput("  Buy groceries  ");
    var task = _service.Create(input);
    task.Title.Should().Be("Buy groceries");
}

// Over-DRY: Shared parameterized setup that obscures what each test actually verifies
// (Don't do this just to avoid repeating the input shape)
```

Some duplication in tests is acceptable when it makes each test independently understandable. Reach for `[Theory]` / `[InlineData]` (xUnit) or `[DataRow]` (MSTest) when the variation itself is the point of the test, not to collapse conceptually different tests into one.

### Prefer Real Implementations Over Mocks

Use the simplest test double that gets the job done. The more your tests use real code, the more confidence they provide.

```
Preference order (most to least preferred):
1. Real implementation  → Highest confidence, catches real bugs
2. Fake                 → In-memory version (e.g., EF Core InMemory provider, in-memory IDistributedCache)
3. Stub                 → Returns canned data, no behavior (hand-written Test class that implements the interface)
4. Mock (interaction)   → Moq / NSubstitute verifying method calls — use sparingly
```

For EF Core, prefer SQLite in-memory or Testcontainers over the `Microsoft.EntityFrameworkCore.InMemory` provider — the in-memory provider doesn't enforce relational constraints, so tests pass against it that would fail in production.

**Use mocks only when:** the real implementation is too slow (external APIs), non-deterministic (random, wall-clock time), or has side effects you can't control (email sending, payment processing). Over-mocking creates tests that pass while production breaks.

### Use `TimeProvider` for Time-Dependent Logic

.NET 8+ ships `TimeProvider` — inject it instead of calling `DateTimeOffset.UtcNow` directly, then use `FakeTimeProvider` (from `Microsoft.Extensions.TimeProvider.Testing`) in tests:

```csharp
public sealed class TaskService(ITaskRepository repository, TimeProvider timeProvider)
{
    public TaskDto MarkOverdue(TaskDto task)
    {
        var now = timeProvider.GetUtcNow();
        return task with { IsOverdue = task.Deadline < now };
    }
}

[Fact]
public void MarkOverdue_DeadlinePassed_SetsOverdueFlag()
{
    var time = new FakeTimeProvider(new DateTimeOffset(2026, 1, 2, 0, 0, 0, TimeSpan.Zero));
    var service = new TaskService(_repository, time);

    var task = new TaskDto(/* ... */, Deadline: new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero));
    var result = service.MarkOverdue(task);

    result.IsOverdue.Should().BeTrue();
}
```

### Use the Arrange-Act-Assert Pattern

```csharp
[Fact]
public void MarkOverdue_DeadlinePassed_SetsOverdueFlag()
{
    // Arrange
    var time = new FakeTimeProvider(new DateTimeOffset(2026, 1, 2, 0, 0, 0, TimeSpan.Zero));
    var service = new TaskService(_repository, time);
    var task = new TaskDto(/* ... */, Deadline: new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero));

    // Act
    var result = service.MarkOverdue(task);

    // Assert
    result.IsOverdue.Should().BeTrue();
}
```

### One Assertion Per Concept

```csharp
// Good: Each test verifies one behavior
[Fact] public void Create_RejectsEmptyTitle() { /* ... */ }
[Fact] public void Create_TrimsWhitespaceFromTitle() { /* ... */ }
[Fact] public void Create_EnforcesMaxTitleLength() { /* ... */ }

// Bad: Everything in one test
[Fact]
public void Create_ValidatesTitlesCorrectly()
{
    Assert.Throws<ValidationException>(() => _service.Create(new("")));
    Assert.Equal("hello", _service.Create(new("  hello  ")).Title);
    Assert.Throws<ValidationException>(() => _service.Create(new(new string('a', 256))));
}
```

### Name Tests Descriptively

A common .NET convention is `MethodUnderTest_Scenario_ExpectedResult`:

```csharp
// Good: reads like a specification
public class TaskService_CompleteTaskAsync_Tests
{
    [Fact] public Task SetsStatusToCompletedAndRecordsTimestamp() { /* ... */ return Task.CompletedTask; }
    [Fact] public Task ThrowsNotFoundException_WhenTaskDoesNotExist() { /* ... */ return Task.CompletedTask; }
    [Fact] public Task IsIdempotent_CompletingAlreadyCompletedTaskIsNoOp() { /* ... */ return Task.CompletedTask; }
    [Fact] public Task SendsNotificationToAssignee() { /* ... */ return Task.CompletedTask; }
}

// Bad: Vague names
public class TaskServiceTests
{
    [Fact] public void Works() { }
    [Fact] public void HandlesErrors() { }
    [Fact] public void Test3() { }
}
```

## Test Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Testing implementation details | Tests break when refactoring even if behavior is unchanged | Test inputs and outputs, not internal structure |
| Flaky tests (timing, order-dependent) | Erode trust in the test suite; `[Fact(Skip = "…")]` accumulates | Use deterministic assertions, `FakeTimeProvider`, per-test `DbContext` scoping |
| Testing framework code | Wastes time testing BCL/EF Core behavior | Only test YOUR code |
| Snapshot abuse (e.g. Verify.Xunit on sprawling objects) | Large snapshots nobody reviews, break on any change | Use sparingly and review every change |
| No test isolation | Tests pass individually but fail together (shared static state, shared `DbContext`) | Each test sets up and tears down its own fixture; use `IClassFixture` / `ICollectionFixture` intentionally |
| Mocking everything | Tests pass but production breaks | Prefer real > fakes > stubs > mocks. Mock only at non-deterministic or external boundaries |
| `Microsoft.EntityFrameworkCore.InMemory` for anything serious | Doesn't enforce relational constraints; false confidence | Use SQLite in-memory or Testcontainers with the real provider |
| `.Result` / `.Wait()` in test bodies | Deadlocks; muddies stack traces | `async Task` test methods and `await` everywhere |

## When to Use Subagents for Testing

For complex bug fixes, spawn a subagent to write the reproduction test:

```
Main agent: "Spawn a subagent to write a test that reproduces this bug:
[bug description]. The test should fail with the current code."

Subagent: Writes the reproduction test (xUnit or MSTest, matching
          the project convention).

Main agent: Verifies the test fails (`dotnet test --filter ...`),
            then implements the fix, then verifies the test passes.
```

This separation ensures the test is written without knowledge of the fix, making it more robust.

## See Also

- Upstream testing-patterns reference (generic, pre-dates this adaptation): [`../../vendor/agent-skills/references/testing-patterns.md`](../../vendor/agent-skills/references/testing-patterns.md)
- For HTTP / browser / desktop integration testing, see [`integration-testing-dotnet`](../integration-testing-dotnet/SKILL.md) — covers `WebApplicationFactory<TEntryPoint>`, Testcontainers, `Microsoft.Playwright`, and `Avalonia.Headless.XUnit`
- xUnit docs: https://xunit.net/
- MSTest docs: https://learn.microsoft.com/dotnet/core/testing/unit-testing-mstest-intro
- `TimeProvider`: https://learn.microsoft.com/dotnet/api/system.timeprovider

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll write tests after the code works" | You won't. And tests written after the fact test implementation, not behavior. |
| "This is too simple to test" | Simple code gets complicated. The test documents the expected behavior. |
| "Tests slow me down" | Tests slow you down now. They speed you up every time you change the code later. |
| "I tested it manually" | Manual testing doesn't persist. Tomorrow's change might break it with no way to know. |
| "The code is self-explanatory" | Tests ARE the specification. They document what the code should do, not what it does. |
| "It's just a prototype" | Prototypes become production code. Tests from day one prevent the "test debt" crisis. |
| "EF Core InMemory is good enough for tests" | It skips relational constraints. You'll discover that the day you deploy to Postgres. Use SQLite in-memory or Testcontainers. |
| "I'll use DateTime.UtcNow — it's fine" | Time-dependent tests go flaky the minute someone runs them on a slow CI machine. Inject `TimeProvider` from day one. |

## Red Flags

- Writing code without any corresponding tests
- Tests that pass on the first run (they may not be testing what you think)
- "All tests pass" but `dotnet test` output shows `Skipped` or `Passed: 0`
- Bug fixes without reproduction tests
- Tests that test BCL / EF Core behavior instead of application behavior
- Test names that don't describe the expected behavior
- `[Fact(Skip = "…")]` / `[Ignore]` added to make the suite pass
- `.Result` or `.Wait()` in test bodies
- Mocking `DbContext` directly instead of using a real provider (SQLite or Testcontainers)
- A solution with no `tests/` directory

## Verification

After completing any implementation:

- [ ] Every new behavior has a corresponding xUnit or MSTest test
- [ ] All tests pass: `dotnet test`
- [ ] Bug fixes include a reproduction test that failed before the fix
- [ ] Test names describe the behavior being verified (`MethodUnderTest_Scenario_Expected` convention)
- [ ] No tests are `[Fact(Skip = "…")]` / `[Ignore]` without a linked issue
- [ ] Time-dependent logic uses `TimeProvider` injected via DI; tests use `FakeTimeProvider`
- [ ] Integration tests use a real provider (SQLite or Testcontainers), not `EntityFrameworkCore.InMemory`
- [ ] Coverage hasn't decreased (`dotnet test --collect:"XPlat Code Coverage"` if tracked)

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/test-driven-development/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - All TypeScript/Jest examples rewritten as dual xUnit + MSTest (with FluentAssertions note) for both the RED step and the Prove-It Pattern; GREEN step uses C# records + `TaskId` strongly-typed ID + `TimeProvider`
  - REFACTOR step mentions `TimeProvider` injection and `BenchmarkDotNet`-justified optimization
  - Test Pyramid labels call out the concrete .NET tooling at each tier (xUnit/MSTest at the base, `WebApplicationFactory` + Testcontainers at the middle, Playwright.NET + Avalonia.Headless at the top)
  - Test Sizes table retargeted: `MyApp.Core.Tests`, `WebApplicationFactory`, SQLite/Testcontainers, Playwright E2E, BenchmarkDotNet
  - Decision Guide uses .NET-specific project names (`MyApp.Integration.Tests`, Playwright.NET, Avalonia.Headless)
  - State-vs-interaction example rewritten with xUnit + FluentAssertions and Moq counter-example
  - DAMP example rewritten in C# with `[Theory]`/`[InlineData]` (xUnit) and `[DataRow]` (MSTest) pointer for parameterized variation
  - "Prefer Real Implementations" table mentions EF Core SQLite in-memory, Testcontainers, Moq/NSubstitute; added explicit warning against `Microsoft.EntityFrameworkCore.InMemory` (no relational constraint enforcement)
  - Added new "Use `TimeProvider` for Time-Dependent Logic" section (.NET 8+ `TimeProvider` + `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing`) — not in upstream
  - Arrange-Act-Assert + One-Assertion-Per-Concept + Name-Tests-Descriptively examples rewritten with xUnit + `MethodUnderTest_Scenario_Expected` naming convention
  - Anti-patterns table adds: `EntityFrameworkCore.InMemory` false confidence, `.Result`/`.Wait()` deadlocks, `IClassFixture`/`ICollectionFixture` scoping, `Verify.Xunit` snapshot abuse
  - Removed upstream's "Browser Testing with DevTools" section entirely and replaced with a pointer to the new `integration-testing-dotnet` skill (which covers the .NET equivalent)
  - Subagent section uses `dotnet test --filter`
  - Added "See Also" links to xUnit docs, MSTest docs, `TimeProvider` API reference
  - Rationalizations table adds rows on EF Core InMemory and `DateTime.UtcNow` vs `TimeProvider`
  - Red-flag list adds `.Result`/`.Wait()`, mocking `DbContext`, missing `tests/` directory, `[Fact(Skip = "…")]`
  - Verification checklist retargeted to `dotnet test`, `TimeProvider` + `FakeTimeProvider`, real EF Core provider, `--collect:"XPlat Code Coverage"`
  - Preserved verbatim: TDD cycle diagram, Step 1/2/3 structure, Prove-It Pattern flowchart, Test Pyramid diagram, Beyonce Rule, Arrange-Act-Assert frame, Common Rationalizations and Red Flags structure
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
