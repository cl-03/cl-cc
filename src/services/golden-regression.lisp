;;;; src/services/golden-regression.lisp - golden case 回归
(in-package :cl-cc.services)

(defun %golden-comparable-value (value)
  (if (typep value 'cl-cc.lib:result)
      (cl-cc.lib:result-message value)
      value))

(defun compare-golden (actual expected)
  "与 golden case 夹具比较。"
  (equal (%golden-comparable-value actual)
         (%golden-comparable-value expected)))
