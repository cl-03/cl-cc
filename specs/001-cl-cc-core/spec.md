# Feature Specification: CL-CC Core Runtime Reconstruction

**Feature Branch**: `001-cl-cc-core`  
**Created**: 2026-04-01  
**Status**: Draft  
**Input**: User description: "仔细研究 claude code 技术路线资料和本项目文件夹下的 cc-source 参考代码，挖掘代码逻辑，进行完全的仿制开发，同时时刻遵守核心原则：纯 common lisp 开发。参考资料都在工作区内。"

**Reference Context**: `cc-source/claude-code-main/claude-code-main/README.md` 中的高层架构拆分；`cc-source/claude-code-src-main/claude-code-src-main/README.md` 中对命令、工具、QueryEngine、会话与移植工作区的整理；工作区内围绕启动、命令系统、工具系统、权限、上下文、记忆与多 agent 协作的研究文档。

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - 建立可运行的核心 CLI 骨架 (Priority: P1)

作为 CL-CC 的开发者，我希望先拥有一个完全由 Common Lisp 实现的核心 CLI 骨架，使我可以启动程序、解析命令、进入基础会话循环，并验证这一骨架对 Claude Code 关键工作流的映射是否正确。

**Why this priority**: 没有可运行的 CLI 骨架，就无法承载后续工具调用、状态管理、权限控制与兼容性验证，这是一切重建工作的最小可交付增量。

**Independent Test**: 通过启动 CL-CC CLI，执行基础命令与空会话流程，验证命令解析、帮助输出、会话初始化和退出路径全部可在不依赖其他故事的情况下独立通过。

**Acceptance Scenarios**:

1. **Given** 开发者位于已初始化的项目目录，**When** 启动 CL-CC CLI 并请求帮助信息，**Then** 系统输出稳定的命令总览、子命令入口和错误处理说明。
2. **Given** 开发者执行一个基础会话命令，**When** 会话被创建并立刻结束，**Then** 系统生成可审计的会话状态、退出码和最小调试输出。

---

### User Story 2 - 重建命令、工具与执行循环 (Priority: P2)

作为 CL-CC 的开发者，我希望把参考资料中的命令层、工具层与执行循环映射到 Common Lisp 结构中，使系统可以在单次会话中完成命令分发、工具描述、工具调用和上下文推进。

**Why this priority**: 这决定了 CL-CC 是否真正具备 agentic CLI 的核心行为，而不是一个只能显示帮助文本的空壳程序。

**Independent Test**: 通过预置输入或固定夹具运行一次脚本化会话，验证命令分发、工具选择、工具执行结果汇总和执行循环推进均符合预期。

**Acceptance Scenarios**:

1. **Given** 系统已注册若干 CLI 命令与工具定义，**When** 开发者触发一次脚本化任务请求，**Then** 系统按照既定契约完成命令分发、工具调用与结果输出。
2. **Given** 某个工具返回失败结果，**When** 执行循环处理该失败，**Then** 系统以一致格式记录失败原因、保留会话上下文并返回可验证的错误状态。

---

### User Story 3 - 补齐权限、状态持久化与兼容性回归基线 (Priority: P3)

作为 CL-CC 的维护者，我希望核心运行时在权限判定、会话持久化、上下文与记忆边界方面具备最小可用能力，并可用回归夹具持续比对参考行为，从而控制后续重写偏差。

**Why this priority**: 没有权限与持久化边界，系统很难安全演进；没有兼容性基线，重写会很快偏离参考工作流。

**Independent Test**: 通过受控夹具验证权限允许/拒绝路径、会话恢复路径和 golden case 回归比较，证明该故事可独立交付。

**Acceptance Scenarios**:

1. **Given** 某命令或工具请求超出当前权限边界，**When** 系统进行权限评估，**Then** 系统拒绝该操作并返回明确、可审计的拒绝原因。
2. **Given** 存在一个已保存的会话状态，**When** 开发者请求恢复该会话，**Then** 系统恢复必要状态并允许继续后续命令处理。

---

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- 当参考资料中同一能力存在多个实现路径或历史变体时，系统如何记录“当前选择的兼容目标”和“有意偏离点”？
- 当某项参考能力依赖非 Common Lisp 生态时，系统如何在不引入跨语言运行时依赖的前提下标记重写、降级或暂缓？
- 当工具执行失败、超时或返回不可解析结果时，会话循环如何保持一致状态并提供调试信息？
- 当恢复的会话状态不完整、版本不匹配或内容损坏时，系统如何安全失败并提示开发者？
- 当权限规则拒绝高风险动作时，系统如何确保拒绝结果可审计、可回放且不泄漏额外状态？

## Constitution Alignment *(mandatory)*

