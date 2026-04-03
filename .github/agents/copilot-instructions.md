# cl-cc Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-01

## Active Technologies

- Common Lisp, first-class target SBCL 2.4.x with portability-conscious package boundaries + ASDF/UIOP, FiveAM, local project packages for command routing, session serialization, compatibility fixtures, and permission policies (001-cl-cc-core)

## Project Structure

```text
cl-cc.asd
src/
	cli/
	core/
	models/
	session/
	services/
	tools/
	lib/
tests/
	unit/
	integration/
	contract/
specs/
	001-cl-cc-core/
```

## Commands

- Load the ASDF system in SBCL: `sbcl --load cl-cc.asd`
- Load and run the CLI entrypoint during development: `sbcl --load cl-cc.asd --eval "(asdf:load-system :cl-cc)"`
- Run the full test suite: `sbcl --noinform --non-interactive --load cl-cc.asd --eval "(asdf:test-system :cl-cc)" --quit`
- Run focused tests while iterating: load the system in SBCL and invoke the relevant FiveAM suite manually
- Keep fixture and regression runs local and reproducible; prefer scripted invocations over ad hoc REPL state

## Code Style

- Runtime logic, contract adapters, state handling, and tests should be written in Common Lisp.
- Do not introduce other languages as product runtime dependencies. If a capability is missing, prefer a Common Lisp implementation in-repo.
- Keep package boundaries explicit and narrow: CLI in `src/cli/`, execution flow in `src/core/`, session persistence in `src/session/`, tool definitions in `src/tools/`, shared records in `src/models/`.
- Favor portable Common Lisp where practical; isolate SBCL-specific behavior behind small internal interfaces.
- Define contracts before implementation: CLI commands, tool schemas, permission outputs, and session-state formats should remain explicit and testable.
- Follow test-first workflow: write failing FiveAM unit tests, integration scenarios, and contract/golden regression tests before implementation.
- Keep debug output structured and auditable. Permission allow/deny/error paths must be deterministic and easy to inspect.
- When studying `cc-source/`, extract behavior and invariants rather than copying implementation structure or code.

## Recent Changes

- 001-cl-cc-core: Added Common Lisp, first-class target SBCL 2.4.x with portability-conscious package boundaries + ASDF/UIOP, FiveAM, local project packages for command routing, session serialization, compatibility fixtures, and permission policies

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
