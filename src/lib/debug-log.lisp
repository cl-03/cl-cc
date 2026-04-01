;;;; src/lib/debug-log.lisp - 调试日志输出
(in-package :cl-cc.lib)

(defun debug-log (fmt &rest args)
  (apply #'format *error-output* (concatenate 'string "[DEBUG] " fmt "~%") args))
