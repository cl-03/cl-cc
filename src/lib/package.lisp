;;;; src/lib/package.lisp
(defpackage :cl-cc.lib
  (:use :cl :alexandria)
  (:export :cl-cc-error :error-code :error-message
           :result :make-result :result-status :result-payload :result-message
           :debug-log))
(in-package :cl-cc.lib)
