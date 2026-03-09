---
name: secure
description: Deep security scan — OWASP Top 10, secrets detection, auth/authz gaps, and insecure configurations. Use /secure [scope] to run.
disable-model-invocation: false
---

# Secure — Deep Security Scanner

Performs a comprehensive security scan of the codebase across five passes: injection
vulnerabilities, authentication/authorization, secrets and credentials, configuration
security, and dependency vulnerabilities. Unlike `/audit` (which includes security as
one of four broad passes) or `/review` (which checks security only in changed code),
`/secure` is a dedicated, deep security analysis of the full codebase or a targeted scope.

## Output Format

```markdown
## Security Scan — {project name or scope}

**Scope:** {full project | directory scanned}
**Project type:** {detected type(s)}
**Framework:** {detected framework(s)}
**OWASP coverage:** Injection, Broken Auth, Sensitive Data, XXE, Broken Access Control,
Security Misconfiguration, XSS, Insecure Deserialization, Vulnerable Components, Logging

### Critical ({n} findings)

| # | Category | Location | Vulnerability | Risk | Remediation |
|---|----------|----------|---------------|------|-------------|
| 1 | Injection | src/api/search.ts:23 | User input interpolated into SQL query | SQL injection — full DB access | Use parameterized queries |

### High ({n} findings)

| # | Category | Location | Vulnerability | Risk | Remediation |
|---|----------|----------|---------------|------|-------------|
| 1 | Auth | src/middleware/auth.ts:45 | JWT secret hardcoded in source | Token forgery | Move to environment variable |

### Medium ({n} findings)

| # | Category | Location | Vulnerability | Risk | Remediation |
|---|----------|----------|---------------|------|-------------|
| 1 | Config | docker-compose.yml:8 | Debug mode enabled | Stack traces exposed to users | Set `DEBUG=false` in production |

### Low ({n} findings)

| # | Category | Location | Vulnerability | Risk | Remediation |
|---|----------|----------|---------------|------|-------------|
| 1 | Logging | src/utils/logger.ts:12 | No request ID in log entries | Hard to trace incidents | Add correlation IDs |

### Summary

- **Risk level:** {CRITICAL | HIGH | MEDIUM | LOW | CLEAN}
- **Top priority:** {single most important fix}
- **Passes run:** Injection, Auth/AuthZ, Secrets, Configuration, Dependencies
```

## Workflow

### Step 1: Detect Project Type and Framework

Inspect the repo for project indicators:

| File | Type | Framework clues |
|------|------|----------------|
| `package.json` | Node.js | express, fastify, next, koa, hapi |
| `Cargo.toml` | Rust | actix, axum, rocket |
| `pyproject.toml` / `requirements.txt` | Python | django, flask, fastapi |
| `go.mod` | Go | gin, echo, fiber, net/http |
| `Gemfile` | Ruby | rails, sinatra |
| `pom.xml` / `build.gradle` | Java/Kotlin | spring, jakarta |
| `composer.json` | PHP | laravel, symfony |

Framework detection is critical — security patterns are framework-specific (e.g., Django
CSRF vs. Express CSRF, Rails mass assignment vs. Spring binding).

If `$ARGUMENTS` specifies a directory scope, limit all passes to that subtree.

### Step 2: Five-Pass Security Scan

Execute each pass in order. Record every finding with severity (CRITICAL, HIGH, MEDIUM,
LOW), category, file location, the vulnerability, risk description, and remediation.

**Pass 1 — Injection Vulnerabilities**

- **SQL injection** — user input concatenated or interpolated into SQL strings instead
  of parameterized queries. Check raw query methods: `query()`, `execute()`, `raw()`,
  `$queryRawUnsafe()`, template literals with SQL. CRITICAL.
- **Command injection** — user input passed to `exec()`, `spawn()`, `system()`,
  `os.popen()`, `subprocess.run(shell=True)`, or backtick execution. CRITICAL.
- **Path traversal** — user input used in file paths without sanitization. Check for
  `../` bypasses, `path.join()` with user input, and missing `path.resolve()` +
  base-directory validation. CRITICAL.
- **XSS** — user input rendered in HTML without escaping. Check for `innerHTML`,
  `dangerouslySetInnerHTML`, `v-html`, `|safe`, `raw()`, and template engines with
  autoescape disabled. HIGH.
- **NoSQL injection** — user input passed directly as MongoDB query operators (`$gt`,
  `$ne`, `$regex`) without type validation. HIGH.
- **LDAP/XML/SSRF injection** — user input in LDAP filters, XML parsers without
  entity restrictions, or HTTP requests with user-controlled URLs. HIGH.

**Pass 2 — Authentication and Authorization**

- **Missing authentication** — API endpoints or routes without auth middleware. Cross-
  reference route definitions with middleware chains. HIGH.
- **Broken access control** — endpoints that check authentication but not authorization
  (e.g., any logged-in user can access admin routes). Check for role/permission checks
  on sensitive operations. HIGH.
- **Weak password handling** — plaintext password storage, weak hashing (MD5, SHA1
  without salt), missing rate limiting on login endpoints. CRITICAL if plaintext,
  HIGH otherwise.
- **Insecure session management** — session tokens in URLs, missing `httpOnly`/`secure`
  flags on cookies, no session expiration, predictable session IDs. MEDIUM.
