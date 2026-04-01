(:fixture-id "echo-basic"
 :reference-source "cc-source research synthesis"
 :scenario-name "baseline echo execution"
 :expected-output "[SUCCESS] tool:echo-tool result:fixture-input-echo-basic"
 :deviation-policy :strict
 :notes "当前最小 golden case：脚本化请求经过工具选择、echo-tool 执行与统一摘要输出。")