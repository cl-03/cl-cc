;;;; src/models/tool-definition.lisp
(in-package :cl-cc.models)

(defclass tool-definition ()
  ((tool-id :initarg :tool-id :accessor tool-id :documentation "唯一标识")
   (summary :initarg :summary :accessor tool-summary :documentation "工具用途")
  (handler-function :initarg :handler-function :accessor tool-handler-function :documentation "工具处理函数")
   (input-schema :initarg :input-schema :accessor tool-input-schema :documentation "输入契约")
  (output-schema :initarg :output-schema :accessor tool-output-schema :documentation "成功输出契约")
  (error-output-schema :initarg :error-output-schema :accessor tool-error-output-schema :documentation "失败输出契约")
   (failure-modes :initarg :failure-modes :accessor tool-failure-modes :documentation "失败类型")
   (permission-profile :initarg :permission-profile :accessor tool-permission-profile :documentation "权限类别")))
