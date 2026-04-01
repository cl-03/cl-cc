;;;; src/lib/result.lisp - 统一结果类型
(in-package :cl-cc.lib)

(defstruct result
  status   ; :success | :failed | :denied | :partial
  payload ; 任意输出
  message ; 可读摘要
)
