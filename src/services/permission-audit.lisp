;;;; src/services/permission-audit.lisp - 权限审计记录
(in-package :cl-cc.services)

(defun %permission-audit-action (context)
  (or (getf context :action) :unknown))

(defun %permission-audit-source (context)
  (or (getf context :decision-source) :policy))

(defun %permission-audit-reason (decision &optional context)
  (let ((source (%permission-audit-source context)))
    (cond
      ((and (eq decision :allow) (eq source :user-prompt)) :approved-by-user)
      ((eq decision :allow) :allowed)
      ((eq source :user-prompt) :denied-by-user)
      (t :denied-by-policy))))

(defun %permission-audit-summary (decision action &optional context)
  (let ((source (%permission-audit-source context)))
    (cond
      ((and (eq decision :allow) (eq source :user-prompt))
       (format nil "action ~A approved by user" action))
      ((eq decision :allow)
       (format nil "action ~A allowed" action))
      ((eq source :user-prompt)
       (format nil "action ~A denied by user" action))
      (t
       (format nil "action ~A denied" action)))))

(defun %permission-audit-id ()
  (format nil "perm-~A" (get-universal-time)))

(defun audit-permission (decision context)
  "记录权限判定结果并返回审计对象。"
  (let* ((action (%permission-audit-action context))
         (reason (%permission-audit-reason decision context))
         (summary (%permission-audit-summary decision action context))
         (audit (make-instance 'cl-cc.models:permission-decision
                               :decision-id (%permission-audit-id)
                               :action-kind action
                               :decision decision
                               :reason-code reason
                               :human-summary summary
                               :audit-payload context)))
    (cl-cc.lib:debug-log "[PERMISSION] ~A" summary)
    audit))
