;;;; tests/run-tests.lisp - 测试启动入口
(in-package :cl-cc/tests)

(defun run-tests-entry (&rest argv)
  (declare (ignorable argv))
  (run-tests)
  0)
