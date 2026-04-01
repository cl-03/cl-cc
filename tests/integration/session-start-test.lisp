;;;; tests/integration/session-start-test.lisp - 最小会话启动集成测试
(in-package :cl-cc/tests)

(def-suite session-start-test :in cl-cc-suite)

(in-suite session-start-test)

(test session-start-minimal
  (let ((session (cl-cc.services:start-session "test-user")))
    (is (typep session 'cl-cc.models:session-state))
    (is (string= (cl-cc.models:session-id session) "test-user"))))
