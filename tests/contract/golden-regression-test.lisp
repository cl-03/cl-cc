;;;; tests/contract/golden-regression-test.lisp - golden case 回归测试
(in-package :cl-cc/tests)

(def-suite golden-regression-test :in cl-cc-suite)

(in-suite golden-regression-test)

(test golden-regression-strict-match
  (let* ((fixture (read-fixture-form "golden" "echo-basic.lisp"))
         (actual (cl-cc.services:run-fixture (getf fixture :fixture-id))))
    (is (cl-cc.services:compare-golden actual (getf fixture :expected-output)))))

(test golden-regression-drift-detected
  (let ((fixture (read-fixture-form "golden" "echo-basic.lisp")))
    (is (not (cl-cc.services:compare-golden "unexpected-output" (getf fixture :expected-output))))))