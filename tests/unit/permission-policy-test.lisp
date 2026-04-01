;;;; tests/unit/permission-policy-test.lisp - 权限策略单元测试
(in-package :cl-cc/tests)

(def-suite permission-policy-test :in cl-cc-suite)

(in-suite permission-policy-test)

(test check-permission-default
  (is (eq (cl-cc.services:check-permission 'file-write nil) :allow))
  (is (eq (cl-cc.services:check-permission 'unknown-action nil) :deny)))
