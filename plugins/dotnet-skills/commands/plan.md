---
description: Break .NET work into small verifiable tasks with acceptance criteria, `dotnet` CLI verification steps, and dependency ordering
---

Invoke the `dotnet-skills:planning-and-task-breakdown` skill.

Read the existing spec (`SPEC.md` or equivalent) and the relevant parts of the solution — `*.sln`, `Directory.Packages.props`, `global.json`, affected `.csproj` files, and the projects they touch. Then:

1. Enter plan mode — read only, no code changes
2. Identify the dependency graph between projects and between the tasks themselves (e.g. EF Core model → migration → repository → endpoint → tests)
3. Slice work vertically (one complete path per task, not horizontal layers per project)
4. Write tasks with acceptance criteria and concrete verification steps — `dotnet build -warnaserror`, `dotnet test --filter FullyQualifiedName~Xxx`, `dotnet format --verify-no-changes`
5. Add checkpoints between phases
6. Present the plan for human review

Save the plan to `tasks/plan.md` and the task list to `tasks/todo.md`.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/plan.md` at pinned SHA `44dac80`
- Status: modified (skill reference retargeted to the `dotnet-skills:` prefix; codebase-reading list names .NET-specific artifacts `*.sln` / `Directory.Packages.props` / `global.json` / `.csproj`; dependency-graph example names an EF Core vertical slice; verification steps use `dotnet build -warnaserror` / `dotnet test --filter` / `dotnet format --verify-no-changes`)
