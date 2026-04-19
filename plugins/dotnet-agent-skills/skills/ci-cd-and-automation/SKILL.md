---
name: ci-cd-and-automation
description: Automates CI/CD pipelines for .NET/C# projects — GitHub Actions (or Azure DevOps Pipelines) with `setup-dotnet`, quality gates (`dotnet format --verify-no-changes`, `dotnet test`, `dotnet build -warnaserror`, `dotnet list package --vulnerable`), EF Core migrations, preview deploys, feature-flag-driven rollouts, rollback. Use when setting up or modifying build and deployment pipelines for .NET workloads.
version: 0.4.0
source: vendor/agent-skills/skills/ci-cd-and-automation/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# CI/CD and Automation

## Overview

Automate quality gates so that no change reaches production without passing tests, formatting, build-with-warnings-as-errors, and vulnerability checks. CI/CD is the enforcement mechanism for every other skill — it catches what humans and agents miss, and it does so consistently on every single change.

**Shift Left:** Catch problems as early in the pipeline as possible. An analyzer diagnostic caught at `dotnet build -warnaserror` time costs seconds; the same bug caught in production costs hours. Move checks upstream — static analysis before tests, tests before staging, staging before production.

**Faster is Safer:** Smaller batches and more frequent releases reduce risk, not increase it. A deployment with 3 changes is easier to debug than one with 30. Frequent releases build confidence in the release process itself.

## When to Use

- Setting up a new .NET project's CI pipeline
- Adding or modifying automated checks
- Configuring deployment pipelines (Azure App Service, Container Apps, AKS, self-hosted)
- Publishing a NuGet package
- When a change should trigger automated verification
- Debugging CI failures

## The Quality Gate Pipeline

Every change goes through these gates before merge:

```
Pull Request Opened
    │
    ▼
┌───────────────────────┐
│   FORMAT CHECK         │  dotnet format --verify-no-changes
│   ↓ pass               │
│   BUILD (warnerr)      │  dotnet build -warnaserror (analyzers run)
│   ↓ pass               │
│   UNIT TESTS           │  dotnet test  (MyApp.Core.Tests, etc.)
│   ↓ pass               │
│   INTEGRATION TESTS    │  WebApplicationFactory + Testcontainers
│   ↓ pass               │
│   E2E (optional)       │  Playwright.NET, Avalonia.Headless
│   ↓ pass               │
│   VULNERABILITY SCAN   │  dotnet list package --vulnerable
│   ↓ pass               │
│   PACKAGE / PUBLISH    │  dotnet publish; dotnet pack (for libraries)
└───────────────────────┘
    │
    ▼
  Ready for review
```

**No gate can be skipped.** If a build warning fires, fix the code — don't add `#pragma warning disable`. If a test fails, fix the code — don't `[Fact(Skip = "…")]` it.

## GitHub Actions Configuration

### Basic CI Pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-dotnet@v4
        with:
          # Prefer reading from global.json; fallback to explicit version if needed
          global-json-file: global.json

      - name: Restore
        run: dotnet restore

      - name: Format check
        run: dotnet format --verify-no-changes --no-restore

      - name: Build
        run: dotnet build -warnaserror --no-restore --configuration Release

      - name: Test
        run: dotnet test --no-build --configuration Release --collect:"XPlat Code Coverage" --logger "trx;LogFileName=test-results.trx"

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: '**/test-results.trx'

      - name: Vulnerability audit
        run: dotnet list package --vulnerable --include-transitive
