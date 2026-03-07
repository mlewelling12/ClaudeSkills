---
name: test
description: Scaffolds test cases for a file or function. Use /test [file|function] to generate tests.
disable-model-invocation: false
---

# Test — Test Case Scaffolding

Detects the testing framework in use, reads the target code, and generates meaningful test cases
covering happy path, edge cases, and error conditions. Produces ready-to-run test files.

## Output Format

The format adapts to the detected framework (Jest, Vitest, pytest, Go testing, Rust #[test], etc.).
Example for JavaScript/TypeScript:

````javascript
// Test file: {test file path}

describe('{module or function name}', () => {
  // Happy path
  it('should {expected behavior}', () => {
    // Arrange
    // Act
    // Assert
  });

  // Edge cases
  it('should handle {edge case}', () => { ... });

  // Error conditions
  it('should throw when {error condition}', () => { ... });
});
````

## Workflow

### Step 1: Detect Testing Framework

Inspect the project to determine the test setup:

| File | Framework | Test runner | Assertion style |
|------|-----------|-------------|-----------------|
| `jest.config.*` or `"jest"` in package.json | Jest | `npx jest` | `expect().toBe()` |
| `vitest.config.*` or `"vitest"` in package.json | Vitest | `npx vitest` | `expect().toBe()` |
| `pytest.ini`, `pyproject.toml` with `[tool.pytest]` | pytest | `pytest` | `assert` |
| `*_test.go` files present | Go testing | `go test` | `t.Errorf()` |
| `Cargo.toml` with `[dev-dependencies]` | Rust #[test] | `cargo test` | `assert_eq!()` |
| `*.test.ts` or `*.spec.ts` existing | Infer from imports | Check imports | Match existing |

If no framework is detected, check for existing test files and match their patterns. If none
exist, recommend a framework appropriate for the language and ask before proceeding.

### Step 2: Read Target Code

Based on `$ARGUMENTS`:

- **File path**: Read the entire file. Identify all exported/public functions, classes, and methods.
- **Function name**: Search the codebase for the function definition. Read its file and any
  types it depends on.
- **No arguments**: Error — inform the user that a target is required.
  ```
  Usage: /test <file|function>
  Example: /test src/utils/validate.ts
  ```

For the target code, extract:
1. **Function signatures** — names, parameters, return types.
2. **Dependencies** — what the function imports or calls (for mocking decisions).
3. **Branching logic** — if/else, switch, try/catch (each branch needs a test).
4. **Edge cases** — null/undefined handling, empty inputs, boundary values.
5. **Error conditions** — when does it throw or return errors?

### Step 3: Identify Existing Tests

Check if tests already exist for the target:
- Look for `*.test.*`, `*.spec.*`, or `test_*` files matching the target.
- If tests exist, read them. Generate only **new** tests for untested code paths.
- Never duplicate existing test cases.

### Step 4: Generate Test Cases

For each function/method, generate tests in three categories:

**Happy Path (required)**
- Call the function with valid, typical inputs.
- Assert the expected return value or side effect.
- If the function has multiple valid input patterns, test each.

**Edge Cases (required)**
- Empty inputs (empty string, empty array, zero, null/undefined).
- Boundary values (min/max integers, very long strings, single-element arrays).
- Type coercion traps (if the language allows them).

**Error Conditions (when applicable)**
- Invalid inputs that should throw or return errors.
- Missing required parameters.
- Network/IO failures (if the function does external calls — mock these).

For each test case, use the Arrange-Act-Assert pattern:
1. **Arrange** — set up inputs, mocks, and preconditions.
2. **Act** — call the function under test.
3. **Assert** — verify the result or side effect.

### Step 5: Handle Dependencies

For functions with external dependencies (database, API, file system):

1. **Identify what to mock** — external calls, not internal logic.
2. **Use the project's mocking pattern** — if existing tests use `jest.mock()`, use that.
   If they use dependency injection, follow that pattern.
3. **Keep mocks minimal** — only mock what's necessary. Over-mocking makes tests brittle.

### Step 6: Determine Test File Location

Follow the project's convention:
- If tests live in `__tests__/` directories, put the new test there.
- If tests live alongside source files as `*.test.*`, do that.
- If tests live in a top-level `test/` or `tests/` directory, use that.
- Match the naming convention of existing test files exactly.

### Step 7: Present

Output the complete test file. If tests already exist for the target, output only the new
test cases to be added, clearly marked with where they should be inserted.

## Rules

- **Match existing patterns exactly.** If the project uses `describe`/`it`, use that. If it
  uses `test()`, use that. If it uses `snake_case` test names, do that. Consistency matters
  more than preference.
- **Every test must be runnable.** No placeholder assertions, no `TODO` comments, no
  `skip`/`pending` tests. Each test should pass or fail meaningfully when executed.
- **Don't test implementation details.** Test behavior, not internal state. If refactoring
  the function's internals would break the test, the test is too coupled.
- **Don't test the framework.** Don't assert that `Array.push` works. Test your code's logic.
- **Name tests descriptively.** The test name should describe the scenario and expected outcome:
  "returns empty array when input is empty" not "test 1."
- **One assertion per test when practical.** Multiple assertions are acceptable when testing
  related properties of a single operation, but each test should verify one behavior.
- **Mock at the boundary, not everywhere.** Only mock external dependencies (APIs, databases,
  file system). Don't mock internal functions unless necessary for isolation.
- **Include setup/teardown if needed.** If tests need shared state, use `beforeEach`/`afterEach`
  (or the framework's equivalent). Clean up after tests.
- **Don't write tests for trivial code.** Simple getters, single-line wrappers, and type-only
  re-exports don't need tests. Focus on logic.
