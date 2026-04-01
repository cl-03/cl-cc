;;;; src/models/execution-cycle.lisp
(in-package :cl-cc.models)

(defclass execution-cycle ()
  ((cycle-id :initarg :cycle-id :accessor cycle-id :documentation "唯一标识")
   (command-name :initarg :command-name :accessor cycle-command-name :documentation "入口命令")
   (input-payload :initarg :input-payload :accessor cycle-input-payload :documentation "本次请求输入")
   (selected-tools :initarg :selected-tools :accessor cycle-selected-tools :documentation "本次选中的工具列表")
   (context-before :initarg :context-before :accessor cycle-context-before :documentation "执行前上下文摘要")
   (context-after :initarg :context-after :accessor cycle-context-after :documentation "执行后上下文摘要")
   (result-status :initarg :result-status :accessor cycle-result-status :documentation "结果状态")
   (result-summary :initarg :result-summary :accessor cycle-result-summary :documentation "输出摘要")))
