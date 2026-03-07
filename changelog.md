---
name: changelog
description: Generates a formatted changelog from git history. Use /changelog to generate from the last tag, or /changelog <range> for a specific range.
disable-model-invocation: false
---

# Changelog — Release Notes from Git History

Generates a well-formatted changelog from git commits, grouped by category. Works with tags,
SHA ranges, or date ranges. Output is ready to paste into release notes or a CHANGELOG.md file.

## Output Format

```markdown
## {version or range} — {date}

### Features
- {description} ({short SHA})

### Fixes
- {description} ({short SHA})

### Refactors
- {description} ({short SHA})

### Docs
- {description} ({short SHA})

### Other
- {description} ({short SHA})

**{N} commits by {M} contributors**
```

Empty categories are omitted.

## Workflow

### Step 1: Determine Range

Based on `$ARGUMENTS`:

- **No arguments**: From the most recent tag to HEAD.
  ```
  git describe --tags --abbrev=0  # get latest tag
  git log {tag}..HEAD --format="%h %s (%an)" --no-merges
  ```
  If no tags exist, use the last 20 commits:
  ```
  git log -20 --format="%h %s (%an)" --no-merges
  ```

- **Single tag/SHA**: From that ref to HEAD.
  ```
  git log {ref}..HEAD --format="%h %s (%an)" --no-merges
  ```

- **Two refs separated by `..`**: Use the range as-is.
  ```
  git log {ref1}..{ref2} --format="%h %s (%an)" --no-merges
  ```

- **Date range** (e.g., `2024-01-01..2024-02-01`): Use `--since` and `--until`.
  ```
  git log --since="{start}" --until="{end}" --format="%h %s (%an)" --no-merges
  ```

### Step 2: Categorize Commits

Classify each commit into a category based on its message prefix or content:

| Category    | Matches                                                  |
|-------------|----------------------------------------------------------|
| Features    | `feat:`, `feature:`, `add:`, or introduces new functionality |
| Fixes       | `fix:`, `bugfix:`, `hotfix:`, or resolves a bug          |
| Refactors   | `refactor:`, `refact:`, `cleanup:`, structural changes   |
| Docs        | `docs:`, `doc:`, documentation-only changes              |
| Other       | Everything else (chores, tests, CI, deps, etc.)          |

Rules for classification:
- Use the conventional commit prefix if present.
- If no prefix, infer from the commit message content. Be conservative — when unsure, use Other.
- Merge commits are excluded (already filtered by `--no-merges`).

### Step 3: Polish Descriptions

For each commit, rewrite the message into a clean changelog entry:
- Strip the conventional commit prefix (`feat: ` → just the description).
- Capitalize the first word.
- Remove trailing periods.
- Keep to one line. If the commit message is multi-line, use only the subject.
- Append the short SHA in parentheses for traceability.

### Step 4: Compile and Present

1. Group entries by category in the order: Features, Fixes, Refactors, Docs, Other.
2. Omit empty categories.
3. Add a footer line with total commit count and unique contributor count.
4. Output the formatted changelog.

## Rules

- **Read-only.** This skill never modifies files or git state. It only reads and outputs.
- **No fabrication.** Every entry must correspond to an actual commit. If the range has no
  commits, say "No commits found in range {range}."
- **Respect the range.** Don't include commits outside the specified range.
- **De-duplicate.** If a commit appears in multiple categories due to ambiguous wording, place
  it in the most specific one. Features > Fixes > Refactors > Docs > Other.
- **Keep it scannable.** Changelog entries should be one line each. Save long descriptions for
  PR bodies, not changelogs.
- **Author attribution.** Include author names only when there are multiple contributors.
  Solo repos don't need "(by Alice)" on every line.
