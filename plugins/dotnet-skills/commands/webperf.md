---
description: Run a web performance audit on a Blazor / ASP.NET Core front end via the web-performance-auditor persona
---

`/webperf` targets .NET **web** front ends specifically — Blazor (Server / WebAssembly / Auto) and ASP.NET Core MVC / Razor Pages. Do not use it for utility libraries, CLIs, desktop apps (Avalonia / MAUI), or server-only code with no browser-facing output. For server-side runtime performance, use the `dotnet-skills:performance-optimization-dotnet` skill instead.

## Determine the mode

**Deep mode** — activate when any of these is available:
- A Lighthouse JSON report file (e.g. `npx lighthouse <url> --output json --output-path ./report.json`, or `npx -p chrome-devtools-mcp chrome-devtools lighthouse_audit --output-format=json` from the Chrome DevTools MCP CLI)
- A PageSpeed Insights JSON response (includes Lighthouse + CrUX)
- A CrUX API response (requires `CRUX_API_KEY` or `GOOGLE_API_KEY`)
- A DevTools performance trace
- A live URL plus the `chrome-devtools` MCP server configured in the harness (the agent can capture metrics directly via `lighthouse_audit` and `performance_*` tools)
- The Chrome DevTools MCP CLI invoked locally (via `npx -p chrome-devtools-mcp chrome-devtools <tool>` or after `npm i -g chrome-devtools-mcp`) — the user runs commands like `chrome-devtools lighthouse_audit --output-format=json` and passes the JSON output to the agent

**Quick mode** — default when none of the above are available. The agent scans source (`.razor` / `.cshtml` / `Program.cs` / `.csproj` / `wwwroot/`) for structural anti-patterns and labels every finding as `potential impact`.

## Run the audit

Spawn the `web-performance-auditor` subagent. Pass it explicitly:

- The files, components, or diff under review
- The rendering model when known (Blazor Server / WebAssembly / Auto, MVC, Razor Pages) — it changes which bottlenecks matter
- Any artifact paths (Lighthouse JSON, PSI JSON, CrUX response, trace) or pasted JSON content
- The target URL or page name when known
- A note on which mode you expect (Quick or Deep), so the agent surfaces missing inputs if Deep was intended

The subagent returns a scorecard (only populated with sourced values), a ranked list of findings, positive observations, and proactive recommendations.

## Output

Return the full audit report to the user. No synthesis or merge step is needed — this is a single-persona command. Server-side findings the auditor surfaces (EF Core N+1, allocations, Kestrel) are handed off to `dotnet-skills:performance-optimization-dotnet`, not fixed here.

---

**Source & Modifications**

- Upstream: [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) — `.claude/commands/webperf.md` at pinned SHA `3a6fc63` (new command, added upstream in PR #222)
- Status: modified (retargeted to .NET web front ends — Blazor render modes + ASP.NET Core MVC/Razor Pages; Quick-mode source globs changed to `.razor`/`.cshtml`/`Program.cs`/`.csproj`/`wwwroot/`; scope note excludes desktop XAML and points server-runtime concerns at `dotnet-skills:performance-optimization-dotnet`; spawns the `web-performance-auditor` persona directly — matching upstream's reviewer-not-implementer fix — and is deliberately **not** part of the `/ship` fan-out)