```

Note: `dotnet list package --vulnerable` exits 0 even when vulnerabilities are found. To fail the job on criticals, pipe through a grep or use a wrapper action like [`dotnet-outdated`](https://github.com/dotnet-outdated/dotnet-outdated) or a custom PowerShell step that parses the output.

### With Database Integration Tests (EF Core + PostgreSQL)

```yaml
  integration:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: ci_user
          POSTGRES_PASSWORD: ${{ secrets.CI_DB_PASSWORD }}
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          global-json-file: global.json
      - run: dotnet restore

      - name: Apply EF Core migrations
        env:
          ConnectionStrings__Default: Host=localhost;Database=testdb;Username=ci_user;Password=${{ secrets.CI_DB_PASSWORD }}
        # Use a migration bundle for production; for CI, dotnet ef is fine
        run: dotnet ef database update --project src/MyApp.Infrastructure --startup-project src/MyApp

      - name: Integration tests
        env:
          ConnectionStrings__Default: Host=localhost;Database=testdb;Username=ci_user;Password=${{ secrets.CI_DB_PASSWORD }}
        run: dotnet test tests/MyApp.Integration.Tests --no-restore --configuration Release
```

> **Note:** Even for CI-only test databases, use GitHub Secrets for credentials rather than hardcoding values. This builds good habits and prevents accidental reuse of test credentials in other contexts. When possible, prefer Testcontainers inside the test project itself so the CI YAML stays simple — then the `services:` block goes away.

**Testcontainers alternative** (preferred when your test host can run Docker): put the PostgreSQL lifecycle inside `tests/MyApp.Integration.Tests` via `Testcontainers.PostgreSql`, and drop the `services.postgres` block entirely. See `integration-testing-dotnet`.

### E2E Tests with Playwright.NET

```yaml
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { global-json-file: global.json }
      - run: dotnet restore

      - name: Build test project
        run: dotnet build tests/MyApp.EndToEnd.Tests --configuration Release --no-restore

      # Playwright.NET installs browsers via a generated PowerShell/Bash script after build
      - name: Install Playwright browsers
        run: pwsh tests/MyApp.EndToEnd.Tests/bin/Release/net8.0/playwright.ps1 install --with-deps chromium

      - name: Run E2E tests
        run: dotnet test tests/MyApp.EndToEnd.Tests --no-build --configuration Release

      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: tests/MyApp.EndToEnd.Tests/TestResults/
```

### Publishing a NuGet Package

```yaml
  pack-and-publish:
    runs-on: ubuntu-latest
    needs: quality
    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }  # For MinVer / Nerdbank.GitVersioning
      - uses: actions/setup-dotnet@v4
        with: { global-json-file: global.json }

      - run: dotnet pack src/MyLib --configuration Release --output nupkgs

      - name: Push to NuGet
        run: dotnet nuget push "nupkgs/*.nupkg" --api-key ${{ secrets.NUGET_API_KEY }} --source https://api.nuget.org/v3/index.json --skip-duplicate
```

## Azure DevOps Pipelines (alternative)

For teams on Azure DevOps, the equivalent `azure-pipelines.yml` structure:

```yaml
trigger:
  branches: { include: [main] }

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: UseDotNet@2
    inputs:
      useGlobalJson: true

  - script: dotnet restore
    displayName: Restore

  - script: dotnet format --verify-no-changes --no-restore
    displayName: Format check

  - script: dotnet build -warnaserror --no-restore -c Release
    displayName: Build

  - script: dotnet test --no-build -c Release --collect:"XPlat Code Coverage" --logger trx
    displayName: Test

  - task: PublishTestResults@2
    condition: succeededOrFailed()
    inputs:
      testResultsFormat: VSTest
      testResultsFiles: '**/*.trx'
```

## Feeding CI Failures Back to Agents

The power of CI with AI agents is the feedback loop. When CI fails:

```
CI fails
    │
    ▼
Copy the failure output (truncate to the actual diagnostic, not the whole log)
    │
    ▼
Feed it to the agent:
"The CI pipeline failed with this error:
[paste specific error, including CA/CS/IDE diagnostic ID and file:line]
Fix the issue and verify locally (dotnet build -warnaserror + dotnet test)
before pushing again."
    │
    ▼
