;;;; src/tools/package.lisp
(defpackage :cl-cc.tools
  (:use :cl :cl-cc)
  (:export :*tool-registry* :register-tool :find-tool :find-tool-definition
           :list-tool-definitions :define-tool :echo-tool :failing-tool
           :file-read-tool :directory-list-tool :file-write-tool :file-edit-tool :grep-tool :glob-tool :todo-write-tool
           :shell-tool :shell-task-list-tool :shell-task-detail-tool :shell-task-tool :shell-task-cleanup-tool :shell-task-output-tool
           :current-shell-task-snapshots))
(in-package :cl-cc.tools)
