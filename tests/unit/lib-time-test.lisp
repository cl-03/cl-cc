;;;; tests/unit/lib-time-test.lisp - lib time helper tests
(in-package :cl-cc/tests)

(def-suite lib-time-test :in cl-cc-suite)
(in-suite lib-time-test)

(test elapsed-seconds-preserves-internal-time-unit-conversion
  (let ((expected (/ 25 (float internal-time-units-per-second 1d0))))
    (is (= (cl-cc.lib:elapsed-seconds 100 125) expected))
    (is (= (cl-cc.lib:elapsed-seconds 42 42) 0d0))))