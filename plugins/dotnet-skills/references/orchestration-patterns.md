# Orchestration Patterns

Reference catalog of agent orchestration patterns this plugin endorses, plus anti-patterns to avoid. Read this before adding a new slash command that coordinates multiple personas, or before introducing a new persona that "wraps" existing ones.

The governing rule: **the user (or a slash command) is the orchestrator. Personas do not invoke other personas.** Skills are mandatory hops inside a persona's workflow.

All examples below are grounded in the `dotnet-skills` plugin's actual personas (`code-reviewer`, `security-auditor`, `test-engineer`) and commands (`/spec`, `/plan`, `/build`, `/test`, `/review`, `/code-simplify`, `/ship`).

---

## Endorsed patterns

### 1. Direct invocation (no orchestration)

Single persona, single perspective, single artifact. The default and the cheapest option.

```
user → code-reviewer → report → user
```

**Use when:** the work is one perspective on one artifact and you can describe it in one sentence.

**Examples:**
- "Review this PR" → `code-reviewer`
- "Find security issues in `AuthorizationHandler.cs`" → `security-auditor`
- "What tests are missing for the checkout flow in `CheckoutEndpoints.cs`?" → `test-engineer`

**Cost:** one round trip. The baseline you should always compare orchestrated patterns against.

---

### 2. Single-persona slash command

A slash command that wraps one persona with the plugin's skills. Saves the user from re-explaining the workflow every time.

```
/review → code-reviewer (with dotnet-skills:code-review-and-quality skill) → report
```

**Use when:** the same single-persona invocation happens repeatedly with the same setup.

**Examples in this plugin:** `/review`, `/test`, `/code-simplify`.

**Cost:** same as direct invocation. The slash command is just a saved prompt.

**Anti-signal:** if the slash command's body is mostly "decide which persona to call," delete it and let the user call the persona directly.

---

### 3. Parallel fan-out with merge

