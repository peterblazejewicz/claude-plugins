# .NET Agent Skills — Claude Code Plugin

Agent skills for **.NET 8+ (LTS or newer)** development, adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills). Covers spec → plan → build → verify → review → ship with a .NET/C# focus: Avalonia UI first, then ASP.NET Core, Blazor, and .NET MAUI. Testing with xUnit and MSTest; data access with EF Core.

## Status

`2.5.1` — **Fix Copilot CLI install warnings.** Relocates the ported persona-directory README from `agents/README.md` to `references/agents-overview.md` so Copilot CLI's agent loader stops scanning it as a malformed agent. Copilot CLI scans every `.md` file in a plugin's `agents/` directory (not just `*.agent.md`, despite what the CLI docs say); a frontmatter-less README therefore produced `custom agent markdown frontmatter is malformed` warnings at install time ([github/copilot-cli#2187](https://github.com/github/copilot-cli/issues/2187) open, no exclusion mechanism exists). Cross-links in all 6 persona files and in `commands/dotnet-skills.md` rebased to the new path. No functional change to any persona or skill — installs cleanly on both Claude Code and Copilot CLI now.

`2.5.0` — **GitHub Copilot CLI compatibility.** Adds `.agent.md` wrappers alongside the three Claude Code subagents (`code-reviewer`, `security-auditor`, `test-engineer`) so they're invocable on Copilot CLI as `/agent code-reviewer`, `/agent security-auditor`, `/agent test-engineer`. The existing `marketplace.json` already works as a Copilot CLI marketplace (confirmed live — Copilot CLI reads `.claude-plugin/marketplace.json` directly). `plugin.json` enriched with `author` / `license` / `repository` / `homepage` / `keywords` / `category` fields that feed Copilot's `/plugin` discovery UI (Claude Code ignores them; the strict schema allows them). All 21 `SKILL.md` files already portable across both tools — the Agent Skills frontmatter is a cross-vendor standard. Custom slash commands are not a Copilot CLI surface yet ([github/copilot-cli#618](https://github.com/github/copilot-cli/issues/618) open) — Copilot users get the three agent entry points plus skill auto-activation; the 8 Claude Code commands remain unchanged.

Prior releases: `2.4.1` surfaced the `/ship` fan-out + new agent docs in the catalog. `2.4.0` restructured `/ship` as a three-phase fan-out orchestrator (Phase A parallel personas; Phase B .NET pre-launch checklist; Phase C go/no-go with rollback); ported upstream `agents/README.md` + `references/orchestration-patterns.md` with .NET framing. `2.3.0` dropped FluentAssertions everywhere and made xUnit v3 + Microsoft.Testing.Platform canonical — native `Xunit.Assert.X` / MSTest `Assert.X` across 9 files (FluentAssertions v8 moved to the XCEED source-available license in January 2025; v7.x is the last Apache-2.0 line); `Avalonia.Headless.XUnit` version-cliff callout (xUnit v3 requires Avalonia 12 — April 2026; 11.x stays on xUnit v2). `2.2.1` hotfix removed an invalid `"agents": "./agents/"` entry from `plugin.json` that slipped into 2.2.0 and broke install-time manifest validation (Claude Code auto-discovers `./agents/` by convention — no field required). `2.2.0` added 3 .NET-adapted subagents ported from the upstream `agents/` set. `2.1.0` added 7 short slash-command wrappers (`/spec`, `/plan`, `/build`, `/test`, `/review`, `/code-simplify`, `/ship`) adapted from the upstream `.claude/commands/` set. `2.0.0` renamed the plugin from `dotnet-agent-skills` to `dotnet-skills` (breaking). `1.0.0` landed the meta skill `using-agent-skills`; `1.0.1` added an xUnit v3 + Microsoft.Testing.Platform patch; `1.0.2` moved maintenance artifacts out of the installed plugin surface; `1.0.3` and `1.0.4` closed two rounds of external review with contrasting examples, host-model lens notes, library `ConfigureAwait(false)` guidance, EF Core raw-SQL overload clarifications, the `SynchronizationContext` deadlock warning on the Adapter Pattern, and the strongly-typed ID JSON converter.

## Attribution

This plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT © 2025 Addy Osmani). It is **not** a GitHub fork — upstream content is adapted skill-by-skill into `skills/` with .NET/C# adaptations.

- Upstream license: MIT — see [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt)
- Attribution summary: [`NOTICE.md`](./NOTICE.md)

Every ported skill carries a `Source & Modifications` footer linking back to the upstream file at the pinned commit.

## Installation

### Claude Code

```bash
claude plugins marketplace add peterblazejewicz/claude-plugins
claude plugins install dotnet-skills
```

### GitHub Copilot CLI

**Preferred — via the plugin marketplace** (Copilot CLI 1.x, GA Feb 2026):

```bash
copilot plugin marketplace add peterblazejewicz/claude-plugins
# then inside copilot:
/plugin install dotnet-skills@blazejewicz-claude-plugins
```

Copilot CLI reads the same `.claude-plugin/marketplace.json` as Claude Code — no second marketplace to maintain. Skills and agents install under `~/.copilot/plugins/`.

**Alternative — per-repo install** (commit the agents directly to your project):

```bash
# Copy the 3 Copilot-shaped agent personas into your repo
cp /path/to/claude-plugins/plugins/dotnet-skills/agents/code-reviewer.agent.md   .github/agents/
cp /path/to/claude-plugins/plugins/dotnet-skills/agents/security-auditor.agent.md .github/agents/
cp /path/to/claude-plugins/plugins/dotnet-skills/agents/test-engineer.agent.md    .github/agents/

# Optionally, copy individual skills to activate automatically in this repo
mkdir -p .github/skills/test-driven-development
cp /path/to/claude-plugins/plugins/dotnet-skills/skills/test-driven-development/SKILL.md \
   .github/skills/test-driven-development/SKILL.md
```

Use this when your team wants the personas version-controlled alongside the code rather than installed per-developer. Full copy of all 21 skills is rarely what you want — copy only the ones that apply to the repo. See [GitHub Docs — Creating agent skills for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills) and [Creating custom agents for Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-custom-agents-for-cli).

## Usage

### Claude Code

```
/dotnet-skills
```

Lists available skills and their triggers. Individual skills activate from natural-language prompts (e.g. _"help me spec out a new C# service"_ triggers `spec-driven-development`). The 8 lifecycle commands (`/spec`, `/plan`, `/build`, `/test`, `/review`, `/code-simplify`, `/ship`, `/dotnet-skills`) are Claude Code–only.

### GitHub Copilot CLI

Three personas are invocable directly:

```
/agent code-reviewer
/agent security-auditor
/agent test-engineer
```

The 21 skills activate automatically via description-match — ask Copilot to plan a .NET feature, write a failing xUnit test, or do a security review, and the right skill engages. Custom slash commands aren't a Copilot CLI surface yet ([github/copilot-cli#618](https://github.com/github/copilot-cli/issues/618)); use the agents + skill auto-activation pattern.

### VS Code Copilot Chat

The same `.agent.md` files work in VS Code Copilot Chat when the repo is open (workspace-scope) or when you copy them to `~/.copilot/agents/` (user-scope). Invoke with `@<name>`:

```
@code-reviewer Review this change across the five axes.
@test-engineer Analyze coverage for OrderService and propose missing tests.
@security-auditor Audit this endpoint for OWASP Top 10 in ASP.NET Core context.
```

### Usage tips

1. **Keep prompts task-focused.** Copilot matches skills by description — naming the artifact (`xUnit test`, `EF Core migration`, `Avalonia view`) reliably activates the right skill from the 21 in this pack.
2. **Compose agents for high-stakes changes.** For a change that touches auth or payment, run `/agent code-reviewer` first, then `/agent security-auditor` on the same diff — the two reports complement rather than duplicate (code-reviewer covers the five-axis baseline; security-auditor goes OWASP-deep on ASP.NET Core specifics).
3. **Lean on `test-engineer` for bug-fix discipline.** Its Prove-It Pattern (write a failing xUnit/MSTest test first, confirm it fails for the right reason, then fix) is the fastest way to avoid landing a "fix" that passes tests for the wrong reason.
4. **Don't duplicate skills into your repo unless you need to.** The plugin-marketplace install is the simpler story; the per-repo copy path is for teams that want agents committed to the project for reproducibility across developers.

## Commands

8 slash commands ship with this plugin. `/dotnet-skills` is the catalog command; the other 7 map to the development lifecycle and activate the right skills automatically — ported from the upstream [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) command set with .NET framing.

| What you're doing          | Command           | Key principle                                  |
| -------------------------- | ----------------- | ---------------------------------------------- |
| List skills and triggers   | `/dotnet-skills`  | Inventory before action                        |
| Define what to build       | `/spec`           | Spec before code                               |
| Plan how to build it       | `/plan`           | Small, atomic tasks with `dotnet` verification |
| Build incrementally        | `/build`          | One vertical slice at a time                   |
| Prove it works             | `/test`           | xUnit/MSTest as proof                          |
| Review before merge        | `/review`         | Five-axis review, `file.cs:line` findings      |
| Simplify the code          | `/code-simplify`  | Clarity over cleverness                        |
| Ship to production         | `/ship`           | Faster is safer, rollback first                |

Skills also activate automatically based on what you're doing — designing an API triggers `api-and-interface-design`, building an Avalonia view triggers `frontend-ui-engineering-avalonia`, and so on.

### What each command activates

| Command           | Skills it invokes                                                                                             |
| ----------------- | ------------------------------------------------------------------------------------------------------------- |
| `/spec`           | `spec-driven-development`                                                                                     |
| `/plan`           | `planning-and-task-breakdown`                                                                                 |
| `/build`          | `incremental-implementation` + `test-driven-development` (+ `debugging-and-error-recovery` on failure)        |
| `/test`           | `test-driven-development` (+ `integration-testing-dotnet` for HTTP / DB / browser / Avalonia boundaries)      |
| `/review`         | `code-review-and-quality` (+ `security-and-hardening` + `performance-optimization-dotnet`)                    |
| `/code-simplify`  | `code-simplification` (+ `code-review-and-quality` to review the result)                                      |
| `/ship`           | `shipping-and-launch`                                                                                         |

### Disambiguating when shadowed

If `/test` or `/review` collides with a personal command or another plugin in your setup, invoke the qualified form: `/dotnet-skills:test`, `/dotnet-skills:review`. The qualified form works for every command in this plugin.

## Agents

3 .NET-adapted subagents ship alongside the commands — reusable personas for deeper single-purpose work, ported from the upstream [`agents/`](https://github.com/addyosmani/agent-skills/tree/44dac80216da709913fb410f632a65547866346f/agents) set. Each agent has a `Source & Modifications` footer linking back to its upstream file at the pinned commit.

| Agent | Persona | When to use |
| --- | --- | --- |
| [code-reviewer](./agents/code-reviewer.md) | Staff-Engineer five-axis reviewer (correctness, readability, architecture, security, performance) with nullable-RT / DI lifetime / EF Core N+1 / `IHttpClientFactory` / UI-thread checks | Thorough `file.cs:line`-anchored review before merge, categorized Critical / Important / Suggestion |
| [security-auditor](./agents/security-auditor.md) | Security-Engineer running an OWASP-aligned audit of the ASP.NET Core / Blazor / MAUI stack (FluentValidation, Identity + JWT + policy-based authz, Data Protection, Key Vault, security headers, CORS, HMAC webhooks, OAuth PKCE) | Security-focused review with proof-of-concept Critical / High / Medium / Low findings and .NET-API-grounded fixes |
| [test-engineer](./agents/test-engineer.md) | QA-Engineer designing test suites (xUnit v3 or v2, or MSTest — native `Assert.X`), `WebApplicationFactory<T>` / Testcontainers / `Microsoft.Playwright` / `Avalonia.Headless.XUnit`; `TimeProvider` + `FakeTimeProvider`; Prove-It Pattern | Planning a test suite, writing a failing test for a bug, or analyzing coverage gaps |

**Invocation.** Launch an agent through the `Agent` tool with `subagent_type: dotnet-skills:<name>`. Claude Code auto-namespaces plugin-provided agents, so `dotnet-skills:code-reviewer` coexists with built-in and sibling-plugin subagents of the same short name (e.g. `pr-review-toolkit:code-reviewer`, `feature-dev:code-reviewer`) — always use the qualified form to pick the .NET-adapted one.

**Copilot CLI.** The same three personas ship as `.agent.md` siblings (`code-reviewer.agent.md`, `security-auditor.agent.md`, `test-engineer.agent.md`) in `plugins/dotnet-skills/agents/`. Invoke as `/agent code-reviewer`, `/agent security-auditor`, `/agent test-engineer`. Bodies are kept in lockstep with the Claude Code forms; upstream attribution is not duplicated — the `.agent.md` footer points to the `.md` sibling as canonical.

## Skills

21 ported skills grouped by development phase — the commands above are the entry points; any skill can also be referenced directly by name. Run `/dotnet-skills` for the current inventory with trigger examples.

### Define — clarify what to build

| Skill                                                                  | What it does                                                                                 | Use when                                                                    |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [idea-refine](./skills/idea-refine/SKILL.md)                           | Divergent/convergent thinking to turn vague .NET ideas into a one-pager with MVP scope        | You have a rough concept (new Avalonia app, API, NuGet library) to explore  |
| [spec-driven-development](./skills/spec-driven-development/SKILL.md)   | PRD covering objective, `dotnet` CLI commands, project structure, code style, testing, bounds | Starting a new .NET project, feature, or significant change                 |

### Plan — break it down

| Skill                                                                              | What it does                                                                                                  | Use when                                            |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| [planning-and-task-breakdown](./skills/planning-and-task-breakdown/SKILL.md)       | Decompose specs into small tasks with `dotnet test --filter` / `dotnet build -warnaserror` verification steps | You have a spec and need implementable units       |

### Build — write the code

| Skill                                                                                                | What it does                                                                                                       | Use when                                                                |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| [incremental-implementation](./skills/incremental-implementation/SKILL.md)                           | Thin vertical slices — `dotnet test` + `dotnet build -warnaserror` between each. `IOptions<FeatureOptions>` flags   | Any change touching more than one project                               |
| [api-and-interface-design](./skills/api-and-interface-design/SKILL.md)                               | Contract-first design with C# records, ProblemDetails, FluentValidation, strongly-typed IDs, pattern-matching      | Designing APIs, module boundaries, or public interfaces                 |
| [context-engineering](./skills/context-engineering/SKILL.md)                                         | CLAUDE.md / `.editorconfig` / analyzer setup for .NET projects                                                     | Starting a session, switching stacks, or when output quality drops      |
| [source-driven-development](./skills/source-driven-development/SKILL.md)                             | Ground decisions in Microsoft Learn + framework docs + analyzer diagnostics                                        | You want authoritative, source-cited code for any .NET framework        |
| [frontend-ui-engineering-avalonia](./skills/frontend-ui-engineering-avalonia/SKILL.md)               | Avalonia 11/12 with CommunityToolkit.Mvvm, compiled bindings, `FluentTheme` + `ThemeVariant`, `AutomationProperties` | Building or modifying Avalonia UI                                       |
| [test-driven-development](./skills/test-driven-development/SKILL.md)                                 | RED/GREEN/REFACTOR with xUnit v3 (or v2) or MSTest using native `Assert.X`, Prove-It Pattern, `TimeProvider`/`FakeTimeProvider`   | Implementing logic, fixing bugs, or changing behavior                   |

### Verify — prove it works

| Skill                                                                                  | What it does                                                                                                            | Use when                                                      |
| -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [integration-testing-dotnet](./skills/integration-testing-dotnet/SKILL.md)             | `WebApplicationFactory<T>` (HTTP), Testcontainers (DB), `Microsoft.Playwright` (Blazor), `Avalonia.Headless.XUnit` (UI) | Building or debugging anything that crosses a boundary        |
| [debugging-and-error-recovery](./skills/debugging-and-error-recovery/SKILL.md)         | Systematic root-cause triage for `dotnet test` failures, DI issues, cancellation, DbContext concurrency                 | Tests fail, builds break, or behavior is unexpected          |

### Review — quality gates before merge

| Skill                                                                                  | What it does                                                                                                                 | Use when                                                         |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| [code-review-and-quality](./skills/code-review-and-quality/SKILL.md)                   | Five-axis review with .NET-specific checks (async correctness, DI lifetimes, EF Core N+1, nullable annotations)              | Before merging any change                                        |
| [code-simplification](./skills/code-simplification/SKILL.md)                           | Reduce C# complexity — null-coalescing, `switch` expressions, `record struct`, pattern-matching — while preserving behavior  | Code works but is harder to read or maintain than it should be   |
| [security-and-hardening](./skills/security-and-hardening/SKILL.md)                     | FluentValidation, EF Core parameterization, Identity/JWT, policy-based authz, `dotnet list package --vulnerable`             | Handling user input, auth, data storage, or external integrations |
| [performance-optimization-dotnet](./skills/performance-optimization-dotnet/SKILL.md)   | Measure-first with BenchmarkDotNet, dotnet-counters, dotnet-trace, PerfView; fixes N+1 / sync-over-async / GC pressure        | Performance requirements exist or a regression is suspected      |

### Ship — deploy with confidence

| Skill                                                                              | What it does                                                                                              | Use when                                                        |
| ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| [git-workflow-and-versioning](./skills/git-workflow-and-versioning/SKILL.md)       | Trunk-based branches, atomic commits, Husky.Net pre-commit with `dotnet test` / `format` / `build`        | Making any code change (always)                                 |
| [ci-cd-and-automation](./skills/ci-cd-and-automation/SKILL.md)                     | GitHub Actions / Azure DevOps with `setup-dotnet`, quality gates, Testcontainers, Playwright.NET E2E      | Setting up or modifying build and deploy pipelines              |
| [documentation-and-adrs](./skills/documentation-and-adrs/SKILL.md)                 | ADRs, XML doc comments, Swashbuckle OpenAPI metadata, README with `dotnet` CLI commands                   | Making architectural decisions, changing APIs, shipping features |
| [deprecation-and-migration](./skills/deprecation-and-migration/SKILL.md)           | `[Obsolete]`, strangler pattern, `IOptionsMonitor` feature flags, NuGet unlist, Roslyn analyzer code fixes | Removing old systems, migrating users, or sunsetting features   |
| [shipping-and-launch](./skills/shipping-and-launch/SKILL.md)                       | Pre-launch checklist, `Microsoft.FeatureManagement`, Application Insights / OpenTelemetry, migration rollback | Preparing to deploy to production                              |

### Meta — how to use this pack

| Skill                                                                  | What it does                                                                                        | Use when                                                     |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| [using-agent-skills](./skills/using-agent-skills/SKILL.md)             | Discovers and invokes the right skill for the task; phase-by-phase map of what's available         | Starting a session or when a task doesn't map to one skill   |

## Requirements

- [Claude Code](https://claude.ai/code) with plugin support
- Target workloads: .NET 8+ LTS, C# 12+, xUnit v3 (recommended) or v2 or MSTest — native `Assert.X` only (no FluentAssertions), EF Core, Avalonia UI (ASP.NET Core, Blazor, MAUI covered by guidance; dedicated sibling UI skills are optional future work)

## License

MIT (this plugin). Upstream content is MIT © 2025 Addy Osmani — preserved verbatim in [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt).
