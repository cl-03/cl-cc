# Contract: CLI Interface

## Purpose

定义 CL-CC 核心 CLI 的最小对外契约，覆盖启动、帮助、会话开始、会话恢复和脚本化执行入口。

## Planned Commands

### `cl-cc --help`

- Purpose: 输出 CLI 总览与基本用法
- Input: 无或 `--help`
- Output:
  - 命令总览
  - 子命令入口
  - 错误提示方式
- Failure Behavior:
  - 不应因为缺失可选配置而失败

### `cl-cc session start`

- Purpose: 创建最小会话并进入基础执行循环
- Input:
  - 可选输入载荷
  - 可选调试标志
- Output:
  - `session-id`
  - 初始状态摘要
  - 结果状态
- Failure Behavior:
  - 初始化失败时返回统一错误结构
- Output Schema Note:
  - text 输出当前以稳定的人类可读摘要返回会话创建结果与可选 history-index 信息
  - json 输出当前稳定包含 `status`、`sessionId`、`historyIndex`、`sessionStatus`、`exitCode`

### `cl-cc session resume <session-id-or-path>`

- Purpose: 恢复先前保存的会话状态
- Input:
  - 会话标识或快照路径
- Output:
  - 恢复后的状态摘要
  - 继续执行所需的上下文摘要
- Failure Behavior:
  - 状态损坏、版本不匹配或资源缺失时安全失败
- Output Schema Note:
  - text 输出当前返回稳定的恢复摘要
  - json 输出当前稳定包含 `status`、`sessionId`、`historyIndex`、`sessionStatus`、`exitCode`

### `cl-cc run --fixture <fixture-id>`

- Purpose: 使用固定夹具运行一次脚本化核心流程
- Input:
  - fixture 标识
- Output:
  - 本次执行摘要
  - 工具调用结果
  - 比较结果（若启用回归比较）
- Failure Behavior:
  - 夹具不存在或格式非法时返回稳定错误
- Output Schema Note:
  - text 输出为聚合后的执行摘要
  - json 输出当前稳定包含 `status`、`fixtureCount`、`successfulCount`、`failedCount`、`statusCounts`、`ok`、`exitCode`、`results`
  - `results` 中的每条 fixture 记录当前稳定包含 `fixtureId`、`status`、`result`、`toolResults`
  - `toolResults` 中的每条工具尝试当前稳定包含 `toolId`、`status`、`output`、`error`、`errorCode`
  - `toolResults.output` 的字段集合当前直接由工具定义中的 `output-schema` / `error-output-schema` 提供，并通过 registry 元数据同步到帮助文本与 README 参考

## Cross-Cutting Output Requirements

- 所有命令必须返回稳定退出语义
- 所有错误输出必须包含机器可判定状态和人类可读摘要
- 调试模式下允许附加结构化诊断信息
- 默认输出和错误输出必须区分清楚
- 命令契约应允许把输入 schema 与输出 schema 一并沉淀到 registry 元数据，供帮助文本、README 参考和自动化回归共用
