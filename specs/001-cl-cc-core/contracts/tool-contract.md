# Contract: Tool Execution and Permission Boundary

## Purpose

定义 CL-CC 中工具注册、调用和权限判定的最小契约。

## Tool Definition Contract

Each tool definition must provide:

- `tool-id`: 稳定标识
- `summary`: 工具用途说明
- `input-schema`: 输入结构定义
- `output-schema`: 成功输出结构定义
- `error-output-schema`: 失败输出结构定义，可选
- `permission-profile`: 需要的权限类别
- `failure-modes`: 可能失败类型列表

Tool `input-schema` / `output-schema` / `error-output-schema` may declare both a text summary and machine-readable JSON fields; when JSON fields are present, field names and summaries should be explicit enough to flow into generated tool reference docs and contract assertions. Output fields may also declare a stable `:source` so execution can materialize structured success/error payloads from metadata instead of hardcoded field-name checks.

## Execution Contract

1. 执行循环接收命令或脚本化请求。
2. 根据上下文选择一个或多个工具定义。
3. 对每个高风险工具动作执行权限判定。
4. 若权限允许，则执行工具并记录结果。
5. 若权限拒绝，则返回拒绝结果并保留会话一致性。
6. 将工具结果汇总回执行循环输出。

## Permission Decision Output

Each permission decision must expose:

- `decision`: `allow | deny | error`
- `action-kind`: 动作类别
- `reason-code`: 稳定原因码
- `summary`: 人类可读摘要
- `audit-payload`: 可选审计负载

## Failure Semantics

- 工具输入非法: 返回 `failed`
- 权限拒绝: 返回 `denied`
- 工具内部异常: 返回 `failed`
- 部分完成: 返回 `partial`
- 全部完成: 返回 `success`

## Compatibility Policy

- 与参考资料严格一致的输入输出应进入 golden cases
- 有意偏离的地方必须在夹具说明中显式标记
- 未解释偏差在 contract/golden regression 中视为失败