- **CA-001**: 本功能范围内的运行时代码、命令分发、工具执行循环、权限判定、状态持久化与测试夹具 MUST 使用 Common Lisp 实现；如果某项参考能力无法直接用现有 Common Lisp 库完成，必须明确记录为“仓内重写”或“延后支持”。
- **CA-002**: 对 `cc-source/` 的引用仅用于说明目标行为、模块边界、状态机不变量与兼容性夹具来源，不得把其中任何其他语言实现作为运行时依赖。
- **CA-003**: 本功能涉及的 CLI 命令集、工具描述结构、会话状态格式、权限决策输出与调试输出 MUST 在后续计划中写成明确契约，并说明与参考行为的一致点和偏离点。
- **CA-004**: 在进入实现前，必须先定义失败中的单元测试、脚本化集成测试以及与参考行为对齐的 golden case 回归测试。
- **CA-005**: 本功能必须显式覆盖安全边界、可观测性、性能预算和版本影响，尤其要说明哪些操作允许执行、哪些操作必须拒绝，以及拒绝时的可审计输出。

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: 系统 MUST 提供一个完全由 Common Lisp 实现的 CLI 入口，使开发者可以启动 CL-CC、查看帮助、执行基础命令并创建最小会话。
- **FR-002**: 系统 MUST 提供与参考资料中的命令层、工具层和执行层相对应的核心抽象，使命令分发、工具定义和执行循环可以被独立测试和组合。
- **FR-003**: 系统 MUST 支持至少一条脚本化核心工作流，使一次用户请求能够穿过命令解析、上下文装配、工具调用和结果输出全过程。
- **FR-004**: 系统 MUST 为会话状态、上下文数据、权限决策和工具结果定义稳定且可序列化的数据结构，以支持保存、恢复和回归比较。
- **FR-005**: 系统 MUST 对高风险动作执行权限判定，并在允许、拒绝和失败三类路径上输出一致、可审计的结果。
- **FR-006**: 系统 MUST 提供最小可用的持久化机制，用于保存会话元数据、恢复必要执行状态并在不兼容或损坏时安全失败。
- **FR-007**: 系统 MUST 允许开发者将 `cc-source/` 中选定参考行为固化为 golden case 或等价夹具，并在回归测试中自动比较 CL-CC 当前行为。
- **FR-008**: 系统 MUST 为参考研究结论建立显式映射，至少覆盖启动装配、命令系统、工具系统、执行循环、权限边界、上下文/记忆和会话恢复这几个能力域。
- **FR-009**: 系统 MUST 为开发者提供可读的调试输出，以便定位命令分发、工具失败、权限拒绝、状态恢复与兼容性偏差问题。
- **FR-010**: 系统 MUST 明确标注当前未实现或有意偏离的参考能力，并在文档或规格产物中记录原因、影响范围和后续计划。

### Key Entities *(include if feature involves data)*

- **Command Definition**: 表示一个 CLI 命令或子命令的契约，包含名称、参数模式、执行入口、帮助文本和错误输出约束。
- **Tool Definition**: 表示模型或执行循环可调用的工具契约，包含工具标识、输入模式、输出模式、权限需求和失败语义。
- **Session State**: 表示一次会话的持久化状态，包含会话标识、上下文摘要、历史记录索引、权限快照和恢复所需的最小元数据。
- **Execution Cycle**: 表示单次请求在命令分发、上下文装配、工具调用与结果输出之间的推进过程，用于测试状态转移和错误传播。
- **Permission Decision**: 表示某个潜在高风险动作的判定结果，包含动作类别、判定原因、允许或拒绝状态以及审计输出。
- **Compatibility Fixture**: 表示从参考资料提炼出的行为样例、golden case 或不变量集合，用于比较当前实现与目标行为的偏差。

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: 开发者可以在 10 分钟内根据项目文档启动 CL-CC CLI、执行帮助命令并跑通一次基础脚本化会话。
- **SC-002**: 启动装配、命令分发、工具调用、权限判定和会话恢复这 5 类核心路径中，每类至少有 1 个可自动执行的回归场景。
- **SC-003**: 首批选定的参考行为样例中，至少 80% 在 CL-CC 的 golden case 回归中达到预期的一致输出或被显式标记为有意偏离。
- **SC-004**: 所有进入 MVP 范围的运行时能力都不依赖其他语言作为产品运行时前提，并且所有偏离项都能在规格或计划文档中追踪到原因。

## Assumptions

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right assumptions based on reasonable defaults
  chosen when the feature description did not specify certain details.
-->

- 本 feature 聚焦“核心运行时骨架与兼容性基线”，不要求在第一次迭代内覆盖语音、远程桥接、完整 UI、全部 provider 路由和全部多 agent 模式。
- 研究与对齐的主要来源是工作区中的 `cc-source/` 文档、源码快照和研究性 README，而不是外部在线服务行为。
- 目标用户首先是本项目开发者与维护者，因此本阶段优先保证架构映射、行为可验证和回归能力，而不是终端用户级完整体验。
- 默认选择一个主 Common Lisp 实现作为首发运行环境，并在计划阶段说明后续可移植性边界。
- 若某些参考能力依赖外部账号、远程服务或未公开协议，本 feature 允许通过夹具、桩或降级行为先建立本地兼容性基线。