Multiple personas operate on the same input concurrently, each producing an independent report. A merge step (in the main agent's context) synthesizes them into a single decision.

```
                    ┌─→ code-reviewer    ─┐
/ship → fan out  ───┼─→ security-auditor ─┤→ merge → go/no-go + rollback
                    └─→ test-engineer    ─┘
```

**Use when:**
- The sub-tasks are genuinely independent (no shared mutable state, no ordering dependency)
- Each sub-agent benefits from its own context window
- The merge step is small enough to stay in the main context
- Wall-clock latency matters

**Examples in this plugin:** `/ship`. Merge step runs the .NET pre-launch checklist (`dotnet test`, `dotnet build -warnaserror`, `dotnet list package --vulnerable --include-transitive`, `dotnet ef migrations list`) against the three parallel reports and produces a rollback plan keyed on `dotnet ef database update <PreviousMigration>`.

**Cost:** N parallel sub-agent contexts + one merge turn. Higher than direct invocation, but faster wall-clock and produces better reports because each sub-agent stays focused on its single perspective.

**Validation checklist before adopting this pattern:**
- [ ] Can I run all sub-agents at the same time without ordering issues?
- [ ] Does each persona produce a different *kind* of finding, not just the same finding from a different angle?
- [ ] Will the merge step fit in the main agent's remaining context?
- [ ] Is the user's wait time long enough that parallelism is actually noticeable?

If any answer is "no," fall back to direct invocation or a single-persona command.

---

### 4. Sequential pipeline as user-driven slash commands

The user runs slash commands in a defined order, carrying context (or commit history) between them. There is no orchestrator agent — the user IS the orchestrator.

```
user runs:  /spec  →  /plan  →  /build  →  /test  →  /review  →  /ship
```

**Use when:** the workflow has dependencies (each step needs the previous step's output) and human judgment between steps adds value.

**Examples in this plugin:** the entire DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP lifecycle. See `plugins/dotnet-skills/skills/using-agent-skills/SKILL.md` for the full lifecycle map.

**Cost:** one sub-agent context per step. Free for the orchestration layer because there is no orchestrator agent.

**Why not automate it:** an LLM "lifecycle orchestrator" would (a) lose nuance between steps because it has to summarize for hand-off, (b) skip the human checkpoints that catch wrong-direction work early (e.g. a spec that misses a target-framework decision or an EF Core migration strategy), and (c) double the token cost via paraphrasing turns.

---

### 5. Research isolation (context preservation)

When a task requires reading large amounts of material that shouldn't pollute the main context, spawn a research sub-agent that returns only a digest.

```
main agent → research sub-agent (reads 50 files) → digest → main agent continues
```

**Use when:**
- The main session needs to stay focused on a downstream task
- The investigation result is much smaller than the input it consumes
- The decision quality benefits from the main agent having room to think after

**Examples:** "Find every call site of `FromSqlRaw` across the solution," "Summarize what these 12 ADRs say about EF Core provider choices," "Inventory every `[Obsolete]`-marked API in `MyApp.Core`."

**Cost:** one isolated sub-agent context. Worth it any time the alternative is loading hundreds of `.cs` files into the main context.

**On Claude Code, use the built-in `Explore` subagent** rather than defining a custom research persona. `Explore` runs on Haiku, is denied write/edit tools, and is purpose-built for this pattern. Define a custom research subagent only when `Explore` doesn't fit (e.g. you need a domain-specific system prompt that names `Directory.Packages.props` / `global.json` / `*.sln` conventions).

---

## Claude Code compatibility

This catalog is harness-agnostic, but most readers will run it on Claude Code. Here's how each pattern maps onto Claude Code's primitives — and where the platform enforces our rules for us.

### Where personas live

Plugin subagents go in `agents/` at the plugin root. `dotnet-skills` is a plugin (`plugins/dotnet-skills/.claude-plugin/plugin.json`), so `agents/code-reviewer.md`, `agents/security-auditor.md`, and `agents/test-engineer.md` are auto-discovered when the plugin is enabled. No path configuration needed — and no `agents` key in the manifest either (a 2.2.0 regression bug proved that adding one fails manifest validation).

### Subagents vs. Agent Teams

Claude Code has two parallelism primitives. Pattern 3 (parallel fan-out with merge) maps to **subagents**. If you need teammates that talk to each other, use **Agent Teams** instead.

| | Subagents | Agent Teams |
|--|-----------|-------------|
| Coordination | Main agent fans out, sub-agents only report back | Teammates message each other, share a task list |
| Context | Own context window per subagent | Own context window per teammate |
| When to use | Independent tasks producing reports | Collaborative work needing discussion |
| Status | Stable | Experimental — requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| Cost | Lower | Higher — each teammate is a separate Claude instance |

**The personas in this plugin work in both modes.** When spawned as subagents (e.g. by `/ship`), they report findings to the main session. When spawned as teammates (`Spawn a teammate using the security-auditor agent type…`), they can challenge each other's findings directly. The persona definition is the same; only the spawning context changes.

One subtlety: the `skills` and `mcpServers` frontmatter fields in a persona are honored when it runs as a subagent but **ignored when it runs as a teammate** — teammates load skills and MCP servers from your project and user settings, the same as a regular session. If a persona depends on a specific skill or MCP server being loaded, configure it at the session level so it's available in both modes.

### Platform-enforced rules

Two rules in this catalog aren't just convention — Claude Code enforces them:

- **"Subagents cannot spawn other subagents"** (verbatim from the docs). Anti-pattern B (persona-calls-persona) and Anti-pattern D (deep persona trees) cannot exist on Claude Code by construction.
- **"No nested teams"** — teammates cannot spawn their own teams. Same anti-patterns blocked at the team level.

This means you can adopt the patterns in this catalog without worrying about contributors accidentally building the anti-patterns. They'll just fail to load.

### Built-in subagents to know about

Before defining a custom subagent, check whether one of these covers the role:

| Built-in | Purpose |
|----------|---------|
| `Explore` | Read-only codebase search and analysis. Use this for Pattern 5 (research isolation). |
| `Plan` | Read-only research during plan mode. |
| `general-purpose` | Multi-step tasks needing both exploration and modification. |

Don't redefine these. Layer your specialist personas (`code-reviewer`, `security-auditor`, `test-engineer`) on top of them.

### Frontmatter restrictions for plugin agents

Plugin subagents do **not** support the `hooks`, `mcpServers`, or `permissionMode` frontmatter fields — these are silently ignored. If a future persona needs any of those, the user must copy the file into `.claude/agents/` or `~/.claude/agents/` instead.

The fields that DO work in plugin agents are: `name`, `description`, `tools`, `disallowedTools`, `model`, `maxTurns`, `skills`, `memory`, `background`, `effort`, `isolation`, `color`, `initialPrompt`. Use `model` per-persona if you want to optimize cost (e.g. Haiku for `test-engineer` coverage scans, Sonnet for `code-reviewer`, Opus for `security-auditor`).

### Spawning multiple subagents in parallel

In Claude Code, parallel fan-out (Pattern 3) requires issuing **multiple Agent tool calls in a single assistant turn**. Sequential turns serialize execution. `/ship` calls this out explicitly. Any new orchestrator command should do the same.

---

## Worked example: Agent Teams for competing-hypothesis debugging

This example shows when to reach for **Agent Teams** instead of `/ship`'s subagent fan-out. The two patterns look similar from a distance — both spawn the same three personas — but the value comes from a different place.

### The scenario

> *Checkout occasionally hangs for ~30 seconds before completing, then surfaces a `TaskCanceledException` with no inner exception. It happens roughly once every 50 sessions. No errors in Application Insights before the cancellation; `dotnet-counters` shows no CPU or GC spike. Started after last week's release.*

Plausible root causes (mutually exclusive, all fit the symptoms):

1. A race condition between two `Task.WhenAll` branches in the new payment-confirmation flow
2. A policy-based `[Authorize]` handler that occasionally falls through to a slow synchronous Key Vault call (sync-over-async, hitting the default `HttpClient.Timeout` of 100s)
3. A missing index on an EF Core query that scales with cart size — plan regression caused by a provider update
4. A flaky Stripe webhook where the SDK retries silently before surfacing `TaskCanceledException` via `CancellationToken`

A single agent will pick the first plausible theory and stop investigating. A `/ship`-style subagent fan-out would have each persona report independently — but their reports never meet, so nothing rules out the wrong theories.

This is exactly the case the Agent Teams docs describe: *"With multiple independent investigators actively trying to disprove each other, the theory that survives is much more likely to be the actual root cause."*

### Why this is *not* a `/ship` job

| | `/ship` (subagents) | Agent Teams |
|--|--------------------|-------------|
| Sub-agents see | The same diff, different lenses | A shared task list, each other's messages |
| Output | Three independent reports → one merge | Adversarial debate → consensus root cause |
| Right when | You want a verdict on a known artifact | You want to *find* the artifact among hypotheses |

`/ship` is a verdict; Agent Teams is an investigation.

### Setup (one-time, per-environment)

Agent Teams is experimental. In `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Requires Claude Code v2.1.32 or later. The personas in this plugin are picked up automatically — no team-config files to author by hand.

### The trigger prompt

Type into the lead session, in natural language:

```
Users report checkout hangs for ~30 seconds intermittently after last
week's release. Surfaces as TaskCanceledException with no inner
exception. No errors in Application Insights; dotnet-counters clean.

Create an agent team to debug this with competing hypotheses. Spawn
three teammates using the existing agent types:

  - code-reviewer  — investigate race conditions and sync-over-async
                     patterns (.Result, .Wait(), GetAwaiter().GetResult())
                     on the checkout code path; check CancellationToken
                     propagation and HttpClient.Timeout defaults
  - security-auditor — investigate the [Authorize] policy handlers
                       and any synchronous Key Vault / secrets calls
                       added recently; check IHttpClientFactory
                       registrations for blocking handlers
  - test-engineer  — propose xUnit/MSTest tests (or Playwright flow)
                     that would distinguish between the hypotheses
                     and check coverage gaps in checkout

Have them message each other directly to challenge each other's
theories. Update findings as consensus emerges. Only converge when
two teammates agree they can disprove the others'.
```

The lead spawns three teammates referencing the existing persona names. The persona body is **appended** to each teammate's system prompt as additional instructions (on top of the team-coordination instructions the lead installs); the trigger prompt above becomes their task.

### What happens

1. Each teammate runs in its own context window, exploring the codebase from its own lens.
2. Teammates use `message` to send findings to each other directly. The lead doesn't have to relay.
3. The shared task list shows who's investigating what — visible at any time with `Ctrl+T` (in-process mode) or in a tmux pane (split mode).
4. When `code-reviewer` finds a `Task.WhenAll` with a captured synchronous `HttpClient.Send` call, it messages `security-auditor` to confirm the Key Vault-backed auth path isn't part of the race. `security-auditor` checks and replies — either confirming the race is the real issue or producing counter-evidence (e.g. an authn check using `GetTokenAsync` but awaiting on the UI thread).
5. `test-engineer` proposes a focused integration test (`WebApplicationFactory<Program>` + a `DelegatingHandler` that injects a slow response) for whichever theory is winning, which the team uses to verify before declaring consensus.
6. The lead synthesizes the converged finding and presents it to you.

You can interrupt at any teammate by cycling with `Shift+Down` and typing — useful for redirecting an investigator who's gone down a wrong path.

### When to clean up

When the investigation lands on a root cause, tell the lead:

```
Clean up the team
```

Always cleanup through the lead, not a teammate (per the docs: teammates lack full team context for cleanup).

### Cost expectation

Three Sonnet teammates running for ~10–15 minutes of investigation costs noticeably more than the same three personas spawned as subagents by `/ship`. The justification is *quality of conclusion* — for production debugging where the wrong fix is expensive (e.g. rolling back an EF Core migration that already ran on 30% of tenants), the extra tokens are a bargain. For a routine PR review, stick with `/ship`.

### Anti-pattern in this scenario

Do **not** rebuild this as a `/debug` slash command that fans out subagents. Subagents can't message each other — you'd lose the adversarial debate that makes the pattern work. If a workflow keeps coming up, document the trigger prompt above as a snippet rather than wrapping it in a slash command that misuses subagents.

### When *not* to use Agent Teams

- Production-bound verdict on a known diff → use `/ship` (subagents).
- One specialist perspective on one artifact → direct persona invocation.
- Sequential lifecycle (`/spec` → `/plan` → `/build`) → user-driven slash commands (Pattern 4).
- Read-heavy research with a small digest → built-in `Explore` subagent.

Reach for Agent Teams only when teammates **need** to challenge each other to produce the right answer.

---

## Anti-patterns

### A. Router persona ("meta-orchestrator")

A persona whose job is to decide which other persona to call.

```
/work → router-persona → "this needs a review" → code-reviewer → router (paraphrases) → user
```

**Why it fails:**
- Pure routing layer with no domain value
- Adds two paraphrasing hops → information loss + roughly 2× token cost
- The user already knew they wanted a review; they could have called `/review` directly
- Replicates the work that slash commands and intent mapping in `CLAUDE.md` already do

**What to do instead:** add or refine slash commands. Document intent → command mapping in `CLAUDE.md`.

---

### B. Persona that calls another persona

A `code-reviewer` that internally invokes `security-auditor` when it sees `[Authorize]` attributes.

**Why it fails:**
- Personas were designed to produce a single perspective; chaining them defeats that
- The summary the calling persona passes loses context the called persona needs
- Failure modes multiply (which persona's output format wins? whose rules apply?)
- Hides cost from the user

**What to do instead:** have the calling persona *recommend* a follow-up audit in its report. The user or a slash command runs the second pass.

---

### C. Sequential orchestrator that paraphrases

An agent that calls `/spec`, then `/plan`, then `/build`, etc. on the user's behalf.

**Why it fails:**
- Loses the human checkpoints that catch wrong-direction work (e.g. a spec that picks the wrong target framework or a plan that ignores EF Core migration ordering)
- Each hand-off summarizes context — accumulated drift over a long pipeline
- Doubles token cost: orchestrator turn + sub-agent turn for every step
- Removes user agency at exactly the points where judgment matters most

**What to do instead:** keep the user as the orchestrator. Document the recommended sequence in the plugin's `README.md` and the `using-agent-skills` skill, and let users invoke it.

---

### D. Deep persona trees

`/ship` calls a `pre-ship-coordinator` that calls a `quality-coordinator` that calls `code-reviewer`.

**Why it fails:**
- Each layer adds latency and tokens with no decision value
- Debugging becomes a multi-level investigation
- The leaf personas lose context to multiple summarization steps

**What to do instead:** keep the orchestration depth at most 1 (slash command → personas). The merge happens in the main agent.

---

## Decision flow

When considering a new orchestrated workflow, walk this flow:

```
Is the work one perspective on one artifact?
├── Yes → Direct invocation. Stop.
└── No  → Will the same composition repeat?
         ├── No  → Direct invocation, ad hoc. Stop.
         └── Yes → Are sub-tasks independent?
                  ├── No  → Sequential slash commands run by user (Pattern 4).
                  └── Yes → Parallel fan-out with merge (Pattern 3).
                           Validate against the checklist above.
                           If any check fails → fall back to single-persona command (Pattern 2).
```

---

## When to add a new pattern to this catalog

Add a new entry only after:

1. You've used the pattern at least twice in real work
2. You can name a concrete artifact in this plugin that demonstrates it
3. You can explain why an existing pattern wouldn't have worked
4. You can describe its anti-pattern shadow (what people will mistakenly build instead)

Premature catalog entries become aspirational documentation that no one follows.

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/1f66d57a5e1b041b11e49a8cdca275aa472f0131/references/orchestration-patterns.md
- **Pinned commit**: `1f66d57a5e1b041b11e49a8cdca275aa472f0131` (synced 2026-04-21)
- **Status**: `modified`
- **Changes**:
  - Intro grounds the catalog in this plugin's actual personas and commands (`code-reviewer`, `security-auditor`, `test-engineer`, `/spec` / `/plan` / `/build` / `/test` / `/review` / `/code-simplify` / `/ship`)
  - Direct-invocation examples use C# file paths (`AuthorizationHandler.cs`, `CheckoutEndpoints.cs`)
  - Pattern 2 names skill references with the `dotnet-skills:` prefix (e.g. `dotnet-skills:code-review-and-quality`)
  - Pattern 3 merge-step description specifies the .NET pre-launch checklist (`dotnet test`, `dotnet build -warnaserror`, `dotnet list package --vulnerable --include-transitive`, `dotnet ef migrations list`) and the `dotnet ef database update <PreviousMigration>` rollback
  - Pattern 4 cross-references `plugins/dotnet-skills/skills/using-agent-skills/SKILL.md` and names .NET-specific hand-off failure modes (target-framework decisions, EF Core migration strategy)
  - Pattern 5 examples use .NET investigation scenarios (`FromSqlRaw` call sites, EF Core provider ADRs, `[Obsolete]`-marked APIs in `MyApp.Core`) and a `Directory.Packages.props` / `global.json` / `*.sln` convention hint for custom research personas
  - "Where personas live" section notes the 2.2.0 manifest-validation regression (adding an `agents` key to `plugin.json` fails install) — a downstream-specific caveat from this marketplace's history
  - Competing-hypothesis worked example re-grounded in a `TaskCanceledException` scenario with Application Insights / `dotnet-counters` signals; hypothesis list names `Task.WhenAll`, policy-based `[Authorize]` + Key Vault sync-over-async, EF Core query plan regression, and Stripe webhook retries; test-engineer mitigation uses `WebApplicationFactory<Program>` + `DelegatingHandler` instead of the upstream's generic integration test
  - Cost-expectation paragraph names an EF Core partial-rollout rollback as the "expensive wrong fix" case
  - Anti-pattern B example replaced (`auth code` → `[Authorize]` attributes); Anti-pattern C example names EF Core migration ordering as a hand-off failure mode
  - "Where personas live" (plugin-path heading) is the `dotnet-skills` path; anti-pattern C points at this plugin's README + `using-agent-skills` skill rather than upstream's generic README
  - Core structure (5 endorsed patterns, Claude Code compatibility section, competing-hypothesis worked example, 4 anti-patterns, decision flow, catalog-addition criteria) preserved from upstream
- **License**: MIT © 2025 Addy Osmani — see [`../LICENSES/agent-skills-MIT.txt`](../LICENSES/agent-skills-MIT.txt)
