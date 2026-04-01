;;;; src/core/package.lisp
(defpackage :cl-cc.core
  (:use :cl :cl-cc)
  (:export :*command-registry* :register-command :find-command :find-command-handler
           :reset-command-registry :ensure-default-commands :list-command-definitions
           :command-key-from-argv :dispatch-command :command-positional-argument
           :command-positional-arguments
           :command-option-value :command-option-values
           :make-execution-context :execution-context-session :execution-context-command
           :execution-context-input :execution-context-output :execution-context-status
           :execution-context-results :run-execution-cycle :session-loop))
(in-package :cl-cc.core)
