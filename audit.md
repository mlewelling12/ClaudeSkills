---
name: audit
description: Codebase health audit — dependencies, complexity, tech debt, and security posture. Use /audit [scope] to run.
disable-model-invocation: false
---

# Audit — Codebase Health Report

Performs a full codebase health audit across four passes: dependencies, complexity, tech debt,
and security posture. Produces a point-in-time snapshot with findings ranked by severity. Unlike
`/review` or `/preflight` (which target specific changes), `/audit` evaluates the entire project.

## Output Format

```markdown
## Codebase Audit — {project name or root dir}

**Date:** {date}
**Scope:** {full project | directory audited}
**Project type:** {detected type(s)}

### Critical ({n} findings)

| # | Pass | Location | Finding | Suggested Action |
|---|------|----------|---------|------------------|
| 1 | Security | src/config.ts:12 | Hardcoded database password | Move to environment variable |

### Warnings ({n} findings)

| # | Pass | Location | Finding | Suggested Action |
|---|------|----------|---------|------------------|
| 1 | Dependencies | package.json | 8 packages outdated by 2+ major versions | Run `npm outdated` and update |

### Info ({n} findings)

| # | Pass | Location | Finding | Suggested Action |
|---|------|----------|---------|------------------|
| 1 | Tech Debt | src/utils.ts:45 | TODO: refactor this | Schedule cleanup |

### Summary
- **Health:** {HEALTHY | NEEDS ATTENTION | AT RISK}
- **Top priority:** {single most important action item}
- **Passes run:** Dependencies, Complexity, Tech Debt, Security Posture
```

## Workflow

### Step 1: Detect Project Type

Inspect the repo root (or the provided `$ARGUMENTS` scope directory) for project indicators:

| File | Type | Package tool | Notes |
|------|------|--------------|-------|
| `package.json` | Node.js | npm/yarn/pnpm | Check `lock` file to determine tool |
| `Cargo.toml` | Rust | cargo | |
| `pyproject.toml` / `requirements.txt` | Python | pip/poetry | |
| `go.mod` | Go | go modules | |
| `Gemfile` | Ruby | bundler | |
| `pom.xml` / `build.gradle` | Java/Kotlin | maven/gradle | |
| `composer.json` | PHP | composer | |

If no project indicators are found, report: *"No recognized project type detected.
Skipping dependency and build-specific checks. Running generic file-based audit only
(Complexity, Tech Debt, Security Posture)."* — then skip the dependency pass entirely.

If `$ARGUMENTS` specifies a directory scope, limit all passes to that subtree.

### Step 2: Four-Pass Audit

Execute each pass in order. Record every finding with a severity (CRITICAL, WARN, INFO),
the pass name, file location, and a suggested action.

**Pass 1 — Dependencies**

Check dependency health. Skip this pass if no package manifest was detected.

- **Outdated packages** — run the appropriate outdated command (`npm outdated`, `cargo outdated`,
  `pip list --outdated`, etc.). Flag packages 2+ major versions behind as WARN. Flag packages
  with no updates in 2+ years as INFO.
- **Known vulnerabilities** — run the audit command if available (`npm audit`, `cargo audit`,
  `pip-audit`, `govulncheck`). Flag critical/high CVEs as CRITICAL, medium as WARN, low as INFO.
- **Unmaintained dependencies** — check for packages marked deprecated in the registry.
  Flag as WARN.
- **License compliance** — inspect dependency licenses. Flag copyleft licenses (GPL, AGPL) in
  non-copyleft projects as WARN. Flag missing license declarations as INFO.

If an audit command is not installed, note it as INFO: *"{tool} not available — install it
for vulnerability scanning."*

**Pass 2 — Complexity**

Identify complexity hotspots by reading source files. Exclude directories: `node_modules`,
`vendor`, `.git`, `dist`, `build`, `target`, `__pycache__`, `.venv`.