Agent fixes → pushes → CI runs again
```

**Key patterns:**

```
Format failure       → Agent runs `dotnet format` and commits the result separately
Analyzer diagnostic  → Agent reads the rule ID (CA1822, IDE0051, EF1001, ...) and fixes at the cited location
Test failure         → Agent follows the debugging-and-error-recovery skill
Build error          → Agent checks .csproj / Directory.Packages.props / global.json SDK match
Vulnerability found  → Agent bumps the package in Directory.Packages.props or adds an allowlist entry with review date
```

## Deployment Strategies

### Preview Deployments

Every PR gets a preview deployment for manual testing. For Azure App Service, use slot-per-PR with the Azure/webapps-deploy action; for Container Apps, use a revision-per-PR:

```yaml
  deploy-preview:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { global-json-file: global.json }
      - run: dotnet publish src/MyApp -c Release -o publish

      - uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - uses: azure/webapps-deploy@v3
        with:
          app-name: myapp-staging
          slot-name: pr-${{ github.event.pull_request.number }}
          package: publish
```

### Feature Flags

Feature flags decouple deployment from release. Deploy incomplete or risky features behind `IOptions<FeatureOptions>` or `Microsoft.FeatureManagement` so you can:

- **Ship code without enabling it.** Merge to main early, enable when ready.
- **Roll back without redeploying.** Disable the flag instead of reverting code.
- **Canary new features.** Enable for 1% of users, then 10%, then 100% (Azure App Configuration feature filters support percentile and user-targeting natively).
- **Run A/B tests.** Compare behaviour with and without the feature.

```csharp
// Program.cs
builder.Services.AddFeatureManagement();

// In a Minimal API endpoint
app.MapGet("/checkout", async (IFeatureManager features) =>
{
    if (await features.IsEnabledAsync("NewCheckoutFlow"))
    {
        return Results.Extensions.NewCheckout();
    }
    return Results.Extensions.LegacyCheckout();
});
```

**Flag lifecycle:** Create → Enable for testing → Canary → Full rollout → Remove the flag and dead code. Flags that live forever become technical debt — set a cleanup date when you create them and add a Roslyn analyzer / CI grep that flags stale flag names.

### Staged Rollouts

```
PR merged to main
    │
    ▼
  Staging deployment (auto, via workflow_run or deploy job)
    │ Manual verification + smoke run against staging slot
    ▼
  Production deployment (manual trigger, or slot swap after 15-min staging bake)
    │
    ▼
  Monitor for errors (15-minute window): Application Insights failures, p95 latency,
  Gen2 GC rate, thread-pool queue length
    │
    ├── Errors detected → Rollback (slot swap back / revert image)
    └── Clean → Done
```

### Rollback Plan

Every deployment should be reversible:

```yaml
# Manual rollback workflow
name: Rollback
on:
  workflow_dispatch:
    inputs:
      target_slot:
        description: 'Slot to promote back (e.g. staging-last-known-good)'
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Swap slot back
        run: |
          az webapp deployment slot swap \
            --resource-group rg-myapp \
            --name myapp-prod \
            --slot ${{ inputs.target_slot }} \
            --target-slot production
```

For EF Core schema changes, pair the rollback with a migration-down step or design the migration using the expand-contract pattern so no rollback is needed. See `shipping-and-launch`.

## Environment Management

```
appsettings.json                → Committed (defaults, no secrets)
appsettings.Development.json    → Committed (dev-only overrides, no secrets)
appsettings.Production.json     → Committed (production-safe defaults)
appsettings.*.local.json        → NOT committed (per-developer overrides)
User Secrets (Development)      → dotnet user-secrets, outside repo
CI secrets                      → GitHub Secrets / Azure DevOps variable groups
Production secrets              → Azure Key Vault + Managed Identity, or AWS Secrets Manager
```

CI should never have production secrets. Use separate secrets for CI testing. For Key Vault access from CI, prefer OIDC federation (`azure/login@v2` with `federated-credential`) over long-lived service-principal secrets.

## Automation Beyond CI

### Dependabot / Renovate

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: nuget
    directory: /
    schedule:
      interval: weekly
    open-pull-requests-limit: 5
    groups:
      microsoft:
        patterns:
          - "Microsoft.*"
          - "System.*"
```

