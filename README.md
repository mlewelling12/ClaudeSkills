# Claude Code Skills

A collection of slash-command skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Each `.md` file is a self-contained prompt that Claude executes as a structured workflow.

## Skill Catalog

### Slash Commands

| Skill | Command | Description |
|-------|---------|-------------|
| [audit](audit.md) | `/audit [scope]` | Codebase health audit — dependencies, complexity, tech debt, and security posture |
| [changelog](changelog.md) | `/changelog [range]` | Generates a formatted changelog from git history |
| [debug](debug.md) | `/debug <issue>` | Structured debugging — reproduces, hypothesizes, isolates, and fixes |
| [deps](deps.md) | `/deps <action> <pkg> [scope]` | Dependency impact analyzer — maps usage, assesses risk, and produces a migration checklist |
| [doc](doc.md) | `/doc [file\|module]` | Generates or updates documentation for a file, module, or project |
| [iterate](iterate.md) | `/iterate <task>` | Iterative refinement loop that survives context compaction |
| [plan](plan.md) | `/plan <feature>` | Creates a structured implementation plan for a feature |
| [preflight](preflight.md) | `/preflight` | Pre-merge checklist — build, lint, tests, and common issue checks |
| [refactor](refactor.md) | `/refactor <target>` | Guided refactoring with safety checks and incremental changes |
| [review](review.md) | `/review [branch]` | Structured 4-pass code review of staged or branch changes |
| [standup](standup.md) | `/standup` | Generates a daily standup summary from recent git activity |
| [test](test.md) | `/test [file\|function]` | Scaffolds test cases with framework detection |

### Utilities

| File | Description |
|------|-------------|
| [statusline.sh](statusline.sh) | Bash script for Claude Code's status bar — shows git branch, token count, and session info. Configured via `settings.json`, not invoked as a slash command. |

## Usage Examples

**Generate a standup summary:**
```
/standup
```
Claude reads the last 24 hours of git activity and produces a formatted summary with completed work, in-progress items, and blockers.

**Review changes before merging:**
```
/review feature/auth-flow
```
Runs a 4-pass review (correctness, security, performance, maintainability) on the diff between `main` and `feature/auth-flow`.

**Plan and iterate on a feature:**
```
/plan Add rate limiting to the API
/iterate Implement the rate limiting plan
```
`/plan` creates a structured task breakdown saved to `.claude/plans/`. `/iterate` picks up from where it left off, making one focused change per iteration with verification.

## Installation

### Install all skills

```bash
git clone --depth 1 https://github.com/mlewelling12/ClaudeSkills.git /tmp/claude-skills
mkdir -p .claude/commands
cp /tmp/claude-skills/*.md .claude/commands/
rm -rf /tmp/claude-skills
```

### Install a single skill

```bash
mkdir -p .claude/commands
curl -o .claude/commands/review.md https://raw.githubusercontent.com/mlewelling12/ClaudeSkills/main/review.md
```

### Install the status line

Copy `statusline.sh` to a stable location and reference it in your Claude Code `settings.json`:

```bash
mkdir -p ~/.claude
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/mlewelling12/ClaudeSkills/main/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add to `.claude/settings.json`:

```json
{
  "statusLine": "~/.claude/statusline.sh"
}
```

## Contributing

### Format

Every skill file must have:

1. **YAML frontmatter** — `name`, `description`, and `disable-model-invocation` fields
2. **Structured workflow phases** — numbered steps with clear actions
3. **Output format section** — defines what Claude should produce
4. **Rules section** — constraints and guardrails for execution

### Naming conventions

- Skill files: `lowercase.md` (e.g., `review.md`, `debug.md`)
- Utility scripts: `lowercase.sh` (e.g., `statusline.sh`)
- Skill names match filenames without extension

### Quality bar

- **State directories** (`.claude/plans/`, `.claude/debug/`, etc.) must be created on first use
- **`.gitignore` handling** — any skill that creates state directories must add them to `.gitignore` if not present
- **Slug collisions** — if generating slugs for filenames, append `-2`, `-3`, etc. when a file already exists
- **Read-only by default** — skills that only analyze code should not modify files unless explicitly requested

### Submitting

1. Fork the repo
2. Create a feature branch (`feature/add-my-skill`)
3. Add your skill file — do not modify existing skills
4. Open a PR with a description of what the skill does and example usage
