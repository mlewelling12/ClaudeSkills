---
name: doc
description: Generates or updates documentation for a file, module, or project. Use /doc [file|module] to generate docs, /doc to document the whole project.
disable-model-invocation: false
---

# Doc — Documentation Generator

Reads code structure, infers purpose, and produces markdown documentation with API signatures,
usage examples, and parameter descriptions. Works on a single file, a module/directory, or the
entire project.

## Output Format

````markdown
# {Module or File Name}

{1-2 sentence description of what this code does}

## Installation / Setup
{only if project-level docs}

## API Reference

### `functionName(param1: type, param2: type): returnType`

{Brief description of what it does}

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| param1 | string | yes | {description} |
| param2 | number | no | {description, default value} |

**Returns:** `type` — {description}

**Example:**
```{language}
{usage example}
```

**Throws:** {error conditions, if any}

### `anotherFunction(...)`
...

## Types / Interfaces

### `TypeName`
{description and field listing}

## Constants / Configuration
{exported constants with descriptions}
````

## Workflow

### Step 1: Determine Scope

Based on `$ARGUMENTS`:

- **No arguments**: Document the entire project. Read the project root for entry points,
  package manifest, and directory structure. Produce a top-level README-style doc.

- **File path provided**: Document that single file. Read the full file.

- **Module/directory provided**: Document all public exports from that directory. Read
  the index/barrel file first, then referenced files.

### Step 2: Read and Analyze

For each file in scope:

1. **Identify exports** — functions, classes, types, constants that are public-facing.
   Skip internal/private helpers unless they are complex enough to warrant documentation.
2. **Extract signatures** — function names, parameter names and types, return types.
   Use type annotations if present; infer from usage if not.
3. **Read JSDoc/docstrings** — if existing documentation exists, use it as a starting point.
   Improve clarity but don't contradict intentional descriptions.
4. **Identify usage patterns** — look for how exports are used within the codebase (imports,
   call sites) to inform example code.

### Step 3: Generate Documentation

For each export, produce:

1. **Signature** — full function/class signature with types.
2. **Description** — what it does, in 1-3 sentences. Focus on *what* and *why*, not *how*.
3. **Parameters** — table with name, type, required/optional, description, and default value.
4. **Return value** — type and description.
5. **Example** — a realistic usage example. Prefer examples drawn from actual call sites in
   the codebase over fabricated ones.
6. **Throws/Errors** — document error conditions if the function throws or returns errors.
7. **Side effects** — note if the function modifies external state (writes files, mutates
   globals, makes network calls).

### Step 4: Structure the Output

Organize documentation by category:

1. **Overview** — module purpose and high-level description.
2. **API Reference** — functions and methods, ordered by importance or logical grouping
   (not alphabetical unless no natural grouping exists).
3. **Types/Interfaces** — type definitions and interfaces.
4. **Constants** — exported configuration or constant values.
5. **Examples** — if the module is complex, add a "Getting Started" section with a
   multi-step example before the API reference.

### Step 5: Present

Output the documentation as a single markdown document. If documenting a full project,
structure it as a README. If documenting a single file or module, structure it as API docs.

## Rules

- **Read-only by default.** Output documentation to the chat. Do not write files unless the
  user explicitly asks to save (e.g., "write a README" or "update the docs").
- **Document the public API, not internals.** Private functions, helper utilities, and
  implementation details should only be documented if they are complex and non-obvious.
- **Infer, don't invent.** If a parameter's purpose isn't clear from the code, say so rather
  than guessing. Use "purpose unclear from code" instead of a wrong description.
- **Match the project's language.** If the code is TypeScript, use TypeScript syntax in
  signatures and examples. If Python, use Python. Don't mix languages.
- **Keep examples realistic.** Use actual values and patterns from the codebase, not
  placeholder strings like "foo" and "bar."
- **Don't document the obvious.** A function called `getUserById(id: string)` doesn't need
  a description that says "Gets a user by their ID." Focus on non-obvious behavior: caching,
  side effects, error conditions, edge cases.
- **Respect existing docs.** If the code already has good docstrings or JSDoc, incorporate
  them. Don't discard intentional documentation.
- **One pass, complete output.** Deliver the full documentation in a single response. Don't
  ask follow-up questions unless the scope is genuinely ambiguous.
