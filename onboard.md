---
name: onboard
description: Codebase onboarding guide — generates architecture overview, key flows, entry points, and getting-started instructions. Use /onboard [area] to run.
disable-model-invocation: false
---

# Onboard — Codebase Onboarding Guide

Generates a structured onboarding guide for new developers joining a project. Four
passes: architecture overview, key flows, entry points, and getting-started instructions.
Unlike `/doc` (which documents individual files or modules), `/onboard` explains how
the entire codebase fits together — the big picture a new developer needs before diving
into code.

## Output Format

```markdown
## Onboarding Guide — {project name}

**Project type:** {detected type(s)}
**Primary language:** {language}
**Framework:** {detected framework(s)}
**Package manager:** {npm | yarn | pnpm | cargo | pip | go modules | ...}

### Architecture Overview

**Pattern:** {monolith | monorepo | microservices | serverless | library | CLI}

```
{directory tree showing key directories with one-line descriptions}
```

**Key directories:**

| Directory | Purpose | Key files |
|-----------|---------|-----------|
| src/api/ | REST API route handlers | routes.ts, middleware.ts |
| src/models/ | Database models and schemas | user.ts, order.ts |
| src/services/ | Business logic layer | auth.ts, billing.ts |

**Data flow:**
{1-paragraph description of how data moves through the system}

### Key Flows

#### {Flow 1: e.g., "User Authentication"}
1. `src/api/auth.ts:login()` — receives credentials
2. `src/services/auth.ts:validate()` — checks against DB
3. `src/utils/jwt.ts:sign()` — creates token
4. Response with token + refresh token

#### {Flow 2: e.g., "Order Processing"}
1. ...

### Entry Points

| Entry Point | File | Purpose |
|------------|------|---------|
| Main server | src/index.ts | Express app bootstrap, middleware setup |
| CLI | src/cli.ts | Command-line interface |
| Worker | src/worker.ts | Background job processor |
| Tests | jest.config.ts | Test configuration and setup |

### Conventions

- **Naming:** {camelCase | snake_case | PascalCase} for {files | functions | classes}
- **File structure:** {convention description, e.g., "one component per file"}
- **Error handling:** {pattern used, e.g., "custom AppError class with error codes"}
- **Testing:** {framework and pattern, e.g., "Jest with co-located test files (*.test.ts)"}
- **Environment:** {how config is managed, e.g., ".env files with dotenv, validated at startup"}

### Getting Started

```bash
{step-by-step commands to clone, install, configure, and run the project}
```

**Prerequisites:** {required tools and versions}
**Environment setup:** {required env vars or config files}
**Common tasks:**

| Task | Command |
|------|---------|
| Run dev server | `npm run dev` |
| Run tests | `npm test` |
| Run linter | `npm run lint` |
| Build for production | `npm run build` |

### Where to Start

- **To understand the domain:** Read {file or directory}
- **To add a new API endpoint:** Follow the pattern in {file}
- **To add a new feature:** Start at {file}, then {file}
- **To fix a bug:** Check {file} for routing, {file} for business logic
```

## Workflow

### Step 1: Determine Scope

Parse `$ARGUMENTS`:

- **No arguments**: Generate a full project onboarding guide.
- **Area specified** (e.g., "auth", "api", "frontend"): Focus the guide on that area
  of the codebase. Still include enough project-level context for orientation.

### Step 2: Detect Project Type

Inspect the repo root for project indicators:

| File | Type | Framework clues |
|------|------|----------------|
| `package.json` | Node.js | express, next, react, vue, angular, nestjs |
| `Cargo.toml` | Rust | actix, axum, rocket, clap |
| `pyproject.toml` / `requirements.txt` | Python | django, flask, fastapi |
| `go.mod` | Go | gin, echo, fiber, cobra |
| `Gemfile` | Ruby | rails, sinatra |
| `pom.xml` / `build.gradle` | Java/Kotlin | spring, quarkus |
| `docker-compose.yml` | Multi-service | Container orchestration |

Also check for:
- Monorepo indicators (`lerna.json`, `pnpm-workspace.yaml`, `nx.json`, `turbo.json`)
- CI/CD configuration (`.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml`)
- Documentation (`README.md`, `docs/`, `CONTRIBUTING.md`)

### Step 3: Four-Pass Analysis

**Pass 1 — Architecture Overview**

Map the project structure:

1. **Read the directory tree** — identify top-level organization.
2. **Classify the architecture pattern** — monolith, monorepo, microservices, library,
   CLI, serverless, or hybrid.
3. **Identify key directories** — source code, tests, config, build output, documentation.
   For each, provide a one-line purpose description.
4. **Map the data flow** — how does a request or input move through the system? Trace
   from entry point through middleware/services to data layer and back.
5. **Identify external dependencies** — databases, message queues, external APIs,
   third-party services.

**Pass 2 — Key Flows**

Trace the 3-5 most important workflows through the codebase:

1. **Identify critical flows** — authentication, the primary CRUD operations, any
   background processing, the main user-facing feature.
2. **For each flow, trace the call chain** — list each function/method in order with
   file:line references. Show how data transforms at each step.
3. **Prioritize flows by importance** — authentication and the core business operation
   come first.

Skip trivial flows (health checks, static file serving) unless they illustrate an
important pattern.

**Pass 3 — Entry Points and Conventions**

1. **Find all entry points** — main server bootstrap, CLI commands, worker processes,
   test runner config, build scripts. List each with file and purpose.
2. **Detect conventions**:
   - Naming: read 10+ source files and determine the dominant naming pattern.
   - File structure: one-class-per-file, barrel exports, co-located tests, etc.
   - Error handling: custom error classes, error middleware, result types.
   - Testing: framework, file naming, test organization.
   - Config management: environment variables, config files, feature flags.

**Pass 4 — Getting Started**

1. **Read README.md** — extract any existing setup instructions.
2. **Read package manifest** — identify install command, available scripts.
3. **Check for required config** — `.env.example`, `.env.template`, or config docs.
4. **Build the getting-started sequence** — clone, install deps, configure env, run.
5. **List common developer tasks** — dev server, tests, lint, build, deploy.
6. **Identify "where to start" pointers** — which files should a new developer read
   first to understand the domain, the API, the data model.

### Step 4: Present

Output the full onboarding guide. Write for a developer who has never seen this
codebase. Assume they know the language and framework at a general level but know
nothing project-specific.

## Rules

- **Read-only.** This skill analyzes and reports. It never modifies code.
- **Write for a newcomer.** Avoid jargon specific to the project without explanation.
  Spell out acronyms on first use. Don't assume familiarity with the codebase.
- **Be concrete.** Reference specific files and functions, not abstract descriptions.
  "The auth flow starts in `src/api/auth.ts:login()`" is useful. "Authentication is
  handled by the auth module" is not.
- **Prioritize what matters.** A new developer needs to understand the 5 most important
  things, not all 50 things. Focus on core flows and architecture, not edge cases.
- **Don't invent information.** Only document what you can verify by reading the code.
  If you can't find setup instructions, say so rather than guessing.
- **Respect existing docs.** If the project has a good README or CONTRIBUTING guide,
  reference it rather than duplicating. Add what's missing, not what's already there.
- **Respect exclusions.** Never scan `node_modules`, `vendor`, `.git`, build output,
  lockfiles, or generated/vendored directories.
- **Scope adherence.** If the user provides an area, focus on that area but include
  enough project context for orientation.
- **One pass, complete output.** Deliver the full guide in a single response. Do not
  ask follow-up questions.
