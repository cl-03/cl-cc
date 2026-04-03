;;;; src/package.lisp - CL-CC 顶层包定义
(defpackage :cl-cc
  (:use :cl)
  (:export :main :parse-argv :print-help :render-help :render-command-reference-markdown
           :sync-command-reference-file :command-reference-file-needs-sync-p
           :handle-session-start :handle-session-resume :handle-session-run :handle-chat :handle-run-fixture
           :schema-field))
(in-package :cl-cc)

(defun schema-field (name summary &rest properties)
  (append (list :name name :summary summary) properties))
