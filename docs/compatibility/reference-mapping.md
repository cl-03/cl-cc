# Reference Mapping

本文件记录 CL-CC 当前实现与参考研究结论之间的最小映射关系。

## 启动装配

- 目标能力：CLI 启动、帮助输出、命令分发。
- 当前实现：`src/cli/main.lisp`、`src/cli/argv.lisp`、`src/cli/help-command.lisp`。
- 当前状态：已支持 `--help`、`session start`、`session resume`、`run --fixture`，并通过 command registry 统一分发；帮助文本也由注册表元数据生成。

## 命令系统

- 目标能力：命令注册、子命令路由、统一退出码。
- 当前实现：`src/core/command-registry.lisp` 与 `src/cli/*.lisp`。
- 当前状态：CLI 主入口已通过 command registry 分发 `help`、`session start`、`session resume`、`run --fixture`，且注册表已存放 `command-definition` 元数据对象。
- 当前状态补充：aliases 已参与实际分发，`arguments-schema` 已支持位置参数与命名参数校验，并通过统一错误输出返回 `invalid-arguments`。
- 当前状态补充：帮助渲染已直接展示 schema 派生的 usage 与 option 摘要，`session start -i <id> --history-index <n>` 已打通到实际 handler。
- 当前状态补充：`run --fixture` 已支持 `-o/--output-format text|json`，并可解析 `--output-format=json` 形式。
- 当前状态补充：`run --fixture` 的 JSON 输出已统一为稳定 envelope；单 fixture 与多 fixture 都返回顶层 `status`、`fixtureCount`、`successfulCount`、`failedCount`、`statusCounts`、`ok`、`exitCode`、`results`，`results` 中再承载每个 fixture 的 `fixtureId`、`status`、`result` 与 `toolResults`；`toolResults` 会逐项暴露 `toolId`、`status`、`output`、`error`、`errorCode`，其中成功路径的 `output` 会按工具 `output-schema` 派生结构化字段；`statusCounts` 为后续 `denied`、`not-found` 等状态扩展保留了稳定结构，且 `exitCode` 现在由聚合状态真实派生并与 CLI 实际返回值对齐。
- 参考纠偏补充：对照 `cc-source` 的 structured/machine-readable 输出约束后，CL-CC 当前已将 `debug-log` 统一切到 `stderr`，避免在 `run --fixture --output-format json` 等自动化路径中污染 `stdout` JSON 载荷。
- 参考纠偏补充：对照 `cc-source` 更细粒度的错误/结果语义后，CL-CC 当前已将 `permission-denied` 与 `tool-not-found` 从底层执行记录一路提升到 `run --fixture` 的顶层聚合 `status` 与 `exitCode`，不再一律塌缩为 `failed`。
- 参考纠偏补充：顶层聚合 `status` 现已改为显式优先级规则而不是零散条件判断；全成功时为 `success`，单一失败类型保持 `denied` / `not-found` / `failed`，只要出现混合结果就稳定聚合为 `partial`。
- 参考纠偏补充：`run --fixture` 的 service 层现已先返回 `cl-cc.lib:result` 结构化对象，再由 `src/cli/run-command.lisp` 统一负责 text/json 序列化；这更接近 `cc-source` 的 structured output 分层，同时仍保持纯 Common Lisp 实现。现有 golden regression 通过 `result-message` 兼容既有文本 golden fixture。
- 参考纠偏补充：`docs sync-reference` 已同步切换到相同分层，先构造 `cl-cc.lib:result`，再经 `src/cli/result-rendering.lisp` 输出 machine-readable JSON；`run` 与 `docs` 不再各自维护一套 JSON 拼装逻辑。
- 参考纠偏补充：`session start` 与 `session resume` 也已切换到同一模式；service 层保留返回 `session-state` 的底层 API，同时新增 result-first 包装，由 CLI 统一经 `src/cli/result-rendering.lisp` 输出稳定 text 摘要。
- 当前状态补充：`session start` 与 `session resume` 现已支持 `-o/--output-format text|json`；JSON 输出当前稳定包含 `status`、`sessionId`、`historyIndex`、`sessionStatus`、`exitCode`，使 session 命令的 output-schema 也成为可执行契约，而不只是帮助元数据。
- 当前状态补充：`command-definition` 现已同时承载 `arguments-schema` 与 `output-schema`；README 生成命令参考会直接展示 registry 声明的输出契约，当前已覆盖 `docs sync-reference`、`run --fixture`、`help`、`session start`、`session resume`。
- 当前状态补充：`output-schema` 的 `:json` 元数据现已从简单字段名列表升级为带 `:name` / `:summary` 的字段描述；`src/cli/help-command.lisp` 会从 registry metadata 同时生成 `Output Schema` 与 `JSON Fields`，使字段级说明也成为可回归、可文档生成的单一事实来源。
- 当前状态补充：命令 `output-schema` 的字段描述现已支持嵌套 `:fields`；`run --fixture` 当前会在命令参考中继续展开 `results.fixtureId` / `results.status` / `results.result` / `results.toolResults.*`，从而把嵌套 payload 结构也纳入 registry 驱动的帮助与 README 契约。
- 当前状态补充：命令字段描述当前还可通过 `:tool-schema-refs` 直接展开工具定义中的 `output-schema` / `error-output-schema`；`run --fixture` 的 `toolResults.output` 现已直接引用 `echo-tool` 与 `failing-tool` 的工具输出契约，而不是重复维护一份平行字段说明。
- 当前状态补充：`src/services/schema-validation.lisp` 现已把这份 registry-driven `run --fixture` 输出契约推进到运行时校验层；contract test 不再只断言样例值，而会把 `cl-cc.lib:result` 规范化为对外 JSON envelope 后，递归验证顶层字段、`results` 集合、`toolResults` 集合，以及通过 `:tool-schema-refs` 派生出的工具 success/error 输出字段。
- 当前状态补充：`statusCounts` 现也已纳入字段级 output-schema，不再只是“计数映射”摘要；命令参考、README 生成块与运行时 validator 当前都按稳定对象字段 `success`、`failed`、`partial`、`denied`、`not-found`、`unknown` 对齐。
- 当前状态补充：命令输出 schema 字段当前还支持 `:enum` 与 `:nullable` 语义；`run --fixture` 已开始用它们约束顶层/fixture/tool 级 `status` 和 `errorCode` 等稳定字段，帮助文档会直接展示允许值，运行时 validator 也会基于规范化后的外部 JSON 表示拒绝非法枚举值。
- 当前状态补充：结果 schema 校验入口现已抽象为按命令名分派的通用机制，而非仅服务 `run --fixture`；`docs sync-reference`、`session start`、`session resume` 现也会把内部 `cl-cc.lib:result` 规范化成各自的对外 JSON envelope，再按 command registry 中的 `output-schema` 做递归校验。
- 当前状态补充：命令/工具 schema 字段现还支持 `:type` 元数据；帮助与 README 会直接标注 `string` / `integer` / `boolean` / `object` 等类型，运行时 validator 也会对这些稳定字段执行真实类型检查，而不是只校验字段存在性、可空性和枚举值。
- 当前状态补充：output-schema 字段现已支持显式 `:required` 语义，默认仍为必填；帮助和 README 会为 `:required nil` 的字段显示 `[optional]`，运行时 validator 也会接受这些字段缺失，同时保留“字段存在时仍需通过 type/enum/bounds/nullable 校验”的约束。
- 当前状态补充：output-schema 与 tool schema 现还支持显式 `:closed` 语义；docs/session/run 的顶层 JSON envelope 以及 `statusCounts`、`results[*]`、`toolResults[*]`、`toolResults.output` 等关键嵌套对象都已声明为 closed shape，帮助和 README 会显示 `[closed]`，运行时 validator 会拒绝 schema 未声明的额外字段。结果对象规范化层同时保留 optional 字段的“缺失 vs null”区别，避免在内部 envelope 转换时把缺失字段错误扩展成显式 `null`。
- 当前状态补充：array 字段现已支持 `:min-items` 集合基数约束；当前稳定能力首先用于 `run --fixture.results` 与 `results[*].toolResults`，要求这些自动化关键集合至少包含 1 个元素。帮助和 README 会直接显示 `[min-items: 1]`，运行时 validator 与负例契约测试会拒绝空集合结果。
- 当前状态补充：output-schema 字段现还支持 relation 约束，至少包括 `:equals-field` 与 `:equals-collection-size-of`；当前 `run --fixture.fixtureCount` 已声明必须等于 `results` 的元素个数，`successfulCount` 与 `failedCount` 则分别绑定 `statusCounts.success` 与 `statusCounts.failed`。帮助和 README 会直接显示 `[count-of: ...]` / `[matches: ...]`，运行时 validator 与负例契约测试会拒绝这些汇总字段与同一 payload 中其他字段不一致的结果对象。
- 当前状态补充：relation 约束现已扩展到布尔字段；`run --fixture.ok` 当前通过 `:true-when-zero-field "exitCode"` 绑定到退出码语义，要求 `exitCode = 0` 时 `ok = true`，非零时 `ok = false`。帮助和 README 会显示 `[true-when-zero: exitCode]`，运行时 validator 与负例契约测试会拒绝 `ok` 与 `exitCode` 不一致的结果对象。
- 当前状态补充：relation 约束现已扩展到条件枚举字段；`run --fixture.status` 当前通过 `:enum-when-zero-field (:field "exitCode" :values ("success"))` 与 `:enum-when-nonzero-field (:field "exitCode" :values ("partial" "failed" "denied" "not-found"))` 绑定到退出码语义，要求 `exitCode = 0` 时顶层状态只能为 `success`，非零时只能为非成功聚合状态。帮助和 README 会显示 `[allowed-when-zero: exitCode => success]` 与 `[allowed-when-nonzero: exitCode => ...]`，运行时 validator 与负例契约测试会拒绝 `status` 与 `exitCode` 不一致的结果对象。
- 当前状态补充：relation 约束现已继续扩展到条件相等字段；`run --fixture.statusCounts.success` / `failed` / `denied` / `not-found` 当前可通过 `:equals-field-when-value (:when-field "status" :value ... :field "fixtureCount")` 绑定到顶层聚合状态，要求当顶层 `status` 声称为这些单一聚合状态之一时，对应计数字段必须等于 `fixtureCount`。帮助和 README 会显示 `[matches-when: status = ... => fixtureCount]`，运行时 validator 与负例契约测试会拒绝“聚合状态”与“状态计数”彼此不一致的结果对象。
- 当前状态补充：relation 约束现已继续扩展到聚合求和字段；`run --fixture.fixtureCount` 当前可通过 `:equals-sum-of-fields (:fields ("statusCounts.success" ...))` 绑定到整组 `statusCounts.*` 字段，要求总 fixture 数必须等于各状态计数字段的总和。帮助和 README 会显示 `[sum-of: ...]`，运行时 validator 与负例契约测试会拒绝“fixture 总数”和“状态分布总和”彼此不一致的结果对象。
- 当前状态补充：CLI 的 machine-readable 输出当前已不只验证内部 `cl-cc.lib:result` 对象；`src/services/schema-validation.lisp` 现还提供最小 JSON 解析与按命令 output-schema 校验真实序列化字符串的入口，contract test 已覆盖 `session`、`docs`、`run --fixture` 的实际 JSON 输出，包括 pretty 模式下的多行 JSON。
- 当前状态补充：`run --fixture` 的集合字段当前已开始显式使用 `:type :array`，至少覆盖 `results` 与 `toolResults`；validator 现会把 keyword property list 识别为 `object`，把记录集合识别为 `array`，从而让嵌套集合契约具备真实类型约束，而不是仅依赖 `:collection` 的递归遍历副作用。
- 当前状态补充：稳定 JSON 命令当前都已开始使用 `durationSeconds` 数值字段：`run --fixture` 在顶层/fixture/tool 三级输出耗时，`docs sync-reference`、`session start`、`session resume` 也会暴露命令级耗时；这些字段统一声明为 `:type :number`，执行层记录真实耗时，CLI JSON 渲染稳定输出非整数 JSON number，运行时 schema validator 与实际 JSON-string-level contract test 会同时验证这些数值字段。
- 当前状态补充：数值型 output-schema 字段现还支持 `:minimum` 边界；`historyIndex`、各类 count、`exitCode` 与 `durationSeconds` 已统一声明为非负值，帮助/README 会直接显示 `[min: 0]`，运行时 validator 与负例契约测试也会拒绝小于 0 的结果值。
- 当前状态补充：数值型 output-schema 字段现还支持 `:maximum` 边界；当前稳定语义首先用于 `exitCode`，统一限制在 `0..255`，帮助/README 会直接显示 `[max: 255]`，运行时 validator 与负例契约测试会拒绝越界退出码。
- 当前状态补充：参数 schema 已支持默认值与可重复 option 聚合，`run --fixture -t failing-tool -t echo-tool` 会按给定顺序覆盖自动工具选择。
- 当前状态补充：参数 schema 已支持 option 依赖与互斥约束，`run --fixture --pretty` / `--compact` 只能在 JSON 输出模式下使用，且不能同时出现。
- 当前状态补充：`docs sync-reference [<output-path>] [--check] [--output-format text|json]` 已可直接刷新 README 生成命令参考区块，或以 text/json 形式检查文档是否与 registry 派生输出发生漂移；JSON 输出当前稳定包含 `path`、`status`、`checkOnly`、`updated`、`needsSync`、`exitCode` 字段，且在无漂移时不会重复写回文件。
- 当前偏离：参数 schema 还未包含更细的复合类型系统、跨参数条件默认值和多值位置参数语义；帮助渲染也尚未按权限配置或上下文动态裁剪。

