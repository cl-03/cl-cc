;;;; src/services/tool-selection.lisp - 工具选择逻辑
(in-package :cl-cc.services)

(defun select-tools (context)
  "根据 context 选择工具，默认返回 echo-tool。context 可扩展。"
  (cond
    ((string= context "fail") (list "failing-tool" "echo-tool"))
    (t (list "echo-tool" "failing-tool"))))
