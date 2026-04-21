# Agent Personas

Specialist .NET/C# personas that play a single role with a single perspective. Each persona is a Markdown file consumed as a system prompt by your harness (Claude Code, Cursor, Copilot, etc.). On Claude Code, the files in this directory are auto-discovered as subagents when the `dotnet-skills` plugin is enabled — no path configuration needed.

| Persona | Role | Best for |
|---------|------|----------|
| [code-reviewer](code-reviewer.md) | .NET Staff Engineer | Five-axis review before merge — nullable honesty, async correctness, DI lifetimes, EF Core N+1, `MyApp.*` layering |
| [security-auditor](security-auditor.md) | .NET Security Engineer | Vulnerability detection translated to ASP.NET Core / EF Core / Blazor equivalents of OWASP Top 10 |
| [test-engineer](test-engineer.md) | .NET QA Engineer | Test strategy, coverage analysis, Prove-It pattern — xUnit v3/v2 or MSTest with native `Assert.X` |

## How personas relate to skills and commands

Three layers, each with a distinct job:

| Layer | What it is | Example | Composition role |
|-------|-----------|---------|------------------|
| **Skill** | A workflow with steps and exit criteria | `dotnet-skills:code-review-and-quality` | The *how* — invoked from inside a persona or command |
| **Persona** | A role with a perspective and an output format | `code-reviewer` | The *who* — adopts a viewpoint, produces a report |
| **Command** | A user-facing entry point | `/review`, `/ship` | The *when* — composes personas and skills |

The user (or a slash command) is the orchestrator. **Personas do not call other personas.** Skills are mandatory hops inside a persona's workflow.

## When to use each

### Direct persona invocation
Pick this when you want one perspective on the current change and the user is in the loop.

- "Review this PR" → invoke `code-reviewer` directly
- "Are there security issues in `AuthorizationHandler.cs`?" → invoke `security-auditor` directly
- "What tests are missing for the checkout flow in `CheckoutEndpoints.cs`?" → invoke `test-engineer` directly

### Slash command (single persona behind it)
Pick this when there's a repeatable workflow you'd otherwise re-explain every time.

- `/review` → wraps `code-reviewer` with `dotnet-skills:code-review-and-quality`
- `/test` → wraps `test-engineer` with `dotnet-skills:test-driven-development`
- `/code-simplify` → wraps the simplification workflow over C# idioms

### Slash command (orchestrator — fan-out)
Pick this only when **independent** investigations can run in parallel and produce reports that a single agent then merges.

- `/ship` → fans out to `code-reviewer` + `security-auditor` + `test-engineer` in parallel, then synthesizes their reports into a go/no-go decision against the .NET pre-launch checklist (EF Core migration rollback, `dotnet list package --vulnerable`, feature flags, monitoring)

This is the only orchestration pattern this plugin endorses. See [`../references/orchestration-patterns.md`](../references/orchestration-patterns.md) for the full pattern catalog and anti-patterns.

## Decision matrix

```
Is the work a single perspective on a single artifact?
├── Yes → Direct persona invocation
└── No  → Are the sub-tasks independent (no shared mutable state, no ordering)?
         ├── Yes → Slash command with parallel fan-out (e.g. /ship)
         └── No  → Sequential slash commands run by the user (/spec → /plan → /build → /test → /review)
```

## Worked example: valid orchestration

`/ship` is the canonical fan-out orchestrator in this plugin:

```
/ship
  ├── (parallel) code-reviewer    → review report (nullable, async, DI, EF Core N+1)
  ├── (parallel) security-auditor → audit report (OWASP → ASP.NET Core, FromSqlRaw, CVEs)
  └── (parallel) test-engineer    → coverage report (xUnit/MSTest gaps, boundary tests)
                  ↓
        merge phase (main agent) — .NET checklist: dotnet test, dotnet build -warnaserror,
                                   dotnet list package --vulnerable, dotnet ef migrations list
                  ↓
        go/no-go decision + rollback plan (dotnet ef database update <PreviousMigration>)
```

Why this works:
- Each sub-agent operates on the same diff but produces a **different perspective**
- They have no dependencies on each other → genuine parallelism, real wall-clock savings
- Each runs in a fresh context window → main session stays uncluttered
- The merge step is small and benefits from full context, so it stays in the main agent

## Worked example: invalid orchestration (do not build this)

A `meta-orchestrator` persona whose job is "decide which other persona to call":

```
/work-on-pr → meta-orchestrator
                  ↓ (decides "this needs a review")
              code-reviewer
                  ↓ (returns)
              meta-orchestrator (paraphrases result)
                  ↓
              user
```

