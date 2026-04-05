;;;; tests/unit/permission-policy-test.lisp - 权限策略单元测试
(in-package :cl-cc/tests)

(def-suite permission-policy-test :in cl-cc-suite)

(in-suite permission-policy-test)

(test check-permission-default
  (is (eq (cl-cc.services:check-permission 'file-write nil) :allow))
  (is (eq (cl-cc.services:check-permission 'file-edit-tool nil) :allow))
  (is (eq (cl-cc.services:check-permission 'shell-tool nil) :allow))
  (is (eq (cl-cc.services:check-permission 'shell-task-list-tool nil) :allow))
  (is (eq (cl-cc.services:check-permission 'shell-task-detail-tool nil) :allow))
  (is (eq (cl-cc.services:check-permission 'shell-task-cleanup-tool nil) :allow))
  (is (eq (cl-cc.services:check-permission 'shell-task-tool nil) :allow))
  (is (eq (cl-cc.services:check-permission 'shell-task-output-tool nil) :allow))
  (is (eq (cl-cc.services:check-permission 'unknown-action nil) :deny)))

(test check-permission-normalizes-symbol-and-string-actions
  (is (eq (cl-cc.services:check-permission 'Echo-Tool nil) :allow))
  (is (eq (cl-cc.services:check-permission "FILE-READ" nil) :allow))
  (is (eq (cl-cc.services:check-permission "Delete-File" nil) :deny)))
