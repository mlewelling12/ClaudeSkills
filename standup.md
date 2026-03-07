---
name: standup
description: Generates a daily standup summary from recent git activity, open branches, and WIP changes. Use /standup to generate.
disable-model-invocation: false
---

# Standup — Daily Status from Git Activity

Generates a "yesterday / today / blockers" standup summary by analyzing recent git history,
open branches, and uncommitted work. Zero manual input required — just run `/standup`.

## Output Format

```markdown
## Standup — {date}

### Yesterday
- {completed work inferred from recent commits}

### Today
- {planned work inferred from open branches and WIP changes}

### Blockers
- {detected issues: merge conflicts, failing tests, stale branches}
- None _(if no blockers detected)_
```

## Workflow

### Step 1: Gather Context

Collect all relevant git data. Run these commands:

1. **Recent commits** (last 24 hours, all branches):
   ```
   git log --all --since="24 hours ago" --format="%h %s (%an, %ar)" --no-merges
   ```

2. **Open branches** with their last commit age:
   ```
   git branch -a --sort=-committerdate --format="%(refname:short) %(committerdate:relative) %(subject)"
   ```

3. **Uncommitted changes** (staged + unstaged):
   ```
   git status --short
   git diff --stat
   ```

4. **Merge conflicts** (if any):
   ```
   git diff --name-only --diff-filter=U
   ```

5. **Stale branches** (no commits in 7+ days, excluding main/master):
   ```
   git branch --sort=committerdate --format="%(refname:short) %(committerdate:relative)" | head -5
   ```

### Step 2: Analyze and Categorize

- **Yesterday**: Group recent commits by theme (feature, fix, refactor, docs). Summarize each
  group in one bullet. Use commit messages as the source — don't fabricate work that isn't there.
- **Today**: Infer planned work from:
  - Active branches with recent commits (likely continuing)
  - Uncommitted changes (work in progress)
  - If no WIP exists, state "No active WIP detected — check task board."
- **Blockers**: Flag any of:
  - Unresolved merge conflicts
  - Branches significantly behind main
  - Stale branches that may need cleanup
  - If none detected, output "None"

### Step 3: Present

Output the formatted standup to the user. Keep each bullet to one line. Prioritize signal
over completeness — a 5-bullet standup is better than a 20-bullet dump.

## Rules

- **Read-only.** This skill never modifies files, branches, or git state.
- **Scope to the current repo.** Only analyze the repo in the working directory.
- **24-hour window.** "Yesterday" means the last 24 hours, not literally yesterday. This
  handles weekends and irregular schedules.
- **No hallucination.** Every bullet must trace back to a commit, branch, or file change.
  If there's no recent activity, say so — don't invent work.
- **Keep it short.** Target 3-7 bullets for Yesterday, 1-3 for Today, 0-2 for Blockers.
  Standup updates should take 30 seconds to read.
- **Multi-author awareness.** If the repo has multiple contributors, attribute work to authors.
  If solo, omit author attribution to reduce noise.