Why this fails:
- Pure routing layer with no domain value
- Adds two paraphrasing hops → information loss + 2× token cost
- The user already knows they want a review; let them call `/review` directly
- Replicates work that slash commands and intent-mapping in `CLAUDE.md` already do

## Rules for personas

1. A persona is a single role with a single output format. If you find yourself adding a second role, create a second persona.
2. **Personas do not invoke other personas.** Composition is the job of slash commands or the user. On Claude Code this is also a hard platform constraint — *"subagents cannot spawn other subagents"* — so the rule is enforced for you.
3. A persona may invoke skills (the *how*) — e.g. `code-reviewer` references `dotnet-skills:code-review-and-quality` for the full process.
4. Every persona file ends with a "Composition" block stating where it fits.

## Claude Code interop

The personas in this plugin are designed to work as Claude Code subagents and as Agent Teams teammates without modification:

- **As subagents:** auto-discovered when the `dotnet-skills` plugin is enabled (no path config needed). Use the Agent tool with `subagent_type: code-reviewer` (or `security-auditor`, `test-engineer`). `/ship` is the canonical example. If you've also defined your own persona with the same name in `.claude/agents/` or `~/.claude/agents/`, Claude Code's scope priority resolves in your favor — your customizations win over the plugin defaults.
- **As Agent Teams teammates** (experimental, requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`): reference the same persona name when spawning a teammate. The persona's body is **appended to** the teammate's system prompt as additional instructions (not a replacement), so your persona text sits on top of the team-coordination instructions the lead installs (SendMessage, task-list tools, etc.).

Subagents only report results back to the main agent. Agent Teams let teammates message each other directly. Use subagents when reports are enough; use Agent Teams when sub-agents need to challenge each other's findings (e.g. competing-hypothesis debugging for a flaky `TaskCanceledException`). See [`../references/orchestration-patterns.md`](../references/orchestration-patterns.md) for the full mapping.

Plugin agents do not support `hooks`, `mcpServers`, or `permissionMode` frontmatter — those fields are silently ignored. Avoid relying on them when authoring new personas here.

## Adding a new persona

1. Create `agents/<role>.md` with the same frontmatter format used by existing personas (`name`, `description`, `source`).
2. Define the role, scope, output format, and rules — grounded in .NET/C# specifics.
3. Add a **Composition** block at the bottom (Invoke directly when / Invoke via / Do not invoke from another persona).
4. Add the persona to the table at the top of this file.
5. If the persona enables a new orchestration pattern, document it in [`../references/orchestration-patterns.md`](../references/orchestration-patterns.md) rather than inventing the pattern in the persona file itself.
6. If the persona is ported from an upstream file, carry the "Source & Modifications" footer so the sync script can track drift against the pinned commit.

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/1f66d57a5e1b041b11e49a8cdca275aa472f0131/agents/README.md
- **Pinned commit**: `1f66d57a5e1b041b11e49a8cdca275aa472f0131` (synced 2026-04-21)
- **Status**: `modified`
- **Changes**:
  - Persona descriptions retargeted to `.NET Staff Engineer` / `.NET Security Engineer` / `.NET QA Engineer` with concrete .NET framing (nullable honesty, async correctness, EF Core N+1, OWASP → ASP.NET Core/EF Core/Blazor, xUnit v3/v2 or MSTest with native `Assert.X`)
  - Skill references prefixed with `dotnet-skills:` (e.g. `dotnet-skills:code-review-and-quality`, `dotnet-skills:test-driven-development`)
  - Direct-invocation examples use C# file paths (`AuthorizationHandler.cs`, `CheckoutEndpoints.cs`)
  - `/ship` fan-out diagram annotated with the .NET merge checklist (`dotnet test`, `dotnet build -warnaserror`, `dotnet list package --vulnerable`, `dotnet ef migrations list`) and rollback step (`dotnet ef database update <PreviousMigration>`)
  - Competing-hypothesis debugging example names a .NET failure mode (flaky `TaskCanceledException`) instead of the generic upstream checkout-hang
  - "Adding a new persona" step 6 added — carry the "Source & Modifications" footer on ported personas so `scripts/sync-agent-skills.ps1 -Verify` can track drift against the pinned commit
  - Link to `CLAUDE.md` replaces upstream's `AGENTS.md` (which lives vendor-only in this repo — see `sync-state/dotnet-skills/SYNC.md`)
  - Core structure (persona table, three-layer composition table, decision matrix, worked examples for valid and invalid orchestration, persona rules, Claude Code interop note) preserved from upstream
- **License**: MIT © 2025 Addy Osmani — see [`../LICENSES/agent-skills-MIT.txt`](../LICENSES/agent-skills-MIT.txt)
