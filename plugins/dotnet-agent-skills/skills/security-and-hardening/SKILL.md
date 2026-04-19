---
name: security-and-hardening
description: Hardens .NET/C# code against vulnerabilities — input validation (FluentValidation), EF Core parameterization, ASP.NET Core Identity / JWT bearer / policy-based authz, Data Protection, antiforgery, user-secrets + Key Vault, `dotnet list package --vulnerable`. Use when handling user input, authentication, data storage, or external integrations in ASP.NET Core, Blazor, or Avalonia/MAUI apps that talk to an API.
version: 0.3.0
source: vendor/agent-skills/skills/security-and-hardening/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. Note: this is the most heavily adapted skill in Wave 1 — upstream JS/npm examples have been fully rewritten for the .NET ecosystem. -->

# Security and Hardening

## Overview

Security-first development practices for .NET applications — ASP.NET Core web apps, Blazor, Avalonia, MAUI, and library code. Treat every external input as hostile, every secret as sacred, and every authorization check as mandatory. Security isn't a phase — it's a constraint on every line of code that touches user data, authentication, or external systems.

## When to Use

- Building anything that accepts user input (HTTP endpoints, message consumers, file watchers, UI text fields)
- Implementing authentication or authorization (ASP.NET Core Identity, cookie auth, JWT bearer, OAuth, policy-based authz)
- Storing or transmitting sensitive data (PII, payment info, API tokens, connection strings)
- Integrating with external APIs or services (HttpClient, gRPC, Service Bus)
- Adding file uploads, webhooks, or callbacks
- Handling payment or regulated data (GDPR, HIPAA, PCI DSS)

## The Three-Tier Boundary System

### Always Do (No Exceptions)

- **Validate all external input** at the system boundary (endpoints, message handlers) with FluentValidation / DataAnnotations / MediatR pipeline behaviour
- **Parameterize all database queries** — EF Core's LINQ does this by default; if you must drop to raw SQL, use `FromSql` with interpolated strings (parameterized) or `FromSqlInterpolated`, never `FromSqlRaw($"... {input}")`
- **Encode output** — Razor and Blazor auto-encode `@model.Something` by default; never use `@Html.Raw(userInput)` or `MarkupString` on user-sourced content
- **Use HTTPS** for all external communication; `app.UseHsts()` + `app.UseHttpsRedirection()` in `Program.cs`
- **Hash passwords** with ASP.NET Core Identity's `PasswordHasher<TUser>` (PBKDF2 with SHA-256, tuned work factor), or Argon2 via `Konscious.Security.Cryptography` for new systems
- **Set security headers** — CSP, HSTS, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin` (use `NetEscapades.AspNetCore.SecurityHeaders` or `Microsoft.AspNetCore.Authentication.Cookies`)
- **Use `HttpOnly`, `Secure`, `SameSite` cookies** for auth — ASP.NET Core cookie authentication sets these correctly by default; don't override them without a reason
- **Use antiforgery tokens** for state-changing requests in cookie-auth apps — `[ValidateAntiForgeryToken]` on MVC controllers, automatic for Razor Pages, `IAntiforgery` middleware for Minimal APIs
- **Audit dependencies** — `dotnet list package --vulnerable --include-transitive` before every release (add a CI step that fails on criticals)

### Ask First (Requires Human Approval)

- Adding new authentication flows or changing auth logic (OIDC scheme changes, external provider integrations)
- Storing new categories of sensitive data (PII, payment info, health records)
- Adding new external service integrations
- Changing CORS configuration (`app.UseCors(...)`)
- Adding file upload handlers
- Modifying rate limiting or throttling (`AddRateLimiter(...)`)
- Granting elevated permissions, new `[Authorize(Policy = "…")]` values, or new roles
- Rotating the Data Protection key ring (will invalidate all existing auth cookies and encrypted payloads)

### Never Do

- **Never commit secrets** to version control (API keys, connection strings with passwords, JWT signing keys, certificate `.pfx` files)
- **Never log sensitive data** (passwords, tokens, full credit card numbers, PII beyond what's audit-required) — scrub at the `ILogger` boundary
- **Never trust client-side validation** as a security boundary (Blazor WebAssembly is client-side; validate again on the server)
- **Never disable security headers** for convenience
- **Never use `BinaryFormatter`** for anything, ever (officially deprecated and unsafe — the framework itself emits a compile-time error now)
- **Never use `MarkupString` / `@Html.Raw` with user content** without sanitization (XSS vector)
- **Never store auth tokens in browser `localStorage`** from Blazor WebAssembly — use `HttpOnly` cookies or `sessionStorage` with short lifetimes and accept the XSS exposure risk
- **Never expose stack traces** or internal error details to users — ASP.NET Core's production `UseExceptionHandler("/Error")` strips them by default, keep it that way
- **Never interpolate user input into `FromSqlRaw`** — use `FromSqlInterpolated($"...{input}")` so EF Core parameterizes it, or `FromSql($"...{input}")` in newer versions

## OWASP Top 10 Prevention (C# / .NET)

### 1. Injection (SQL, NoSQL, OS Command)

```csharp
// BAD: SQL injection via interpolation into FromSqlRaw
var user = await db.Users
    .FromSqlRaw($"SELECT * FROM Users WHERE Id = '{userId}'")
    .FirstOrDefaultAsync();

