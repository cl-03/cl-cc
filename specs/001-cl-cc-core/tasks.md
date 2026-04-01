# Tasks: CL-CC Core Runtime Reconstruction

**Input**: 设计文档来自 `/specs/001-cl-cc-core/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`

**Tests**: 宪章要求测试先行。每个用户故事都必须先写失败中的测试，再进入实现。

**Organization**: 任务按阶段和用户故事分组，确保每个故事都能独立实现、独立验证、独立演示。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可并行执行（不同文件、无直接依赖）
- **[Story]**: 任务所属用户故事，如 `US1`、`US2`、`US3`
- 所有描述都包含明确文件路径，便于直接落地

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 初始化纯 Common Lisp 项目骨架、ASDF 系统与测试入口。

- [x] T001 创建 `project.asd`、`src/`、`tests/`、`fixtures/` 目录骨架，并补齐 `src/package.lisp` 与 `tests/test-package.lisp`
- [x] T002 建立 CLI 启动入口与测试启动入口：`src/cli/main.lisp`、`src/cli/argv.lisp`、`tests/run-tests.lisp`
- [x] T003 [P] 建立夹具与快照目录约定及基础说明：`fixtures/contracts/`、`fixtures/sessions/`、`fixtures/golden/`、`docs/compatibility/README.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 建立所有用户故事共享的核心模型、基础服务与边界约束。

**⚠️ CRITICAL**: 这一阶段完成前，不得开始任何用户故事实现。

- [x] T004 定义共享 package/export 边界：更新 `src/package.lisp`，并创建 `src/lib/package.lisp`、`src/core/package.lisp`、`src/models/package.lisp`、`src/session/package.lisp`、`src/services/package.lisp`、`src/tools/package.lisp`
- [x] T005 [P] 实现核心数据模型：`src/models/command-definition.lisp`、`src/models/tool-definition.lisp`、`src/models/session-state.lisp`、`src/models/execution-cycle.lisp`、`src/models/permission-decision.lisp`、`src/models/compatibility-fixture.lisp`
- [x] T006 [P] 实现统一结果、错误与调试输出基础：`src/lib/result.lisp`、`src/lib/errors.lisp`、`src/lib/debug-log.lisp`
- [x] T007 [P] 实现会话序列化与快照仓储抽象：`src/session/serializer.lisp`、`src/session/store.lisp`
- [x] T008 [P] 实现权限策略抽象与审计记录骨架：`src/services/permission-policy.lisp`、`src/services/permission-audit.lisp`
- [x] T009 实现命令注册表与执行上下文骨架：`src/core/command-registry.lisp`、`src/core/execution-context.lisp`
- [x] T010 建立兼容性夹具加载与 golden 比较基础设施：`src/services/fixture-loader.lisp`、`src/services/golden-regression.lisp`、`tests/contract/fixture-helpers.lisp`
- [x] T011 编写 Foundational 层单元测试：`tests/unit/models-test.lisp`、`tests/unit/session-store-test.lisp`、`tests/unit/permission-policy-test.lisp`

**Checkpoint**: 核心模型、快照抽象、权限边界、夹具装载能力全部就绪，用户故事可以开始。

---

## Phase 3: User Story 1 - 建立可运行的核心 CLI 骨架 (Priority: P1) 🎯 MVP

**Goal**: 交付可启动、可显示帮助、可创建最小会话并安全退出的纯 Common Lisp CLI。

**Independent Test**: 运行 `cl-cc --help` 与 `cl-cc session start`，验证帮助输出、最小会话创建、统一退出语义和调试输出。

### Tests for User Story 1 ⚠️

> **NOTE: 先写这些测试，并确认它们在实现前失败。**

- [x] T012 [P] [US1] 编写 CLI 帮助契约测试：`tests/contract/cli-help-contract-test.lisp`
- [x] T013 [P] [US1] 编写最小会话启动集成测试：`tests/integration/session-start-test.lisp`
- [x] T014 [P] [US1] 编写 CLI 参数解析单元测试：`tests/unit/argv-parser-test.lisp`

### Implementation for User Story 1

- [x] T015 [P] [US1] 实现 CLI 参数解析与帮助文本渲染：`src/cli/argv.lisp`、`src/cli/help-command.lisp`
- [x] T016 [US1] 实现 CLI 主入口与退出码映射：`src/cli/main.lisp`
- [x] T017 [P] [US1] 实现最小会话初始化服务：`src/services/session-service.lisp`
- [x] T018 [US1] 实现 `session start` 命令处理与空执行循环：`src/cli/session-command.lisp`、`src/core/session-loop.lisp`
- [x] T019 [US1] 为 CLI 骨架补充统一错误处理和调试输出接线：更新 `src/cli/main.lisp`、`src/core/session-loop.lisp`

**Checkpoint**: `--help` 与 `session start` 可独立工作，CLI 已具备最小可用骨架。

---

## Phase 4: User Story 2 - 重建命令、工具与执行循环 (Priority: P2)

**Goal**: 交付一次脚本化请求从命令分发到工具调用、结果汇总和失败传播的完整执行路径。

**Independent Test**: 运行 `cl-cc run --fixture <fixture-id>`，验证命令分发、工具选择、工具执行、失败语义和执行结果摘要。

### Tests for User Story 2 ⚠️

- [x] T020 [P] [US2] 编写脚本化执行契约测试：`tests/contract/run-fixture-contract-test.lisp`
- [x] T021 [P] [US2] 编写工具成功/失败执行集成测试：`tests/integration/tool-execution-test.lisp`
- [x] T022 [P] [US2] 编写执行循环状态迁移单元测试：`tests/unit/execution-cycle-test.lisp`

### Implementation for User Story 2

- [x] T023 [P] [US2] 实现工具注册表与工具选择逻辑：`src/tools/registry.lisp`、`src/services/tool-selection.lisp`
- [x] T024 [P] [US2] 实现基线工具与失败工具夹具：`src/tools/echo-tool.lisp`、`src/tools/failing-tool.lisp`
- [x] T025 [US2] 实现执行循环推进器与结果汇总：`src/core/execution-engine.lisp`、`src/services/tool-runner.lisp`
- [x] T026 [US2] 实现 `run --fixture` 命令入口：`src/cli/run-command.lisp`
- [x] T027 [US2] 将命令注册表、工具注册表与执行循环接入 CLI：更新 `src/core/command-registry.lisp`、`src/cli/main.lisp`
- [x] T028 [US2] 补齐工具失败、部分完成与统一摘要输出：更新 `src/lib/result.lisp`、`src/services/tool-runner.lisp`

**Checkpoint**: 脚本化请求可独立跑通，工具成功与失败路径均可验证。

---

## Phase 5: User Story 3 - 补齐权限、状态持久化与兼容性回归基线 (Priority: P3)

**Goal**: 交付权限允许/拒绝路径、会话保存与恢复、golden case 回归比较的最小可用闭环。

**Independent Test**: 运行 `cl-cc session resume <session-id-or-path>` 与权限拒绝/损坏快照/回归夹具场景，验证可审计输出和安全失败。

### Tests for User Story 3 ⚠️

- [x] T029 [P] [US3] 编写权限判定契约测试：`tests/contract/permission-contract-test.lisp`
- [x] T030 [P] [US3] 编写会话恢复与损坏快照集成测试：`tests/integration/session-resume-test.lisp`
- [x] T031 [P] [US3] 编写 golden case 回归测试：`tests/contract/golden-regression-test.lisp`

### Implementation for User Story 3

- [x] T032 [P] [US3] 实现高风险动作权限判定与拒绝输出：更新 `src/services/permission-policy.lisp`、`src/services/permission-audit.lisp`
- [x] T033 [P] [US3] 实现会话保存、恢复与版本校验：更新 `src/session/serializer.lisp`、`src/session/store.lisp`、`src/services/session-service.lisp`
- [x] T034 [US3] 实现 `session resume` 命令入口与恢复流程：`src/cli/session-resume-command.lisp`
- [x] T035 [US3] 将权限层接入工具执行路径：更新 `src/services/tool-runner.lisp`、`src/core/execution-engine.lisp`
- [x] T036 [US3] 实现 golden case 比较、偏差标记与参考映射说明：更新 `src/services/golden-regression.lisp`、`docs/compatibility/reference-mapping.md`
- [x] T037 [US3] 补齐恢复失败、权限拒绝和偏差诊断输出：更新 `src/lib/debug-log.lisp`、`src/lib/errors.lisp`、`src/cli/session-resume-command.lisp`

**Checkpoint**: 权限、持久化与兼容性回归基线全部可独立验证。

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 整理跨故事文档、补足测试盲区，并按 quickstart 做整体验证。

- [x] T038 [P] 更新开发与验证文档：`README.md`、`specs/001-cl-cc-core/quickstart.md`、`docs/compatibility/README.md`
- [x] T039 清理重复代码并统一 package/export 命名：更新 `src/package.lisp` 与各子目录 `package.lisp`
- [x] T040 [P] 补充跨故事单元测试与回归夹具样例：`tests/unit/cli-output-test.lisp`、`fixtures/contracts/`、`fixtures/golden/`
- [x] T041 执行 quickstart 五个场景并记录结果到 `docs/compatibility/validation-report.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 无依赖，可立即开始。
- **Foundational (Phase 2)**: 依赖 Setup 完成；阻塞所有用户故事。
- **User Stories (Phase 3+)**: 全部依赖 Foundational 完成。
- **Polish (Phase 6)**: 依赖所有目标用户故事完成。