Group related packages so `Microsoft.EntityFrameworkCore` and `Microsoft.EntityFrameworkCore.Design` bump together — otherwise they'll arrive on different PRs and one will fail the build.

### Build Cop Role

Designate someone responsible for keeping CI green. When the build breaks, the Build Cop's job is to fix or revert — not the person whose change caused the break. This prevents broken builds from accumulating while everyone assumes someone else will fix it.

### PR Checks

- **Required reviews:** At least 1 approval before merge
- **Required status checks:** CI must pass before merge
- **Branch protection:** No force-pushes to main
- **Auto-merge:** If all checks pass and approved, merge automatically
- **Squash-merge** or **rebase-merge** preference set at repo level to match the `git-workflow-and-versioning` conventions

## CI Optimization

When the pipeline exceeds 10 minutes, apply these strategies in order of impact:

```
Slow CI pipeline?
├── Cache NuGet packages and build outputs
│   └── actions/setup-dotnet caches via global-json + lock files; add actions/cache for ~/.nuget/packages
├── Run jobs in parallel
│   └── Split format, build, test, e2e into separate parallel jobs
├── Only run what changed
│   └── Use path filters to skip unrelated jobs (e.g., skip e2e for docs-only PRs)
├── Use matrix builds
│   └── Shard test suites across multiple runners (dotnet test --filter by category)
├── Optimize the test suite
│   └── Move slow integration tests to a nightly schedule; keep the PR path fast
├── Use larger runners
│   └── GitHub-hosted larger runners or self-hosted for CPU-heavy builds
└── `--no-restore` / `--no-build` between steps
    └── Avoid re-restoring NuGet on every stage
```

**Example: caching + parallelism**

