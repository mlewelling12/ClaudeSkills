# Claude Code Skills

A collection of reusable [Claude Code](https://docs.anthropic.com/en/docs/claude-code) custom slash command skills for software development workflows.

## Skill Catalog

| Skill | Command | Description |
|-------|---------|-------------|
| [changelog](changelog.md) | `/changelog [range]` | Generates a formatted changelog from git history. Defaults to changes since the last tag. |
| [debug](debug.md) | `/debug <issue>` | Structured debugging workflow — reproduces, hypothesizes, isolates, and fixes. Tracks state to avoid going in circles. |
| [doc](doc.md) | `/doc [file\|module]` | Generates or updates documentation for a file, module, or project. Read-only by default. |
| [iterate](iterate.md) | `/iterate <task>` | Iterative refinement loop that survives context compaction. Externalizes state to disk for multi-step tasks. |
| [plan](plan.md) | `/plan <feature>` | Creates a structured implementation plan for a feature, saved as a trackable markdown file. |
| [preflight](preflight.md) | `/preflight` | Pre-merge checklist — runs build, lint, tests, and checks for secrets, large files, and common issues. |
| [refactor](refactor.md) | `/refactor <target>` | Guided refactoring with safety checks — runs tests before/after, applies changes incrementally, reverts on failure. |
| [review](review.md) | `/review [branch]` | Structured 4-pass code review (correctness, security, performance, maintainability) with severity ratings. |
| [standup](standup.md) | `/standup` | Generates a daily standup summary from recent git activity, open branches, and WIP changes. |
| [test](test.md) | `/test [file\|function]` | Scaffolds test cases for a file or function. Detects the testing framework and generates meaningful tests. |

**Utility:**

| File | Description |
|------|-------------|
| [statusline.sh](statusline.sh) | Bash script for a colored Claude Code status bar showing model, tokens, cost, and git state. Not a slash command — configured via `settings.json`. |

## Usage Examples

**Generate a standup summary:**
```
/standup
```
Outputs what you did yesterday, what's in progress, and any blockers — all derived from git history.

**Review your changes before committing:**
```
/review
```
Runs a 4-pass review on your working changes, flagging issues as CRITICAL, IMPORTANT, or MINOR.

**Plan a new feature, then iterate on it:**
```
/plan Add user authentication with OAuth2
/iterate Implement the auth plan from .claude/plans/add-user-auth.md
```

## Installation

1. Clone this repo (or copy individual `.md` files) into your project's `.claude/commands/` directory:

   ```bash
   # All skills
   git clone https://github.com/mlewelling12/ClaudeSkills.git .claude/commands/

   # Or just the ones you need
   curl -O https://raw.githubusercontent.com/mlewelling12/ClaudeSkills/main/review.md
   mv review.md .claude/commands/
   ```

2. Skills are immediately available as `/command-name` in Claude Code.

3. For `statusline.sh`, add to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "command": "bash /path/to/statusline.sh"
     }
   }
   ```

## Contributing

### Skill format

Every skill is a single `.md` file with:

1. **YAML frontmatter** — `name`, `description`, and `disable-model-invocation: false`:
   ```yaml
   ---
   name: skill-name
   description: One-line description. Include the command syntax (e.g., "Use /skill-name <arg> to do X").
   disable-model-invocation: false
   ---
   ```

2. **Structured body** — Use clear markdown sections. Most skills follow this pattern:
   - Title and overview
   - Output format (what the skill produces)
   - Workflow steps (numbered, specific, actionable)
   - Rules / constraints

### Quality bar

- Instructions must be specific and actionable — "List 3 bugs" not "find issues"
- Every workflow step should be unambiguous to an LLM
- Skills that create state directories (e.g., `.claude/debug/`) must include:
  - Directory creation step
  - `.gitignore` handling
  - Slug collision handling (append `-2`, `-3`, etc.)
- Keep token cost in mind — be concise without losing clarity
- Test your skill in Claude Code before submitting

### Naming conventions

- File name matches the `name` field in frontmatter (e.g., `review.md` has `name: review`)
- Use lowercase, single-word names where possible
- Use hyphens for multi-word names (e.g., `code-review.md`)

### Submitting

1. Create a feature branch: `git checkout -b feature/add-skill-name`
2. Add your `.md` file to the repo root — do not modify or delete existing files
3. Open a PR with a description of what the skill does and example usage
