# Validation Report

日期：2026-04-02

## Quickstart Scenario 1: CLI 帮助

- 验证入口：`cl-cc/tests` 中 `cli-help-contract-test` 与 `cli-output-test`
- 结果：通过
- 说明：帮助输出包含 `Usage:`、`docs sync-reference [<output-path>] [--check] [--output-format <output-format>]`、`session start`、`run --fixture`；README 生成参考当前会直接展示 command registry 派生的 Output Schema 与 `JSON Fields` 区块，并继续追加 tool registry 派生的 `工具参考` 区块；工具 schema 当前会分别展示 `Input JSON Fields`、`Output JSON Fields` 与 `Error JSON Fields`；其中 `run --fixture` 的命令契约已继续展开嵌套的 `results` / `toolResults` 子字段；当前已覆盖 `docs sync-reference`、`run --fixture`、`help`、`session start`、`session resume`、`echo-tool`、`failing-tool`

## Quickstart Scenario 1.1: 文档同步状态输出

- 验证入口：`command-dispatch-test`
- 结果：通过
- 说明：`docs sync-reference --check --output-format json` 会稳定返回 `path`、`status`、`checkOnly`、`updated`、`needsSync`、`exitCode`；无漂移时再次同步不会重复写回文件；当前与 `run --fixture` 共用 CLI 侧结构化结果渲染路径

## Quickstart Scenario 2: 基础脚本化会话

- 验证入口：`run-fixture-contract-test`、`tool-execution-test`
- 结果：通过
- 说明：`echo-tool` 成功返回统一摘要；`failing-tool` 失败路径可审计；工具注册表当前已从裸 handler 升级为 `tool-definition` 元数据对象，执行路径仍通过 `find-tool` 取得处理函数，兼容既有调用面；`run --fixture` 的 service 层当前先返回结构化 `cl-cc.lib:result`，CLI 再统一渲染 text/json；JSON 输出稳定返回 `status`、`fixtureCount`、`successfulCount`、`failedCount`、`statusCounts`、`ok`、`exitCode`、`results`，且每条 fixture 记录已附带结构化 `toolResults`；`exitCode` 与 CLI 实际返回码一致；调试日志已改走 `stderr`，不再污染 machine-readable `stdout`；顶层 `status` 现可区分 `failed`、`denied`、`not-found`，混合结果会稳定聚合为 `partial`；当前与 `docs sync-reference` 共用 `src/cli/result-rendering.lisp` 渲染层
- 说明补充：工具定义当前已把成功输出 `output-schema` 与失败输出 `error-output-schema` 分开建模，并支持字段级 `:source` 元数据；`toolResults.output` 会直接按工具 schema 派生结构化 success/error 字段。

## Quickstart Scenario 2.1: run --fixture schema conformance

- 验证入口：`run-fixture-contract-test`
- 结果：通过
- 说明：`src/services/schema-validation.lisp` 现已基于 command registry 中 `run --fixture` 的 `output-schema` 递归校验实际结果对象；校验入口会先把内部 `cl-cc.lib:result` 规范化为 CLI JSON envelope，再验证顶层 `status`、聚合计数、逐 fixture 记录，以及 `toolResults.output` 通过 `:tool-schema-refs` 引用的工具 success/error schema；成功路径中未显式存储的 `error` / `errorCode` 也会按对外契约视为 `null`。

## Quickstart Scenario 2.2: statusCounts field-level contract

- 验证入口：`cli-help-contract-test`、`run-fixture-contract-test`
- 结果：通过
- 说明：`run --fixture` 的 `statusCounts` 已从摘要说明升级为字段级 schema，当前稳定暴露 `success`、`failed`、`partial`、`denied`、`not-found`、`unknown` 六个计数字段；README/generated help 与运行时 schema validator 都已同步按该对象契约验证。

## Quickstart Scenario 2.3: enum and nullable output semantics

- 验证入口：`cli-help-contract-test`、`run-fixture-contract-test`
- 结果：通过
- 说明：`run --fixture` 的稳定 JSON 字段现已开始声明并验证值域语义；当前至少覆盖顶层 `status`、fixture 级 `status`、tool 级 `status` 以及 `errorCode` 的枚举集合，并显式声明 `error` / `errorCode` 在成功路径可为 `null`；contract test 现包含故意构造的非法结果对象，确认 validator 会拒绝超出 schema 枚举的值。

## Quickstart Scenario 2.4: generic command result schema validation