```yaml
jobs:
  format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { global-json-file: global.json }
      - run: dotnet restore
      - run: dotnet format --verify-no-changes --no-restore

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { global-json-file: global.json }
      - run: dotnet restore
      - run: dotnet build -warnaserror --no-restore -c Release

  test:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { global-json-file: global.json }
      - run: dotnet restore
      - run: dotnet test --no-restore -c Release --collect:"XPlat Code Coverage"
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "CI is too slow" | Optimize the pipeline (see CI Optimization above), don't skip it. A 5-minute pipeline prevents hours of debugging. |
| "This change is trivial, skip CI" | Trivial changes break builds (a missed `using`, a renamed NuGet package). CI is fast for trivial changes anyway. |
| "The test is flaky, just re-run" | Flaky tests mask real bugs and waste everyone's time. Fix the flakiness (inject `TimeProvider`, enforce `DbContext` scope, disable parallel test collections if needed). |
| "We'll add CI later" | Projects without CI accumulate broken states. Set it up on day one — `actions/setup-dotnet` is 4 lines of YAML. |
| "Manual testing is enough" | Manual testing doesn't scale and isn't repeatable. Automate what you can. |
| "dotnet list package --vulnerable is noisy" | Noise means underlying risk, not noise. Triage it; don't suppress it. |

## Red Flags

- No CI pipeline in the project
- CI failures ignored or silenced
- Tests disabled via `[Fact(Skip = "…")]` to make the pipeline pass
- Production deploys without staging verification
- No rollback mechanism
- Secrets stored in `appsettings.json` or CI YAML (not a secrets manager)
- Long CI times with no optimization effort
- `dotnet build` (without `-warnaserror`) hiding analyzer warnings in CI
- Publishing a NuGet package from CI without a signed/verified source code path

## Verification

After setting up or modifying CI:

- [ ] All quality gates are present (format, build with `-warnaserror`, test, vulnerability scan)
- [ ] Pipeline runs on every PR and push to main
- [ ] Failures block merge (branch protection configured)
- [ ] CI results feed back into the development loop (agent can read failure output)
- [ ] Secrets are stored in GitHub Secrets / Key Vault / Azure DevOps variable groups — not in code
- [ ] Deployment has a rollback mechanism (slot swap, image revert, or `dotnet ef database update <previous>`)
- [ ] Pipeline runs in under 10 minutes for the standard PR path (integration E2E can be longer)
- [ ] NuGet package PRs bump related packages in groups (`Microsoft.EntityFrameworkCore.*` together)

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/ci-cd-and-automation/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - Quality-gate pipeline block rewritten with .NET gate names (`dotnet format --verify-no-changes`, `dotnet build -warnaserror`, `dotnet test`, Testcontainers integration tests, Playwright.NET / Avalonia.Headless E2E, `dotnet list package --vulnerable`, `dotnet pack`)
  - Basic CI pipeline rewritten for `actions/setup-dotnet@v4` reading `global.json`, `dotnet restore` + `dotnet format` + `dotnet build -warnaserror` + `dotnet test` with `XPlat Code Coverage` + `dotnet list package --vulnerable`; added note that the command exits 0 even on findings
  - Integration-tests block keeps PostgreSQL `services:` example but calls out Testcontainers + `integration-testing-dotnet` as the preferred approach that makes the YAML simpler; uses `dotnet ef database update` for migrations; connection string via `ConnectionStrings__Default`
  - E2E section rewritten for Playwright.NET with the generated `playwright.ps1 install` step
  - Added a "Publishing a NuGet Package" tag-triggered job with MinVer/Nerdbank-compatible `fetch-depth: 0` note
  - Added an Azure DevOps Pipelines alternative for teams on that platform
  - Feedback-loop key-patterns list retargeted to dotnet format, analyzer diagnostic IDs (CA1822, IDE0051, EF1001), `Directory.Packages.props`/`global.json`, vulnerability allowlist
  - Preview Deployments rewritten for Azure App Service slot-per-PR with `azure/webapps-deploy@v3`; `dotnet publish` step
  - Feature Flags rewritten as `Microsoft.FeatureManagement` + `IFeatureManager` in a Minimal API; mentioned Azure App Configuration feature filters
  - Staged rollout bullets add Application Insights / Gen2 GC / thread-pool queue length as monitoring signals
  - Rollback example replaced Vercel-rollback with Azure App Service slot-swap via `azure/login@v2` + `az webapp deployment slot swap`; pointer to EF Core migration rollback + expand-contract
  - Environment management rewritten with `appsettings.*.json` hierarchy + `dotnet user-secrets` for dev + Azure Key Vault with OIDC federation for CI→Key Vault
  - Dependabot example swapped `package-ecosystem: npm` for `nuget`, added a `groups:` example for Microsoft.* + System.* packages
  - PR checks list adds squash/rebase preference tying into `git-workflow-and-versioning`
  - CI Optimization retargeted: NuGet cache + `--no-restore`/`--no-build` flags + `dotnet test --filter` for sharding
  - Caching/parallelism example rewritten with `actions/setup-dotnet@v4` and `global-json-file`
  - Rationalizations table adds rows on flaky tests via `TimeProvider`/`DbContext` scoping, `actions/setup-dotnet` brevity, `dotnet list package --vulnerable` triage
  - Red-flag list adds `[Fact(Skip = "…")]`, `dotnet build` without `-warnaserror`, unsigned NuGet publish path
  - Verification checklist items retargeted (build-with-warnaserror, Key Vault / GitHub Secrets / variable groups, slot swap or migration-down rollback, Microsoft.* grouping)
  - Preserved verbatim: Shift Left / Faster is Safer framing, quality-gate pipeline shape (gate list), feedback-loop diagram, Build Cop role, CI Optimization decision-tree structure, Common Rationalizations and Red Flags table frames
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
