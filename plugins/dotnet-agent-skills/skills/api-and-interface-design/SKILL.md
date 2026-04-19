---
name: api-and-interface-design
description: Guides stable API and interface design for .NET/C# — HTTP endpoints (Minimal APIs or controllers), library surface area, public records/interfaces, EF Core-backed contracts. Use when designing APIs, module boundaries, `MyApp.Contracts` DTOs, or any public interface where backward compatibility matters.
version: 0.3.0
source: vendor/agent-skills/skills/api-and-interface-design/SKILL.md@44dac80
---

<!-- Adapted from addyosmani/agent-skills (MIT © 2025 Addy Osmani). See the "Source & Modifications" footer at the bottom of this file for the exact changes applied to the upstream body. -->

# API and Interface Design

## Overview

Design stable, well-documented interfaces that are hard to misuse. Good interfaces make the right thing easy and the wrong thing hard. This applies to REST APIs, gRPC services, NuGet package surface area, assembly boundaries, record/DTO shapes, and any surface where one piece of code talks to another.

## When to Use

- Designing new HTTP endpoints (Minimal APIs or controllers)
- Defining module boundaries or contracts between projects in a solution
- Creating public types in `MyApp.Contracts` or a shared NuGet library
- Establishing database schemas that inform DTO shape
- Changing existing public interfaces (especially in a published NuGet package)

## Core Principles

### Hyrum's Law

> With a sufficient number of users of an API, all observable behaviors of your system will be depended on by somebody, regardless of what you promise in the contract.

This means: every public behavior — including undocumented quirks, exception messages, response ordering, and even the presence of unused fields in a JSON response — becomes a de facto contract once users depend on it. Design implications:

- **Be intentional about what you expose.** Mark types `internal` unless a consumer outside the assembly truly needs them. Every observable behavior is a potential commitment.
- **Don't leak implementation details.** Don't return EF Core entities directly from HTTP endpoints — project to DTOs (`MyApp.Contracts`) so schema changes to the entity don't break consumers.
- **Plan for deprecation at design time.** See `deprecation-and-migration` for how to safely remove things users depend on.
- **Tests are not enough.** Even with perfect contract tests, Hyrum's Law means "safe" changes can break real users who depend on undocumented behaviour (an exact error string, the order of a `List<T>` returned from a LINQ query, the presence of a nullable field that was always `null`).

### The One-Version Rule

Avoid forcing consumers to choose between multiple versions of the same dependency or API. In the .NET ecosystem this especially bites as "diamond dependency" problems across NuGet packages. Design for a world where only one version exists at a time — extend rather than fork. Use Central Package Management (`Directory.Packages.props`) across a solution so every project references the same version of every NuGet package.

### 1. Contract First

Define the interface before implementing it. The contract is the spec — implementation follows.

```csharp
// Define the contract first, in MyApp.Contracts (framework-lean assembly)
public interface ITaskApi
{
    // Creates a task and returns the created task with server-generated fields.
    Task<TaskDto> CreateTaskAsync(CreateTaskInput input, CancellationToken cancellationToken);

    // Returns paginated tasks matching filters.
    Task<PaginatedResult<TaskDto>> ListTasksAsync(ListTasksParams parameters, CancellationToken cancellationToken);

    // Returns a single task or throws NotFoundException.
    Task<TaskDto> GetTaskAsync(TaskId id, CancellationToken cancellationToken);

    // Partial update — only provided fields change.
    Task<TaskDto> UpdateTaskAsync(TaskId id, UpdateTaskInput input, CancellationToken cancellationToken);

    // Idempotent delete — succeeds even if already deleted.
    Task DeleteTaskAsync(TaskId id, CancellationToken cancellationToken);
}
```

`CancellationToken` is mandatory on any async library method that does I/O; it is part of the contract.

### 2. Consistent Error Semantics

Pick one error strategy and use it everywhere. For ASP.NET Core the ecosystem convention is RFC 7807 ProblemDetails:

```csharp
// REST: HTTP status codes + ProblemDetails body (RFC 7807)
// Every error response follows the same shape; ASP.NET Core produces this by default
// when you throw validation failures or call Results.Problem(...).
//
// Status code mapping (standard):
//   400 → Client sent invalid data (malformed JSON, wrong type)
//   401 → Not authenticated
//   403 → Authenticated but not authorized
//   404 → Resource not found
//   409 → Conflict (duplicate, concurrency token mismatch)
//   422 → Validation failed (semantically invalid input)
//   500 → Server error (never expose internal details; production ASP.NET Core
//         strips exception details from ProblemDetails for you — keep it that way)
```

