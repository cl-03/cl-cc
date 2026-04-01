# CL-CC

CL-CC 是一个以纯 Common Lisp 实现的 Claude Code 核心运行时重建项目。

## 当前范围

- CLI 启动与帮助输出
- `session start` / `session resume`
- `run --fixture` 脚本化执行路径
- command registry 驱动的 CLI 分发
- `--help` 已纳入统一命令分发路径
- command registry 已升级为 `command-definition` 元数据驱动注册
- command aliases 与最小 `arguments-schema` 校验已接入运行时分发
- CLI 帮助文本已改为从 command registry 元数据自动生成
- `arguments-schema` 已支持位置参数与命名参数定义，当前已接入 `session start --session-id <id>`
- `arguments-schema` 已支持短/长选项统一定义与基础整数类型校验，当前已接入 `session start -i <id> --history-index <n>`
- `arguments-schema` 已支持 `--flag=value` 形式解析，并在 `run --fixture -o json` / `run --fixture --output-format=json` 上接入枚举校验
- `arguments-schema` 已支持默认值与可重复选项；当前 `run --fixture` 可用重复 `-t/--tool <tool-id>` 覆盖自动工具选择顺序
- `arguments-schema` 已支持参数依赖与互斥约束；当前 `run --fixture --pretty` / `--compact` 只能在 `--output-format json` 下使用，且二者互斥
- `arguments-schema` 已支持条件默认值；当前 `run --fixture --pretty` / `--compact` 会自动将输出格式补成 `json`
- `run --fixture` 的 JSON 输出已统一为稳定 envelope，当前包含 `status`、`fixtureCount`、`successfulCount`、`failedCount`、`statusCounts`、`ok`、`exitCode`、`results`，且每条 fixture 记录已附带结构化 `toolResults`；`exitCode` 与 CLI 实际返回码一致；顶层 `status` 已可区分 `success`、`partial`、`failed`、`denied`、`not-found`，并在混合结果场景下稳定聚合为 `partial`
- `run --fixture` 的 service 层现先返回结构化 `cl-cc.lib:result`，再由 CLI 统一序列化为 text/json 输出，避免格式拼装散落在业务逻辑中
- `run --fixture` 与 `docs sync-reference` 已共享 CLI 侧结果渲染层；二者都先产出结构化 `cl-cc.lib:result`，再统一序列化为 text/json 输出
- `session start` 与 `session resume` 现也先由 service 层返回结构化 `cl-cc.lib:result`，CLI 再统一走共享结果渲染入口输出 text 摘要
- `session start` 与 `session resume` 当前也支持 `-o/--output-format text|json`；JSON 输出稳定包含 `status`、`sessionId`、`historyIndex`、`sessionStatus`、`exitCode`
- `docs sync-reference [<output-path>] [--check] [--output-format text|json]` 可检查或写回 registry 派生的命令参考 Markdown 生成区块，并以稳定 JSON 状态字段供脚本消费
- 工具注册表现已升级为 `tool-definition` 元数据驱动；README 生成区块当前也会直接展示 tool registry 派生的 `工具参考`，并从工具 schema 元数据派生 `Input JSON Fields` / `Output JSON Fields`
- 工具注册、工具选择、执行循环、失败传播
- 权限判定与审计输出
- 会话快照保存、恢复、版本校验与带 history trail 的最小 session loop 推进
- golden case 回归基线

## 运行测试

```powershell
sbcl --noinform --non-interactive --load cl-cc.asd --eval "(asdf:load-system '|cl-cc/tests|)" --eval "(cl-cc/tests:run-tests)"
```

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## 命令参考

### `docs sync-reference`

- Usage: `cl-cc docs sync-reference [<output-path>] [--check] [--output-format <output-format>]`
- Summary: 将生成的命令参考同步到指定 Markdown 文件，或以 text/json 形式检查漂移
- Aliases: `cl-cc docs sync`
- Output Schema: `text`: result message; `json`: `path`, `status`, `checkOnly`, `updated`, `needsSync`, `durationSeconds`, `exitCode` [closed]
- JSON Fields:
  - `path`: 目标文档路径 [type: `string`]
  - `status`: 同步状态: synced、in-sync 或 drift [type: `string`] [allowed: `synced`, `in-sync`, `drift`]
  - `checkOnly`: 是否处于只检查模式 [type: `boolean`]
  - `updated`: 本次是否实际写回文件 [type: `boolean`]
  - `needsSync`: 当前文档是否存在漂移 [type: `boolean`]
  - `durationSeconds`: 本次 docs sync 执行时长（秒） [type: `number`] [min: `0`]
  - `exitCode`: 命令退出码 [type: `integer`] [min: `0`] [max: `255`]
