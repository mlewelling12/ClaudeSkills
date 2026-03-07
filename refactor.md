---
name: refactor
description: Guided refactoring with safety checks — identifies scope, runs tests before/after, applies changes incrementally. Use /refactor <target> to start.
disable-model-invocation: false
---

# Refactor — Guided Refactoring with Safety Checks

Applies refactoring transformations incrementally with test verification before and after each
change. Supports common patterns: extract function, rename, inline, move, simplify conditional,
and decompose class.

## Output Format

````markdown
## Refactor: {target} — {refactoring type}

### Scope
**Target:** {file:function or file:class}
**Refactoring:** {type — extract, rename, inline, move, simplify, decompose}
**Files affected:** {list of files that will change}

### Pre-check
- Tests: {PASS x/x | FAIL — abort}
- Lint: {PASS | FAIL — note issues}

### Changes

#### Change 1: {description}
**File:** {path}
```diff
{diff of the change}
```

#### Change 2: {description}
...

### Post-check
- Tests: {PASS x/x | FAIL — revert}
- Lint: {PASS | FAIL}

### Summary
{1-2 sentences: what was refactored, why it's better, any follow-up needed}
````

## Workflow

### Step 1: Identify Target and Refactoring Type

Parse `$ARGUMENTS` to determine:

- **Target** — a file, function, class, or code pattern to refactor.
- **Refactoring type** — auto-detect from the target's issues, or use the type specified
  by the user.

If no target is provided:
```
Usage: /refactor <target>
Examples:
  /refactor src/utils.ts:calculateTotal    — refactor a specific function
  /refactor src/auth/                       — refactor a module
  /refactor "extract validation logic"      — describe what to refactor
```

Common refactoring types and when to apply them:

| Type | When to use | Signal |
|------|-------------|--------|
| **Extract function** | A block of code does a distinct subtask within a larger function | Function > 30 lines, or a comment explains a code block |
| **Rename** | Name doesn't reflect purpose | Variable/function name is misleading or vague |
| **Inline** | Abstraction adds indirection without value | Function called once, or wraps a single expression |
| **Move** | Code lives in the wrong module | Function is imported by many modules but defined far away |
| **Simplify conditional** | Complex branching logic | Nested if/else > 3 levels, or repeated condition checks |
| **Decompose class** | Class has too many responsibilities | Class > 300 lines, or methods cluster into distinct groups |

### Step 2: Read and Understand

1. **Read the target code** — full file, not just the function. Understand the context.
2. **Read callers** — search for all usages of the target. Refactoring a function used in
   50 places has different risk than one used in 2 places.
3. **Read tests** — find existing tests for the target. These are your safety net.
4. **Identify the scope** — list all files that will need to change.

### Step 3: Pre-check

Run the test suite before making any changes. Detect the test runner from project files:

| File present | Test command |
|-------------|-------------|
| `package.json` with `scripts.test` | `npm test` |
| `Makefile` with `test` target | `make test` |
| `pytest.ini`, `pyproject.toml`, or `setup.cfg` with pytest config | `pytest` |
| `Cargo.toml` | `cargo test` |
| `go.mod` | `go test ./...` |

If none match, search for a `test` or `spec` directory and infer the runner from file
extensions and imports.

- **Tests pass**: Record the baseline. Proceed.
- **Tests fail**: Stop. Report the failing tests. Do not refactor code with a failing test
  suite — you won't be able to distinguish pre-existing failures from regressions.

Also run lint if available. Note any pre-existing lint issues so they aren't confused with
regressions.

### Step 4: Plan Changes

Break the refactoring into incremental steps. Each step should:

1. Be a single, atomic transformation.
2. Keep the code in a valid state (compilable, tests should still pass).
3. Be independently reviewable.

Order changes to minimize risk:
- **Rename** before **move** (moving renamed symbols is clearer).
- **Extract** before **simplify** (extracted functions can be simplified in isolation).
- **Add new code** before **remove old code** (create the destination, then update callers,
  then remove the source).

### Step 5: Apply Changes

For each planned change:

1. **Make the change** — apply one transformation.
2. **Verify** — run tests. If tests fail:
   - Check if the failure is caused by the change.
   - If yes, revert the change using `git checkout -- <affected files>` to restore
     the last passing state, then adjust the approach.
   - If no (flaky test), note it and continue.
3. **Record** — add the change to the output with a diff.

Continue until all planned changes are applied.

### Step 6: Post-check

Run the full test suite and lint again:

- **Tests pass**: Refactoring is safe. Report success.
- **Tests fail**: Identify which change caused the regression. Revert to the last passing
  state and report what went wrong.
- **Lint changes**: If the refactoring introduced lint issues, fix them. If it resolved
  pre-existing lint issues, note that as a bonus.

### Step 7: Present

Output the full refactoring report: scope, pre-check, each change with diff, post-check,
and summary.

## Rules

- **Tests must pass before and after.** If the test suite fails before refactoring, stop.
  If it fails after, revert. Refactoring should never change behavior.
- **One transformation at a time.** Don't combine extract + rename + move into a single step.
  Atomic changes are reviewable and revertable.
- **Don't change behavior.** Refactoring is restructuring without changing what the code does.
  If you need to fix a bug, that's a separate step — do it before or after the refactoring,
  not during.
- **Preserve the public API.** Don't rename or remove exported functions/types without the
  user's explicit approval. Internal changes are free; public changes need consent.
- **Callers must be updated.** If you rename a function, update every call site. If you move
  a module, update every import. Incomplete refactoring is worse than no refactoring.
- **Don't refactor what you don't understand.** If the code's purpose is unclear, read more
  context or ask the user before restructuring it. You might be removing intentional complexity.
- **Stop at diminishing returns.** If the code is already clean and the refactoring would only
  save a line or two, say so and skip it. Not everything needs refactoring.
- **Respect the codebase's idioms.** Don't impose a different style or pattern. If the project
  uses callbacks, don't convert to promises. If it uses classes, don't switch to functions.
  Match the existing conventions.
