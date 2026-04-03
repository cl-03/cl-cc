# Quickstart: CL-CC Core Runtime Reconstruction

## Goal

验证首批纯 Common Lisp 核心运行时能力已经形成一个最小可用基线：CLI 启动、命令帮助、脚本化执行循环、权限拒绝、会话保存与恢复、兼容性夹具回归。

## Prerequisites

- 已安装目标 Common Lisp 实现（首发为 SBCL 2.4.x）
- 工作目录位于仓库根目录
- 已生成并加载项目 ASDF 系统（推荐入口：`cl-cc.asd`）
- 测试夹具与 golden outputs 已放入约定目录

## Canonical Test Command

```powershell
sbcl --noinform --non-interactive --load cl-cc.asd --eval "(asdf:test-system :cl-cc)" --quit
```

## Scenario 1: 启动 CLI 并查看帮助

1. 启动 CL-CC CLI。
2. 请求帮助输出。
3. 验证结果：
   - 显示稳定的命令入口
   - 显示错误处理或用法提示
   - 无跨语言运行时依赖痕迹

## Scenario 2: 跑通一次基础脚本化会话

1. 使用固定输入触发一个基础命令。
2. 让执行循环完成命令分发、上下文推进和工具调用。
3. 验证结果：
   - 产生一个新的会话标识
   - 记录执行前后上下文摘要
   - 输出成功或失败的统一结果结构

## Scenario 3: 验证权限拒绝路径

1. 触发一个被权限策略标记为高风险的动作。
2. 让权限层做出拒绝判定。
3. 验证结果：
   - 返回稳定的拒绝状态
   - 输出明确的原因码和可读说明
   - 会话状态仍保持可审计且不损坏

## Scenario 4: 验证会话恢复路径

1. 先执行一次会话并保存快照。
2. 使用恢复命令加载该快照。
3. 验证结果：
   - 恢复成功时可以继续处理后续命令
   - 若快照损坏或版本不匹配，系统安全失败并提供诊断信息

## Scenario 5: 跑兼容性回归夹具

1. 选择首批 golden cases。
2. 运行 contract/golden regression 测试。
3. 验证结果：
   - 严格一致的场景通过
   - 有意偏离的场景被显式标记并附带说明
   - 未解释偏差视为失败

## Done When

- 上述 5 个场景全部可以本地复现
- 每个场景都有自动化验证入口
- 所有运行时能力均保持纯 Common Lisp 实现
