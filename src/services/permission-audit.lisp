;;;; src/services/permission-audit.lisp - 权限审计记录
(in-package :cl-cc.services)

(defun audit-permission (decision context)
  "记录权限判定结果并返回审计对象。"
  (let* ((action (or (getf context :action) :unknown))
         (reason (if (eq decision :allow) :allowed :denied-by-policy))
         (summary (if (eq decision :allow)
                      (format nil "action ~A allowed" action)
                      (format nil "action ~A denied" action)))
         (audit (make-instance 'cl-cc.models:permission-decision
                               :decision-id (format nil "perm-~A" (get-universal-time))
                               :action-kind action
                               :decision decision
                               :reason-code reason
                               :human-summary summary
                               :audit-payload context)))
    (cl-cc.lib:debug-log "[PERMISSION] ~A" summary)
    audit))
