---
name: testrun
description: Runs tests, parses results, and diagnoses failures with root cause analysis and suggested fixes. Use /testrun [file|function|suite] to execute.
disable-model-invocation: false
---

# Testrun — Test Execution and Failure Diagnosis

Runs the project's test suite (or a targeted subset), parses the output, and diagnoses
failures with root cause analysis and suggested fixes. Three passes: Execute, Analyze,
Diagnose. Unlike `/test` (which scaffolds test code), `/testrun` runs existing tests and
helps you understand why they fail.

## Output Format

```markdown
## Test Run — {target}

**Runner:** {detected runner and command}
**Scope:** {file | function | suite | full}
**Duration:** {elapsed time}

### Results

| Status | Count |
|--------|-------|
| Passed | {n} |
| Failed | {n} |
| Skipped | {n} |
| Errored | {n} |
| **Total** | **{n}** |

### Failures ({n})

#### 1. `{test name}`

**File:** {test file path}:{line}
**Error:** {error message or assertion diff}
**Category:** {assertion | runtime | timeout | environment}

**Root Cause:** {1-2 sentence explanation of why the test fails}

**Suggested Fix:**
{concrete code change or action to resolve the failure}

---

#### 2. `{test name}`
...

### Summary

- **Pass rate:** {n}% ({passed}/{total})
- **Top failure pattern:** {most common failure category or root cause}
- **Verdict:** ALL PASSING | HAS FAILURES | HAS ERRORS | CANNOT RUN
```

## Workflow

### Step 1: Detect Test Runner

Inspect the project to determine the test setup. Use the same detection as `/test`:

| File | Framework | Run command |
|------|-----------|-------------|
| `jest.config.*` or `"jest"` in package.json | Jest | `npx jest` |
| `vitest.config.*` or `"vitest"` in package.json | Vitest | `npx vitest run` |
| `pytest.ini`, `pyproject.toml` with `[tool.pytest]`, or `conftest.py` | pytest | `pytest` |
| `*_test.go` files present | Go testing | `go test ./...` |
| `Cargo.toml` with `[dev-dependencies]` | Rust | `cargo test` |
| `Makefile` with `test` target | Make | `make test` |
| `package.json` with `"test"` script | npm script | `npm test` |

Priority: framework-specific config > `package.json` script > Makefile. If multiple
frameworks exist, prefer the one with a dedicated config file.

If no runner is detected:
```
Could not detect a test runner. Usage: /testrun [file|function|suite]
Supported: Jest, Vitest, pytest, Go testing, Rust cargo test, npm test, make test.
```
Then stop.

### Step 2: Build the Command

Based on `$ARGUMENTS` and the detected runner, construct the test command:

- **No arguments**: Run the full suite.
- **File path**: Run tests in that file only.
  - Jest/Vitest: `npx jest {file}` / `npx vitest run {file}`
  - pytest: `pytest {file}`
  - Go: `go test {package}`
  - Rust: `cargo test --test {name}`
- **Function or test name**: Run that specific test.
  - Jest/Vitest: `npx jest -t "{name}"` / `npx vitest run -t "{name}"`
  - pytest: `pytest -k "{name}"`
  - Go: `go test -run "{name}" ./...`
  - Rust: `cargo test {name}`
- **Suite or directory**: Run all tests under that path.
  - Jest/Vitest: `npx jest {path}` / `npx vitest run {path}`
  - pytest: `pytest {path}`
  - Go: `go test ./{path}/...`

Add flags for machine-readable output when available:
- Jest: `--verbose --no-coverage`
- Vitest: `--reporter=verbose`
- pytest: `-v --tb=short`
- Go: `-v`
- Rust: `-- --nocapture`

### Step 3: Execute (Pass 1)

Run the constructed command. Capture both stdout and stderr.

- **Timeout**: Cap execution at 300 seconds (5 minutes). If the suite exceeds this,
  kill the process and report: `"Test suite timed out after 5 minutes. Consider running
  a smaller scope with /testrun <file|function>."`
