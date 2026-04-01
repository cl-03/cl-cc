<!--
Sync Impact Report
Version change: template -> 1.0.0
Modified principles:
- Principle slot 1 -> I. 纯 Common Lisp 实现
- Principle slot 2 -> II. 参考实现用于研究，不用于运行时复用
- Principle slot 3 -> III. 契约优先的 CLI 与工具接口
- Principle slot 4 -> IV. 测试先行与兼容性回归门禁
- Principle slot 5 -> V. 安全、可观测性、版本化与简洁性
Added sections:
- 实施约束
- 开发工作流
Removed sections:
- None
Templates requiring updates:
- ✅ updated: .specify/templates/plan-template.md
- ✅ updated: .specify/templates/spec-template.md
- ✅ updated: .specify/templates/tasks-template.md
Follow-up TODOs:
- None
-->
# CL-CC Constitution

## Core Principles

### I. 纯 Common Lisp 实现
CL-CC 的产品运行时代码、核心业务逻辑、测试断言与契约适配层 MUST 使用 Common Lisp 实现。
仓库可以包含文档、规范文件与本地自动化脚本，但这些辅助文件 MUST NOT 承担产品逻辑。
如果某项能力在参考实现里依赖其他语言或生态，团队 MUST 以 Common Lisp 重写，或在规格中明确降级或延后。
Rationale: 本项目的首要目标不是包装现成实现，而是以 Common Lisp 独立重建 Claude Code 的能力边界。

### II. 参考实现用于研究，不用于运行时复用
`cc-source/` 及其他外部仓库 MUST 仅作为行为研究、架构对照与测试样例来源，MUST NOT 成为运行时依赖、嵌入式子模块或跨语言桥接层。
任何功能规格或实现计划，只要借鉴了参考实现，都 MUST 说明参考来源、目标行为、不变量，以及 Common Lisp 重构边界。
未经明确授权的代码段 MUST NOT 直接复制到本项目；团队应提炼行为、接口与约束，再以新的 Common Lisp 设计重新表达。
Rationale: 这样既能借鉴已有研究成果，也能保持本项目在实现、维护与权属边界上的清晰性。

### III. 契约优先的 CLI 与工具接口
CL-CC 是面向工程工作流的 agentic CLI；因此命令、子命令、工具调用模式、配置文件、会话文件与结构化输出 MUST 先定义契约，再写实现。
任何会改变用户可见行为或工具协议的工作，都 MUST 在 `spec.md` 中写出可验证要求，在 `plan.md` 中记录兼容性策略，并在 `tasks.md` 中安排迁移或回归任务。
当参考实现存在多个候选行为时，项目 MUST 选择一个对外稳定、可测试、可文档化的契约，而不是把与参考仓库一致当作唯一说明。
Rationale: 先固定外部接口，才能在 Common Lisp 重写过程中保持功能收敛并控制回归面。

### IV. 测试先行与兼容性回归门禁
所有功能开发 MUST 先补足失败中的测试，再进入实现；至少覆盖单元测试、用户路径集成测试，以及受影响 CLI 或工具契约的回归测试。
如果任务目标是对齐 `cc-source/` 中既有行为，则测试 MUST 明确写出要兼容什么、允许偏离什么，以及如何验证偏离是有意的。
在测试未通过前，变更 MUST NOT 被视为完成；在缺失可执行测试的情况下，计划与任务文档 MUST 说明阻塞原因与补测方案。
Rationale: 对重写项目而言，最容易漂移的是行为语义；测试先行是防止看起来像、实际上不兼容的可靠机制。

### V. 安全、可观测性、版本化与简洁性
默认实现 MUST 采用最小权限、显式确认和可审计路径；任何可能修改文件、执行命令或访问外部资源的能力都 MUST 有清晰的权限边界与失败路径。
运行时 MUST 提供足够的结构化日志或调试输出以支持问题复现，但 MUST 避免未经说明的遥测、隐式上报或不可关闭的外部通信。
所有破坏性契约变更 MUST 记录迁移说明并遵循语义化版本管理；架构设计 MUST 优先选择小而清晰的 Common Lisp 模块，而非过早抽象或跨层耦合。
Rationale: 重写项目既要安全可信，也要便于排错与迭代，而这些目标都依赖可观察、可演进、可理解的设计。

## 实施约束

- 允许借鉴的对象是行为、交互流程、模块边界与测试思路；不允许把其他语言实现作为本项目的产品依赖。
- 新增依赖时，优先选择 Common Lisp 库；若确实缺失，MUST 先评估是否应在仓库内以 Common Lisp 自行实现。
- 面向用户的协作、需求澄清、评审结论与阶段汇报 MUST 默认使用中文，除非用户明确要求切换语言。
- 规格、计划、任务与最终实现都 MUST 明确区分参考行为、本项目当前行为与后续对齐计划。
- 性能目标需要在需求阶段量化；无法量化时，MUST 在 `spec.md` 中标记待澄清，而不是留给实现阶段临时决定。

## 开发工作流

1. `/speckit.specify` 产物 MUST 说明用户价值、参考来源、Common Lisp 重写边界、契约变化与可执行验收场景。
2. `/speckit.plan` 产物 MUST 在 Constitution Check 中逐条验证纯 Common Lisp、契约覆盖、测试先行、安全和日志边界，以及版本影响。
3. `/speckit.tasks` 产物 MUST 先生成测试任务，再生成实现任务；任何契约变更都 MUST 有文档、迁移或兼容性回归任务。
4. 合并前 MUST 完成代码评审并通过全部相关测试；若命令接口、工具模式或会话格式发生变化，还 MUST 更新相应文档与版本说明。
5. 研究 `cc-source/` 时，结论应沉淀为规格、计划或注释化设计说明，而不是把参考仓库如此实现当作最终决策理由。

## Governance

本宪章高于仓库内其他流程性约定；若与临时说明冲突，以本宪章为准。
宪章修订 MUST 通过显式变更完成，并同时更新受影响模板、迁移说明和审查清单。
版本规则遵循语义化策略：新增原则或显著扩展为 MINOR，原则重定义或移除为 MAJOR，措辞澄清为 PATCH。
每次规格评审、计划评审和代码评审 MUST 包含一次合规检查，确认纯 Common Lisp、契约、测试、安全与可观测性要求没有被绕过。
若某次工作需要临时偏离宪章，必须先在规格或计划中记录理由、替代方案、回归风险与回归时间点，经确认后方可执行。

**Version**: 1.0.0 | **Ratified**: 2026-04-01 | **Last Amended**: 2026-04-01