// GOOD: EF Core LINQ (parameterized automatically)
var user = await db.Users.SingleOrDefaultAsync(u => u.Id == userId, cancellationToken);

// GOOD: Raw SQL when you need it, parameterized
var user = await db.Users
    .FromSqlInterpolated($"SELECT * FROM Users WHERE Id = {userId}") // EF Core parameterizes {userId}
    .FirstOrDefaultAsync(cancellationToken);

// GOOD: Dapper also parameterizes with anonymous-object parameters
var user = await connection.QuerySingleOrDefaultAsync<User>(
    "SELECT * FROM Users WHERE Id = @Id",
    new { Id = userId });
```

For OS commands (`Process.Start`), never concatenate user input — use the `ProcessStartInfo.ArgumentList` collection (each item escaped individually) instead of `Arguments` (single-string interpolation).

### 2. Broken Authentication

```csharp
// ASP.NET Core Identity — hashes with PBKDF2 by default
// Program.cs
builder.Services
    .AddIdentity<ApplicationUser, IdentityRole>(options =>
    {
        options.Password.RequiredLength = 12;
        options.Password.RequireNonAlphanumeric = true;
        options.Lockout.MaxFailedAccessAttempts = 5;
        options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
    })
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();

// Cookie auth hardening
builder.Services.ConfigureApplicationCookie(options =>
{
    options.Cookie.HttpOnly = true;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.ExpireTimeSpan = TimeSpan.FromHours(24);
    options.SlidingExpiration = true;
});
```

For JWT bearer auth, validate issuer + audience + signing key + lifetime + clock skew explicitly:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!)),
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
```

### 3. Cross-Site Scripting (XSS)

For Razor Pages / MVC / Blazor, auto-encoding is the default:

```razor
@* GOOD: Razor auto-encodes by default *@
<p>@Model.UserInput</p>

@* BAD: Raw HTML rendering of user input *@
<p>@Html.Raw(Model.UserInput)</p>

@* Blazor equivalent — auto-encoded *@
<p>@userInput</p>

@* BAD in Blazor: MarkupString bypasses encoding *@
<p>@((MarkupString)userInput)</p>
```