- **JWT issues** — `algorithm: "none"` allowed, symmetric keys for multi-service auth,
  missing expiration (`exp` claim), secret in source code. HIGH.
- **Missing CSRF protection** — state-changing endpoints (POST/PUT/DELETE) without CSRF
  tokens or SameSite cookies in web applications. MEDIUM.

**Pass 3 — Secrets and Credentials**

Scan for hardcoded secrets. Apply these patterns:

```
AKIA[0-9A-Z]{16}                                    # AWS Access Key
(?i)(api_key|apikey|secret|token|password|credential|auth)\s*[:=]\s*['"][A-Za-z0-9/+=]{16,}['"]
-----BEGIN\s+(RSA|EC|DSA|OPENSSH|PGP)?\s*PRIVATE KEY-----
(?i)(mysql|postgres|mongodb|redis|amqp|sqlite)://[^:]+:[^@]+@
ghp_[A-Za-z0-9]{36}                                 # GitHub PAT
sk-[A-Za-z0-9]{48}                                   # OpenAI API key
xox[bpas]-[A-Za-z0-9-]+                             # Slack token
```

Severity:
- CRITICAL for secrets in source code, configuration, or environment files tracked by git.
- LOW for secrets in test fixtures, example configs, or documentation (flag but don't alarm).

Also check:
- **`.env` files tracked by git** — CRITICAL. Should be in `.gitignore`.
- **Private keys in repo** — `*.pem`, `*.key`, `id_rsa`. CRITICAL.
- **Credentials in CI config** — plaintext secrets in `.github/workflows/`, `Jenkinsfile`,
  `.gitlab-ci.yml` instead of secret references. HIGH.

**Pass 4 — Configuration Security**

- **Debug mode in production configs** — `DEBUG=true`, `NODE_ENV=development` in
  production config files. MEDIUM.
- **Permissive CORS** — `Access-Control-Allow-Origin: *` or reflecting the Origin header
  without validation. MEDIUM.
- **Disabled security features** — CSRF disabled, HTTPS not enforced, security headers
  missing (`X-Frame-Options`, `Content-Security-Policy`, `Strict-Transport-Security`). MEDIUM.
- **Verbose error responses** — stack traces, internal paths, or database errors returned
  to clients in production. MEDIUM.
- **Default credentials** — default admin passwords, unchanged database credentials from
  boilerplate. HIGH.
- **Insecure TLS** — allowing TLS 1.0/1.1, weak cipher suites, or certificate verification
  disabled (`verify=False`, `rejectUnauthorized: false`). HIGH.

**Pass 5 — Dependency Vulnerabilities**

Run available audit tools:

| Project type | Command | Fallback |
|-------------|---------|----------|
| Node.js | `npm audit` | Read `package-lock.json` for known vulnerable versions |
| Python | `pip-audit` | Check `requirements.txt` against known CVE databases |
| Rust | `cargo audit` | Read `Cargo.lock` for advisories |
| Go | `govulncheck ./...` | Read `go.sum` for known issues |
| Ruby | `bundle-audit check` | Manual check |

Severity: Map directly from CVE severity (critical → CRITICAL, high → HIGH, etc.).

If audit tooling is not installed, note: *"{tool} not available — install it for
automated vulnerability scanning."* and attempt manual version checks where possible.

### Step 3: Classify and Summarize

Determine overall risk level:

- **CRITICAL**: Any CRITICAL findings.
- **HIGH**: No CRITICAL, but HIGH findings exist.
- **MEDIUM**: No CRITICAL or HIGH, but MEDIUM findings exist.
- **LOW**: Only LOW findings.
- **CLEAN**: No findings.

Identify the single highest-priority remediation action.

### Step 4: Present

Output the formatted report. Findings grouped by severity (Critical first). Each finding
includes category, location, the vulnerability, risk, and a concrete remediation step —
not just "fix this."

Omit empty severity sections. If the codebase is clean:

```
### Summary
- **Risk level:** CLEAN
- **Top priority:** None — no security issues found.
```

## Rules

- **Read-only.** This skill scans and reports. It never modifies code.
- **No false positives on secrets.** Only flag patterns that strongly resemble real
  credentials. Test fixtures using `test-api-key-12345` or `password123` are LOW, not
  CRITICAL. Example/placeholder values in documentation are LOW.
- **Framework-specific checks.** Use framework-aware patterns. Django's ORM is not
  vulnerable to SQL injection via normal usage, but `raw()` and `extra()` calls are.
  Express with `helmet` middleware is more secure than without. Calibrate findings to
  the actual framework.
- **Context matters.** A debug flag in a local dev config is LOW. The same flag in a
  production Dockerfile is MEDIUM. An API key in a test file is LOW. The same key in
  a handler is CRITICAL.
- **Respect exclusions.** Never scan `node_modules`, `vendor`, `.git`, build output,
  lockfiles, or generated/vendored directories. Respect `.gitignore`.
- **Scope adherence.** If the user provides a scope argument, limit the scan to that
  subtree. Do not scan outside the specified scope.
- **Timeout protection.** Cap any single command (e.g., `npm audit`) at 120 seconds.
  If it times out, record as MEDIUM: *"{command} timed out after 120s."*
- **One pass, complete output.** Deliver the full scan in a single response. Do not
  ask follow-up questions or request user input mid-scan.
- **Idempotent.** Running `/secure` twice on the same codebase should produce the
  same results. Do not leave artifacts or modify state.
