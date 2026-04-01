;;;; src/package.lisp - CL-CC 顶层包定义
(defpackage :cl-cc
  (:use :cl)
  (:export :main :parse-argv :print-help :render-help :render-command-reference-markdown
           :sync-command-reference-file :command-reference-file-needs-sync-p
           :handle-session-start :handle-session-resume :handle-run-fixture))
(in-package :cl-cc)
