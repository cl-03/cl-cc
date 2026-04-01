;;;; tests/test-package.lisp - CL-CC 测试包定义
(defpackage :cl-cc/tests
  (:use :cl :fiveam :cl-cc)
  (:export :run-tests))
(in-package :cl-cc/tests)

(def-suite cl-cc-suite)

(defun run-tests ()
  (fiveam:run! 'cl-cc-suite))
