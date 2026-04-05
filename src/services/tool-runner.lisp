;;;; src/services/tool-runner.lisp - 工具执行与结果汇总
(in-package :cl-cc.services)

(defun %permission-denied-message (action)
  (format nil "permission denied for action: ~A" action))

(defun %tool-not-found-message (tool)
  (format nil "tool not found: ~A" tool))

(defun %permission-denied-error (action)
  (cl-cc.lib:make-cl-cc-error :permission-denied
                              (%permission-denied-message action)))

(defun %tool-not-found-error (tool)
  (cl-cc.lib:make-cl-cc-error :tool-not-found
                              (%tool-not-found-message tool)))

(defun %tool-permission-profile (tool)
  (let ((definition (cl-cc.tools:find-tool-definition tool)))
    (and definition
         (cl-cc.models:tool-permission-profile definition))))

(defun %approval-enabled-p (context)
  (eq (getf context :approval-mode) :interactive))

(defun %approval-required-p (tool context)
  (and (%approval-enabled-p context)
  (member (%tool-permission-profile tool) '(:file-write :shell))))

(defun %approval-callback (context)
  (getf context :approval-callback))

(defun %approval-granted-p (tool action input context)
  (let ((callback (%approval-callback context)))
    (if callback
        (not (null (funcall callback tool action input (%tool-permission-profile tool))))
        t)))

(defun %permission-decision-source (decision requires-approval)
  (if (and requires-approval
           (eq decision :allow))
      :user-prompt
      (if requires-approval
          :user-prompt
          :policy)))

(defun %resolved-permission-decision (tool action input context)
  (let* ((policy-decision (check-permission action context))
         (requires-approval (%approval-required-p tool context))
         (decision (if (and (eq policy-decision :allow)
                            requires-approval)
                       (if (%approval-granted-p tool action input context)
                           :allow
                           :deny)
                       policy-decision)))
    (values decision
            (%permission-decision-source decision requires-approval))))

(defun %permission-audit-context (tool action input context decision-source)
  (list :action action
        :tool tool
        :input input
        :permission-profile (%tool-permission-profile tool)
        :decision-source decision-source
        :fixture (getf context :fixture)))

(defun run-tool (tool input &key context)
  "执行指定工具，并经过权限判定。"
  (let ((action (or (getf context :action) tool)))
    (multiple-value-bind (decision decision-source)
        (%resolved-permission-decision tool action input context)
      (audit-permission decision (%permission-audit-context tool action input context decision-source))
      (unless (eq decision :allow)
        (error (%permission-denied-error action)))
      (let ((tool-fn (cl-cc.tools:find-tool tool)))
        (if tool-fn
            (let ((cl-cc.models:*active-session* (getf context :session)))
              (funcall tool-fn input))
            (error (%tool-not-found-error tool)))))))
