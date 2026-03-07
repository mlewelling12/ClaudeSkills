---
name: review
description: Structured code review of staged, uncommitted, or branch changes. Use /review to review working changes, /review <branch> to review a branch diff.
disable-model-invocation: false
---

# Review — Structured Code Review

Performs a systematic 4-pass code review of changes, outputting actionable findings ranked
by severity. Works on uncommitted changes (default) or a branch diff against main.

## Output Format

```markdown
## Code Review — {scope description}

### Summary
{1-2 sentence overview of what the changes do}

### Findings

#### CRITICAL
- **[file:line]** {issue} — {why it matters and suggested fix}

#### IMPORTANT
- **[file:line]** {issue} — {recommendation}

#### MINOR
- **[file:line]** {issue} — {suggestion}

### Verdict
{APPROVE | REQUEST CHANGES | NEEDS DISCUSSION}
{1 sentence rationale}
```

## Workflow

### Step 1: Determine Scope

Based on `$ARGUMENTS`:

- **No arguments**: Review uncommitted changes (staged + unstaged).
  ```
  git diff HEAD
  ```
  If no uncommitted changes exist, fall back to the last commit:
  ```
  git diff HEAD~1..HEAD
  ```

- **Branch name provided**: Review the branch diff against main/master.
  ```
  git diff main...<branch>
  ```

- **File path provided**: Review only that file's uncommitted changes.
  ```
  git diff HEAD -- <file>
  ```

Collect the diff and identify all changed files.

### Step 2: Read Context

For each changed file, read the full file (not just the diff) to understand the surrounding
code. A diff-only review misses context-dependent bugs.

### Step 3: Four-Pass Review

Execute each pass in order. Track findings with severity and file location.

**Pass 1 — Correctness**
- Logic errors, off-by-one bugs, null/undefined access
- Missing error handling at system boundaries (user input, API calls, file I/O)
- Race conditions, deadlocks, or state management issues
- Broken control flow (unreachable code, missing returns, fallthrough)
- Type mismatches or incorrect function signatures

**Pass 2 — Security**
- Injection vulnerabilities (SQL, XSS, command injection, path traversal)
- Hardcoded secrets, credentials, or API keys
- Missing input validation or sanitization at trust boundaries
- Insecure defaults (permissive CORS, debug mode, weak crypto)
- Authentication/authorization gaps

**Pass 3 — Performance**
- N+1 queries or unbounded loops over data
- Missing indexes for frequent queries
- Unnecessary re-renders or recomputation
- Large allocations in hot paths
- Missing pagination or unbounded result sets

**Pass 4 — Maintainability**
- Dead code, unused imports, unreachable branches
- Naming that obscures intent
- Missing abstractions where duplication is significant (3+ copies)
- Overly complex functions (high cyclomatic complexity)
- Breaking changes to public APIs without versioning

### Step 4: Classify and Present

Assign each finding a severity:

- **CRITICAL**: Must fix before merge. Bugs, security vulnerabilities, data loss risks.
- **IMPORTANT**: Should fix before merge. Performance issues, missing edge cases, poor patterns
  that will cause problems soon.
- **MINOR**: Nice to fix. Style, naming, minor refactors. Safe to defer.

Output findings grouped by severity. Each finding must reference a specific file and line number.

### Step 5: Verdict

- **APPROVE**: No CRITICAL or IMPORTANT findings. Ship it.
- **REQUEST CHANGES**: Has CRITICAL or IMPORTANT findings. Fix before merge.
- **NEEDS DISCUSSION**: Architectural or design concerns that need team input.

## Rules

- **Read-only.** This skill never modifies code. It only reads and reports.
- **Be specific.** Every finding must reference a file and line. "The code has issues" is not
  a finding.
- **No style nitpicks in CRITICAL/IMPORTANT.** Formatting, bracket style, and whitespace
  preferences are MINOR at most. Don't block a merge over style.
- **Acknowledge good work.** If the code is clean, say so. Not every review needs findings.
  "APPROVE — clean implementation, no issues found" is a valid output.
- **Context matters.** A missing null check in a prototype is MINOR. The same missing check in
  payment processing is CRITICAL. Calibrate severity to the domain.
- **Don't rewrite the PR.** A review suggests improvements — it doesn't redesign the solution.
  If the approach is fundamentally wrong, flag it as NEEDS DISCUSSION with rationale.
- **One pass, complete output.** Don't ask follow-up questions. Deliver the full review in a
  single response.
