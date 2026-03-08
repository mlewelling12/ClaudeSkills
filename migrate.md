---
name: migrate
description: Pattern-based codebase migration — finds all instances of an old pattern, transforms them to a new pattern, and verifies each change. Use /migrate <from> to <to> [scope].
disable-model-invocation: false
---

# Migrate — Pattern-Based Codebase Migration

Finds every instance of a source pattern across the codebase, transforms each to a target
pattern, and verifies nothing broke. Handles framework upgrades, API version bumps, and
cross-cutting pattern replacements. Three passes: discover, transform, verify.

Unlike `/refactor` (which restructures local scope) or `/deps` (which analyzes a single
package without modifying code), `/migrate` performs bulk find-and-transform across the
entire codebase with rollback on failure.

## Output Format

```markdown
## Migration — {from} → {to}

**Scope:** {full project | scoped directory}
**Pattern:** {source pattern} → {target pattern}
**Project type:** {detected type(s)}

### Discovery Summary

| # | File | Line(s) | Match | Context |
|---|------|---------|-------|---------|
| 1 | src/api/client.ts | 12, 45 | `oldMethod()` | Called inside `fetchData()` |

**Total matches:** {n}
**Files affected:** {n}
**Estimated scope:** {trivial | moderate | significant}

### Transform Log

| # | File | Status | Detail |
|---|------|--------|--------|
| 1 | src/api/client.ts | ✅ Done | 2 replacements, tests pass |
| 2 | src/auth/login.ts | ⚠️ Manual | Complex usage — requires manual review |
| 3 | src/db/query.ts | ❌ Reverted | Test regression in `query.test.ts` |

### Verification

- **Build:** {PASS | FAIL}
- **Tests:** {PASS x/x | FAIL — details}
- **Lint:** {PASS | FAIL}

### Summary

**Migrated:** {n} files
**Skipped (manual):** {n} files — require manual intervention
**Reverted:** {n} files — caused regressions
**Remaining:** {list of files needing manual attention, if any}
```

## Workflow

### Step 1: Parse Arguments

Parse `$ARGUMENTS` to extract:

- **From pattern**: The source pattern, API, or import to find. Required.
- **To pattern**: The target replacement. Required.
- **Scope**: Optional directory to restrict the migration. Default: full project.

Detect the `to` keyword to split from/to. Examples:

| Input | From | To | Scope |
|-------|------|----|-------|
| `lodash to lodash-es` | `lodash` | `lodash-es` | full project |
| `axios to fetch src/api/` | `axios` | `fetch` | `src/api/` |
| `React.FC to React.FunctionComponent` | `React.FC` | `React.FunctionComponent` | full project |
| `v1/api to v2/api` | `v1/api` | `v2/api` | full project |

If the `to` keyword is missing or either pattern is empty, respond:
*"Usage: `/migrate <from> to <to> [scope]`"* — then stop.

### Step 2: Detect Project Type and Test Runner

Inspect the repo for project indicators to determine the build and test toolchain:

| File | Type | Test command |
|------|------|-------------|
| `package.json` with `scripts.test` | Node.js | `npm test` |
| `Cargo.toml` | Rust | `cargo test` |
| `pyproject.toml` / `pytest.ini` | Python | `pytest` |
| `go.mod` | Go | `go test ./...` |
| `Makefile` with `test` target | Any | `make test` |

If no test runner is detected, note: *"No test runner found. Verification will be limited
to build/lint checks."*

Run the test suite before making any changes to establish a green baseline. If tests
fail before migration, stop: *"Test suite fails before migration — fix existing
failures first."*

### Step 3: Discovery (Pass 1)

Find all instances of the source pattern across the codebase. Build a complete inventory
before changing anything.

1. **Search for the source pattern** — use multiple strategies:
   - Literal string match for names, imports, and API calls.
   - Import/require pattern match: `import .* from ['"]<from>`, `require\(['"]<from>`,
     `from <from> import`, `use <from>`.
   - If the from pattern contains a method or type name, search for all usages including
     destructured imports, aliased imports, and re-exports.

