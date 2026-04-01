;;;; src/core/execution-context.lisp - 执行上下文骨架
(in-package :cl-cc.core)

(defstruct execution-context
  session
  command
  input
  output
  status
  results)
