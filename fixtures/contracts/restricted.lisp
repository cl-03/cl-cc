(:fixture-id "restricted"
 :input "restricted"
 :expected-output "[FAILED] all tools failed"
 :notes "用于验证权限拒绝路径，执行层会把 restricted 输入映射到 delete-file 动作。")