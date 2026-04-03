# Implementation Plan: CL-CC Core Runtime Reconstruction

**Branch**: `001-cl-cc-core` | **Date**: 2026-04-01 | **Spec**: `/specs/001-cl-cc-core/spec.md`
**Input**: Feature specification from `/specs/001-cl-cc-core/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

以纯 Common Lisp 为唯一产品运行时，先重建 CL-CC 的最小可用核心：CLI 启动与命令分发、工具定义与执行循环、权限边界、会话状态持久化，以及基于 `cc-source/` 研究资料的兼容性夹具与回归基线。技术路线采用单仓单系统的 Common Lisp CLI 项目结构，先交付本地单用户运行时，再逐步扩大到更复杂的上下文、记忆和协作能力。

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Common Lisp, first-class target SBCL 2.4.x with portability-conscious package boundaries  
**Primary Dependencies**: ASDF/UIOP, FiveAM, local project packages for command routing, session serialization, compatibility fixtures, and permission policies  
**Storage**: Local filesystem snapshots for session state, fixture inputs, and golden-case outputs  
**Testing**: FiveAM unit tests, scripted integration scenarios, contract/golden regression comparisons  
**Target Platform**: Local developer CLI on Windows first, with planned Linux and macOS compatibility
**Project Type**: Common Lisp CLI runtime with reusable core library modules  
**Performance Goals**: `--help` under 500 ms on a warm local run, cold start under 2 s on the reference machine, scripted core session under 5 s for baseline fixtures  
**Constraints**: Pure Common Lisp runtime only, no foreign-language product dependencies, offline-capable local validation, explicit permission gates, Chinese-facing collaboration output, auditable debug logs  
**Scale/Scope**: Single-user local runtime, first three user stories only, core startup/dispatch/tool-loop/session/permission path before advanced remote or multi-agent features

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Runtime logic remains entirely in Common Lisp; non-Common Lisp assets are limited to study materials, documentation, and local Speckit automation.
- [x] The reference behaviors under study are explicitly limited to startup assembly, command routing, tool execution, QueryEngine-like request advancement, permission boundaries, session persistence, and compatibility fixture extraction from `cc-source/`.
- [x] Planned user-visible contracts cover CLI commands, tool definitions, session-state persistence, and permission-decision output; advanced provider routing, voice, remote bridge, and full UI flows are intentionally deferred.
- [x] Testing strategy is test-first and split into unit, integration, and contract/golden regression layers before implementation begins.
- [x] Security boundaries, structured debug output, performance budget, version impact, and Chinese-language collaboration expectations are explicitly carried into this plan.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
cl-cc.asd
src/
├── cli/
├── core/
├── models/
├── session/
├── services/
├── tools/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: Select Option 1 as a single Common Lisp project rooted at the canonical ASDF entry `cl-cc.asd`. Runtime entrypoints live under `src/cli/`; reusable request, command, and execution abstractions live under `src/core/`; persistent state and recovery logic live under `src/session/`; user-visible tools live under `src/tools/`; data and policy records live under `src/models/` and `src/services/`; regression fixtures and test layers live under `tests/unit/`, `tests/integration/`, and `tests/contract/`. `project.asd` is retained only as a compatibility shim for older local commands.

## Complexity Tracking

No constitution violations are currently expected. The first implementation slice stays within the mandated pure-Common-Lisp, contract-first, and test-first boundaries.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
