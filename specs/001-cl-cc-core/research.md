# Research: CL-CC Core Runtime Reconstruction

## Decision 1: 以单一 Common Lisp CLI 项目作为第一阶段交付形态

- Decision: 使用单个 Common Lisp 系统承载 CLI 入口、核心执行循环、会话状态和权限边界，而不是一开始拆成多个独立服务或子系统。
- Rationale: 参考资料显示 Claude Code 的能力分层很多，但当前 MVP 目标是建立可运行、可回归、可扩展的核心运行时。单系统结构更适合在纯 Common Lisp 条件下先验证关键状态机与契约。
- Alternatives considered:
  - 多进程或多服务拆分：过早引入边界与通信复杂度，不利于首批兼容性验证。
  - 直接复刻参考仓库目录结构：与当前纯 Common Lisp 实现目标不匹配，且会制造伪一致感。

## Decision 2: 兼容目标以“行为夹具”而不是“逐文件对照”表达

- Decision: 从 `cc-source/` 中提炼启动、命令分发、工具执行、权限拒绝、会话恢复等关键行为，固化为 golden cases 和契约夹具，而不是追求目录或逐文件镜像。
- Rationale: 宪章要求参考资料只能用于研究，不能成为运行时依赖；因此最可靠的对齐方式是提炼不变量、输入输出和状态迁移，再在 Common Lisp 中重写。
- Alternatives considered:
  - 逐模块机械对照：容易被参考仓库语言与实现细节绑架。
  - 只保留口头对齐目标：缺乏回归约束，后续实现容易漂移。

## Decision 3: 主实现锁定 SBCL 2.4.x，包边界保持可移植性

- Decision: 第一阶段以 SBCL 2.4.x 作为首发运行环境，同时将系统结构、数据模型和接口写成尽量可移植的 Common Lisp 形式。
- Rationale: 需要一个稳定、常用、工具链成熟的 Common Lisp 实现来支撑 CLI、测试和文件系统操作；SBCL 在此阶段最现实。
- Alternatives considered:
  - 同时支持多实现：前期测试矩阵和兼容处理成本过高。
  - 绑定 SBCL 专有接口：会损害后续可移植性目标。

## Decision 4: 会话状态和兼容性夹具先采用文件系统持久化

- Decision: 使用本地文件系统保存会话元数据、恢复快照、测试输入和 golden outputs。
- Rationale: 当前阶段不需要数据库；文件系统对单用户本地 CLI 足够，同时便于审计、回放和版本控制。
- Alternatives considered:
  - 引入数据库：过度设计，且不利于离线、轻量的开发者工作流。
  - 完全不持久化：无法支撑恢复路径和兼容性回归要求。

## Decision 5: 权限模型采用显式判定与可审计拒绝输出

- Decision: 对潜在高风险动作建立显式权限判定层，至少覆盖允许、拒绝和失败三类结果，并记录动作类别、原因和输出格式。
- Rationale: 参考资料把权限直接嵌进 agent 工作流；对重写项目来说，早期就要把边界显式化，否则后续工具能力扩展会失控。
- Alternatives considered:
  - 默认全部放行：与安全目标冲突。
  - 交给未来再做：会让当前 CLI/工具契约缺失关键边界。

## Decision 6: 测试策略采用三层结构

- Decision: 使用 FiveAM 驱动单元测试，配合脚本化集成测试和 contract/golden regression 测试。
- Rationale: 需要同时验证内部状态迁移、端到端 CLI 流程和与参考行为的一致性。
- Alternatives considered:
  - 只做单元测试：无法覆盖 CLI 和兼容性目标。
  - 只做集成测试：难以定位核心状态机错误。

## Decision 7: 首批实现范围只覆盖核心运行时基线

- Decision: 第一阶段不实现语音、远程 bridge、完整 provider routing、完整多 agent 编排和复杂 UI 交互。
- Rationale: 当前 feature 的目标是建立可运行的 CL 核心与回归边界，不是一次性吞下全部能力域。
- Alternatives considered:
  - 一次性覆盖全部研究主题：任务不可收敛，计划和测试都会失真。

## Reference Behaviors To Preserve In MVP

- CLI 能启动、展示帮助、进入并退出基础会话。
- 命令层与工具层分离，执行循环能推进一次脚本化请求。
- 高风险动作有权限判定和可审计输出。
- 会话状态可保存、可恢复、损坏时可安全失败。
- 兼容性夹具可比较当前输出与目标参考行为。

## Deferred Areas

- 远程接入与桥接协议
- 复杂 provider 路由和真实外部账号交互
- 语音与复杂 UI 模式
- 多 agent 协作编排的完整实现
- 遥测与实验控制相关能力