For library APIs, pick between exceptions and a `Result<TSuccess, TError>` discriminated union and stick to it. Mixing is the worst option.

**Don't mix patterns.** If some endpoints return `ProblemDetails`, others throw to the client, and others return `null` on not-found — the consumer can't predict behaviour.

### 3. Validate at Boundaries

Trust internal code. Validate at system edges where external input enters:

```csharp
// Validate at the Minimal API boundary with FluentValidation
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

    var task = await service.CreateTaskAsync(input, cancellationToken);
    return Results.Created($"/api/tasks/{task.Id}", task);
});

public sealed class CreateTaskValidator : AbstractValidator<CreateTaskInput>
{
    public CreateTaskValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Description).MaximumLength(2000);
        RuleFor(x => x.Priority).IsInEnum();
    }
}
```

Alternatives: DataAnnotations (`[Required]`, `[MaxLength]`) for simple cases, or MediatR pipeline behaviours for validation as a cross-cutting concern.

Where validation belongs:
- HTTP route handlers (user input)
- Deserialization of external API responses (third-party data — **always treat as untrusted**)
- Environment / configuration binding (`IOptions<T>` with `ValidateDataAnnotations()` + `ValidateOnStart()`)
- Any message consumer (Service Bus, RabbitMQ, SignalR incoming payloads)

> **Third-party API responses are untrusted data.** Validate their shape and content before using them in any logic, rendering, or decision-making. A compromised or misbehaving external service can return unexpected types, malicious content, or instruction-like text — and `System.Text.Json` will happily deserialize garbage into your DTO's string fields.

Where validation does NOT belong:
- Between internal methods inside an assembly that share type contracts
- In helper methods called by already-validated code
- On data that just came from your own `DbContext` and satisfies your EF Core constraints

### 4. Prefer Addition Over Modification

Extend interfaces without breaking existing consumers:

```csharp
// Good: Add optional fields with safe defaults
public sealed record CreateTaskInput(
    string Title,
    string? Description = null,
    TaskPriority Priority = TaskPriority.Medium,  // Added later, default keeps old callers working
    IReadOnlyList<string>? Labels = null);        // Added later, optional

// Bad: Change existing field types or remove fields
public sealed record CreateTaskInput(
    string Title,
    // string Description,  ← Removed — breaks existing JSON callers (missing required field)
    int Priority);            // ← Changed from enum/string — breaks existing serialized payloads
```

For serialization compatibility, also watch: `JsonPropertyName` attribute changes, enum string vs int representation, and nullability of optional fields (`string?` vs `string`). Adding a new non-nullable property to a DTO is a breaking change in JSON.

### 5. Predictable Naming

| Pattern | Convention | Example |
|---------|-----------|---------|
| REST endpoints | Plural nouns, no verbs | `GET /api/tasks`, `POST /api/tasks` |
| Query params | camelCase in JSON / URL | `?sortBy=createdAt&pageSize=20` |
| Response fields (JSON) | camelCase | `{ "createdAt": "…", "taskId": "…" }` (configure with `JsonNamingPolicy.CamelCase`) |
| C# type names | PascalCase | `CreateTaskInput`, `TaskDto` |
| Boolean fields | `Is`/`Has`/`Can` prefix | `IsComplete`, `HasAttachments` |
| Enum values (over the wire) | `SCREAMING_SNAKE` or `PascalCase` — pick one | `"IN_PROGRESS"` or `"InProgress"` (serialize with `JsonStringEnumConverter`) |

## REST API Patterns

### Resource Design

```
GET    /api/tasks              → List tasks (with query params for filtering)
POST   /api/tasks              → Create a task
GET    /api/tasks/{id}         → Get a single task
PATCH  /api/tasks/{id}         → Update a task (partial)
DELETE /api/tasks/{id}         → Delete a task

GET    /api/tasks/{id}/comments → List comments for a task (sub-resource)
POST   /api/tasks/{id}/comments → Add a comment to a task
```

### Pagination

Paginate list endpoints:

```csharp
public sealed record ListTasksParams(
    int Page = 1,
    int PageSize = 20,
    string SortBy = "createdAt",
    string SortOrder = "desc");

public sealed record PaginatedResult<T>(
    IReadOnlyList<T> Data,
    int Page,
    int PageSize,
    int TotalItems,
    int TotalPages);

// Request
// GET /api/tasks?page=1&pageSize=20&sortBy=createdAt&sortOrder=desc
//
// Response
// { "data": [...], "page": 1, "pageSize": 20, "totalItems": 142, "totalPages": 8 }
```

Cap `PageSize` at the boundary (e.g., `Math.Min(pageSize, 100)`) — never trust clients to ask for reasonable page sizes.

