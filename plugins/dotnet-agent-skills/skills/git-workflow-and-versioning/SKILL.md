---
name: git-workflow-and-versioning
description: Structures git workflow practices for .NET/C# projects — atomic commits, trunk-based branches, pre-commit hygiene with `dotnet test` + `dotnet format`, worktrees for parallel agent work. Use when making any code change to a .NET solution, when committing, branching, resolving conflicts, or organizing work across multiple parallel streams.
version: 0.3.0
source: vendor/agent-skills/skills/git-workflow-and-versioning/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# Git Workflow and Versioning

## Overview

Git is your safety net. Treat commits as save points, branches as sandboxes, and history as documentation. With AI agents generating code at high speed, disciplined version control is the mechanism that keeps changes manageable, reviewable, and reversible.

## When to Use

Always. Every code change flows through git.

## Core Principles

### Trunk-Based Development (Recommended)

Keep `main` always deployable. Work in short-lived feature branches that merge back within 1-3 days. Long-lived development branches are hidden costs — they diverge, create merge conflicts, and delay integration. DORA research consistently shows trunk-based development correlates with high-performing engineering teams.

```
main ──●──●──●──●──●──●──●──●──●──  (always deployable)
        ╲      ╱  ╲    ╱
         ●──●─╱    ●──╱    ← short-lived feature branches (1-3 days)
```

This is the recommended default. Teams using gitflow or long-lived branches can adapt the principles (atomic commits, small changes, descriptive messages) to their branching model — the commit discipline matters more than the specific branching strategy.

- **Dev branches are costs.** Every day a branch lives, it accumulates merge risk.
- **Release branches are acceptable.** When you need to stabilize a release while main moves forward.
- **Feature flags > long branches.** Prefer deploying incomplete work behind flags (`IOptions<FeatureOptions>`) rather than keeping it on a branch for weeks.

### 1. Commit Early, Commit Often

Each successful increment gets its own commit. Don't accumulate large uncommitted changes.

```
Work pattern:
  Implement slice → dotnet test → Verify → Commit → Next slice

Not this:
  Implement everything → Hope it works → Giant commit
```

Commits are save points. If the next change breaks something, you can revert to the last known-good state instantly.

### 2. Atomic Commits

Each commit does one logical thing:

```
# Good: Each commit is self-contained
git log --oneline
a1b2c3d feat: add task creation endpoint with FluentValidation
d4e5f6g feat: add task creation Avalonia view with CommunityToolkit.Mvvm
h7i8j9k feat: wire view to service via DI, add loading state
m1n2o3p test: add xUnit tests for task creation (unit + integration via WebApplicationFactory)

# Bad: Everything mixed together
git log --oneline
x1y2z3a Add task feature, fix sidebar, update Directory.Packages.props, refactor utils
```

### 3. Descriptive Messages

Commit messages explain the *why*, not just the *what*:

```
# Good: Explains intent
feat: add email validation to registration endpoint

Prevents invalid email formats from reaching the database.
Uses FluentValidation at the endpoint level, consistent with
the pattern already in AuthEndpoints (see MyApp/Endpoints/Auth).

# Bad: Describes what's obvious from the diff
update AuthEndpoints.cs
```

**Format:**
```
<type>: <short description>

<optional body explaining why, not what>
```

**Types:**
- `feat` — New feature
- `fix` — Bug fix
- `refactor` — Code change that neither fixes a bug nor adds a feature
- `test` — Adding or updating xUnit/MSTest tests
- `docs` — Documentation only
- `chore` — Tooling, dependencies, config (`Directory.Packages.props`, CI YAML, `.editorconfig`)

### 4. Keep Concerns Separate

Don't combine formatting changes with behavior changes. Don't combine refactors with features. Each type of change should be a separate commit — and ideally a separate PR:

```
# Good: Separate concerns
git commit -m "refactor: extract validation logic to MyApp.Core.Validation"
git commit -m "feat: add phone number validation to registration"

# Bad: Mixed concerns
git commit -m "refactor validation and add phone number field"
```

**Separate refactoring from feature work.** A refactoring change and a feature change are two different changes — submit them separately. This makes each change easier to review, revert, and understand in history. Small cleanups (renaming a local variable) can be included in a feature commit at reviewer discretion. A pure `dotnet format` run always stands alone.

### 5. Size Your Changes

Target ~100 lines per commit/PR. Changes over ~1000 lines should be split. See the splitting strategies in `code-review-and-quality` for how to break down large changes.

```
~100 lines  → Easy to review, easy to revert
~300 lines  → Acceptable for a single logical change
~1000 lines → Split into smaller changes
```