- **Environment errors**: If the command fails to start (missing binary, install error,
  compilation failure), report the error immediately and stop. Do not attempt to parse
  partial output.
- **Record**: Duration, exit code, full output.

### Step 4: Analyze (Pass 2)

Parse the test output to extract results:

1. **Count outcomes** — passed, failed, skipped, errored. Map framework-specific
   terminology to these four categories:
   - Jest/Vitest: `passed` / `failed` / `skipped` / `todo`
   - pytest: `PASSED` / `FAILED` / `SKIPPED` / `ERROR`
   - Go: `ok` (line) / `FAIL` (line) / `skip` / panic
   - Rust: `ok` / `FAILED` / `ignored`

2. **Extract failures** — for each failed test, capture:
   - Test name (full path including describe/context nesting)
   - File and line number (from stack trace or test location)
   - Error message or assertion diff
   - Relevant stack trace (first 10 frames, exclude framework internals)

3. **Classify failures** into categories:
   - **assertion** — expected vs. actual mismatch. The test ran but the result was wrong.
   - **runtime** — uncaught exception, null reference, type error. The code under test
     crashed.
   - **timeout** — individual test exceeded its time limit.
   - **environment** — missing dependency, unavailable service, file not found. The test
     couldn't run properly.

### Step 5: Diagnose (Pass 3)

For each failed test, perform root cause analysis:

1. **Read the failing test** — open the test file and read the specific test case. Understand
   what it asserts and what inputs it provides.

2. **Read the code under test** — trace from the test to the function or module being tested.
   Read the relevant source code.

3. **Compare expected vs. actual** — using the assertion diff and source code, determine
   why the output diverges from the expectation:
   - Is the test wrong (stale expectation, incorrect assertion)?
   - Is the code wrong (bug in implementation)?
   - Is the environment wrong (missing fixture, stale mock, flaky dependency)?

4. **Identify root cause** — provide a 1-2 sentence explanation of why the test fails.
   Be specific: name the function, the incorrect value, the missing condition.

5. **Suggest a fix** — provide a concrete code change or action. Reference the specific
   file and line. If the fix is in the test code, say so. If the fix is in the source
   code, say so. If the issue is environmental, describe the setup step needed.

**Scope cap**: Diagnose up to 10 failures in detail. If more than 10 tests fail, diagnose
the first 10 and note:
*"{n} additional failures not diagnosed. Run `/testrun <specific file>` to investigate."*

### Step 6: Present

Output the full report in the format above. Include all passed/failed/skipped counts,
all diagnosed failures, and the summary verdict.

Verdicts:
- **ALL PASSING** — zero failures, zero errors.
- **HAS FAILURES** — one or more assertion or runtime failures.
- **HAS ERRORS** — one or more environment or compilation errors.
- **CANNOT RUN** — test runner not found, install failed, or suite timed out.

## Rules

- **Read-only analysis.** This skill runs tests and reports results. It never modifies
  source code or test code. Suggested fixes are presented as recommendations, not applied.
- **Run tests exactly once.** Execute the test command a single time. Do not re-run
  tests, retry flaky tests, or run subsets to isolate failures — the single run provides
  all data needed for analysis.
- **Framework-aware parsing.** Use the correct output format for the detected runner.
  Do not assume Jest output format when running pytest.
- **Diagnose, don't guess.** Read the actual test code and source code before suggesting
  a root cause. Every diagnosis must reference specific code.
- **Cap diagnosis at 10 failures.** For large failure sets, diagnose the first 10 and
  guide the user to narrow scope. Analyzing 50 failures produces noise, not signal.
- **Respect timeouts.** Kill long-running suites at 300 seconds. Individual test timeouts
  are the runner's responsibility.
- **No coverage by default.** Do not add coverage flags unless the user explicitly asks.
  Coverage slows execution and is a separate concern.
- **Separate from /test.** This skill runs and analyzes tests. `/test` writes them. Do not
  scaffold new test code in this skill.
- **One pass, complete output.** Deliver the full report in a single response. Do not ask
  follow-up questions.
