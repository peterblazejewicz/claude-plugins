# NOTICE

The `dotnet-agent-skills` plugin is an **indirect fork** of [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills).

- **Upstream**: https://github.com/addyosmani/agent-skills
- **Upstream license**: MIT — `SPDX-License-Identifier: MIT`
- **Upstream copyright**: © 2025 Addy Osmani
- **Upstream license text**: preserved verbatim at [`LICENSES/agent-skills-MIT.txt`](./LICENSES/agent-skills-MIT.txt)

## Scope of adaptation

This derivative retargets upstream's JavaScript/TypeScript-oriented content toward the modern .NET ecosystem:

- .NET 8+ LTS runtime, C# 12+ language features
- xUnit and MSTest as testing frameworks
- Entity Framework Core as the data access layer
- Avalonia UI as the primary UI target (ASP.NET Core, Blazor, .NET MAUI to follow)

## Where adaptations live

- Upstream snapshot (read-only): [`vendor/agent-skills/`](./vendor/agent-skills)
- Ported skills (adapted): [`skills/`](./skills)
- Per-skill provenance and modification list: the **Source & Modifications** footer in every ported `SKILL.md`
- Machine-readable port ledger: [`SYNC.md`](./SYNC.md)
- Pinned upstream commit + sync log: [`UPSTREAM.md`](./UPSTREAM.md)

## Attribution requirements

Per MIT, the copyright notice and permission text must travel with substantial portions of the upstream material. Those requirements are satisfied by:

1. The verbatim LICENSE at `LICENSES/agent-skills-MIT.txt`
2. The attribution paragraph in this plugin's `README.md`
3. The credits paragraph in the marketplace root `README.md`
4. The per-skill footer on every ported `SKILL.md`
