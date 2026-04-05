;;;; src/lib/package.lisp
(defpackage :cl-cc.lib
  (:use :cl :alexandria)
  (:export :string-designator-downcase :string-designator-upcase :string-designator-keyword
           :elapsed-seconds
           :cl-cc-error :make-cl-cc-error :error-code :error-message
           :result :make-result :result-status :result-payload :result-message
           :debug-log
           :parse-json-document :json-null-p
           :capture-git-context))
(in-package :cl-cc.lib)
