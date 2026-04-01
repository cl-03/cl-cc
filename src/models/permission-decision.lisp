;;;; src/models/permission-decision.lisp
(in-package :cl-cc.models)

(defclass permission-decision ()
  ((decision-id :initarg :decision-id :accessor decision-id :documentation "唯一标识")
   (action-kind :initarg :action-kind :accessor decision-action-kind :documentation "动作类别")
   (decision :initarg :decision :accessor decision-decision :documentation "allow | deny | error")
   (reason-code :initarg :reason-code :accessor decision-reason-code :documentation "原因码")
   (human-summary :initarg :human-summary :accessor decision-human-summary :documentation "可读说明")
   (audit-payload :initarg :audit-payload :accessor decision-audit-payload :documentation "审计输出")))
