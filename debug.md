---
name: debug
description: Structured debugging workflow — reproduces, hypothesizes, isolates, and fixes. Use /debug <issue description> to start.
disable-model-invocation: false
---

# Debug — Structured Debugging Workflow

Systematically debugs an issue by reproducing it, forming hypotheses, isolating the root cause,
and proposing a fix. Tracks debugging state to avoid going in circles.

## State Files

Debug sessions are tracked in `.claude/debug/` (create if needed, add to `.gitignore`).

### `.claude/debug/{slug}.md` — Session log

````markdown
# Debug: {issue description}

**Started:** {date}
**Status:** investigating | root-cause-found | fixed | abandoned
**Root cause:** {filled in when found}

## Reproduction
{steps to reproduce, observed vs expected behavior}

## Hypotheses

### H1: {hypothesis}
**Status:** confirmed | rejected | untested
**Evidence:** {what was checked and what it showed}

### H2: {hypothesis}
...

## Investigation Log
1. {action taken} → {result observed}
2. {action taken} → {result observed}

## Fix
{description of the fix, if applied}
````

## Workflow

### Step 1: Understand the Issue

Parse `$ARGUMENTS` as the issue description. Then:

1. **Clarify the symptom** — what is actually happening? Error message, wrong output,
   crash, hang, or unexpected behavior?
2. **Identify expected behavior** — what should happen instead?
3. **Determine scope** — which part of the codebase is likely involved? Search for relevant
   files, functions, and error messages.

If `$ARGUMENTS` includes an error message, search the codebase for that exact string to
find where it originates.

### Step 2: Reproduce

Attempt to reproduce the issue:

1. **Find or create a reproduction** — look for an existing test that triggers the bug, or
   identify the minimal steps to reproduce.
2. **Confirm the symptom** — run the reproduction and verify the observed behavior matches
   the reported issue.
3. **Record the reproduction** — document exact steps so it can be re-verified after the fix.

If the issue cannot be reproduced, document what was tried and check for environment-specific
factors (OS, versions, configuration, race conditions).

### Step 3: Form Hypotheses

Based on the symptom and code analysis, generate 2-5 ranked hypotheses:

1. **Start with the most likely cause** — common patterns:
   - Off-by-one errors, null/undefined access, wrong variable referenced
   - Stale state, missing cache invalidation, race conditions
   - Incorrect assumptions about input format or types
   - Missing error handling, swallowed exceptions
   - Dependency version mismatch, API contract change
2. **Each hypothesis must be testable** — specify what to check and what result would
   confirm or reject it.
3. **Rank by likelihood** — investigate the most probable cause first.

### Step 4: Investigate

For each hypothesis, starting with the highest-ranked:

1. **Instrument** — add targeted reads to relevant code. Read the specific functions,
   check variable states, trace the execution path.
2. **Test** — run the reproduction or a targeted check to gather evidence.
3. **Evaluate** — does the evidence support or reject this hypothesis?
4. **Record** — log what was checked and what was found. This prevents re-investigating
   the same thing.

If a hypothesis is rejected, move to the next one. If all hypotheses are rejected, form
new ones based on what was learned.

**Circuit breaker:** If after 5 investigation steps no root cause is found, stop and
summarize what's known, what's been ruled out, and suggest next steps (including asking
the user for more context).

### Step 5: Isolate Root Cause

When evidence confirms a hypothesis:

1. **Pinpoint the exact location** — file, function, and line where the bug originates.
2. **Explain the causal chain** — how does the bug at that location produce the observed
   symptom? Trace the path from root cause to user-visible behavior.
3. **Verify isolation** — confirm that this is the root cause, not a secondary symptom.
   The fix should address the cause, not paper over the effect.

### Step 6: Propose Fix

1. **Describe the fix** — what needs to change and why.
2. **Show the code change** — present the specific edit(s) needed.
3. **Assess risk** — could the fix break anything else? What other code depends on the
   changed behavior?
4. **Suggest a verification step** — how to confirm the fix works (run a test, reproduce
   the original steps).

Do NOT apply the fix automatically. Present it for user approval. If the user asks you to
apply it, make the change and run verification.

### Step 7: Persist Session

1. Generate a slug from the issue description.
2. Write the debug session to `.claude/debug/{slug}.md`.
3. Present the summary to the user.

## Rules

- **Reproduce first, hypothesize second.** Don't guess at causes before confirming the symptom.
  A bug you can't reproduce is a bug you can't verify you've fixed.
- **Read the code, don't assume.** Always read the actual source before forming hypotheses.
  Bugs live in what the code does, not what you think it does.
- **One hypothesis at a time.** Investigate hypotheses sequentially, not in parallel. Mixing
  investigations leads to confused conclusions.
- **Record everything.** Every action and result goes in the investigation log. If you've
  checked something, write it down so you don't check it again.
- **Don't fix symptoms.** Adding a null check around a crash is a band-aid, not a fix. Find
  why the value is null in the first place.
- **Five-step circuit breaker.** If 5 investigation steps yield no root cause, stop and
  regroup. Don't spiral into increasingly unlikely hypotheses.
- **Don't modify code during investigation.** Read and analyze only. The fix comes after
  the root cause is confirmed, not during the search.
- **Check history first.** Before starting, check `.claude/debug/` for previous sessions
  on the same issue. Don't repeat failed investigations.
- **Propose, don't apply.** Present the fix for user approval before making changes. The
  user may have context that changes the right approach.
