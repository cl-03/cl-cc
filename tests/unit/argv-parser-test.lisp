;;;; tests/unit/argv-parser-test.lisp - CLI 参数解析单元测试
(in-package :cl-cc/tests)

(def-suite argv-parser-test :in cl-cc-suite)

(in-suite argv-parser-test)

(test parse-help-flag
  (let ((args (cl-cc:parse-argv '("run" "--help"))))
    (is (eq (cl-cc::cli-args-help args) t))))
