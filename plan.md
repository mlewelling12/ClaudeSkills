---
name: plan
description: Creates a structured implementation plan for a feature. Use /plan <feature description> to generate, /plan to list existing plans.
disable-model-invocation: false
---

# Plan — Structured Implementation Planning

Breaks a feature or task into an actionable implementation plan with tasks, acceptance criteria,
dependencies, and file scope. Persists plans to `.claude/plans/` for reference during execution.

## State Files

Plans are stored in `.claude/plans/` (create if needed, add to `.gitignore`).

### `.claude/plans/{slug}.md` — The plan document

```markdown
# Plan: {feature name}

**Created:** {date}
**Status:** draft | active | completed
**Estimated tasks:** {count}

## Goal
{1-2 sentence description of what this feature achieves and why}

## Acceptance Criteria
- [ ] {verifiable criterion 1}
- [ ] {verifiable criterion 2}

## Tasks

### 1. {task name}
**Files:** {files to create or modify}
**Depends on:** none | {task numbers}
**Criteria:** {what "done" means for this task}

{Brief description of what to do — 2-4 sentences max}

### 2. {task name}
...

## Open Questions
- {decisions that need to be made before or during implementation}

## Out of Scope
- {things explicitly NOT included in this plan}
```

## Workflow

### Step 1: Understand the Request

Parse `$ARGUMENTS` as the feature description. Then:

1. **Explore the codebase** — read relevant files to understand the current architecture,
   patterns, and conventions. Don't plan in a vacuum.
2. **Identify the goal** — what does the user actually want? Restate it concisely.
3. **Identify constraints** — tech stack, existing patterns, testing conventions, deployment
   considerations.

### Step 2: Define Acceptance Criteria

Write 3-7 acceptance criteria. Each must be:
- **Verifiable** — you can objectively determine if it's met (test passes, endpoint returns
  expected response, UI renders correctly).
- **Specific** — "user can log in" not "authentication works."
- **Complete** — cover the happy path, key error cases, and edge cases.

### Step 3: Break into Tasks

Decompose the feature into sequential tasks. For each task:

1. **Name** — short, action-oriented (e.g., "Add user model and migration").
2. **Files** — list specific files that will be created or modified.
3. **Dependencies** — which tasks must complete first. Task 1 should have no dependencies.
4. **Criteria** — what "done" means for this individual task.
5. **Description** — brief implementation notes. Not a full spec — just enough to guide execution.

Guidelines for task breakdown:
- **3-10 tasks** for most features. Under 3 means the plan is too vague. Over 10 means the
  feature should be split.
- **Each task should be completable in one iteration** of the `/iterate` loop.
- **Order by dependency**, not by importance. Foundation first, polish last.
- **Include a verification task** at the end (run tests, manual smoke test, etc.).

### Step 4: Identify Risks

Add sections for:
- **Open Questions** — decisions that need user or team input before proceeding. Don't guess
  on ambiguous requirements — surface them.
- **Out of Scope** — things the user might expect but that aren't included. Being explicit
  prevents scope creep.

### Step 5: Persist and Present

1. Generate a slug from the feature name (e.g., "Add dark mode toggle" → `add-dark-mode-toggle`).
   If a plan with that slug already exists, append an incrementing number
   (e.g., `add-dark-mode-toggle-2`, `add-dark-mode-toggle-3`).
2. Create `.claude/plans/` directory if needed. Add to `.gitignore` if not present.
3. Write the plan to `.claude/plans/{slug}.md`.
4. Present the plan to the user for review.

## Resuming / Listing Plans

- `/plan` with no arguments: list all plans in `.claude/plans/` with their status.
- `/plan <slug>` where slug matches an existing plan: display that plan.
- `/plan <new feature>` where no matching plan exists: create a new plan.

## Rules

- **Read the codebase first.** A plan that ignores existing patterns and architecture is worse
  than no plan. Spend time understanding before prescribing.
- **Prefer machine-verifiable criteria.** "Tests pass" is better than "code is clean."
  "API returns 200 with expected payload" is better than "endpoint works."
- **Don't over-specify.** The plan guides execution — it doesn't replace it. Implementation
  details belong in the code, not the plan. Keep task descriptions to 2-4 sentences.
- **Surface uncertainty.** If requirements are ambiguous, add them to Open Questions instead
  of guessing. A wrong assumption baked into a plan wastes more time than asking upfront.
- **One plan per feature.** Don't combine unrelated features into a single plan. If the user
  requests multiple features, create separate plans.
- **Plans are living documents.** They can be updated as implementation reveals new information.
  Don't treat them as immutable specs.
- **Task count sanity check.** If you have more than 10 tasks, the feature is too large. Suggest
  splitting it into multiple plans.
