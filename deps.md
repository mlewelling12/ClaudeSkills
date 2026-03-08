---
name: deps
description: Dependency impact analyzer — maps usage, assesses risk, and produces a migration checklist before you upgrade, add, or remove a package. Use /deps <action> <package> [scope].
disable-model-invocation: false
---

# Deps — Dependency Impact Analyzer

Analyzes the blast radius of a dependency change before you make it. Maps where a package
is used, identifies breaking changes, and produces an ordered migration checklist. Three
modes: `/deps upgrade <pkg>`, `/deps add <pkg>`, `/deps remove <pkg>`. Optionally scope
to a subdirectory: `/deps upgrade lodash src/api/`.

For a broad dependency health overview, use `/audit`. This skill focuses on the impact of
a specific dependency change.

## Output Format

```markdown
## Dependency Impact — {action} {package} {version info if applicable}

**Project type:** {detected type(s)}
**Package manager:** {npm | pip | cargo | go mod | ...}
**Current version:** {installed version or "not installed"}
**Target version:** {version being upgraded to, or "N/A" for remove}

### Risk Summary

| Severity | Count | Key Concern |
|----------|-------|-------------|
| Critical | {n}   | {top critical concern or "—"} |
| Warning  | {n}   | {top warning or "—"} |
| Info     | {n}   | {top info item or "—"} |

### Usage Map

| File | Line(s) | Import / Usage | Direct Consumers |
|------|---------|----------------|------------------|
| src/api/client.ts | 3, 45 | `import { fetch } from 'pkg'` | `ApiService`, `AuthClient` |

**Coupling depth:** {low | moderate | high}
**Files affected:** {count}

### Breaking Changes

| Change | Affected Usage | Severity |
|--------|---------------|----------|
| `fetch()` renamed to `request()` | src/api/client.ts:3 | Critical |

{If no changelog found: "No changelog or release notes available for this version.
Breaking changes could not be verified — review the package diff manually."}

### Migration Checklist

Ordered by dependency depth (leaf files first, shared modules last):

- [ ] **src/api/client.ts** — Rename `fetch()` to `request()` (breaking change)
- [ ] **src/api/auth.ts** — Update import path (re-export changed)
- [ ] **Run tests** — Verify `npm test` passes after changes

**Estimated scope:** {trivial | moderate | significant}
```

## Workflow

### Step 1: Parse Arguments

Parse `$ARGUMENTS` to determine:

- **Action**: `upgrade`, `add`, or `remove`. If no action keyword is found, default to
  `upgrade`.
- **Package name**: Required. If missing, respond: *"Usage: `/deps <upgrade|add|remove> <package> [scope]`"*
  and stop.
- **Scope**: Optional directory path to restrict analysis. Default to full project.

### Step 2: Detect Project Type

Inspect the repo for package manifests:

| File | Type | Package tool | Lockfile |
|------|------|-------------|----------|
| `package.json` | Node.js | npm/yarn/pnpm | `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` |
| `Cargo.toml` | Rust | cargo | `Cargo.lock` |
| `pyproject.toml` / `requirements.txt` | Python | pip/poetry | `requirements.txt` / `poetry.lock` |
| `go.mod` | Go | go modules | `go.sum` |
| `Gemfile` | Ruby | bundler | `Gemfile.lock` |
| `pom.xml` / `build.gradle` | Java/Kotlin | maven/gradle | |
| `composer.json` | PHP | composer | `composer.lock` |

