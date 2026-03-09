---
name: api
description: API contract analyzer — documents endpoints, detects breaking changes, and validates schemas. Use /api [file|module] to run.
disable-model-invocation: false
---

# API — Contract Analyzer

Analyzes API surface area: documents endpoints, detects breaking changes between versions,
validates request/response schemas, and flags inconsistencies. Three passes: inventory,
contract validation, breaking change detection. Unlike `/doc` (which generates prose
documentation) or `/review` (which reviews arbitrary code changes), `/api` focuses
specifically on API contracts and their correctness.

## Output Format

```markdown
## API Analysis — {target}

**Scope:** {file | module | full project}
**API type:** {REST | GraphQL | gRPC | WebSocket | library}
**Framework:** {detected framework}

### Endpoint Inventory ({n} endpoints)

| # | Method | Path | Auth | Request Body | Response | Status |
|---|--------|------|------|-------------|----------|--------|
| 1 | GET | /api/users | Bearer token | — | `User[]` | OK |
| 2 | POST | /api/users | Bearer token | `CreateUserInput` | `User` | ⚠️ Missing validation |
| 3 | DELETE | /api/users/:id | None | — | 204 | ⚠️ No auth |

### Contract Issues ({n} findings)

| # | Severity | Endpoint | Issue | Fix |
|---|----------|----------|-------|-----|
| 1 | CRITICAL | POST /api/users | No input validation on `email` field | Add schema validation |
| 2 | IMPORTANT | GET /api/users | Returns full user objects including `passwordHash` | Exclude sensitive fields |
| 3 | MINOR | GET /api/health | Returns 200 with error message instead of 5xx | Use proper status codes |

### Breaking Changes ({n} detected)

| # | Type | Location | Before | After | Impact |
|---|------|----------|--------|-------|--------|
| 1 | Removed field | /api/users response | `username` field present | Field removed | Clients relying on `username` will break |
| 2 | Type change | /api/orders request | `quantity: string` | `quantity: number` | Clients sending strings will get 400 |

### Consistency Check

- **Naming:** {consistent | mixed — details}
- **Error format:** {consistent | mixed — details}
- **Auth pattern:** {consistent | mixed — details}
- **Versioning:** {present | absent}

### Summary

- **API health:** {CLEAN | HAS ISSUES | NEEDS ATTENTION}
- **Top priority:** {most important fix}
- **Endpoints:** {n total}, {n with issues}
```

## Workflow

### Step 1: Determine Scope and API Type

Parse `$ARGUMENTS`:

- **No arguments**: Scan the full project for API definitions.
- **File path**: Analyze that file's API surface.
- **Module/directory**: Analyze all API definitions in that subtree.

Detect API type:

| Indicator | API type |
|-----------|----------|
| Route definitions (`app.get()`, `@GetMapping`, `@app.route`) | REST |
| `.graphql` / `.gql` files, `typeDefs`, `resolvers` | GraphQL |
| `.proto` files | gRPC |
| WebSocket handlers (`ws.on`, `@WebSocketGateway`) | WebSocket |
| Exported functions/classes with JSDoc/docstrings | Library API |

If no API surface is detected:
*"No API endpoints found in `{target}`. Usage: `/api [file|module]`"* — then stop.

### Step 2: Detect Framework and Conventions

Identify the API framework to understand routing patterns:

| Framework | Route pattern |
|-----------|--------------|
| Express/Fastify | `app.get('/path', handler)`, `router.post()` |
| Django/DRF | `urlpatterns`, `@api_view`, `ViewSet` |
| Flask/FastAPI | `@app.route()`, `@router.get()` |
| Spring | `@GetMapping`, `@PostMapping`, `@RequestMapping` |
| Rails | `routes.rb`, `resources :name` |
| Go (gin/echo) | `r.GET("/path", handler)`, `e.POST()` |
| Next.js | `pages/api/`, `app/api/` file-based routes |

Also check for:
- API documentation specs (OpenAPI/Swagger YAML/JSON, `tsoa`, `nestjs/swagger`)
- Schema validation libraries (`joi`, `zod`, `pydantic`, `marshmallow`, `class-validator`)
- Auth middleware configuration

### Step 3: Three-Pass Analysis

**Pass 1 — Endpoint Inventory**

Build a complete map of all API endpoints:

