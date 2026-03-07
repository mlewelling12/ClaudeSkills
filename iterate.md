---
name: iterate
description: Iterative refinement loop that survives compaction. Use /iterate <task> to start, /iterate to continue.
disable-model-invocation: false
---

# Iterate — Persistent Refinement Loop

A Ralph Loop-inspired iterative refinement skill. State is externalized to disk so the loop
survives context compaction. Re-invoke with `/iterate` after compaction to seamlessly resume.

## State Files

State lives in `.claude/iterate/` (gitignored). Two files:

### `.claude/iterate/state.json` — Machine-readable loop state

```json
{
  "task": "Original task description from user",
  "acceptance_criteria": ["list of what 'done' looks like — verifiable where possible"],
  "scope": ["files and areas being refined"],
  "iteration": 3,
  "max_iterations": 30,
  "status": "running",
  "last_snapshot": "Concise 2-3 sentence summary of current state for context recovery after compaction",
  "last_review_iteration": 0,
  "history": [
    {
      "iteration": 1,
      "action": "What was changed and why",
      "result": "Outcome — what improved",
      "verification": "Build/test/lint results if applicable",
      "assessment": "What still needs work, ranked by impact",
      "diminishing": false
    }
  ]
}
```

### `.claude/iterate/progress.md` — Human-readable progress log

Append-only markdown log. Each iteration adds a section:
```markdown
## Iteration N
**Action:** What was done
**Result:** What changed
**Assessment:** What still needs work
**Verdict:** continuing | diminishing | done
```

This file is also useful for the user to review progress at a glance.

## Workflow

### Phase 1: Starting a New Loop

Triggered when `$ARGUMENTS` is non-empty and no active loop exists (status != "running").

1. Parse `$ARGUMENTS` as the task description.
2. Explore the relevant codebase/specs to understand current state — read files, check structure,
   understand what already exists.
3. Define **acceptance criteria**: What does "done" look like? For code tasks, prefer machine-verifiable
   criteria (tests pass, builds clean, lint clean). For design/spec tasks, define what "complete" and
   "internally consistent" means as concretely as possible. For mixed tasks (spec + prototype), define
   criteria for both.
4. Identify **scope** — which files/areas will be touched. This can include specs, code, configs, and
   documentation.
5. Create `.claude/iterate/` directory if needed. Write `state.json` with `iteration: 0, status: "running"`.
   Initialize `progress.md` with task description and criteria.
6. Ensure `.claude/iterate/` is in `.gitignore` (add if missing).
7. Begin iteration 1 immediately.

### Phase 2: Each Iteration

1. **Read state** — always re-read `state.json` (never trust memory).
2. **Assess** — based on the history and last_snapshot, identify the single most impactful
   improvement remaining. Prioritize:
   - Correctness issues (bugs, errors, inconsistencies between specs)
   - Missing pieces (gaps in design, unaddressed requirements)
   - Structural improvements (clarity, organization, modularity)
   - Implementation progress (if building code: write, test, verify)
   - Performance improvements (slow pages, unnecessary re-renders, N+1 queries)
   - Polish (naming, formatting, edge cases)
3. **Dispatch subagent** — use the Agent tool to dispatch a subagent for this iteration.
   The subagent does the actual work (reading files, editing code, running tests). The
   orchestrator NEVER reads or edits scope files directly. Use the prompt template below,
   filling in the specifics for this iteration.
4. **Process result** — read the subagent's returned summary. Extract: what changed, verification
   results, and the subagent's assessment of what still needs work.
5. **Record** — update both `state.json` (append to history, update last_snapshot) and
   `progress.md` (append new section). Use the subagent's summary as the basis.
6. **Evaluate stopping condition** (see below).
7. **Checkpoint** — every 5 iterations, provide a brief progress summary to the user regardless
   of whether stopping criteria are met.
8. **Commit** — after each iteration that makes substantial changes (new files, significant edits,
   new features), commit the changes with a descriptive message. Use `git add` for specific
   changed files (not `git add -A`) and include the iteration number in the commit message.

### Code Review Protocol

**MANDATORY.** Code review is not optional — it gates all merges.

- **Every 5 iterations**, dispatch a `superpowers:code-reviewer` agent
  (using `subagent_type: "superpowers:code-reviewer"`) to perform a comprehensive review of
  all code added/modified since the last review. The review should check: correctness, security,
  type safety, error handling, architecture, performance, code quality, and test coverage gaps.
  Record the review findings in the iteration history and fix any CRITICAL issues in subsequent
  iterations.

- **Before any stopping condition is triggered** (done, diminishing, max reached), a final code
  review MUST be run even if fewer than 5 iterations have passed since the last review. The loop
  CANNOT end without a passing code review.

- **Code CANNOT be merged until the code reviewer signs off.** If the review finds CRITICAL
  or IMPORTANT issues, they must be fixed and re-reviewed before merge is allowed.

