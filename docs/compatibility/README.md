# 兼容性与夹具目录说明

本目录用于存放 CL-CC 的 golden case 夹具、兼容性回归样例与参考映射文档。

- `fixtures/contracts/`：契约级输入输出夹具
- `fixtures/sessions/`：会话状态快照夹具
- `fixtures/golden/`：兼容性 golden case 夹具
- `reference-mapping.md`：参考实现与当前实现的行为映射说明
- `validation-report.md`：quickstart 场景与回归结果记录

所有夹具均需保持纯 Common Lisp 可读写格式，不得依赖外部语言或二进制序列化。

当前已提供：

- `reference-mapping.md`：能力域映射与当前偏离点
- `validation-report.md`：quickstart 五场景验证记录
- `fixtures/golden/echo-basic.lisp`：首个 strict golden case