### User Story Dependencies

- **US1 (P1)**: Foundational 完成后即可开始；不依赖其他用户故事。
- **US2 (P2)**: Foundational 完成后即可开始，但会复用 US1 的 CLI 外壳与会话入口。
- **US3 (P3)**: Foundational 完成后即可开始，但会接入 US2 的工具执行路径和 US1 的会话命令。

### Within Each User Story

- 先写测试，并确认测试先失败。
- 先实现模型与契约接线，再实现服务与 CLI 入口。
- 先打通核心路径，再补统一错误处理和调试输出。
- 每个故事完成后，必须能单独验证，不依赖后续故事。

### Parallel Opportunities

- `T003` 可与 `T001`、`T002` 并行。
- `T005`、`T006`、`T007`、`T008` 在 `T004` 后可并行。
- US1 的 `T012`、`T013`、`T014` 可并行；`T015` 与 `T017` 可并行。
- US2 的 `T020`、`T021`、`T022` 可并行；`T023` 与 `T024` 可并行。
- US3 的 `T029`、`T030`、`T031` 可并行；`T032` 与 `T033` 可并行。
- `T038` 与 `T040` 可在最终阶段并行。

---

## Parallel Example: User Story 2

```text
Task: "T020 [US2] 编写脚本化执行契约测试：tests/contract/run-fixture-contract-test.lisp"
Task: "T021 [US2] 编写工具成功/失败执行集成测试：tests/integration/tool-execution-test.lisp"
Task: "T022 [US2] 编写执行循环状态迁移单元测试：tests/unit/execution-cycle-test.lisp"

Task: "T023 [US2] 实现工具注册表与工具选择逻辑：src/tools/registry.lisp、src/services/tool-selection.lisp"
Task: "T024 [US2] 实现基线工具与失败工具夹具：src/tools/echo-tool.lisp、src/tools/failing-tool.lisp"
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. 完成 Phase 1: Setup
2. 完成 Phase 2: Foundational
3. 完成 Phase 3: US1
4. 验证 `cl-cc --help` 与 `cl-cc session start`
5. 以 CLI 骨架作为第一里程碑

### Incremental Delivery

1. Setup + Foundational 完成后，形成可扩展骨架
2. 加入 US1，得到可启动 CLI
3. 加入 US2，得到可执行脚本化请求的核心循环
4. 加入 US3，得到权限/持久化/兼容性闭环
5. 最后执行 quickstart 五场景回归

### Team Strategy

1. 共同完成 Setup + Foundational
2. 一人负责 US1 CLI 骨架
3. 一人负责 US2 工具执行与 fixture 运行
4. 一人负责 US3 权限、恢复和 golden 回归

---

## Notes

- `[P]` 表示不同文件、低冲突、可并行。
- 任务描述已经映射到 spec 中的三条用户故事与 plan 中的项目结构。
- `cc-source/` 仅用于提炼夹具与参考映射，不得成为运行时依赖。
- 所有运行时代码、测试代码与契约适配层都必须保持纯 Common Lisp。