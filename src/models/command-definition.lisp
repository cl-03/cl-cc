;;;; src/models/command-definition.lisp
(in-package :cl-cc.models)

(defclass command-definition ()
  ((name :initarg :name :accessor command-name :documentation "命令名称")
   (aliases :initarg :aliases :accessor command-aliases :documentation "别名列表")
   (arguments-schema :initarg :arguments-schema :accessor command-arguments-schema :documentation "参数模式")
  (output-schema :initarg :output-schema :accessor command-output-schema :documentation "输出模式")
   (summary :initarg :summary :accessor command-summary :documentation "帮助摘要")
   (handler-symbol :initarg :handler-symbol :accessor command-handler-symbol :documentation "处理函数符号")
   (permission-profile :initarg :permission-profile :accessor command-permission-profile :documentation "权限类别")))
