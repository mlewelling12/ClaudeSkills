---
name: preflight
description: Pre-merge checklist — runs build, lint, tests, and checks for common issues before merging. Use /preflight to run.
disable-model-invocation: false
---

# Preflight — Pre-Merge Checklist

Runs a comprehensive pre-merge checklist to catch issues before they hit CI or land on main.
Checks build, lint, tests, TODOs, branch freshness, and common pitfalls. One command, full
confidence.

## Output Format

```markdown
## Preflight Check — {branch} → {base}

| Check             | Status | Details                      |
|-------------------|--------|------------------------------|
| Build             | PASS   |                              |
| Lint              | FAIL   | 3 errors in src/utils.ts     |
| Tests             | PASS   | 42 passed, 0 failed          |
| Type check        | PASS   |                              |
| Branch up-to-date | WARN   | 5 commits behind main        |
| TODOs/FIXMEs      | WARN   | 2 new TODOs in changed files |
| Secrets scan      | PASS   |                              |
| Large files       | PASS   |                              |

### Verdict: {READY | NOT READY | REVIEW NEEDED}
{1 sentence summary}

### Issues to Fix
- {actionable item 1}
- {actionable item 2}
```

## Workflow

### Step 1: Detect Project Type

Inspect the repo to determine available tools:

| File             | Tool        | Build command   | Lint command        | Test command   | Type check          |
|------------------|-------------|-----------------|---------------------|----------------|---------------------|
| `package.json`   | npm/yarn/pnpm | `npm run build` | `npm run lint`    | `npm test`     | `npx tsc --noEmit`  |
| `Cargo.toml`     | cargo       | `cargo build`   | `cargo clippy`      | `cargo test`   | _(included in build)_ |
| `pyproject.toml` | python      | _(skip)_        | `ruff check .`      | `pytest`       | `mypy .`            |
| `go.mod`         | go          | `go build ./...`| `golangci-lint run` | `go test ./...`| `go vet ./...`      |
| `Makefile`       | make        | `make build`    | `make lint`         | `make test`    | _(skip)_            |

If multiple project files exist, run checks for all detected toolchains.
If a command doesn't exist (e.g., no `lint` script in package.json), skip it and mark as "N/A."

### Step 2: Run Checks

Execute each check in order. Capture stdout/stderr and exit codes.

**Check 1 — Build**
Run the build command. PASS if exit code 0, FAIL otherwise.

**Check 2 — Lint**
Run the lint command. PASS if exit code 0, FAIL with error count otherwise.

**Check 3 — Tests**
Run the test command. PASS with pass/fail counts, FAIL if any test fails.

**Check 4 — Type Check**
Run the type checker. PASS if clean, FAIL with error count.

**Check 5 — Branch Freshness**
```
git fetch origin main 2>/dev/null
git rev-list HEAD..origin/main --count
```
PASS if 0 commits behind. WARN if 1-10 behind. FAIL if 10+ behind.

**Check 6 — TODOs/FIXMEs in Changed Files**
Scan files changed on this branch for new TODO/FIXME/HACK/XXX comments:
```
git diff main --name-only | xargs grep -n "TODO\|FIXME\|HACK\|XXX" 2>/dev/null
```
PASS if none. WARN with count and locations if found.

**Check 7 — Secrets Scan**
Check changed files for patterns that look like secrets using these regex patterns:

```
# AWS access key IDs
AKIA[0-9A-Z]{16}

# Generic high-entropy secrets assigned to key/token/secret variables
(?i)(api_key|apikey|secret|token|password|credential)\s*[:=]\s*['"][A-Za-z0-9/+=]{20,}['"]

# Private keys (PEM format)
-----BEGIN\s+(RSA|EC|DSA|OPENSSH|PGP)?\s*PRIVATE KEY-----

# .env files in the diff
^diff --git a/\.env

# Connection strings with embedded credentials
(?i)(mysql|postgres|mongodb|redis|amqp)://[^:]+:[^@]+@
```

PASS if none. FAIL if potential secrets detected. When a match occurs in test fixtures,
example configs, or documentation, downgrade to WARN — only FAIL for matches in source code.

**Check 8 — Large Files**
Check for files over 1MB in the diff:
```
git diff main --name-only | xargs ls -la 2>/dev/null | awk '$5 > 1048576'
```
PASS if none. WARN with file sizes if found.

### Step 3: Verdict

- **READY**: All checks PASS (WARNs are acceptable).
- **NOT READY**: Any check is FAIL. List all failures as actionable items.
- **REVIEW NEEDED**: No FAILs but multiple WARNs that together suggest risk.

### Step 4: Present

Output the formatted checklist table and verdict. List specific, actionable items for any
FAILs or WARNs.

## Rules

- **Run everything from the repo root.** Commands should use the project root as the working
  directory.
- **Don't fix, just report.** Preflight is diagnostic. It tells you what's wrong — it doesn't
  fix it. Use `/review` or manual fixes for that.
- **Fail fast on critical issues.** If the build fails, still run remaining checks — the user
  wants the full picture, not one error at a time.
- **Timeout protection.** Cap each command at 120 seconds. If a command times out, mark it as
  WARN with "timed out after 120s."
- **No false positives on secrets.** Only flag patterns that strongly resemble real secrets.
  Don't flag test fixtures, example values, or documentation strings. When in doubt, WARN
  rather than FAIL.
- **Branch detection.** Auto-detect the current branch and the base branch (main or master).
  If neither exists, ask the user which branch to compare against.
- **Respect .gitignore.** Don't scan ignored files for TODOs, secrets, or large files.
- **Idempotent.** Running `/preflight` twice should produce the same results (assuming no
  changes in between). Don't leave artifacts.