- **Large files** — files exceeding 500 lines. WARN if >500, CRITICAL if >1000.
- **Long functions** — functions/methods exceeding 80 lines. WARN if >80, CRITICAL if >150.
- **Deep nesting** — nesting depth >4 levels. Flag as WARN with location.
- **High file count in single directory** — directories with >30 source files. Flag as INFO
  suggesting subdirectory organization.

Focus on source files only (detect by extension based on project type). Skip generated files,
lockfiles, and vendored code.

**Pass 3 — Tech Debt**

Scan the codebase for debt indicators:

- **TODO/FIXME/HACK/XXX comments** — count and list locations. WARN if total >20, INFO otherwise.
  Group by file for readability.
- **Dead code indicators** — unused exports, unreferenced files, commented-out code blocks
  (>5 consecutive commented lines). Flag as INFO.
- **Duplication** — identify files with substantially similar content or functions with
  near-identical logic (3+ copies of the same pattern). Flag as WARN.
- **Inconsistent patterns** — mixed formatting styles, inconsistent naming conventions
  (e.g., camelCase and snake_case in the same module). Flag as INFO.

**Pass 4 — Security Posture**

Check for security issues across the full codebase:

- **Hardcoded secrets** — scan for patterns:
  ```
  AKIA[0-9A-Z]{16}
  (?i)(api_key|apikey|secret|token|password|credential)\s*[:=]\s*['"][A-Za-z0-9/+=]{20,}['"]
  -----BEGIN\s+(RSA|EC|DSA|OPENSSH|PGP)?\s*PRIVATE KEY-----
  (?i)(mysql|postgres|mongodb|redis|amqp)://[^:]+:[^@]+@
  ```
  CRITICAL for matches in source code. Downgrade to INFO for test fixtures, examples, or docs.
- **Sensitive files in repo** — check for `.env`, `*.pem`, `*.key`, `credentials.json`,
  `*secret*` files that are tracked by git. CRITICAL if found.
- **Missing `.gitignore` entries** — check whether `.env`, `node_modules`, `dist`, `.venv`,
  and other common entries are gitignored. WARN if missing for detected project type.
- **Permissive configurations** — check for `DEBUG=true`, `CORS *`, disabled CSRF, or
  `--insecure` flags in config files. WARN if found.

### Step 3: Classify and Summarize

Aggregate findings across all passes. Determine overall health:

- **HEALTHY**: Zero CRITICAL, 5 or fewer WARNs.
- **NEEDS ATTENTION**: Zero CRITICAL, but 6+ WARNs.
- **AT RISK**: Any CRITICAL findings.

Identify the single highest-priority action item for the summary.

### Step 4: Present

Output the formatted report. Findings are grouped by severity (Critical first, then Warnings,
then Info) — not by pass. Each finding includes a pass category tag so the user knows which
area it belongs to.

If no findings exist in a severity group, omit that section entirely. If the codebase is
clean, output:

```
### Summary
- **Health:** HEALTHY
- **Top priority:** None — codebase is in good shape.
```

## Rules

- **Read-only.** This skill audits and reports. It never modifies code, dependencies, or
  configuration.
- **This skill audits the full codebase.** For change-specific checks, use `/review` or
  `/preflight`.
- **No false positives on secrets.** Only flag patterns that strongly resemble real credentials.
  Test fixtures, example values, and documentation strings are INFO, not CRITICAL.
- **Respect exclusions.** Never scan `node_modules`, `vendor`, `.git`, build output, or other
  generated/vendored directories. Respect `.gitignore`.
- **Scope adherence.** If the user provides a scope argument, limit the audit to that subtree.
  Do not audit outside the specified scope.
- **Bail out gracefully.** If the project has no recognized type and no source files, report
  that the audit found nothing to scan rather than producing an empty report.
- **Timeout protection.** Cap any single command (e.g., `npm audit`) at 120 seconds. If it
  times out, record as WARN: *"{command} timed out after 120s."*
- **One pass, complete output.** Deliver the full audit in a single response. Do not ask
  follow-up questions or request user input mid-audit.
- **Idempotent.** Running `/audit` twice on the same codebase should produce the same results.
  Do not leave artifacts or modify state.