If you must render user HTML (rich-text editors, markdown), sanitize with [HtmlSanitizer](https://github.com/mganss/HtmlSanitizer):

```csharp
var sanitizer = new HtmlSanitizer();
var clean = sanitizer.Sanitize(userHtml);
```

For Avalonia/MAUI apps, XSS doesn't apply (no HTML renderer) but the same principle holds: anything you push through a WebView or format-string sink needs encoding.

### 4. Broken Access Control

Always check authorization, not just authentication. Prefer policy-based authz over role-checking strings scattered in code:

```csharp
// Program.cs — define policies centrally
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("TaskOwner", policy =>
        policy.Requirements.Add(new ResourceOwnerRequirement()));
});

builder.Services.AddScoped<IAuthorizationHandler, ResourceOwnerHandler>();

// Endpoint
app.MapPatch("/api/tasks/{id}", async (
    string id,
    UpdateTaskInput input,
    ITaskService service,
    IAuthorizationService authz,
    ClaimsPrincipal user,
    CancellationToken cancellationToken) =>
{
    var task = await service.FindByIdAsync(id, cancellationToken);
    if (task is null) return Results.NotFound();

    var authzResult = await authz.AuthorizeAsync(user, task, "TaskOwner");
    if (!authzResult.Succeeded)
    {
        return Results.Problem(
            statusCode: StatusCodes.Status403Forbidden,
            title: "Forbidden",
            detail: "Not authorized to modify this task");
    }

    var updated = await service.UpdateAsync(id, input, cancellationToken);
    return Results.Ok(updated);
})
.RequireAuthorization();
```

Authentication answers "are you logged in"; authorization answers "can you do this to this resource". Both must pass.

### 5. Security Misconfiguration

```csharp
// Program.cs — security headers
app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    context.Response.Headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
    await next();
});

// Content Security Policy — prefer the NetEscapades.AspNetCore.SecurityHeaders package
app.UseSecurityHeaders(policies =>
    policies
        .AddContentSecurityPolicy(builder =>
        {
            builder.AddDefaultSrc().Self();
            builder.AddScriptSrc().Self();
            builder.AddStyleSrc().Self().UnsafeInline(); // tighten if possible
            builder.AddImgSrc().Self().From("data:").From("https:");
            builder.AddConnectSrc().Self();
        }));

// HSTS + HTTPS redirect
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}
app.UseHttpsRedirection();

// CORS — restrict to known origins (NEVER "*" with credentials)
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy => policy
        .WithOrigins(builder.Configuration.GetSection("AllowedOrigins").Get<string[]>() ?? [])
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials());
});
```

### 6. Sensitive Data Exposure

Never return sensitive fields in API responses — use DTOs that exclude them:

```csharp
// Don't serialize the entity directly. Project to a DTO.
public sealed record PublicUserDto(string Id, string Email, string DisplayName);

public static PublicUserDto ToPublicDto(this ApplicationUser user) =>
    new(user.Id, user.Email!, user.DisplayName);

// Don't put secrets in source
// BAD
public const string ApiKey = "sk_live_…";

// GOOD: read from IConfiguration (dotnet user-secrets / env / Key Vault)
public sealed class StripeOptions
{
    public required string ApiKey { get; init; }
}

builder.Services
    .AddOptions<StripeOptions>()
    .Bind(builder.Configuration.GetSection("Stripe"))
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

**ASP.NET Core Data Protection** handles session cookies and anti-forgery tokens for you, but for encrypting arbitrary data at rest (PII fields in a database, for example), use `IDataProtectionProvider` with a named purpose string and configure a shared key ring on Azure Key Vault / Redis / file share when running multiple instances.

## Input Validation Patterns

### Schema Validation at Boundaries (FluentValidation)

```csharp
public sealed record CreateTaskInput(
    string Title,
    string? Description,
    TaskPriority Priority = TaskPriority.Medium,
    DateTimeOffset? DueDate = null);

public sealed class CreateTaskValidator : AbstractValidator<CreateTaskInput>
{
    public CreateTaskValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Description).MaximumLength(2000);
        RuleFor(x => x.Priority).IsInEnum();
        RuleFor(x => x.DueDate).GreaterThan(DateTimeOffset.UtcNow).When(x => x.DueDate is not null);
    }
}

// Endpoint
app.MapPost("/api/tasks", async (
    CreateTaskInput input,
    IValidator<CreateTaskInput> validator,
    ITaskService service,
    CancellationToken cancellationToken) =>
{
    var result = await validator.ValidateAsync(input, cancellationToken);
    if (!result.IsValid)
    {
        return Results.ValidationProblem(result.ToDictionary());
    }

    var task = await service.CreateAsync(input, cancellationToken);
    return Results.Created($"/api/tasks/{task.Id}", task);
});
```

### File Upload Safety

```csharp
private static readonly HashSet<string> AllowedContentTypes = new(StringComparer.OrdinalIgnoreCase)
{
    "image/jpeg", "image/png", "image/webp"
};

private static readonly Dictionary<string, byte[]> MagicBytes = new()
{
    ["image/jpeg"] = [0xFF, 0xD8, 0xFF],
    ["image/png"]  = [0x89, 0x50, 0x4E, 0x47],
    ["image/webp"] = [0x52, 0x49, 0x46, 0x46], // 'RIFF', plus WEBP at offset 8
};

private const long MaxSizeBytes = 5 * 1024 * 1024; // 5 MB