- **Iterative review loop** — a single review pass is NOT sufficient. After fixing issues
  found by the reviewer, dispatch the `superpowers:code-reviewer` agent AGAIN to verify the
  fixes are correct and no new issues were introduced. Continue this review→fix→re-review
  cycle until the reviewer explicitly signs off with no CRITICAL or IMPORTANT issues remaining.
  Only MINOR issues may be deferred. This prevents incorrect fixes from slipping through.

- **After a successful merge**, checkout main/master, pull latest, and create a new feature
  branch before continuing work. This simulates a real development workflow.

Track `last_review_iteration` in `state.json` to know when the next review is due.

### Subagent Prompt Template

When dispatching the iteration subagent, provide:

```
TASK: {original task description}
ACCEPTANCE CRITERIA: {acceptance criteria list}

ITERATION {N} INSTRUCTION: {specific, focused instruction for what to change this iteration}

SCOPE FILES: {list of files the subagent should read and potentially modify}

HISTORY (recent relevant entries only):
{curated history — what's been tried, what failed, what to avoid}

RULES:
- Make exactly ONE focused change. Do not boil the ocean.
- Verify your change: build/test/lint for code, consistency check for specs.
- If verification fails, fix or revert before returning.
- Do NOT modify files outside the scope listed above.

RETURN FORMAT:
- Action: What you changed and why (1-2 sentences)
- Result: What improved (1-2 sentences)
- Verification: Build/test/lint results, or consistency check outcome
- Assessment: What still needs the most work, ranked by impact (2-3 items)
- Diminishing: true/false — was this improvement trivial?
```

### Phase 3: Stopping Conditions

Check these in order:

1. **Max iterations reached** — if `iteration >= max_iterations`, stop. Present summary and ask
   user if they want to extend the cap.
2. **Acceptance criteria met** — if all defined criteria are satisfied (tests pass, builds clean,
   specs complete, etc.), set `status: "done"` and present the final summary.
3. **Diminishing returns** — if the last 3 iterations all have `diminishing: true` (only trivial
   improvements), recommend stopping. Let the user decide.
4. **Self-assessment** — if you genuinely believe the result is as refined as it can reasonably
   get, recommend stopping with justification.
5. **Otherwise** — continue to next iteration automatically. Only pause to ask the user at the
   5-iteration checkpoint or when a significant decision requires their input.

**IMPORTANT:** Before any stop (conditions 1-4), run the final code review if one hasn't been
done since the last set of changes. The loop does NOT end without a passing review.

### Phase 4: Resuming After Compaction

When `/iterate` is invoked with no arguments and `state.json` exists with `status: "running"`:

1. Read `state.json` completely — `last_snapshot` tells you where things stand, `history` shows
   what's been tried, `scope` tells you which files to re-read.
2. Read `progress.md` for the human-readable trail.
3. Re-read all files in `scope` to see their current on-disk state.
4. Continue with the next iteration number. Do NOT repeat previous work — check history to avoid
   re-trying failed approaches.

### Phase 5: Completion

When the loop ends (any stopping condition):

1. Run final code review (if not already done — see Code Review Protocol).
2. Set `status: "done"` in `state.json`.
3. Add a `## Summary` section to `progress.md` with:
   - Total iterations
   - Key changes made
   - Final state assessment
   - Any remaining opportunities (noted but not acted on)
4. Present the summary to the user.
5. The state files remain on disk for reference. User can start a new loop with `/iterate <new task>`,
   which will archive the old state to `.claude/iterate/archive/` before starting fresh.

## Rules

- **Orchestrator never touches scope files.** All file reading, editing, and verification happens
  inside subagents. The orchestrator only reads/writes state files (`state.json`, `progress.md`).
  This keeps the orchestrator's context lean and preserves the original task intent across the
  entire session.
- **Curate history for subagents.** Don't dump the entire history into each subagent prompt.
  Include only entries relevant to this iteration — especially failed approaches to avoid repeating.
- **ONE change per iteration.** Resist the urge to fix multiple things at once.
- **Always re-read before acting.** Never assume file contents from memory — they may have changed.
- **History is append-only.** Never modify or delete previous history entries during a run.
- **Revert bad changes.** If an iteration makes things worse, revert it immediately and record the
  failure in history. Try a different approach next iteration.
- **Honest assessments.** Mark iterations as `diminishing: true` when improvements are trivial.
  "Good enough" is a valid and desirable stopping point.
- **Verify when possible.** For code tasks, build/lint/test after every change. For spec tasks,
  check internal consistency.
- **Don't repeat yourself.** Before each iteration, scan history to avoid re-trying approaches that
  already failed or produced minimal improvement.
- **Respect the cap.** `max_iterations` exists to prevent runaway loops. Default is 30.
- **Autonomous by default.** Keep iterating without pausing for user input unless you hit a
  checkpoint (every 5 iterations), a stopping condition, or a decision that genuinely requires
  the user's judgment. The goal is hours of unattended progress.
- **Spec and code are equal.** This project involves both design specs and implementation. An
  iteration can refine a spec OR write code — both count as progress.
- **Code review gates merge.** NEVER merge without a passing code review. This is non-negotiable.
- **Feature branches for continued work.** After merge, always checkout main, pull, and create
  a fresh feature branch before continuing iterations.
