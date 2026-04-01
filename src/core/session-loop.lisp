;;;; src/core/session-loop.lisp - 会话主循环骨架
(in-package :cl-cc.core)

(defun %session-history-trail (session)
  (let ((summary (cl-cc.models:session-context-summary session)))
    (cond
      ((and (listp summary) (getf summary :history-trail))
       (getf summary :history-trail))
      ((listp summary)
       (list summary))
      (t (list (list :event :session-created
                     :session-id (cl-cc.models:session-id session)
                     :history-index 0))))))

(defun session-loop (session)
  "会话主循环，带调试输出和异常捕获。"
  (handler-case
      (let* ((previous-history (%session-history-trail session))
             (next-history-index (1+ (or (cl-cc.models:session-history-index session) 0)))
             (context (make-execution-context :session session
                                             :command "session-loop"
                                             :input (cl-cc.models:session-id session)
                                             :output nil
                                             :status :running
                                             :results nil))
             (summary (list :session-id (cl-cc.models:session-id session)
                            :status :completed
                            :history-index next-history-index
                            :execution-command (execution-context-command context)
                            :execution-status :completed
                            :history-trail nil))
             (history-entry (copy-list summary))
             (history-trail (append previous-history (list history-entry))))
        (setf (getf summary :history-trail) history-trail)
        (setf (execution-context-output context) summary)
        (setf (execution-context-status context) :completed)
        (setf (cl-cc.models:session-history-index session) next-history-index)
        (setf (cl-cc.models:session-context-summary session) summary)
        (setf (cl-cc.models:session-updated-at session) "loop-updated")
        (cl-cc.lib:debug-log "[SESSION] 启动会话循环: ~A" (cl-cc.models:session-id session))
        summary)
    (cl-cc.lib:cl-cc-error (e)
      (cl-cc.lib:debug-log "[SESSION ERROR] ~A: ~A" (cl-cc.lib:error-code e) (cl-cc.lib:error-message e))
      nil)
    (error (e)
      (cl-cc.lib:debug-log "[SESSION UNHANDLED ERROR] ~A" e)
      nil)))