- Options:
  - --check  仅检查命令参考是否需要同步，不写回文件
  - -o, --output-format <output-format>  指定输出格式: text 或 json [default: text]

### `help`

- Usage: `cl-cc help`
- Summary: 显示 CLI 帮助
- Aliases: `cl-cc --help`, `cl-cc -h`, `cl-cc help`
- Output Schema: `text`: CLI help text

### `run --fixture`

- Usage: `cl-cc run --fixture <fixture-id>... [--output-format <output-format>] [--pretty] [--compact] [--tool <tool-id>]`
- Summary: 执行 fixture 驱动的脚本化请求
- Aliases: `cl-cc r --fixture`
- Output Schema: `text`: fixture execution summary; `json`: `status`, `fixtureCount`, `successfulCount`, `failedCount`, `durationSeconds`, `statusCounts`, `ok`, `exitCode`, `results` [closed]
- JSON Fields:
  - `status`: 聚合结果状态 [type: `string`] [allowed-when-zero: `exitCode` => `success`] [allowed-when-nonzero: `exitCode` => `partial`, `failed`, `denied`, `not-found`] [allowed: `success`, `partial`, `failed`, `denied`, `not-found`]
  - `fixtureCount`: 本次执行的 fixture 数量 [type: `integer`] [min: `0`] [count-of: `results`] [sum-of: `statusCounts.success`, `statusCounts.failed`, `statusCounts.partial`, `statusCounts.denied`, `statusCounts.not-found`, `statusCounts.unknown`]
  - `successfulCount`: 成功 fixture 数量 [type: `integer`] [min: `0`] [matches: `statusCounts.success`]
  - `failedCount`: 失败 fixture 数量 [type: `integer`] [min: `0`] [matches: `statusCounts.failed`]
  - `durationSeconds`: 本次 run 聚合执行时长（秒） [type: `number`] [min: `0`]
  - `statusCounts`: 各状态计数映射 [type: `object`] [closed]
    - `success`: 成功 fixture 数量 [type: `integer`] [min: `0`] [matches-when: `status` = `success` => `fixtureCount`]
    - `failed`: 失败 fixture 数量 [type: `integer`] [min: `0`] [matches-when: `status` = `failed` => `fixtureCount`]
    - `partial`: 混合结果 fixture 数量 [type: `integer`] [min: `0`]
    - `denied`: 权限拒绝 fixture 数量 [type: `integer`] [min: `0`] [matches-when: `status` = `denied` => `fixtureCount`]
    - `not-found`: 工具未找到 fixture 数量 [type: `integer`] [min: `0`] [matches-when: `status` = `not-found` => `fixtureCount`]
    - `unknown`: 未归类 fixture 数量 [type: `integer`] [min: `0`]
  - `ok`: 是否全部成功 [type: `boolean`] [true-when-zero: `exitCode`]
  - `exitCode`: 命令退出码 [type: `integer`] [min: `0`] [max: `255`]
  - `results`: 逐 fixture 的结果记录，包含稳定文本摘要与 toolResults [type: `array`] [min-items: `1`] [closed]
    - `fixtureId`: fixture 标识 [type: `string`]
    - `status`: 该 fixture 的聚合状态 [type: `string`] [allowed: `success`, `partial`, `failed`, `denied`, `not-found`]
    - `durationSeconds`: 该 fixture 执行时长（秒） [type: `number`] [min: `0`]
    - `result`: 兼容既有 golden 的稳定文本摘要 [type: `string`]
    - `toolResults`: 逐工具尝试记录 [type: `array`] [min-items: `1`] [closed]
      - `toolId`: 工具标识 [type: `string`]
      - `status`: 该次工具尝试状态 [type: `string`] [allowed: `success`, `failed`, `denied`, `not-found`]
      - `durationSeconds`: 该次工具尝试执行时长（秒） [type: `number`] [min: `0`]
      - `output`: 按工具 output-schema 或 error-output-schema 派生的结构化输出，字段集合由工具定义直接提供 [type: `object`] [optional] [nullable] [closed]
        - `echo-tool.result`: 工具返回的回显结果 [type: `string`]
        - `failing-tool.error`: 失败摘要消息 [type: `string`]
        - `failing-tool.code`: 稳定错误码 [type: `string`]
      - `error`: 失败时的人类可读摘要，成功时为 null [type: `string`] [optional] [nullable]
      - `errorCode`: 稳定错误码，成功时为 null [type: `string`] [allowed: `FAIL`, `PERMISSION-DENIED`, `TOOL-NOT-FOUND`] [optional] [nullable]