## 工具系统

- 目标能力：工具注册、选择、执行、失败传播。
- 当前实现：`src/tools/registry.lisp`、`src/tools/echo-tool.lisp`、`src/tools/failing-tool.lisp`、`src/services/tool-selection.lisp`、`src/services/tool-runner.lisp`。
- 当前状态：已具备成功路径、失败路径、权限拒绝前置检查。
- 当前状态补充：工具注册表现已存放 `tool-definition` 元数据对象而非裸 handler；运行时仍可通过 `find-tool` 取得处理函数，但 `summary`、`input-schema`、`output-schema`、`error-output-schema`、`failure-modes`、`permission-profile` 已进入统一 registry；其中工具 schema 当前也已支持带 `:name` / `:summary` / `:source` 的 JSON 字段描述，README 生成区块可直接派生 `工具参考`、`Input JSON Fields`、`Output JSON Fields` 与 `Error JSON Fields`。
- 当前状态补充：执行层当前已不再依赖字段名特判 `result` / `error` / `code` 来构造结构化工具输出；成功/失败输出均按工具 schema 中声明的 `:source` 从原始结果或错误对象派生。

## 执行循环

- 目标能力：请求推进、上下文输入、结果归档。
- 当前实现：`src/core/execution-context.lisp`、`src/core/execution-engine.lisp`。
- 当前状态：支持多工具顺序尝试、统一成功/失败摘要与执行结果归档。

## 权限边界

- 目标能力：高风险动作允许/拒绝判定及审计输出。
- 当前实现：`src/services/permission-policy.lisp`、`src/services/permission-audit.lisp`。
- 当前状态：高风险动作如 `delete-file` 默认拒绝，并生成权限审计对象。

## 会话恢复

- 目标能力：保存、恢复、损坏安全失败、版本校验。
- 当前实现：`src/session/serializer.lisp`、`src/session/store.lisp`、`src/services/session-service.lisp`。
- 当前状态：支持可读 s-expression 快照、版本 `0.1` 校验、损坏快照抛出统一错误。

## Session Loop

- 目标能力：会话级推进、上下文生成、history 索引更新。
- 当前实现：`src/core/session-loop.lisp`、`src/core/execution-context.lisp`。
- 当前状态：最小 session loop 已能创建 execution-context、推进状态、更新 `history-index`，并将初始会话事件与后续 loop 事件写入 `history-trail`。

## 兼容性回归

- 目标能力：golden case 固化与偏差比较。
- 当前实现：`fixtures/golden/`、`src/services/golden-regression.lisp`、`tests/contract/golden-regression-test.lisp`。
- 当前状态：已建立首个 strict golden case，用于校验基础 echo 执行链路。