;;;; tests/contract/permission-contract-test.lisp - 权限拒绝契约测试
(in-package :cl-cc/tests)

(def-suite permission-contract-test :in cl-cc-suite)

(in-suite permission-contract-test)

(test permission-deny-contract
  (let ((decision (cl-cc.services:check-permission 'delete-file nil)))
    (is (eq decision :deny))
    (is (typep (cl-cc.services:audit-permission decision '(:action delete-file)) 'cl-cc.models:permission-decision))))