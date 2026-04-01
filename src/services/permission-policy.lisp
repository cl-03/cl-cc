;;;; src/services/permission-policy.lisp - 权限策略抽象
(in-package :cl-cc.services)

(defun check-permission (action context)
  "根据 action/context 判定权限。"
  (declare (ignore context))
  (if (member (string-downcase (string action)) '("file-write" "file-read" "run-fixture" "echo-tool" "failing-tool") :test #'string=)
      :allow
      :deny))