1. **Find all route definitions** — scan for framework-specific route patterns.
2. **For each endpoint, extract:**
   - HTTP method (or query/mutation for GraphQL)
   - Path/route pattern
   - Authentication requirements (middleware, decorators, guards)
   - Request body schema (if any)
   - Response shape (return type, status codes)
   - Validation (schema validation middleware/decorators)
3. **Identify undocumented endpoints** — routes with no JSDoc, docstring, or OpenAPI
   annotation. Flag as MINOR.

For GraphQL: inventory queries, mutations, and subscriptions. Map resolver functions.
For gRPC: inventory service methods from `.proto` files. Map to handler implementations.

**Pass 2 — Contract Validation**

Check each endpoint for contract issues:

- **Missing input validation** — endpoints accepting user input without schema validation.
  CRITICAL for write operations (POST/PUT/PATCH), IMPORTANT for reads with query params.
- **Sensitive data exposure** — responses returning fields that should be excluded
  (passwords, tokens, internal IDs, PII not needed by the client). IMPORTANT.
- **Incorrect status codes** — returning 200 for errors, 500 for client errors, missing
  404 for resource-not-found. MINOR.
- **Missing error handling** — endpoints without try/catch or error middleware, or ones
  that return raw error objects/stack traces. IMPORTANT.
- **Inconsistent response shapes** — some endpoints wrapping in `{ data: ... }` while
  others return raw objects. Same type of error returned in different formats. MINOR.
- **Missing pagination** — list endpoints returning unbounded result sets. IMPORTANT
  if the collection can grow.
- **No rate limiting** — public or auth endpoints without rate limit middleware. IMPORTANT
  for auth endpoints, MINOR for others.

**Pass 3 — Breaking Change Detection**

Compare the current API surface against any available reference:

1. **Check for OpenAPI/Swagger spec** — if an API spec file exists, compare the actual
   code routes against the spec. Flag mismatches.
2. **Check git history** — if the current branch has modified API route files, diff
   against the base branch to detect:
   - Removed endpoints
   - Removed or renamed fields in response types
   - Changed field types
   - Changed required/optional status of request fields
   - Changed authentication requirements
3. **Check for versioning** — is the API versioned (`/v1/`, `/v2/`)? Are breaking
   changes behind a new version?

If no reference point exists (no spec file, no meaningful git diff), skip this pass
and note: *"No API spec or base branch diff available for breaking change detection."*

### Step 4: Consistency Check

Evaluate cross-cutting API consistency:

- **Naming conventions** — are paths consistent? (`/api/users` vs `/api/getUsers`,
  camelCase vs. snake_case in field names). Flag mixed styles.
- **Error response format** — is there a standard error shape? (`{ error: { code, message } }`
  vs. `{ message }` vs. raw strings). Flag inconsistencies.
- **Auth pattern** — is authentication applied consistently? Flag endpoints that
  deviate from the project's auth pattern without clear reason.
- **Versioning** — is there an API versioning strategy? Flag breaking changes without
  version bumps.

### Step 5: Present

Output the full API analysis: inventory, contract issues, breaking changes, consistency
check, and summary.

## Rules

- **Read-only.** This skill analyzes and reports. It never modifies code.
- **Be specific.** Every finding must reference an endpoint, file, and line. Provide
  concrete fixes, not generic advice.
- **Framework-aware.** Use framework-specific knowledge. Express middleware ordering
  matters. Django DRF serializers handle validation differently than raw Django views.
  FastAPI auto-validates Pydantic models.
- **Don't flag framework defaults.** If the framework provides built-in validation,
  CSRF, or error handling, don't flag its absence at the code level.
- **Distinguish public from internal APIs.** Public-facing APIs need stricter validation,
  rate limiting, and documentation. Internal service-to-service APIs have different
  requirements.
- **Breaking changes need context.** A removed field is only breaking if clients depend
  on it. Flag it, but note if the field was deprecated or if no external consumers exist.
- **Respect exclusions.** Never scan `node_modules`, `vendor`, `.git`, build output,
  lockfiles, or generated/vendored directories.
- **Scope adherence.** If the user provides a scope, limit analysis to that subtree.
- **One pass, complete output.** Deliver the full analysis in a single response.
- **Timeout protection.** Cap any single command at 120 seconds. If it times out,
  record as a note.
