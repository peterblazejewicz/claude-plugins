# Port ledger

Per-skill port status against upstream [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) at the pinned commit recorded in [`UPSTREAM.md`](./UPSTREAM.md).

**Status values**

- `pending` — not ported yet; upstream file exists only in `vendor/`
- `as-is` — ported with frontmatter/footer only; body unchanged
- `modified` — ported with targeted .NET/C# adaptations; upstream body largely preserved
- `rewritten` — structurally incompatible; re-written for .NET; upstream diff tracking stopped
- `skipped` — intentionally not ported (document why in the notes column)

## Skills

| Upstream | Wave | Ported as | Status | Last sync SHA7 | Notes |
|----------|------|-----------|--------|----------------|-------|
| skills/api-and-interface-design/SKILL.md | 1 | api-and-interface-design | pending | — | |
| skills/browser-testing-with-devtools/SKILL.md | 2 | integration-testing-dotnet | pending | — | Rewrite for `WebApplicationFactory` + `Microsoft.Playwright` |
| skills/ci-cd-and-automation/SKILL.md | 2 | ci-cd-and-automation | pending | — | Inject dotnet CLI + GitHub Actions examples |
| skills/code-review-and-quality/SKILL.md | 1 | code-review-and-quality | pending | — | |
| skills/code-simplification/SKILL.md | 1 | code-simplification | pending | — | |
| skills/context-engineering/SKILL.md | 1 | context-engineering | pending | — | |
| skills/debugging-and-error-recovery/SKILL.md | 1 | debugging-and-error-recovery | pending | — | |
| skills/deprecation-and-migration/SKILL.md | 1 | deprecation-and-migration | pending | — | |
| skills/documentation-and-adrs/SKILL.md | 1 | documentation-and-adrs | pending | — | |
| skills/frontend-ui-engineering/SKILL.md | 3 | frontend-ui-engineering-avalonia | pending | — | Rewrite for Avalonia 11/12 first; siblings for Blazor/ASP/MAUI later |
| skills/git-workflow-and-versioning/SKILL.md | 1 | git-workflow-and-versioning | pending | — | |
| skills/idea-refine/SKILL.md | 1 | idea-refine | pending | — | |
| skills/incremental-implementation/SKILL.md | 1 | incremental-implementation | pending | — | |
| skills/performance-optimization/SKILL.md | 3 | performance-optimization-dotnet | pending | — | Rewrite for BenchmarkDotNet, dotnet-counters, PerfView, dotnet-trace |
| skills/planning-and-task-breakdown/SKILL.md | 1 | planning-and-task-breakdown | pending | — | |
| skills/security-and-hardening/SKILL.md | 1 | security-and-hardening | pending | — | |
| skills/shipping-and-launch/SKILL.md | 1 | shipping-and-launch | pending | — | |
| skills/source-driven-development/SKILL.md | 1 | source-driven-development | pending | — | |
| skills/spec-driven-development/SKILL.md | 0 | spec-driven-development | modified | `44dac80` | .NET framing: `dotnet` CLI commands, C# solution layout, EF Core/xUnit references replace npm/React/Prisma |
| skills/test-driven-development/SKILL.md | 2 | test-driven-development | pending | — | Dual xUnit + MSTest samples |
| skills/using-agent-skills/SKILL.md | 4 | using-agent-skills | pending | — | Will be `rewritten` — diff tracking stops once ported |

## Non-skill upstream directories

| Upstream | Disposition | Notes |
|----------|-------------|-------|
| agents/ | vendor-only | Promote to `skills/` or `commands/` on demand |
| references/ | vendor-only | Promote into per-skill `references/` as ports land |
| hooks/ | vendor-only | Re-evaluate when Wave 3 lands |
| docs/ | vendor-only | Reference only |
| .claude/commands/ | vendor-only | Compare against our `commands/dotnet-skills.md` before promoting any |
| AGENTS.md, CLAUDE.md, CONTRIBUTING.md | vendor-only | Not intended for downstream replication |
