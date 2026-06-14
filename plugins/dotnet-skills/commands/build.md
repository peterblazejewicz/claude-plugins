---
description: Implement tasks incrementally in .NET — RED/GREEN/REFACTOR, `dotnet build`, `dotnet test`, commit. Add "auto" to run the whole plan in one approved pass.
argument-hint: "[auto]"
---

Invoke the `dotnet-skills:incremental-implementation` skill alongside `dotnet-skills:test-driven-development`.

## Modes

- **`/build`** — implement the *next* pending task, then stop (careful, one slice at a time).
- **`/build auto`** — generate the plan if needed, get a single approval, then implement *every* task without stopping between them.

`$ARGUMENTS` selects the mode. Treat `auto` (canonical) or `all` as autonomous mode; anything else (or empty) is the default single-task mode. Autonomous mode is not faster *per task* — it runs the same test-driven loop — it only removes the human stepping *between* tasks.

## Default: one task

Pick the next pending task from the plan. Then:

1. Read the task's acceptance criteria
2. Load relevant context — existing C# code, project conventions, analyzer settings (`.editorconfig`, nullable reference-type mode), types in `MyApp.Contracts` / `MyApp.Core`
3. Write a failing xUnit or MSTest test for the expected behavior (RED)
4. Implement the minimum C# code to pass the test (GREEN)
5. Run the full test suite to check for regressions: `dotnet test`
6. Run the build with warnings-as-errors to verify compilation: `dotnet build -warnaserror`
7. Commit with a descriptive message
8. Mark the task complete and stop

## Autonomous: the whole plan (`/build auto`)

Use this once a spec exists and you want to collapse plan + build into one run. It removes the manual stepping between tasks — **not** the verification. Every task still earns a passing test and its own commit.

1. **Require a spec.** Look only for a spec at a known path: `SPEC.md` at the repo root, `docs/SPEC.md`, or a file under `spec/`. A README or arbitrary doc does **not** count. If none exists, stop and tell the user to run `/spec` first — do not invent requirements.
2. **Establish a clean baseline.** Run `git status --porcelain`. If there are uncommitted changes outside the expected planning artifacts (`SPEC.md`, `docs/SPEC.md`, `spec/*`, `tasks/plan.md`, `tasks/todo.md`), stop and ask the user to commit, stash, or confirm how to handle them. Autonomous per-task commits must not absorb unrelated local work, or the clean-rollback guarantee breaks.
3. **Plan if needed.** If there is no `tasks/plan.md`, invoke `dotnet-skills:planning-and-task-breakdown` to generate one.
4. **Single checkpoint.** Present the full plan and wait for an unambiguous affirmative (e.g. "approve", "go", "yes"). Treat hedged responses ("looks reasonable", "I guess") as **not** approved. This is the only human gate — after approval, run autonomously. If you generated `tasks/plan.md`, commit it as a single preparatory commit now so it doesn't bleed into the first task's commit.
5. **Execute every task in dependency order.** Use each task's declared dependencies; if they aren't explicit, execute in the order the plan lists them. For each task, run the full default loop above (RED → GREEN → `dotnet test` regression → `dotnet build -warnaserror` → commit → mark complete). Stage only the files that task touched plus its task-status update — never `git add -A` blindly — and make one commit per task so any point is a clean rollback.
6. **Stop and ask the user** (do not push through) when:
   - a test can't be made to pass or the build breaks without an obvious fix → follow `dotnet-skills:debugging-and-error-recovery`
   - the spec is ambiguous, or a task needs a decision the spec doesn't cover
   - a task is high-risk or irreversible — auth/permission changes, **destructive EF Core migrations** (dropping or renaming columns/tables, data backfills), changes behind a **feature-flag gate** (`IOptions<FeatureOptions>` / `Microsoft.FeatureManagement`), payments, deletions, deploys, anything touching secrets, **or anything you can't undo with `git revert`** → follow `dotnet-skills:doubt-driven-development` and get explicit sign-off before continuing

   After the user resolves a blocker, they re-invoke `/build auto` — it resumes from the next pending task.
7. **Summarize at the end:** tasks completed, tests added, commits made, and anything skipped, flagged, or left for the user.

If any step fails, follow the `dotnet-skills:debugging-and-error-recovery` skill.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/build.md` at pinned SHA `3a6fc63`
- Status: modified (skill references retargeted to the `dotnet-skills:` prefix; context-loading step names `.editorconfig` / nullable mode / `MyApp.Contracts` as the .NET equivalents of "existing code, patterns, types"; test step names xUnit/MSTest; build/test steps use `dotnet build -warnaserror` / `dotnet test` instead of generic "run the build / run the test suite")
- **Upstream sync 2026-06-14 (plugin v2.6.0)** — ported the upstream `/build auto` autonomous mode (PR #220), retargeted to .NET. Added the `## Modes` split (default single-task vs `auto`/`all`), the spec-required closed path set (`SPEC.md` / `docs/SPEC.md` / `spec/*`), the `git status --porcelain` clean-baseline gate, the single unambiguous-approval checkpoint with a preparatory `tasks/plan.md` commit, the per-task `dotnet test` → `dotnet build -warnaserror` → scoped-stage → one-commit loop (no blind `git add -A`), and the resume contract. The high-risk pause list extends upstream's with **destructive EF Core migrations** and **feature-flag (`IOptions<FeatureOptions>` / `Microsoft.FeatureManagement`) gates**, and routes sign-off through `dotnet-skills:doubt-driven-development`. References `dotnet-skills:planning-and-task-breakdown` for plan generation. Default single-task behavior is unchanged.