public async Task ValidateUploadAsync(IFormFile file, CancellationToken cancellationToken)
{
    if (file.Length == 0 || file.Length > MaxSizeBytes)
    {
        throw new ValidationException("File is empty or exceeds the 5 MB limit.");
    }

    if (!AllowedContentTypes.Contains(file.ContentType))
    {
        throw new ValidationException("Content type not allowed.");
    }

    // Don't trust the file extension or the declared ContentType — sniff the magic bytes.
    await using var stream = file.OpenReadStream();
    Span<byte> header = stackalloc byte[8];
    var read = await stream.ReadAsync(header.ToArray(), cancellationToken);

    var matches = MagicBytes
        .Where(kv => file.ContentType.Equals(kv.Key, StringComparison.OrdinalIgnoreCase))
        .Any(kv => header[..kv.Value.Length].SequenceEqual(kv.Value));

    if (!matches)
    {
        throw new ValidationException("File contents do not match the declared content type.");
    }
}
```

Store uploads outside the web root, scan with an AV pipeline (ClamAV, Defender) if accepting from untrusted users, and serve through a controller that sets `Content-Disposition: attachment` with a sanitized filename.

## Triaging `dotnet list package --vulnerable` Results

Not all audit findings require immediate action. Use this decision tree:

```
dotnet list package --vulnerable --include-transitive reports a vulnerability
├── Severity: Critical or High
│   ├── Is the vulnerable code reachable in your app?
│   │   ├── YES → Fix immediately (update NuGet version, replace the package, or patch)
│   │   └── NO (dev-only dep, unused code path, netstandard2.0 polyfill that's never hit)
│   │       → Fix soon, but not a release-blocker
│   └── Is a fix available?
│       ├── YES → Bump in Directory.Packages.props, verify via dotnet build + dotnet test
│       └── NO → Consider replacing the package, apply a manual workaround, or add to
│                an allowlist with a review date
├── Severity: Moderate
│   ├── Reachable in production? → Fix in the next release cycle
│   └── Dev-only / Test-only? → Fix when convenient, track in backlog
└── Severity: Low
    └── Track and fix during regular dependency updates (Renovate / Dependabot PRs)
```

**Key questions:**
- Is the vulnerable type/method actually called in your code path? `dotnet list package --vulnerable --include-transitive` shows transitive dependencies — not all transitive criticals are reachable.
- Is the dependency in a test-only project or a build-time tool? Test-only criticals still need tracking but don't block production.
- Is the vulnerability exploitable given your deployment context (e.g., a server-side RCE in a package you only use client-side)?

When you defer a fix, document the reason and set a review date. Consider wiring [Renovate](https://docs.renovatebot.com/) or Dependabot to create PRs for security updates automatically so the backlog doesn't rot.

## Rate Limiting

.NET 7+ ships built-in rate limiting via `Microsoft.AspNetCore.RateLimiting`:

```csharp
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("general", opt =>
    {
        opt.PermitLimit = 100;
        opt.Window = TimeSpan.FromMinutes(15);
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = 0;
    });

    options.AddFixedWindowLimiter("auth", opt =>
    {
        opt.PermitLimit = 10;
        opt.Window = TimeSpan.FromMinutes(15);
    });

    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

app.UseRateLimiter();

app.MapGroup("/api").RequireRateLimiting("general");
app.MapGroup("/api/auth").RequireRateLimiting("auth");
```

For distributed scenarios (multiple instances), back the limiter with a shared store (Redis via `RedisRateLimiting`) or accept that per-instance limits are approximations.

## Secrets Management

```
Development:
  ├── dotnet user-secrets init --project src/MyApp
  ├── dotnet user-secrets set "Stripe:ApiKey" "sk_test_..." --project src/MyApp
  └── (stored outside the repo at %APPDATA%\Microsoft\UserSecrets\<id>\secrets.json)

Production:
  ├── Azure Key Vault + Managed Identity (AddAzureKeyVault in Program.cs)
  ├── AWS Secrets Manager / Parameter Store
  ├── Environment variables (last resort — appears in process listings, logs)
  └── NEVER appsettings.json committed to git

.gitignore must include:
  appsettings.*.local.json
  *.pfx
  *.key
  *.pem
  secrets.json
  .env
```

**Always check before committing:**
```bash
# Check for accidentally staged secrets
git diff --cached | grep -iE "password|secret|api.?key|connectionstring|bearer|-----BEGIN"
```

Wire up a pre-commit hook (Husky.Net) that runs this and fails the commit on a match.

## Security Review Checklist

```markdown
### Authentication
- [ ] Passwords hashed with PasswordHasher<TUser> or Argon2 (Konscious)
- [ ] Cookies are HttpOnly + Secure + SameSite (defaults in ASP.NET Core)
- [ ] Login has rate limiting (AddFixedWindowLimiter on /api/auth)
- [ ] Password reset tokens expire (ASP.NET Core Identity default: 1 day)
- [ ] JWT bearer validates issuer + audience + lifetime + signing key + clock skew
- [ ] MFA available for admin accounts

### Authorization
- [ ] Every endpoint has [Authorize] or RequireAuthorization() unless explicitly public
- [ ] Users can only access their own resources (resource-based policy with IAuthorizationHandler)
- [ ] Admin actions require a dedicated policy, not just a role claim check
- [ ] Antiforgery tokens on state-changing requests in cookie-auth apps

### Input
- [ ] All user input validated at the boundary (FluentValidation / DataAnnotations)
- [ ] EF Core LINQ everywhere; any FromSqlRaw use is justified in a code comment
- [ ] Razor/Blazor auto-encoding preserved; no MarkupString / @Html.Raw on user content
- [ ] File uploads validate magic bytes, size, and content type; stored outside web root

### Data
- [ ] No secrets in code, appsettings.json, or git history
- [ ] Sensitive fields excluded from DTOs (never serialize Identity entities directly)
- [ ] PII encrypted at rest via IDataProtectionProvider (key ring shared across instances)

### Infrastructure
- [ ] HSTS + HTTPS redirect enabled in non-Development
- [ ] Security headers configured (CSP, X-Content-Type-Options, X-Frame-Options)
- [ ] CORS restricted to known origins (never "*" with AllowCredentials)
- [ ] dotnet list package --vulnerable clean or documented allowlist with review date
- [ ] Production error page (UseExceptionHandler) strips internal details
```

## See Also

- Upstream checklist (generic, pre-dates this adaptation): [`../../vendor/agent-skills/references/security-checklist.md`](../../vendor/agent-skills/references/security-checklist.md)
- ASP.NET Core security docs: https://learn.microsoft.com/aspnet/core/security/
- EF Core raw-SQL safety: https://learn.microsoft.com/ef/core/querying/sql-queries
- Data Protection: https://learn.microsoft.com/aspnet/core/security/data-protection/

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This is an internal tool, security doesn't matter" | Internal tools get compromised. Attackers target the weakest link; a stolen internal cookie pivots to production. |
| "We'll add security later" | Security retrofitting is 10x harder than building it in. Add it now. Retrofitting `[Authorize]` onto 50 endpoints is tedious *and* error-prone. |
| "No one would try to exploit this" | Automated scanners find it within hours of going public. Security by obscurity is not security. |
| "ASP.NET Core handles security for me" | The framework provides tools; you still have to use them correctly. `[Authorize]` is opt-in; `FromSqlRaw` still compiles; `MarkupString` is a foot-gun. |
| "It's just a prototype" | Prototypes become production. Security habits from day one — it's cheaper than retrofitting. |
| "dotnet list package --vulnerable is noisy" | Noisy means underlying risk, not noise. Triage it; don't ignore it. |
| "Client-side validation in Blazor WebAssembly is enough" | Blazor WebAssembly runs in the user's browser — they can bypass it. Validate on the server again. |

## Red Flags

- User input passed directly to `FromSqlRaw`, `Process.Start(string)`, or `@Html.Raw`
- Secrets in `appsettings.json` checked into git, or `dotnet user-secrets` not set up for the project
- HTTP endpoints without `[Authorize]`, `RequireAuthorization()`, or an explicit "public" annotation
- Missing CORS configuration, or `AllowAnyOrigin()` combined with `AllowCredentials()`
- No rate limiting on auth endpoints
- Stack traces or `ex.ToString()` returned to clients in production
- NuGet dependencies with known Critical or High vulnerabilities and no allowlist entry
- `BinaryFormatter` anywhere in new code
- `MarkupString` / `@Html.Raw` applied to user-sourced HTML
- JWT validation missing any of: issuer, audience, lifetime, signing key, clock skew
- Auth tokens stored in Blazor WebAssembly `localStorage`

## Verification

After implementing security-relevant code:

- [ ] `dotnet list package --vulnerable --include-transitive` shows no unreviewed Critical or High vulnerabilities
- [ ] No secrets in source code or git history (`git log -p | grep -iE "password|apikey"` returns nothing)
- [ ] All user input validated at system boundaries
- [ ] Authentication and authorization checked on every protected endpoint (resource-based authz for user-owned resources)
- [ ] Security headers present in response (check with browser DevTools or `curl -I`)
- [ ] Production error responses don't expose internal details
- [ ] Rate limiting active on auth endpoints
- [ ] File upload handlers validate magic bytes, not just declared content type
- [ ] Data Protection key ring is persisted and shared across instances for multi-node deployments

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/security-and-hardening/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified` (heavy — nearly every code example and tooling reference has been retargeted; upstream structure, OWASP numbering, three-tier boundary frame, and rationalization-table schema preserved)
- **Changes**:
  - Three-tier Always/Ask-First/Never lists rewritten for the .NET ecosystem: FluentValidation, EF Core parameterization, Razor/Blazor auto-encoding, ASP.NET Core Identity `PasswordHasher<TUser>` / Argon2, `NetEscapades.AspNetCore.SecurityHeaders`, ASP.NET Core cookie defaults, antiforgery (`IAntiforgery` / `[ValidateAntiForgeryToken]`), `dotnet list package --vulnerable`, `BinaryFormatter` ban, `MarkupString` / `@Html.Raw` ban, `FromSqlRaw` vs `FromSqlInterpolated`, Data Protection key ring rotation
  - OWASP #1 Injection rewritten with EF Core LINQ vs `FromSqlRaw` vs `FromSqlInterpolated`, Dapper parameterized queries, `ProcessStartInfo.ArgumentList` for command injection
  - OWASP #2 Broken Authentication replaced bcrypt + express-session with ASP.NET Core Identity + `ConfigureApplicationCookie` + JWT bearer `TokenValidationParameters` (issuer/audience/lifetime/signing-key/clock-skew)
  - OWASP #3 XSS rewritten for Razor/Blazor auto-encoding and `MarkupString` foot-gun, pointing at [HtmlSanitizer](https://github.com/mganss/HtmlSanitizer); Avalonia/MAUI called out as non-applicable except through WebView/format sinks
  - OWASP #4 Broken Access Control rewritten as policy-based authz with `IAuthorizationService`, `ResourceOwnerRequirement`, `ClaimsPrincipal`, `Results.Problem(403)`
  - OWASP #5 Misconfiguration replaced `helmet` / `cors` with ASP.NET Core header middleware, `NetEscapades.AspNetCore.SecurityHeaders` CSP builder, `UseHsts`/`UseHttpsRedirection`, `AddCors`
  - OWASP #6 Sensitive Data Exposure rewritten to project to DTOs (don't serialize Identity entities); `IOptions` binding with `ValidateDataAnnotations()` + `ValidateOnStart()`; `IDataProtectionProvider` for encrypted PII at rest with shared key ring guidance
  - Input validation rewritten as FluentValidation + `Results.ValidationProblem`
  - File upload safety rewritten around `IFormFile` with magic-byte sniffing, `AllowedContentTypes`, `MagicBytes`, AV scanning note
  - "Triaging `npm audit` Results" replaced with "Triaging `dotnet list package --vulnerable` Results" — decision tree retargeted (netstandard2.0 polyfill examples, Directory.Packages.props bumps, Renovate/Dependabot)
  - Rate limiting section replaced `express-rate-limit` with .NET 7+ `AddRateLimiter` + `AddFixedWindowLimiter` + `Microsoft.AspNetCore.RateLimiting`, with distributed-limiter note
  - Secrets management rewritten around `dotnet user-secrets init`, Azure Key Vault + Managed Identity, `.gitignore` covers `.pfx`/`.key`/`.pem`/`secrets.json`/`appsettings.*.local.json`
  - Pre-commit secret check grep extended with `connectionstring`, `bearer`, `-----BEGIN` (PEM private key prefix)
  - Security Review Checklist fully rewritten with .NET-specific bullets (PasswordHasher, JWT validation parameters, MFA, `[Authorize]`, FluentValidation, magic-byte uploads, Data Protection key ring, HSTS)
  - Added "See Also" links to Microsoft Learn pages for ASP.NET Core security, EF Core raw-SQL safety, and Data Protection
  - Rationalizations table adds Blazor WebAssembly client-side-trust rationalization
  - Red-flag list rewritten with .NET-specific vectors (`FromSqlRaw`, `@Html.Raw`, `MarkupString`, missing `[Authorize]`, `AllowAnyOrigin()` + `AllowCredentials()`, `BinaryFormatter`, JWT missing validations, Blazor WebAssembly localStorage)
  - Verification checklist retargeted (`dotnet list package --vulnerable`, `git log -p | grep` secret scan, multi-node Data Protection key-ring check, magic-byte upload verification)
  - Preserved: three-tier Always/Ask-First/Never framework, OWASP Top 10 numbering (#1 Injection, #2 Broken Auth, #3 XSS, #4 Broken Access Control, #5 Misconfig, #6 Sensitive Data Exposure), decision-tree shape for vulnerability triage, overall section ordering, rationalization table schema
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