- Options:
  - -o, --output-format <output-format>  指定输出格式: text 或 json [default: text]
  - --pretty  以多行缩进格式输出 JSON [requires: --output-format=json] [conflicts: --compact]
  - --compact  以紧凑单行格式输出 JSON [requires: --output-format=json] [conflicts: --pretty]
  - -t, --tool <tool-id>  覆盖自动工具选择并按给定顺序执行 [repeatable]

### `session resume`

- Usage: `cl-cc session resume <session-id-or-path> [--output-format <output-format>]`
- Summary: 恢复已有会话
- Aliases: `cl-cc s resume`
- Output Schema: `text`: session resume message; `json`: `status`, `sessionId`, `historyIndex`, `sessionStatus`, `durationSeconds`, `exitCode` [closed]
- JSON Fields:
  - `status`: 结果状态，当前固定为 success [type: `string`] [allowed: `success`]
  - `sessionId`: 恢复后的会话 ID [type: `string`]
  - `historyIndex`: 恢复快照中的历史索引，缺失时为 null [type: `integer`] [min: `0`] [optional] [nullable]
  - `sessionStatus`: 恢复后的会话状态 [type: `string`] [allowed: `active`] [optional] [nullable]
  - `durationSeconds`: 本次 session resume 执行时长（秒） [type: `number`] [min: `0`]
  - `exitCode`: 命令退出码 [type: `integer`] [min: `0`] [max: `255`]
- Options:
  - -o, --output-format <output-format>  指定输出格式: text 或 json [default: text]

### `session start`

- Usage: `cl-cc session start [--session-id <session-id>] [--history-index <history-index>] [--output-format <output-format>]`
- Summary: 启动新会话
- Aliases: `cl-cc s start`
- Output Schema: `text`: session start message; `json`: `status`, `sessionId`, `historyIndex`, `sessionStatus`, `durationSeconds`, `exitCode` [closed]
- JSON Fields:
  - `status`: 结果状态，当前固定为 success [type: `string`] [allowed: `success`]
  - `sessionId`: 新会话 ID [type: `string`]
  - `historyIndex`: 初始历史索引，未指定时为 null [type: `integer`] [min: `0`] [optional] [nullable]
  - `sessionStatus`: 会话状态，当前通常为 active [type: `string`] [allowed: `active`] [optional] [nullable]
  - `durationSeconds`: 本次 session start 执行时长（秒） [type: `number`] [min: `0`]
  - `exitCode`: 命令退出码 [type: `integer`] [min: `0`] [max: `255`]
- Options:
  - -i, --session-id <session-id>  显式指定新会话 ID
  - --history-index <history-index>  设置初始历史索引
  - -o, --output-format <output-format>  指定输出格式: text 或 json [default: text]

## 工具参考

### `echo-tool`

- Summary: 回显输入字符串
- Input Schema: `text`: input string; `json`: `input` [closed]
- Input JSON Fields:
  - `input`: 待回显的输入字符串 [type: `string`]
- Output Schema: `text`: echoed string; `json`: `result` [closed]
- Output JSON Fields:
  - `result`: 工具返回的回显结果 [type: `string`]
- Permission Profile: `default`

### `failing-tool`

- Summary: 始终返回失败，用于验证错误传播
- Input Schema: `text`: input string; `json`: `input` [closed]
- Input JSON Fields:
  - `input`: 触发失败路径的输入字符串 [type: `string`]
- Output Schema: `text`: no successful output
- Error Output Schema: `text`: failed output; `json`: `error`, `code` [closed]
- Error JSON Fields:
  - `error`: 失败摘要消息 [type: `string`]
  - `code`: 稳定错误码 [type: `string`]
- Failure Modes: `failed`
- Permission Profile: `default`


<!-- END GENERATED COMMAND REFERENCE -->

## 目录概览

- `src/`：运行时代码
- `tests/`：unit / integration / contract 测试
- `fixtures/`：contracts / sessions / golden 样例
- `docs/compatibility/`：参考映射与验证记录

## 原则

- 产品运行时代码与测试代码保持纯 Common Lisp
- `cc-source/` 仅用于研究和兼容性映射，不作为运行时依赖
- 优先可验证、可回归、可审计的最小实现