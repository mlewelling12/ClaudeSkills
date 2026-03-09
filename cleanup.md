---
name: cleanup
description: Dead code and cruft remover — finds unused exports, orphaned files, stale config, and removes them safely. Use /cleanup [scope] to run.
disable-model-invocation: false
---

# Cleanup — Dead Code and Cruft Remover

Finds and removes dead code, unused exports, orphaned files, and stale configuration.
Three passes: detect, confirm, remove. Unlike `/audit` (which reports issues but doesn't
fix them) or `/refactor` (which restructures live code), `/cleanup` targets code that is
no longer used and safely removes it with verification.

## Output Format

```markdown
## Cleanup — {scope}

**Scope:** {full project | directory}
**Project type:** {detected type(s)}

### Discovery

| # | Type | Location | Evidence | Confidence |
|---|------|----------|----------|------------|
| 1 | Unused export | src/utils/format.ts:45 `formatCurrency` | Zero import references found | HIGH |
| 2 | Orphaned file | src/legacy/old-parser.ts | Not imported by any file, no test references | HIGH |
| 3 | Commented-out code | src/api/users.ts:89-104 | 16 lines of commented code | HIGH |
| 4 | Dead dependency | package.json `moment` | No import/require references in source | MEDIUM |
| 5 | Stale config | .env.staging | References service endpoint that no longer exists | LOW |

**Total candidates:** {n}
**High confidence:** {n}  |  **Medium:** {n}  |  **Low:** {n}

### Removal Log

| # | Location | Action | Verification |
|---|----------|--------|-------------|
| 1 | src/utils/format.ts:45 | Removed `formatCurrency` export | Tests pass |
| 2 | src/legacy/old-parser.ts | Deleted file | Tests pass, no broken imports |
| 3 | src/api/users.ts:89-104 | Removed commented block | Tests pass |
| 4 | package.json `moment` | Removed dependency | Build + tests pass |

### Post-cleanup Verification

- **Build:** {PASS | FAIL}
- **Tests:** {PASS x/x | FAIL — details}
- **Lint:** {PASS | FAIL}

### Summary

- **Removed:** {n} items ({lines removed} lines, {files deleted} files)
- **Skipped:** {n} items — low confidence, need manual review
- **Remaining:** {list of items skipped with reason, if any}
```

## Workflow

### Step 1: Determine Scope

Parse `$ARGUMENTS`:

- **No arguments**: Analyze the full project.
- **Directory path**: Limit cleanup to that subtree.

### Step 2: Detect Project Type and Test Runner

Inspect the repo for project indicators:

| File | Type | Test command |
|------|------|-------------|
| `package.json` with `scripts.test` | Node.js | `npm test` |
| `Cargo.toml` | Rust | `cargo test` |
| `pyproject.toml` / `pytest.ini` | Python | `pytest` |
| `go.mod` | Go | `go test ./...` |
| `Makefile` with `test` target | Any | `make test` |

Run the test suite before making any changes to establish a green baseline. If tests
fail before cleanup, stop: *"Test suite fails before cleanup — fix existing failures
first."*

### Step 3: Discovery (Pass 1)

Find all dead code and cruft candidates. Build a complete inventory before removing
anything.

**Unused exports and functions:**
- Find all exported symbols (functions, classes, constants, types).
- For each, search the entire codebase for import/require references.
- Mark as unused if zero references exist outside the defining file.
- Confidence: HIGH if truly zero references. MEDIUM if referenced only in
  commented-out code or dead branches.

**Orphaned files:**
- Find files not imported by any other file.
- Exclude entry points (files referenced in `package.json` main/bin/exports,
  `Makefile` targets, route definitions, test files, config files).
- Confidence: HIGH if no references and not an entry point. MEDIUM if unclear.

**Commented-out code:**
- Find blocks of 5+ consecutive commented lines that contain code syntax
  (function calls, variable assignments, control flow).
- Exclude license headers, documentation blocks, and configuration examples.
- Confidence: HIGH for obvious dead code. LOW for ambiguous blocks.

**Dead dependencies:**
- For each dependency in the package manifest, search source files for
  import/require statements.
- Exclude devDependencies used only in build/test tooling (check test files,
  config files, and build scripts).
- Confidence: HIGH if zero imports found. MEDIUM if used only in config or
  build files (might be a CLI tool or plugin).

**Stale configuration:**
- Environment variables defined but never read in code.
- Config files for tools no longer in the dependency list.
- CI/CD steps referencing removed scripts or commands.
- Confidence: MEDIUM — configuration can be consumed in non-obvious ways.

Present the full discovery summary to the user with confidence levels and pause
for confirmation before removing anything.

### Step 4: Confirm

Present the discovery table and ask the user to confirm which items to remove.
Default recommendation: remove all HIGH confidence items, skip LOW confidence items,
and flag MEDIUM for user decision.

If the user confirms, proceed to removal. If the user wants to exclude specific
items, respect that.

### Step 5: Remove (Pass 2)

Process confirmed items one at a time:

1. **Make the removal** — delete the dead code, unused export, or orphaned file.
2. **Run verification** — execute the test suite (or build/lint if no tests exist).
3. **Evaluate**:
   - **Tests pass**: Record as done. Move to next item.
   - **Tests fail**: Revert using `git checkout -- <file>` (or `git checkout HEAD -- <file>`
     for deleted files), record as skipped with reason, and move on.

Order removals to minimize cascading issues:
- **Leaf items first** — unused functions in files that are otherwise active.
- **Orphaned files** — standalone files with no dependents.
- **Dependencies last** — removing a package can affect many files.

After every 5 removals, run the full test suite as a batch checkpoint.

### Step 6: Verify (Pass 3)

After all removals are processed:

1. **Run the full test suite** — confirm all tests pass.
2. **Run the build** — confirm the project compiles/builds cleanly.
3. **Run the linter** — confirm no new lint violations.

If verification fails:
- Identify which removal(s) caused the failure.
- Revert those and re-run verification.
- Move reverted items to the skipped list.

### Step 7: Present

Output the full cleanup report: discovery summary, removal log, verification results,
and final summary with counts.

## Rules

- **User confirmation required.** Never remove code without presenting the discovery
  summary and getting user confirmation. Discovery is safe; removal is destructive.
- **One item at a time.** Remove and verify each item individually. Do not batch
  deletions without intermediate verification.
- **Revert on failure.** If a removal causes test regressions, revert immediately.
  Never leave the codebase in a broken state.
- **Conservative on confidence.** When in doubt, classify as MEDIUM or LOW. It is
  better to skip a dead item than to remove live code.
- **Don't remove entry points.** Files referenced in package.json main/bin, Makefile
  targets, or framework conventions (e.g., `pages/`, `routes/`) are not orphans even
  if no explicit import exists.
- **Don't remove test files.** Test files are often not imported by source code. They
  are entry points in their own right. Only flag tests for removal if they test code
  that has already been removed.
- **DevDependencies need extra care.** Build tools, linters, formatters, and test
  runners are used indirectly. Verify by checking config files and build scripts,
  not just source imports.
- **Respect exclusions.** Never scan or modify `node_modules`, `vendor`, `.git`,
  build output, lockfiles, or generated/vendored directories.
- **Scope adherence.** If the user provides a scope, restrict discovery and removal
  to that subtree.
- **Baseline must be green.** Do not start cleanup if the test suite already fails.
- **Timeout protection.** Cap any single command at 120 seconds. If it times out,
  record as skipped and note the timeout.
