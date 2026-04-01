;;;; src/services/tool-runner.lisp - 工具执行与结果汇总
(in-package :cl-cc.services)

(defun run-tool (tool input &key context)
  "执行指定工具，并经过权限判定。"
  (let* ((action (or (getf context :action) tool))
         (decision (check-permission action context)))
    (audit-permission decision (list :action action :tool tool :input input))
    (unless (eq decision :allow)
      (error 'cl-cc.lib:cl-cc-error :code :permission-denied :message (format nil "permission denied for action: ~A" action)))
    (let ((tool-fn (cl-cc.tools:find-tool tool)))
      (if tool-fn
          (funcall tool-fn input)
          (error 'cl-cc.lib:cl-cc-error :code :tool-not-found :message (format nil "tool not found: ~A" tool))))))
