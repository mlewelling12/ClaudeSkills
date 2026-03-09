---
name: perf
description: Performance analysis — finds bottlenecks, expensive operations, and optimization opportunities in code. Use /perf [file|endpoint|function] to run.
disable-model-invocation: false
---

# Perf — Performance Analysis

Identifies performance bottlenecks, expensive operations, and optimization opportunities
through static analysis of code patterns. Three passes: data access, computation, and
resource usage. Unlike `/audit` (which checks overall health including perf as one of four
passes) or `/review` (which flags perf issues only in changed code), `/perf` performs a
deep, dedicated performance analysis of the targeted code.

## Output Format

```markdown
## Performance Analysis — {target}

**Scope:** {file | endpoint | function | full project}
**Project type:** {detected type(s)}
**Framework:** {detected framework(s)}

### Critical ({n} findings)

| # | Category | Location | Issue | Impact | Fix |
|---|----------|----------|-------|--------|-----|
| 1 | Data Access | src/api/users.ts:34 | N+1 query in user list endpoint | O(n) DB calls per request | Batch query with `WHERE id IN (...)` |

### Warnings ({n} findings)

| # | Category | Location | Issue | Impact | Fix |
|---|----------|----------|-------|--------|-----|
| 1 | Computation | src/utils/transform.ts:78 | Repeated array traversal in nested loop | O(n²) where O(n) is possible | Build lookup map before loop |

### Info ({n} findings)

| # | Category | Location | Issue | Impact | Fix |
|---|----------|----------|-------|--------|-----|
| 1 | Resource | src/config.ts:12 | Large JSON parsed on every request | Adds ~5ms per call | Parse once at startup, cache result |

### Summary

- **Hotspot:** {single most impactful file or function}
- **Top fix:** {highest-ROI optimization}
- **Overall:** {CLEAN | HAS HOTSPOTS | NEEDS OPTIMIZATION}
```

## Workflow

### Step 1: Determine Scope

Parse `$ARGUMENTS`:

- **No arguments**: Analyze the full project. Focus on entry points (API routes, main
  functions, event handlers) and their call chains.
- **File path**: Analyze that file and anything it calls.
- **Function name**: Locate the function, analyze it and its call tree.
- **Endpoint/route**: Find the handler and trace the full request path.

If the target cannot be found, respond:
*"Could not find `{target}`. Usage: `/perf [file|endpoint|function]`"* — then stop.

### Step 2: Detect Project Type and Framework

Inspect the repo for project indicators:

| File | Type | Framework clues |
|------|------|----------------|
| `package.json` | Node.js | Check for express, fastify, next, react, vue, angular |
| `Cargo.toml` | Rust | Check for actix, axum, rocket, tokio |
| `pyproject.toml` / `requirements.txt` | Python | Check for django, flask, fastapi, sqlalchemy |
| `go.mod` | Go | Check for gin, echo, fiber, gorm |
| `Gemfile` | Ruby | Check for rails, sinatra, sequel |
| `pom.xml` / `build.gradle` | Java/Kotlin | Check for spring, hibernate |

Framework detection matters because performance patterns are framework-specific (e.g.,
React re-render issues vs. Django ORM N+1 queries).

### Step 3: Three-Pass Analysis

Execute each pass in order. Record every finding with severity (CRITICAL, WARN, INFO),
category, file location, the issue, estimated impact, and a concrete fix.

**Pass 1 — Data Access**

Analyze database queries, API calls, file I/O, and cache usage:

- **N+1 queries** — queries inside loops, ORM lazy-loading in list endpoints, or
  repeated single-record fetches where a batch query would work. CRITICAL.
- **Missing indexes** — queries filtering or sorting on columns without apparent index
  coverage (check migration files or schema definitions). WARN.
- **Unbounded queries** — `SELECT *` without `LIMIT`, missing pagination on list endpoints,
  or fetching all records when only a count or subset is needed. WARN.
- **Redundant fetches** — fetching the same data multiple times in a single request path
  without caching or passing the result through. WARN.
- **Synchronous I/O on hot paths** — blocking file reads, synchronous HTTP calls, or
  sequential awaits that could be parallelized with `Promise.all` / `asyncio.gather` /
  equivalent. WARN.

**Pass 2 — Computation**

Analyze algorithmic complexity and CPU-bound operations:

- **Quadratic or worse loops** — nested iterations over the same collection, or repeated
  `Array.find`/`Array.includes` inside loops (use a Set or Map instead). CRITICAL if
  collection can be large, WARN otherwise.
- **Unnecessary recomputation** — computing the same value multiple times in a loop or
  across function calls without memoization. WARN.
- **Expensive operations in hot paths** — JSON parsing, regex compilation, deep cloning,
  or serialization inside loops or per-request handlers. WARN.
- **Frontend re-renders** (React/Vue/Angular) — missing memoization (`useMemo`, `React.memo`),
  unstable references in dependency arrays, or state updates that trigger unnecessary
  subtree re-renders. WARN.
- **String concatenation in loops** — building large strings with `+=` instead of array
  join or buffer. INFO.

**Pass 3 — Resource Usage**

Analyze memory, connections, and external resource consumption:

- **Memory leaks** — event listeners not removed, growing caches without eviction,
  closures capturing large scopes unnecessarily, or streams not closed. CRITICAL.
- **Connection leaks** — database connections, HTTP clients, or file handles opened but
  not properly closed or returned to pool. CRITICAL.
- **Large payloads** — responses returning full objects when only a few fields are needed,
  or loading entire files into memory when streaming would work. WARN.
- **Missing connection pooling** — creating new DB/HTTP connections per request instead
  of using a pool. WARN.
- **Unbounded caches or queues** — in-memory caches or task queues that grow without
  limits or TTL. WARN.

### Step 4: Classify and Present

Assign severity:

- **CRITICAL**: Will cause visible performance degradation under normal load. N+1 queries,
  memory leaks, quadratic algorithms on user data.
- **WARN**: Will cause problems at scale or under load. Missing pagination, redundant
  fetches, suboptimal algorithms.
- **INFO**: Minor inefficiency. Worth fixing opportunistically but not urgent.

Output findings grouped by severity. Each finding must include a specific file and line,
the issue, estimated impact, and a concrete fix — not just "optimize this."

If no findings exist, output:

```
### Summary
- **Overall:** CLEAN
- **Top fix:** None — no significant performance issues found.
```

## Rules

- **Read-only.** This skill analyzes and reports. It never modifies code.
- **Be specific.** Every finding must reference a file, line, and concrete fix.
  "This could be slow" is not a finding.
- **Estimate impact, don't guess.** Describe impact in terms of complexity (O(n) vs O(n²)),
  frequency (per-request vs. one-time), or data scale. Avoid vague terms like "might be
  slow" without context.
- **Framework-aware.** Flag framework-specific antipatterns (React re-renders, Django
  ORM select_related, Express middleware ordering). Generic advice is less useful.
- **Don't flag micro-optimizations.** Replacing `for` with `forEach`, or `let` with
  `const` for performance reasons is noise. Focus on algorithmic and architectural issues.
- **Respect exclusions.** Never scan `node_modules`, `vendor`, `.git`, build output,
  lockfiles, or generated/vendored directories. Respect `.gitignore`.
- **Scope adherence.** If the user provides a target, analyze that target and its call
  chain — not the entire project.
- **One pass, complete output.** Deliver the full analysis in a single response. Do not
  ask follow-up questions.
- **Timeout protection.** Cap any single command at 120 seconds. If it times out, record
  as WARN and note the timeout.
