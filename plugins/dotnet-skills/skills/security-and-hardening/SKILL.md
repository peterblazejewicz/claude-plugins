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

## Process: Threat Model First

Controls bolted on without a threat model are guesses. Before hardening, spend five minutes thinking like an attacker:

1. **Map the trust boundaries.** Where does untrusted data cross into your system? HTTP requests (body, route, query, headers), form fields, `IFormFile` uploads, webhooks, third-party API responses, `Service Bus` / queue messages, and **LLM output**. Every boundary is attack surface.
2. **Name the assets.** What's worth stealing or breaking? Credentials, PII, payment data, admin actions, money movement.
3. **Run STRIDE over each boundary** — a quick lens, not a ceremony:

| Threat | Ask | Typical .NET mitigation |
|---|---|---|
| **S**poofing | Can someone impersonate a user/service? | ASP.NET Core Identity / JWT bearer auth, HMAC signature verification on webhooks |
| **T**ampering | Can data be altered in transit or at rest? | HTTPS + HSTS, parameterized EF Core queries, Data Protection integrity |
| **R**epudiation | Can an action be denied later? | Audit logging of security events (structured `ILogger`) |
| **I**nformation disclosure | Can data leak? | DTO field allowlists, `ProblemDetails` generic errors, encryption at rest |
| **D**enial of service | Can it be overwhelmed? | `AddRateLimiter`, `RequestSizeLimit` / `FormOptions`, `CancellationToken` + timeouts |
| **E**levation of privilege | Can a user gain rights they shouldn't? | Policy-based `[Authorize]`, per-resource `IAuthorizationService` checks, least privilege |

4. **Write abuse cases next to use cases.** For each feature, ask "how would I misuse this?" — then make that your first xUnit/MSTest test.

If you can't name the trust boundaries for a feature, you're not ready to secure it. This is OWASP **A04: Insecure Design** — most breaches begin in design, not code.

## The Three-Tier Boundary System

> **Host-model lens.** Most bullets below target **ASP.NET Core server code** (Web APIs, Razor Pages, Blazor Server). Cross-cutting items — secret handling, no `BinaryFormatter`, parameterized queries — apply to any .NET host, including Avalonia / MAUI / console apps that talk to a database or external service. Client-only items (Blazor WebAssembly `localStorage`, antiforgery tokens in cookie-auth apps) are labeled inline. When in doubt about whether a bullet applies to your host, check the examples.

### Always Do (No Exceptions)

- **Validate all external input** at the system boundary (endpoints, message handlers) with FluentValidation / DataAnnotations / MediatR pipeline behaviour
- **Parameterize all database queries** — EF Core's LINQ does this by default; for raw SQL prefer `FromSql($"...{input}")` on EF Core 8+ (the `FormattableString` overload parameterizes automatically), or `FromSqlInterpolated($"...{input}")` on EF Core 7 and earlier. Never `FromSqlRaw($"...{input}")` — the `string` overload interpolates in C# **before** EF Core sees the query
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
- **Never interpolate user input into `FromSqlRaw`** — on EF Core 8+ use `FromSql($"...{input}")`; on earlier versions `FromSqlInterpolated($"...{input}")`. Both overloads take `FormattableString` and parameterize each `{}` hole; `FromSqlRaw` takes a plain `string` and does not

## OWASP Top 10 Prevention (C# / .NET)

### 1. Injection (SQL, NoSQL, OS Command)

**Server-side (EF Core raw-SQL APIs)** — `FromSqlRaw`, `FromSqlInterpolated`, and `FromSql` look similar at the call site but have opposite safety semantics:

```csharp
// BAD: SQL injection — FromSqlRaw takes a `string`; the interpolation happens in C#
//      and the user-controlled value lands directly inside the query text.
var user = await db.Users
    .FromSqlRaw($"SELECT * FROM Users WHERE Id = '{userId}'")
    .FirstOrDefaultAsync(cancellationToken);

// GOOD: LINQ — EF Core parameterizes automatically. Prefer this whenever the
//       query shape can be expressed in LINQ.
var user = await db.Users
    .SingleOrDefaultAsync(u => u.Id == userId, cancellationToken);

// GOOD (EF Core 8+, the canonical form): FromSql — the `FormattableString`
//        overload sees each `{}` hole and parameterizes it, even though the
//        syntax looks like C# interpolation.
var user = await db.Users
    .FromSql($"SELECT * FROM Users WHERE Id = {userId}")
    .FirstOrDefaultAsync(cancellationToken);

// GOOD (EF Core 7 and earlier): FromSqlInterpolated — identical safety to the
// EF Core 8+ FromSql above. Still works on EF Core 8+, but FromSql is the
// recommended name going forward.
var user = await db.Users
    .FromSqlInterpolated($"SELECT * FROM Users WHERE Id = {userId}")
    .FirstOrDefaultAsync(cancellationToken);

// GOOD: Dapper — anonymous-object parameters, never string concatenation
var user = await connection.QuerySingleOrDefaultAsync<User>(
    "SELECT * FROM Users WHERE Id = @Id",
    new { Id = userId });
```