- 验证入口：`result-schema-contract-test`
- 结果：通过
- 说明：`src/services/schema-validation.lisp` 现已从 `run --fixture` 专用校验入口提升为按命令名分派的通用结果校验器；当前已覆盖 `docs sync-reference`、`session start`、`session resume`、`run --fixture` 四类 `cl-cc.lib:result` 对象，并对 docs/session 的对外 JSON envelope 做统一规范化后再校验 command registry 中声明的 output-schema。

## Quickstart Scenario 2.5: primitive type validation

- 验证入口：`result-schema-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：命令与工具 output-schema 字段现已支持 `:type` 元数据，并至少覆盖 `string`、`integer`、`boolean`、`object` 四类值；帮助/README 生成块会直接标注字段类型，运行时 validator 则会拒绝类型不匹配的结果对象，例如把 `historyIndex` 伪造成字符串或把 `checkOnly` 伪造成文本值的场景。

## Quickstart Scenario 2.6: rendered CLI JSON output validation

- 验证入口：`cli-json-output-contract-test`
- 结果：通过
- 说明：`src/services/schema-validation.lisp` 现已增加对真实 CLI JSON 字符串的最小解析与 schema 校验入口；`session start`、`session resume`、`docs sync-reference`、`run --fixture` 的 compact/pretty JSON 输出都会先被解析，再按 command registry 中声明的 output-schema 递归验证，从而把契约检查从内部 result 对象推进到最终序列化产物。

## Quickstart Scenario 2.7: explicit array type validation

- 验证入口：`run-fixture-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：`run --fixture` 的 `results` 与 `toolResults` 字段现已显式声明为 `array` 类型；validator 会区分 property-list object 与 collection array，不再把二者都按普通 list 宽松接受。契约测试现已覆盖“对象冒充数组”的负例，并确认运行时会返回预期的 schema type error，而不是在 envelope 规范化阶段抛出 Lisp 条件。

## Quickstart Scenario 2.8: number-typed duration fields

- 验证入口：`run-fixture-contract-test`、`cli-json-output-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：`run --fixture`、`docs sync-reference`、`session start`、`session resume` 的稳定 JSON 输出现都已暴露 `durationSeconds` 字段，并显式声明为 `number` 类型；运行时会测量真实执行时长，CLI JSON 渲染也已支持非整数 JSON number 序列化，使 `:number` 从 validator 预留能力升级为实际在 machine-readable 输出中使用的契约类型。

## Quickstart Scenario 2.9: non-negative numeric bounds

- 验证入口：`result-schema-contract-test`、`run-fixture-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：output-schema 字段现已支持 `:minimum` 数值边界；`historyIndex`、`fixtureCount`、`successfulCount`、`failedCount`、`statusCounts.*`、`exitCode` 以及 docs/session/run 各层 `durationSeconds` 都统一声明为非负值。帮助和 README 生成块会直接显示 `[min: 0]`，运行时 validator 也会在契约测试中拒绝负数结果对象。

## Quickstart Scenario 2.10: bounded exit codes

- 验证入口：`result-schema-contract-test`、`run-fixture-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：output-schema 字段现已支持 `:maximum` 数值边界；当前稳定能力首先用于 `exitCode`，将 docs/session/run 的命令退出码统一限制在 `0..255`。帮助和 README 生成块会直接显示 `[max: 255]`，运行时 validator 与负例契约测试也会拒绝超出上界的结果对象。

## Quickstart Scenario 2.11: explicit optional fields

- 验证入口：`result-schema-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：output-schema 字段现已支持显式 `:required` 语义，默认字段仍为必填；当前 session 的 `historyIndex` / `sessionStatus` 以及 run 的 `toolResults.output` / `error` / `errorCode` 已开始声明为 optional。帮助和 README 生成块会直接显示 `[optional]`，运行时 validator 也会接受这些字段缺失，同时保留字段存在时的类型和值域校验。

## Quickstart Scenario 2.12: closed object contracts

- 验证入口：`result-schema-contract-test`、`cli-json-output-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：output-schema 与 tool schema 现已支持显式 `:closed` 语义；当前 docs/session/run 的顶层 JSON envelope 以及 `run --fixture.statusCounts`、`results[*]`、`toolResults[*]`、`toolResults.output` 等关键嵌套对象都已声明为 closed shape。帮助和 README 生成块会直接显示 `[closed]`，运行时 validator 会拒绝 schema 未声明的额外字段；同时 result-object 规范化层已保留 optional 字段的“缺失 vs null”区别，避免在内部 envelope 转换时破坏 `:required nil` 语义。

## Quickstart Scenario 2.13: non-empty array contracts

- 验证入口：`run-fixture-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：array 字段现已支持 `:min-items` 集合基数约束；当前稳定能力首先用于 `run --fixture.results` 与 `results[*].toolResults`，要求这些关键自动化数组至少包含 1 个元素。帮助和 README 生成块会直接显示 `[min-items: 1]`，运行时 validator 与负例契约测试也会拒绝空数组结果。