2. **Classify each match**:
   - **Automatable**: Direct pattern replacement — the from and to patterns can be
     swapped with a straightforward text transformation.
   - **Manual**: Complex usage that requires human judgment — conditional logic wrapping
     the pattern, dynamic references, metaprogramming, or significantly different API
     signatures between from and to.

3. **Build the discovery summary**: List every match with file, line(s), the matched
   text, and its classification.

4. **Present the discovery summary to the user** and pause for confirmation before
   proceeding. State how many matches are automatable vs. manual. If all matches
   are classified as manual, recommend using `/refactor` instead.

Respect scope restrictions. Exclude: `node_modules`, `vendor`, `.git`, `dist`, `build`,
`target`, `__pycache__`, `.venv`, lockfiles, and generated files.

### Step 4: Transform (Pass 2)

Apply the migration file by file. Process automatable matches only — skip files
classified as manual.

For each file:

1. **Read the full file** — understand surrounding context, not just the matched lines.
2. **Apply the transformation** — replace the source pattern with the target pattern.
   Preserve formatting, indentation, and surrounding code.
3. **Run verification** — execute the test suite (or build/lint if no tests exist).
4. **Evaluate the result**:
   - **Tests pass**: Record as ✅ Done. Move to the next file.
   - **Tests fail and the failure is caused by this change**: Revert the file using
     `git checkout -- <file>`, record as ❌ Reverted, reclassify as manual, and
     move to the next file.
   - **Tests fail but the failure is unrelated** (flaky test): Note the flaky test,
     keep the change, and move on.

Order files to minimize cascading failures:
- **Leaf files first** — files that are not imported by other affected files.
- **Shared modules last** — files imported by many other affected files.

After every 5 files, run the full test suite as a batch checkpoint regardless of
individual file results.

### Step 5: Verify (Pass 3)

After all automatable files are processed:

1. **Run the full test suite** — confirm all tests pass with all changes applied.
2. **Run the build** — confirm the project compiles/builds cleanly.
3. **Run the linter** — confirm no new lint violations.
4. **Scan for remaining instances** — search the codebase for any leftover occurrences
   of the source pattern. These are either manual items or missed matches.

If verification fails:
- Identify which file(s) caused the failure.
- Revert those files and re-run verification.
- Continue reverting until the suite passes.
- Reclassify reverted files as manual.

### Step 6: Present

Output the full migration report:

1. **Discovery Summary** — what was found.
2. **Transform Log** — what was changed, skipped, or reverted.
3. **Verification** — build/test/lint results.
4. **Summary** — totals and list of remaining manual items.

If manual items remain, list each with its file location and a brief explanation of
why automated transformation was not possible.

## Rules

- **User confirmation required.** Never start transforming code without presenting the
  discovery summary and getting user confirmation. Discovery is safe; transformation is
  destructive.
- **One file at a time.** Transform and verify each file individually. Do not batch
  changes across files without intermediate verification.
- **Revert on failure.** If a transformation causes test regressions, revert immediately.
  Never leave the codebase in a broken state between files.
- **Preserve behavior.** The migration should produce functionally equivalent code. If the
  target pattern has different semantics, flag it as manual — do not silently change behavior.
- **Don't transform tests blindly.** Test files may intentionally reference the source
  pattern (e.g., testing backward compatibility). Flag test file matches for manual review
  unless the test clearly just uses the API being migrated.
- **Respect exclusions.** Never scan or modify `node_modules`, `vendor`, `.git`, build
  output, lockfiles, or generated/vendored files. Respect `.gitignore`.
- **Scope adherence.** If the user provides a scope directory, restrict discovery and
  transformation to that subtree. Do not scan or modify files outside the specified scope.
- **No partial state.** If the migration is interrupted, all changes are in individual
  file commits or reverted. The codebase should always be in a valid state.
- **Timeout protection.** Cap any single command (test suite, build) at 120 seconds.
  If it times out, record as ⚠️ and note the timeout.
- **Idempotent discovery.** Running `/migrate` with the same arguments should find the
  same matches. The discovery pass never modifies code.
- **Baseline must be green.** Do not start a migration if the test suite already fails.
  A red baseline makes it impossible to distinguish migration regressions from
  pre-existing failures.
