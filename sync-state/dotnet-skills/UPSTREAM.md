# Upstream tracking

The pinned-commit table below is rewritten by `scripts/sync-agent-skills.ps1` on each sync. Entries in "Sync log" are prepended in place. Everything outside the two marker blocks (the table and the log list) is safe to edit by hand.

<!-- sync:pin:begin -->
| Field | Value |
|-------|-------|
| Upstream repository | https://github.com/addyosmani/agent-skills |
| Upstream license | MIT (© 2025 Addy Osmani) |
| Pinned commit SHA | `1f66d57a5e1b041b11e49a8cdca275aa472f0131` |
| Pinned commit (short) | `1f66d57` |
| Synced on | 2026-04-21 |
| Prior pin | `44dac80` |
| Changed since prior pin | 2 added, 5 modified |
<!-- sync:pin:end -->

## How to re-sync

```powershell
# Re-sync to the current pin (reproducibility check)
pwsh scripts/sync-agent-skills.ps1

# Bump to latest upstream main
pwsh scripts/sync-agent-skills.ps1 -UpstreamRef main

# Bump to a specific commit or tag
pwsh scripts/sync-agent-skills.ps1 -UpstreamRef <sha-or-tag>

# Drift check — verify vendor/ matches the recorded manifest
pwsh scripts/sync-agent-skills.ps1 -Verify
```

After a successful sync:

1. Review `git status` and the rewritten pin table to see what upstream changed.
2. Update [`SYNC.md`](./SYNC.md) — promote skills from `pending` or re-port changed files.
3. Re-port adapted skills whose upstream `skills/<name>/SKILL.md` changed; update each port's `source:` SHA7 and footer accordingly.
4. Commit both `vendor/` updates and the downstream adaptations together so the ledger stays coherent.

## Sync log

<!-- Append-only history of syncs. Newest first. The sync script prepends entries inside the marker block below. -->

<!-- sync:log:begin -->
- **2026-04-21** — Synced to `1f66d57` (2 added, 5 modified).
- **2026-04-21** — Synced to `44dac80` (no changes).
- **2026-04-19** — Initial pin at `44dac80`. Vendor tree populated; sample skill `spec-driven-development` ported.
<!-- sync:log:end -->