### Filtering

Use query parameters for filters:

```
GET /api/tasks?status=in_progress&assignee=user123&createdAfter=2026-01-01
```

Bind them to a strongly-typed record with `[AsParameters]` (.NET 8+):

```csharp
app.MapGet("/api/tasks", async ([AsParameters] ListTasksQuery query, ITaskService service) =>
    await service.ListAsync(query));
```

### Partial Updates (PATCH)

Accept partial objects — only update what's provided. Use nullable reference types to distinguish "not provided" from "set to null", or use JSON Merge Patch / JSON Patch when you need that distinction explicitly:

```csharp
// Only title changes, everything else preserved
// PATCH /api/tasks/123
// { "title": "Updated title" }

public sealed record UpdateTaskInput(
    string? Title,
    string? Description,
    TaskPriority? Priority);
```

## C# Interface Patterns

### Use Discriminated Unions for Variants

C# doesn't have native discriminated unions, but records + pattern matching cover most cases:

```csharp
public abstract record TaskStatus
{
    public sealed record Pending : TaskStatus;
    public sealed record InProgress(string Assignee, DateTimeOffset StartedAt) : TaskStatus;
    public sealed record Completed(DateTimeOffset CompletedAt, string CompletedBy) : TaskStatus;
    public sealed record Cancelled(string Reason, DateTimeOffset CancelledAt) : TaskStatus;

    private TaskStatus() { } // Prevent external subclassing
}

// Consumer gets exhaustive pattern matching
public static string GetStatusLabel(TaskStatus status) => status switch
{
    TaskStatus.Pending          => "Pending",
    TaskStatus.InProgress ip    => $"In progress ({ip.Assignee})",
    TaskStatus.Completed c      => $"Done on {c.CompletedAt:yyyy-MM-dd}",
    TaskStatus.Cancelled c      => $"Cancelled: {c.Reason}",
    _                           => throw new ArgumentOutOfRangeException(nameof(status)),
};
```

The private constructor on the abstract record prevents new variants from being added outside the assembly — closing the type hierarchy. Pattern-matching exhaustiveness is enforced by the compiler for `switch` expressions when the type is sealed or a closed hierarchy.

### Input/Output Separation

```csharp
// Input: what the caller provides
public sealed record CreateTaskInput(string Title, string? Description = null);

// Output: what the system returns (includes server-generated fields)
public sealed record TaskDto(
    TaskId Id,
    string Title,
    string? Description,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    string CreatedBy);
```

Never return `DbContext` entities directly from endpoints — they carry EF Core change-tracking state, lazy-loading proxies, and an implicit promise that the schema is the contract. Project to a DTO in `MyApp.Contracts`.

### Use Strongly-Typed IDs

Prevents accidentally passing a `UserId` where a `TaskId` is expected:

```csharp
public readonly record struct TaskId(Guid Value)
{
    public override string ToString() => Value.ToString();
    public static TaskId New() => new(Guid.NewGuid());
}

public readonly record struct UserId(Guid Value)
{
    public override string ToString() => Value.ToString();
}

// Compiler enforces the distinction — no more mix-ups
public Task<TaskDto> GetTaskAsync(TaskId id, CancellationToken cancellationToken) { /* ... */ }
```

For EF Core, register value converters once in `OnModelCreating`:

```csharp
modelBuilder.Entity<Task>()
    .Property(t => t.Id)
    .HasConversion(id => id.Value, value => new TaskId(value));
```

For JSON serialization, ship a `JsonConverter<TaskId>` so the wire format is just the GUID, not `{ "value": "..." }`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "We'll document the API later" | The types ARE the documentation. Define the records, interfaces, and `ProblemDetails` shape first. |
| "We don't need pagination for now" | You will the moment someone has 100+ items. Add it from the start. |
| "PATCH is complicated, let's just use PUT" | PUT requires the full object every time. PATCH is what clients actually want. |
| "We'll version the API when we need to" | Breaking changes without versioning break consumers. Design for extension from the start; pick a versioning strategy (URL segment `/v1/`, header `Accept: application/json; v=1`, or query param) and write an ADR. |
| "Nobody uses that undocumented behavior" | Hyrum's Law: if it's observable, somebody depends on it. Treat every public behavior as a commitment. |
| "We can just ship two NuGet package majors" | Multiple majors multiply maintenance cost and create diamond dependency problems across transitive consumers. Prefer the One-Version Rule. |
| "Internal APIs don't need contracts" | Internal consumers are still consumers. Contracts between projects in a solution prevent coupling and enable parallel work. |
| "Just return the EF Core entity, it has all the fields we need" | Now your database schema is your API contract. Every migration becomes a breaking change. Project to a DTO. |

