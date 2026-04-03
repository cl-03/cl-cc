;;;; src/services/permission-policy.lisp - 权限策略抽象
(in-package :cl-cc.services)

(defparameter +default-allowed-actions+
  '("file-write" "file-read" "run-fixture" "echo-tool" "failing-tool" "file-edit-tool"))

(defun %permission-action-name (action)
  (cl-cc.lib:string-designator-downcase action))

(defun %default-action-allowed-p (action)
  (member (%permission-action-name action) +default-allowed-actions+ :test #'string=))

(defun check-permission (action context)
  "根据 action/context 判定权限。"
  (declare (ignore context))
  (if (%default-action-allowed-p action)
      :allow
      :deny))