## Quickstart Scenario 2.14: cross-field count consistency

- 验证入口：`run-fixture-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：output-schema 字段现已支持 relation 约束；当前 `run --fixture.fixtureCount` 必须匹配 `results` 的实际元素个数，`successfulCount` 与 `failedCount` 则分别匹配 `statusCounts.success` 与 `statusCounts.failed`。帮助和 README 生成块会直接显示 `[count-of: ...]` / `[matches: ...]`，运行时 validator 与负例契约测试会拒绝计数字段彼此不一致的结果对象。

## Quickstart Scenario 2.15: ok/exitCode consistency

- 验证入口：`run-fixture-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：relation 约束现已扩展到布尔字段；当前 `run --fixture.ok` 通过 `:true-when-zero-field "exitCode"` 与退出码绑定，要求 `exitCode = 0` 时 `ok = true`，非零时 `ok = false`。帮助和 README 生成块会直接显示 `[true-when-zero: exitCode]`，运行时 validator 与负例契约测试会拒绝 `ok` 与 `exitCode` 不一致的结果对象。

## Quickstart Scenario 2.16: status/exitCode consistency

- 验证入口：`run-fixture-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：relation 约束现已扩展到条件枚举字段；当前 `run --fixture.status` 通过 `:enum-when-zero-field` / `:enum-when-nonzero-field` 绑定到 `exitCode`，要求 `exitCode = 0` 时顶层聚合状态只能是 `success`，非零时只能是 `partial`、`failed`、`denied`、`not-found`。帮助和 README 生成块会直接显示 `[allowed-when-zero: exitCode => success]` 与 `[allowed-when-nonzero: exitCode => ...]`，运行时 validator 与负例契约测试会拒绝 `status` 与 `exitCode` 不一致的结果对象。

## Quickstart Scenario 2.17: aggregate status/count consistency

- 验证入口：`run-fixture-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：relation 约束现已继续扩展到条件相等字段；当前 `run --fixture.statusCounts.success` / `failed` / `denied` / `not-found` 可通过 `:equals-field-when-value` 绑定顶层 `status` 与 `fixtureCount`，要求当聚合状态分别声称为 `success`、`failed`、`denied`、`not-found` 时，对应计数字段必须等于总 `fixtureCount`。帮助和 README 生成块会直接显示 `[matches-when: status = ... => fixtureCount]`，运行时 validator 与负例契约测试会拒绝“顶层状态声明”和“聚合计数”彼此不一致的结果对象。

## Quickstart Scenario 2.18: fixtureCount/statusCounts sum consistency

- 验证入口：`run-fixture-contract-test`、`cli-help-contract-test`
- 结果：通过
- 说明：relation 约束现已继续扩展到聚合求和字段；当前 `run --fixture.fixtureCount` 除了必须匹配 `results` 的实际元素个数，还通过 `:equals-sum-of-fields` 绑定到 `statusCounts.success`、`failed`、`partial`、`denied`、`not-found`、`unknown` 的总和。帮助和 README 生成块会直接显示 `[sum-of: ...]`，运行时 validator 与负例契约测试会拒绝“总 fixture 数”和“各状态分布总和”彼此不一致的结果对象。

## Quickstart Scenario 3: 权限拒绝路径

- 验证入口：`permission-contract-test`
- 结果：通过
- 说明：高风险动作 `delete-file` 被拒绝，并生成 `permission-decision`

## Quickstart Scenario 4: 会话恢复路径

- 验证入口：`session-resume-test`
- 结果：通过
- 说明：有效快照可恢复；损坏快照返回统一 `cl-cc-error`；`session start` 与 `session resume` 当前也已切换到先产出 `cl-cc.lib:result`、再由 CLI 统一渲染输出的路径，并支持稳定 JSON 字段 `status`、`sessionId`、`historyIndex`、`sessionStatus`、`exitCode`

## Quickstart Scenario 5: golden 回归

- 验证入口：`golden-regression-test`
- 结果：通过
- 说明：首个 strict golden case `echo-basic` 与当前输出一致；`compare-golden` 已兼容 `cl-cc.lib:result` 并按 `result-message` 对照既有文本 golden fixture

## Full Test Run

- 命令：`sbcl --noinform --non-interactive --load cl-cc.asd --eval "(asdf:test-system :cl-cc)" --quit`
- 结果：`472` checks passed, `0` failed