> **The trap**: `FromSqlRaw($"...{userId}...")` and `FromSql($"...{userId}...")` look nearly identical in source, but the method overload resolution picks opposite paths — `FromSqlRaw` takes a `string` (C# formats it before EF Core sees anything) while `FromSql` and `FromSqlInterpolated` take a `FormattableString` (EF Core sees the holes and parameterizes them). When in doubt, call `FromSql` explicitly — the compiler will reject a plain concatenated string.

**Server-side (OS commands)** — for `Process.Start`, never concatenate user input into `ProcessStartInfo.Arguments` (single string, prone to quoting bugs). Use `ProcessStartInfo.ArgumentList` instead — each item is escaped individually by the runtime.

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

### 7. Server-Side Request Forgery (SSRF)

Any time the server fetches a URL the user influenced — webhooks, "import from URL", image proxies, link previews — an attacker can aim it at internal services (cloud metadata, `localhost`, private IPs). The #1 target is the cloud metadata endpoint `169.254.169.254` (Azure IMDS, AWS/GCP metadata), which can hand out managed-identity tokens.

```csharp
// BAD: fetch whatever the user gives you
var content = await httpClient.GetStringAsync(input.WebhookUrl, ct);

// GOOD: allowlist scheme + host, and pin the connection to a validated public IP
static readonly HashSet<string> AllowedHosts = new(StringComparer.OrdinalIgnoreCase) { "hooks.example.com" };

static Uri AssertSafeUrl(string raw)
{
    if (!Uri.TryCreate(raw, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
        throw new ValidationException("https URL required");
    if (!AllowedHosts.Contains(uri.Host))
        throw new ValidationException("host not allowed");
    return uri;
}

// Pin DNS at connect time so a short-TTL record can't rebind to an internal IP
// between validation and connection (the TOCTOU gap).
var handler = new SocketsHttpHandler
{
    AllowAutoRedirect = false,                 // a 302 to http://169.254.169.254 must not be followed
    ConnectCallback = async (ctx, ct) =>
    {
        var entries = await Dns.GetHostAddressesAsync(ctx.DnsEndPoint.Host, ct);
        foreach (var ip in entries)
            if (IsPrivateOrReserved(ip))        // loopback, link-local (169.254/16, fe80::/10), private, ULA
                throw new ValidationException("resolves to a private/reserved address");
        var socket = new Socket(SocketType.Stream, ProtocolType.Tcp) { NoDelay = true };
        await socket.ConnectAsync(entries, ctx.DnsEndPoint.Port, ct);
        return new NetworkStream(socket, ownsSocket: true);
    }
};
```

`IsPrivateOrReserved` should reject loopback, link-local (`169.254.0.0/16`, `fe80::/10`), private (`10/8`, `172.16/12`, `192.168/16`), and unique-local (`fc00::/7`) ranges across IPv4 and IPv6 — `IPAddress.IsLoopback` plus explicit range checks. Disabling redirects is load-bearing: without it, an allowlisted host can 302 you straight to the metadata endpoint.

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

### Supply-Chain Hygiene

`dotnet list package --vulnerable` catches known CVEs; it won't catch a malicious or typosquatted package. Also:

- **Lock and restore reproducibly.** Commit `packages.lock.json` (enable with `<RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>`) and restore with `dotnet restore --locked-mode` in CI — no silent transitive version drift between machines.
- **Pin package sources.** Configure `<packageSourceMapping>` in `nuget.config` so each package can only come from the expected feed; a public-feed package can't silently shadow a private one (dependency-confusion defense).
- **Review new dependencies before adding them** — maintenance, download counts, and whether they truly earn their place. Every dependency is attack surface (OWASP **A06: Vulnerable Components**, **LLM03: Supply Chain**).
- **Be wary of build-time code execution** — NuGet packages can ship MSBuild `.targets`/`.props` and (legacy) install scripts that run during restore/build. Treat an unfamiliar package's build hooks like any untrusted code.
- **Prefer signed packages** and consider `<trustedSigners>` in `nuget.config` for high-assurance environments.
- **Watch for typosquats** — `Newtonsoft.Json` vs `Newtonsoft.Jsons`, `Serilog` vs `Seri1og`.

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

**If a secret is ever committed, rotate it.** Deleting the line or rewriting history is not enough — assume it's compromised the moment it reaches a remote (forks, CI logs, and mirrors may already have it). Revoke and reissue the key first (rotate the Key Vault secret / regenerate the API key / cycle the connection string), *then* purge it from history.

## Securing AI / LLM Features

If your app calls an LLM — chatbots, summarizers, agents, RAG, anything through `Microsoft.Extensions.AI`, Semantic Kernel, or the Azure OpenAI SDK — it inherits a new attack surface. Map it to the [OWASP Top 10 for LLM Applications (2025)](https://genai.owasp.org/llm-top-10/):

- **Treat all model output as untrusted input (LLM05: Improper Output Handling).** Never pass model output straight into `FromSqlRaw`, `Process.Start`, a `MarkupString` / `@Html.Raw` sink, a file path, or a reflection/`Type.GetType` call. Validate and encode it exactly as you would raw user input.
- **Assume prompts can be hijacked (LLM01: Prompt Injection).** Untrusted text in the context window — a user message, a fetched web page, a PDF — can carry instructions. The system prompt is not a security boundary; enforce permissions in code (policy-based `[Authorize]`, per-resource checks), not in the prompt.
- **Keep secrets and other users' data out of prompts (LLM02 / LLM07).** Anything in the context can be echoed back. Don't put API keys, connection strings, cross-tenant data, or the full system prompt where the model can repeat it.
- **Constrain tool and agent permissions (LLM06: Excessive Agency).** Scope Semantic Kernel functions / tool callbacks to the minimum, require confirmation for destructive or irreversible actions, and validate every tool argument before executing.
- **Bound consumption (LLM10: Unbounded Consumption).** Cap `MaxOutputTokens`, request rate (`AddRateLimiter`), and loop/recursion depth so a crafted input can't run up cost or hang the system. Always thread a `CancellationToken`.
- **Isolate retrieval data (LLM08: Vector and Embedding Weaknesses).** In RAG, treat the vector store as a trust boundary: partition embeddings per tenant so one user can't retrieve another's data, and validate documents before indexing so poisoned content can't steer answers.

```csharp
// BAD: trusting model output as a command or as markup
var sql = await chat.CompleteAsync($"Write SQL for: {userQuestion}", ct);
await db.Database.ExecuteSqlRawAsync(sql.Text, ct);              // arbitrary query execution
var html = (MarkupString)(await chat.CompleteAsync(userMessage, ct)).Text;  // stored XSS, via the model

// GOOD: model output is data — parse defensively, then validate, then act through an allowlist
CommandIntent intent;
try
{
    var json = (await chat.CompleteAsync(userMessage, ct)).Text;
    intent = JsonSerializer.Deserialize<CommandIntent>(json) ?? throw new ValidationException("null intent");
    await _validator.ValidateAndThrowAsync(intent, ct);          // FluentValidation
}
catch (Exception ex) when (ex is JsonException or ValidationException)
{
    throw new ValidationException("unexpected model output");
}
await RunAllowlistedActionAsync(intent.Action, intent.Params, ct);
```

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
- [ ] Server-side fetches of user-supplied URLs are allowlisted and pinned (no SSRF to 169.254.169.254 / internal services)

### Supply Chain
- [ ] packages.lock.json committed; CI restores with --locked-mode
- [ ] nuget.config uses packageSourceMapping (dependency-confusion defense)
- [ ] New dependencies reviewed (maintenance, downloads, build .targets/.props hooks)

### AI / LLM (if used)
- [ ] Model output treated as untrusted (no FromSqlRaw / Process.Start / MarkupString / @Html.Raw / reflection sinks)
- [ ] Secrets and other users' data kept out of prompts; system prompt not echoable
- [ ] Tool/agent permissions scoped; destructive actions require confirmation; tokens/rate/recursion bounded
```

## See Also

- Upstream checklist (generic, pre-dates this adaptation): https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/references/security-checklist.md
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
| "Threat modeling is overkill here" | Five minutes of "how would I attack this?" with STRIDE over each boundary prevents the design flaws no `[Authorize]` attribute can patch later. |
| "It's just LLM output, it's only text" | That "text" can be a SQL statement, a `MarkupString`, or a shell command. Treat model output like any untrusted input. |

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
- Server fetches a user-supplied URL with a bare `HttpClient` (no host allowlist / IP pinning / redirect block) — SSRF
- LLM/model output passed into `FromSqlRaw`, `Process.Start`, `MarkupString` / `@Html.Raw`, or a reflection sink
- Secrets, PII, or the full system prompt placed inside an LLM context window

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
- [ ] A threat model (trust boundaries + STRIDE) was sketched for new attack surface before hardening
- [ ] Server-side URL fetches are allowlisted and IP-pinned with redirects disabled (no SSRF)
- [ ] LLM/model output is parsed defensively, validated, and encoded before use (if AI features present)

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/3a6fc6392823e31e2362091bd4e3cddf5b77af14/skills/security-and-hardening/SKILL.md
- **Pinned commit**: `3a6fc6392823e31e2362091bd4e3cddf5b77af14` (synced 2026-06-14; body originally ported at `44dac80`, unchanged upstream through `1f66d57`, expanded by upstream PR #219 at `3a6fc63`)
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
  - **Upstream sync 2026-06-14 (plugin v2.6.0)** — ported upstream PR #219's expansion, retargeted to .NET:
    - **`## Process: Threat Model First`** added before the Three-Tier Boundary System — trust-boundary mapping (HTTP/`IFormFile`/webhooks/`Service Bus`/LLM output), a STRIDE table with .NET mitigations (Identity/JWT, parameterized EF Core, `AddRateLimiter`, policy-based `[Authorize]`), abuse-cases-as-tests, framed as OWASP A04
    - **OWASP #7 SSRF** added — `HttpClient` host allowlist + `SocketsHttpHandler.ConnectCallback` that pins DNS and rejects private/reserved IPs (closes the TOCTOU/DNS-rebinding gap upstream flagged), `AllowAutoRedirect = false` so an allowlisted host can't 302 to `169.254.169.254` (Azure IMDS)
    - **Supply-Chain Hygiene** subsection added after the vulnerable-package triage — `packages.lock.json` + `dotnet restore --locked-mode`, `nuget.config` `<packageSourceMapping>` (dependency-confusion), build-time `.targets`/`.props` execution risk, `<trustedSigners>`, NuGet typosquats
    - **`## Securing AI / LLM Features`** added — OWASP LLM Top 10 (2025) mapped to .NET sinks (never feed model output into `FromSqlRaw`/`Process.Start`/`MarkupString`/`@Html.Raw`/reflection), prompt-injection / secrets-in-prompt / excessive-agency / unbounded-consumption / RAG-isolation, with a defensive parse-validate-act example over `Microsoft.Extensions.AI` / Semantic Kernel
    - **Secrets Management** augmented with secret-leak response (rotate via Key Vault first; rewriting history isn't enough)
    - Security Review Checklist gained **Supply Chain** + **AI / LLM** subsections and an SSRF line; Rationalizations gained threat-modeling + LLM rows; Red Flags + Verification gained SSRF + LLM + threat-model items
    - OWASP LLM Top 10 (2025) cited as the live anchor; SSRF cloud-metadata target verified as `169.254.169.254`
- **Downstream patches** (applied after the initial sync; not tracked against upstream):
  - **2026-04-19** (plugin v1.0.3) — OWASP #1 Injection block expanded to show `FromSqlRaw` (BAD, `string` overload) alongside `FromSql` (GOOD, EF Core 8+ canonical form), `FromSqlInterpolated` (GOOD, EF Core 7 and earlier — same `FormattableString` safety), LINQ, and Dapper with anonymous-object parameters. Added a "trap" callout explaining why `FromSqlRaw($"...")` and `FromSql($"...")` look identical but have opposite safety. Always-Do and Never-Do bullets updated to match. Added a "Host-model lens" note at the top of the Three-Tier Boundary System clarifying which bullets are ASP.NET Core-specific vs cross-cutting.
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
