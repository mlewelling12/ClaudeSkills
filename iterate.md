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
2. **Re-read scope files** — always re-read the actual files on disk. Content may have changed.
3. **Assess** — identify the single most impactful improvement remaining. Prioritize:
   - Correctness issues (bugs, errors, inconsistencies between specs)
   - Missing pieces (gaps in design, unaddressed requirements)
   - Structural improvements (clarity, organization, modularity)
   - Implementation progress (if building code: write, test, verify)
   - Polish (naming, formatting, edge cases)
4. **Act** — make exactly ONE focused change. Small steps compound. Do not boil the ocean.
   - For spec work: refine one section, resolve one inconsistency, flesh out one design
   - For code work: implement one component, fix one bug, add one test
   - For mixed: alternate between spec and code as needed
5. **Verify** — if the task involves code:
   - Build/compile to catch errors
   - Run relevant tests
   - Lint/format
   - If verification fails, fix or revert before proceeding
   For spec work: check internal consistency, ensure references are valid, verify no contradictions.
6. **Record** — update both `state.json` (append to history, update last_snapshot) and
   `progress.md` (append new section).
7. **Evaluate stopping condition** (see below).
8. **Checkpoint** — every 5 iterations, provide a brief progress summary to the user regardless
   of whether stopping criteria are met.

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

1. Set `status: "done"` in `state.json`.
2. Add a `## Summary` section to `progress.md` with:
   - Total iterations
   - Key changes made
   - Final state assessment
   - Any remaining opportunities (noted but not acted on)
3. Present the summary to the user.
4. The state files remain on disk for reference. User can start a new loop with `/iterate <new task>`,
   which will archive the old state to `.claude/iterate/archive/` before starting fresh.

## Rules

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