## Branching Strategy

### Feature Branches

```
main (always deployable)
  │
  ├── feature/task-creation    ← One feature per branch
  ├── feature/user-settings    ← Parallel work
  └── fix/duplicate-tasks      ← Bug fixes
```

- Branch from `main` (or the team's default branch)
- Keep branches short-lived (merge within 1-3 days) — long-lived branches are hidden costs
- Delete branches after merge
- Prefer feature flags (`IOptions<FeatureOptions>` read from `appsettings.json` or a flag provider) over long-lived branches for incomplete features

### Branch Naming

```
feature/<short-description>   → feature/task-creation
fix/<short-description>       → fix/duplicate-tasks
chore/<short-description>     → chore/bump-efcore
refactor/<short-description>  → refactor/auth-handler
```

## Working with Worktrees

For parallel AI agent work, use git worktrees to run multiple branches simultaneously — especially useful when each agent needs its own build output (`bin/`, `obj/`) without stomping on other work:

```bash
# Create a worktree for a feature branch
git worktree add ../myapp-feature-a feature/task-creation
git worktree add ../myapp-feature-b feature/user-settings

# Each worktree is a separate directory with its own branch
# Agents can work in parallel without interfering
ls ../
  myapp/              ← main branch
  myapp-feature-a/    ← task-creation branch
  myapp-feature-b/    ← user-settings branch

# Each worktree has its own bin/ and obj/ — no NuGet restore conflicts
# When done, merge and clean up
git worktree remove ../myapp-feature-a
```

Benefits:
- Multiple agents can work on different features simultaneously
- No branch switching needed (each directory has its own branch and its own `bin/`/`obj/`)
- If one experiment fails, delete the worktree — nothing is lost
- Changes are isolated until explicitly merged

## The Save Point Pattern

```
Agent starts work
    │
    ├── Makes a change
    │   ├── dotnet test passes? → Commit → Continue
    │   └── dotnet test fails?  → Revert to last commit → Investigate
    │
    ├── Makes another change
    │   ├── dotnet test passes? → Commit → Continue
    │   └── dotnet test fails?  → Revert to last commit → Investigate
    │
    └── Feature complete → All commits form a clean history
```

This pattern means you never lose more than one increment of work. If an agent goes off the rails, `git reset --hard HEAD` takes you back to the last successful state.

## Change Summaries

After any modification, provide a structured summary. This makes review easier, documents scope discipline, and surfaces unintended changes:

```
CHANGES MADE:
- src/MyApp/Endpoints/TaskEndpoints.cs: Added validation filter to POST endpoint
- src/MyApp.Core/Validation/CreateTaskValidator.cs: New FluentValidation validator

THINGS I DIDN'T TOUCH (intentionally):
- src/MyApp/Endpoints/AuthEndpoints.cs: Has similar validation gap but out of scope
- src/MyApp/Middleware/ErrorMiddleware.cs: ProblemDetails shape could be improved (separate task)

POTENTIAL CONCERNS:
- The validator is strict — rejects extra fields. Confirm this is desired.
- Added FluentValidation to Directory.Packages.props (already a transitive dep via ASP.NET Core; pinning surfaces it explicitly)
```

This pattern catches wrong assumptions early and gives reviewers a clear map of the change. The "DIDN'T TOUCH" section is especially important — it shows you exercised scope discipline and didn't go on an unsolicited renovation.

## Pre-Commit Hygiene

Before every commit:

```bash
# 1. Check what you're about to commit
git diff --staged

# 2. Ensure no secrets
git diff --staged | grep -iE "password|secret|api.?key|connectionstring|bearer"

# 3. Run tests
dotnet test

# 4. Run format check (configuration from .editorconfig + analyzers)
dotnet format --verify-no-changes

# 5. Build with warnings-as-errors (catches analyzer diagnostics)
dotnet build -warnaserror
```

Automate this with a pre-commit hook. For .NET solutions a common choice is [Husky.Net](https://alirezanet.github.io/Husky.Net/):

```xml
<!-- In your tools project or root .config/dotnet-tools.json -->
<PackageReference Include="Husky" Version="*" PrivateAssets="All" />
```

```json
// .husky/task-runner.json
{
  "tasks": [
    { "name": "format",         "command": "dotnet", "args": ["format", "--verify-no-changes"] },
    { "name": "test",           "command": "dotnet", "args": ["test", "--no-restore"] },
    { "name": "build-warnerr",  "command": "dotnet", "args": ["build", "-warnaserror", "--no-restore"] }
  ]
}
```

## Handling Generated Files

- **Commit generated files** only if the project expects them (e.g., `Directory.Packages.props`, EF Core migrations under `Migrations/`)
- **Don't commit** build output (`bin/`, `obj/`), local environment files (`appsettings.Development.json` only if it has no secrets — otherwise `.gitignore` it), or per-user IDE config (`.vs/`, `.vscode/settings.json` unless shared)
- **Have a `.gitignore`** that covers at minimum: `bin/`, `obj/`, `.vs/`, `*.user`, `appsettings.*.local.json`, `TestResults/`, `.idea/`

## Using Git for Debugging

```bash
# Find which commit introduced a bug
git bisect start
git bisect bad HEAD
git bisect good <known-good-commit>
# Git checkouts midpoints; run your test at each to narrow down
git bisect run dotnet test --filter "FullyQualifiedName~FailingTestName"

# View what changed recently
git log --oneline -20
git diff HEAD~5..HEAD -- src/

# Find who last changed a specific line
git blame src/MyApp.Core/Tasks/TaskService.cs

# Search commit messages for a keyword
git log --grep="validation" --oneline
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll commit when the feature is done" | One giant commit is impossible to review, debug, or revert. Commit each slice. |
| "The message doesn't matter" | Messages are documentation. Future you (and future agents) will need to understand what changed and why. |
| "I'll squash it all later" | Squashing destroys the development narrative. Prefer clean incremental commits from the start. |
| "Branches add overhead" | Short-lived branches are free and prevent conflicting work from colliding. Long-lived branches are the problem — merge within 1-3 days. |
| "I'll split this change later" | Large changes are harder to review, riskier to deploy, and harder to revert. Split before submitting, not after. |
| "I don't need a .gitignore" | Until `bin/`, `obj/`, or a `.user` file with a local connection string gets committed. Set it up immediately. |

## Red Flags

- Large uncommitted changes accumulating
- Commit messages like "fix", "update", "misc"
- Formatting-only changes mixed with behavior changes
- No `.gitignore` in the project
- Committing `bin/`, `obj/`, `.vs/`, `appsettings.*.local.json`, or `.pfx` / `.pem` key files
- Long-lived branches that diverge significantly from main
- Force-pushing to shared branches
- Amending a commit that has already been pushed to a shared branch

## Verification

For every commit:

- [ ] Commit does one logical thing
- [ ] Message explains the why, follows type conventions
- [ ] `dotnet test` passes before committing
- [ ] `dotnet build -warnaserror` is clean
- [ ] `dotnet format --verify-no-changes` is clean (or run `dotnet format` and commit the result separately)
- [ ] No secrets in the diff
- [ ] No formatting-only changes mixed with behavior changes
- [ ] `.gitignore` covers standard .NET exclusions

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/git-workflow-and-versioning/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - Work-pattern blocks substitute `dotnet test` for the generic "Test" step
  - Atomic-commit example rewritten for a .NET task feature: FluentValidation endpoint, Avalonia view with CommunityToolkit.Mvvm, xUnit + WebApplicationFactory tests
  - Commit-message example rewritten for FluentValidation at endpoint level
  - `chore` examples mention `Directory.Packages.props`, CI YAML, `.editorconfig`
  - Refactor-separation bullet calls out `dotnet format` runs as standalone commits
  - Feature-flag references swap the generic WIP-flag pattern for `IOptions<FeatureOptions>`
  - Worktree example uses .NET directory naming and calls out per-worktree `bin/`/`obj/` (avoids NuGet restore conflicts across parallel agents)
  - Change-summary template uses `MyApp.Core.Validation`, `Directory.Packages.props`
  - Pre-commit block replaces `npm test` / `npm run lint` / `npx tsc --noEmit` with `dotnet test` / `dotnet format --verify-no-changes` / `dotnet build -warnaserror`; secret grep adds `connectionstring` and `bearer`
  - Pre-commit automation example replaces `lint-staged` + husky with [Husky.Net](https://alirezanet.github.io/Husky.Net/) + `task-runner.json`
  - Handling Generated Files rewritten for .NET: `Directory.Packages.props`, EF Core `Migrations/`, `bin/`, `obj/`, `.vs/`, `*.user`, `appsettings.*.local.json`, `TestResults/`
  - `git bisect run` command uses `dotnet test --filter`
  - `git blame` / `.gitignore` examples use `.cs` paths
  - Red-flag list adds `.pfx`/`.pem` key files and amending pushed commits on shared branches
  - Preserved verbatim: trunk-based development rationale, five core principles, branch naming, Save Point pattern, debugging-with-git sub-commands beyond bisect, Common Rationalizations table frame
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
