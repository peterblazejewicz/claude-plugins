---
description: Start spec-driven development for a .NET project — write a structured specification before writing C# code
---

Invoke the `dotnet-skills:spec-driven-development` skill.

Begin by understanding what the user wants to build. Ask clarifying questions about:

1. The objective and target users
2. Core features and acceptance criteria
3. Tech stack preferences and constraints (target framework, UI framework — Avalonia / Blazor / ASP.NET Core / .NET MAUI — data layer, test framework)
4. Known boundaries (what to always do, ask first about, and never do)

Then generate a structured spec covering all six core areas: objective, `dotnet` CLI commands, solution/project structure, code style (including `.editorconfig` / analyzer-level conventions), testing strategy (xUnit v2 or v3, or MSTest), and boundaries.

Save the spec as `SPEC.md` in the repo root and confirm with the user before proceeding.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/spec.md` at pinned SHA `44dac80`
- Status: modified (skill reference retargeted to the `dotnet-skills:` prefix; clarifying questions reframed around .NET target framework / UI framework / data layer / test framework; spec output fields reframed for `dotnet` CLI and `.editorconfig`)