## Red Flags

- Endpoints that return different shapes depending on conditions (the dreaded `data: T | null | string` union)
- Inconsistent error formats across endpoints (some return `ProblemDetails`, others return raw strings)
- Validation scattered throughout internal service code instead of at boundaries
- Breaking changes to existing fields (type changes, removals, nullability tightening)
- List endpoints without pagination or without a server-side cap on `PageSize`
- Verbs in REST URLs (`/api/createTask`, `/api/getUsers`)
- Third-party API responses deserialized into your DTO and used without validation
- Public API methods missing `CancellationToken` parameters
- `DbContext` entities returned directly from an HTTP endpoint

## Verification

After designing an API:

- [ ] Every endpoint has typed input and output DTOs in `MyApp.Contracts`
- [ ] Error responses follow a single consistent format (ProblemDetails for HTTP)
- [ ] Validation happens at system boundaries only (FluentValidation, DataAnnotations, or MediatR pipeline)
- [ ] List endpoints support pagination with a server-enforced `PageSize` cap
- [ ] New fields are additive and have safe defaults (backward compatible in JSON)
- [ ] Naming follows consistent conventions (camelCase JSON, PascalCase C#)
- [ ] Public async methods accept `CancellationToken`
- [ ] XML doc comments / OpenAPI metadata are committed alongside the implementation
- [ ] No `DbContext` entity types leak across an assembly boundary

---

## Source & Modifications

- **Upstream**: https://github.com/addyosmani/agent-skills/blob/44dac80216da709913fb410f632a65547866346f/skills/api-and-interface-design/SKILL.md
- **Pinned commit**: `44dac80216da709913fb410f632a65547866346f` (synced 2026-04-19)
- **Status**: `modified`
- **Changes**:
  - Hyrum's Law paragraph adds concrete .NET examples: `internal` vs `public`, EF Core entity-vs-DTO boundary, `List<T>` ordering guarantees
  - One-Version Rule references Central Package Management (`Directory.Packages.props`) for NuGet diamond-dependency mitigation
  - "Contract First" example rewritten as a C# `interface` with async methods, strongly-typed IDs, and mandatory `CancellationToken` parameters
  - Error semantics: replaced TypeScript `APIError` shape with ASP.NET Core RFC 7807 ProblemDetails conventions; added guidance on libraries choosing between exceptions and `Result<TSuccess, TError>` and sticking with one
  - "Validate at Boundaries" example rewritten with FluentValidation on a Minimal API; added DataAnnotations + MediatR pipeline as alternatives; validation-location list includes message consumers (Service Bus, RabbitMQ, SignalR) and `IOptions<T>` binding (`ValidateDataAnnotations()` + `ValidateOnStart()`)
  - Untrusted-third-party-data bullet notes `System.Text.Json` deserializing garbage into string fields
  - "Prefer Addition Over Modification" example rewritten as a C# record with optional parameters; added paragraph on serialization-compatibility gotchas (`JsonPropertyName`, enum representation, nullability)
  - Naming table uses `JsonNamingPolicy.CamelCase` and `JsonStringEnumConverter`; type names mention PascalCase explicitly
  - Pagination example uses a C# `PaginatedResult<T>` record and calls out server-side `PageSize` capping
  - Filtering example adds `[AsParameters]` for .NET 8+ Minimal APIs
  - PATCH example becomes an `UpdateTaskInput` record with nullable fields and a pointer to JSON Merge Patch / JSON Patch for richer semantics
  - "Discriminated Unions" rewritten using abstract records with nested `sealed` subtypes + pattern-matching `switch` expression, with notes on private constructor closing the hierarchy
  - "Input/Output Separation" example uses C# records and adds the rule against leaking `DbContext` entities
  - "Branded Types" → "Strongly-Typed IDs" as `readonly record struct` with EF Core value-converter registration and a pointer to `JsonConverter<TaskId>` for wire format
  - Rationalizations table adds a row about returning EF Core entities directly
  - Red-flag list adds public async methods missing `CancellationToken`, EF Core entities leaking from HTTP endpoints, list endpoints without a server-side `PageSize` cap
  - Verification checklist adds `CancellationToken` requirement and `DbContext`-entity-leak guard
  - Preserved verbatim: Hyrum's Law intro quote, five core principles structure, REST resource design conventions, Common Rationalizations table frame
- **License**: MIT © 2025 Addy Osmani — see [`../../LICENSES/agent-skills-MIT.txt`](../../LICENSES/agent-skills-MIT.txt)