If no manifest is found, respond: *"No package manifest detected. Cannot analyze
dependencies without a `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, or
equivalent."* — then stop.

Determine the current installed version of the target package from the lockfile or
manifest. For `add` actions, note "not currently installed."

### Step 3: Three-Pass Analysis

Execute each pass in order. Record findings with severity (CRITICAL, WARN, INFO),
file location, and suggested action.

**Pass 1 — Usage Analysis**

Find all import/require/use sites for the target package in the codebase.

- Search for import patterns matching the package name:
  ```
  import .* from ['"]<package>
  require\(['"]<package>
  use <package>
  from <package> import
  ```
- For each import site, identify which functions, classes, or types are used from
  the package.
- Map direct consumers: which modules import files that use this package (one level out).
- **Depth limit**: Trace imports at most 2 levels deep (direct imports + their immediate
  consumers). Do not build a full transitive dependency graph.
- If scope is specified, only search within that subtree.
- Classify coupling:
  - **Low**: 1-3 files use the package, surface-level API usage.
  - **Moderate**: 4-10 files, or usage of package internals / subpath imports.
  - **High**: 11+ files, or deep integration (custom plugins, middleware, type extensions).

For `add` actions, skip this pass — there is no existing usage to analyze. Note:
*"New dependency — no existing usage to map."*

For `remove` actions, flag every usage site as CRITICAL: *"This import will break
when the package is removed."*

**Pass 2 — Change Assessment**

Assess what changes when the action is taken. Approach differs by action:

*Upgrade:*
- Determine the target version (latest stable if not specified).
- Look for changelog, release notes, or CHANGELOG.md in the package. Check the
  package registry (npm, crates.io, PyPI) for release information.
- Identify breaking changes between the current and target version.
- Cross-reference breaking changes with actual usage from Pass 1 — only flag changes
  that affect APIs the project uses.
- If no changelog or release notes are available: report this explicitly. Fall back to
  comparing the package's exported API surface between versions if possible (e.g.,
  `npm info <pkg> exports`). Note the uncertainty: *"Changelog not available —
  breaking changes could not be fully verified."*

*Add:*
- Check the package's license. Flag copyleft (GPL, AGPL) in non-copyleft projects as WARN.
- Check the package's maintenance status — last publish date, open issues count,
  download trends if available.
- Check for known vulnerabilities in the target version.
- Check if the package has peer dependencies that conflict with existing packages.

*Remove:*
- Every usage site from Pass 1 is a breaking change.
- Identify if any other installed packages depend on the target (peer/transitive deps).
- Suggest replacement packages or inline alternatives if the usage is simple.

**Pass 3 — Action Plan**

Synthesize findings into an ordered migration checklist:

- Sort affected files by dependency depth: leaf files (no other affected file imports
  them) first, shared modules last. This minimizes cascading breakage during migration.
- For each file, specify: what to change, why, and which breaking change drives it.
- Include a verification step at the end (run tests, type-check, build).
- Estimate overall scope:
  - **Trivial**: 0-2 files, no breaking API changes.
  - **Moderate**: 3-10 files, or breaking changes with straightforward replacements.
  - **Significant**: 11+ files, breaking changes requiring logic rewrites, or
    deep integration points.

### Step 4: Present

Output the formatted report. Findings appear in the Risk Summary first, then
detailed sections (Usage Map, Breaking Changes, Migration Checklist).

If the package is not found in the project manifest and the action is `upgrade`
or `remove`, respond: *"{package} is not listed in {manifest file}. Did you mean
`/deps add {package}`?"*

## Rules

- **Read-only.** This skill analyzes and reports. It never installs, upgrades, or
  removes packages. It never modifies code, lockfiles, or configuration.
- **No auto-install.** Never run `npm install`, `pip install`, `cargo add`, or
  equivalent commands. The output is a plan for the developer to execute.
- **Depth limit.** Cap import tracing at 2 levels (direct + immediate consumers).
  Full transitive graphs produce noise, not signal.
- **Scope adherence.** If the user provides a scope directory, restrict all analysis
  to that subtree. Do not scan outside the specified scope.
- **Graceful degradation.** When changelogs or release notes are unavailable, say so
  explicitly and note the uncertainty. Do not fabricate version history.
- **Respect exclusions.** Never scan `node_modules`, `vendor`, `.git`, build output,
  or other generated/vendored directories. Respect `.gitignore`.
- **Timeout protection.** Cap any single command at 120 seconds. If it times out,
  record as WARN: *"{command} timed out after 120s."*
- **One pass, complete output.** Deliver the full analysis in a single response. Do
  not ask follow-up questions or request user input mid-analysis.
- **Idempotent.** Running `/deps` twice with the same arguments should produce the
  same results. Do not leave artifacts or modify state.
