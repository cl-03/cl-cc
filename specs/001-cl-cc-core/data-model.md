# Data Model: CL-CC Core Runtime Reconstruction

## CommandDefinition

- Purpose: 描述一个 CLI 命令或子命令的对外契约。
- Fields:
  - `name`: 稳定命令名
  - `aliases`: 可选别名列表
  - `arguments-schema`: 参数与位置参数约束
  - `output-schema`: 命令输出契约；可声明 text 摘要与 machine-readable JSON 字段
  - `summary`: 帮助文本摘要
  - `handler-symbol`: 绑定的 Common Lisp 入口符号
  - `permission-profile`: 执行该命令所需的权限类别
- Relationships:
  - One-to-many with `ToolDefinition` when某命令会暴露或调度多个工具。

## ToolDefinition

- Purpose: 描述执行循环可调用的工具契约。
- Fields:
  - `tool-id`: 唯一标识
  - `summary`: 工具用途
  - `input-schema`: 输入契约
  - `output-schema`: 输出契约
  - `failure-modes`: 明确失败类型
  - `permission-profile`: 高风险动作边界
- Relationships:
  - Referenced by `ExecutionCycle`
  - Audited through `PermissionDecision`

## SessionState

- Purpose: 持久化一次 CLI/agent 会话的最小恢复状态。
- Fields:
  - `session-id`: 唯一标识
  - `created-at`: 创建时间
  - `updated-at`: 最后更新时间
  - `history-index`: 历史序号或摘要索引
  - `context-summary`: 当前上下文摘要
  - `permission-snapshot`: 最近权限上下文
  - `status`: `active | completed | failed | recoverable`
  - `version`: 状态格式版本
- Relationships:
  - Aggregates one or more `ExecutionCycle` records
  - Uses one `PermissionDecision` snapshot set

## ExecutionCycle

- Purpose: 表达一次请求如何穿过命令分发、上下文装配、工具调用和结果输出。
- Fields:
  - `cycle-id`: 唯一标识
  - `command-name`: 入口命令
  - `input-payload`: 本次请求输入
  - `selected-tools`: 本次选中的工具列表
  - `context-before`: 执行前上下文摘要
  - `context-after`: 执行后上下文摘要
  - `result-status`: `success | denied | failed | partial`
  - `result-summary`: 输出摘要
- Relationships:
  - Belongs to one `SessionState`
  - References zero or more `ToolDefinition`
  - Produces zero or more `CompatibilityFixture` comparisons

## PermissionDecision

- Purpose: 记录某个高风险动作的权限判定和审计结果。
- Fields:
  - `decision-id`: 唯一标识
  - `action-kind`: 如 file-write, shell-exec, external-access
  - `decision`: `allow | deny | error`
  - `reason-code`: 稳定原因码
  - `human-summary`: 人类可读说明
  - `audit-payload`: 审计输出
- Relationships:
  - Associated with `CommandDefinition`, `ToolDefinition`, or `ExecutionCycle`

## CompatibilityFixture

- Purpose: 固化从参考资料中提炼出的目标行为样例，用于回归比较。
- Fields:
  - `fixture-id`: 唯一标识
  - `reference-source`: 参考来源路径或文档章节
  - `scenario-name`: 场景名
  - `input-sample`: 测试输入
  - `expected-output`: 目标输出或目标不变量
  - `deviation-policy`: `strict | explainable-deviation | deferred`
  - `notes`: 偏差说明
- Relationships:
  - Validates one or more `ExecutionCycle` outcomes

## State Transitions

### SessionState

- `active -> completed`: 会话正常结束
- `active -> failed`: 会话遇到不可恢复错误
- `active -> recoverable`: 会话中断但可恢复
- `recoverable -> active`: 会话被成功恢复
- `recoverable -> failed`: 恢复失败或状态损坏

### PermissionDecision

- `pending -> allow`
- `pending -> deny`
- `pending -> error`

### ExecutionCycle

- `initialized -> dispatched`
- `dispatched -> tool-running`
- `tool-running -> success`
- `tool-running -> denied`
- `tool-running -> failed`
- `tool-running -> partial`

## Validation Rules

- `session-id`, `cycle-id`, `decision-id`, `fixture-id` 必须全局唯一。
- `version` 必须存在，以支持未来状态格式迁移。
- `ToolDefinition.failure-modes` 不能为空，必须显式列出可预期失败类型。
- `CompatibilityFixture.deviation-policy` 为 `explainable-deviation` 时，`notes` 不能为空。
- `PermissionDecision.decision = deny` 时，必须同时写出 `reason-code` 和 `human-summary`。
