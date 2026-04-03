;;;; src/core/session-loop.lisp - 会话主循环骨架
(in-package :cl-cc.core)

(defun %session-error-log-message (condition)
  (format nil "[SESSION ERROR] ~A: ~A"
          (cl-cc.lib:error-code condition)
          (cl-cc.lib:error-message condition)))

(defun %session-unhandled-error-log-message (condition)
  (format nil "[SESSION UNHANDLED ERROR] ~A" condition))

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

(defun %session-summary-input (summary)
  (and (listp summary)
       (getf summary :input)))

(defun %session-loop-input (session explicit-input)
  (or explicit-input
      (%session-summary-input (cl-cc.models:session-context-summary session))
      (cl-cc.models:session-id session)))

(defun %session-loop-execution-context (session resolved-input tool-inputs approval-mode approval-callback halt-on-denied)
  (make-execution-context :session session
                          :command "session-loop"
                          :input resolved-input
                          :tool-inputs tool-inputs
                          :approval-mode approval-mode
                          :approval-callback approval-callback
                          :halt-on-denied halt-on-denied
                          :output nil
                          :status :running
                          :results nil))

(defun %session-loop-summary (session next-history-index resolved-input context result tool-ids execution-plan previous-history)
  (let* ((summary (list :session-id (cl-cc.models:session-id session)
                        :status :completed
                        :history-index next-history-index
                        :input resolved-input
                        :selected-tools tool-ids
                        :execution-plan execution-plan
                        :result result
                        :tool-results (execution-context-results context)
                        :execution-command (execution-context-command context)
                        :execution-status (execution-context-status context)
                        :history-trail nil))
         (history-entry (copy-list summary))
         (history-trail (append previous-history (list history-entry))))
    (setf (getf summary :history-trail) history-trail)
    summary))

(defun session-loop (session &key input tool-ids-override approval-mode approval-callback halt-on-denied)
  "会话主循环，带调试输出和异常捕获。"
  (handler-case
      (let* ((previous-history (%session-history-trail session))
             (next-history-index (1+ (or (cl-cc.models:session-history-index session) 0)))
             (resolved-input (%session-loop-input session input))
       (plan (cl-cc.services:plan-session-execution resolved-input :tool-ids-override tool-ids-override))
         (tool-ids (getf plan :tool-ids))
         (tool-inputs (getf plan :tool-inputs))
     (context (%session-loop-execution-context session resolved-input
                          tool-inputs
                          approval-mode
                          approval-callback
                          halt-on-denied))
             (result (apply #'run-execution-cycle context tool-ids))
         (summary (%session-loop-summary session next-history-index resolved-input context result tool-ids
                         (getf plan :steps) previous-history)))
        (setf (execution-context-output context) summary)
        (setf (cl-cc.models:session-history-index session) next-history-index)
        (setf (cl-cc.models:session-context-summary session) summary)
        (setf (cl-cc.models:session-updated-at session) "loop-updated")
        (cl-cc.lib:debug-log "[SESSION] 启动会话循环: ~A" (cl-cc.models:session-id session))
        summary)
    (cl-cc.lib:cl-cc-error (e)
      (cl-cc.lib:debug-log "~A" (%session-error-log-message e))
      nil)
    (error (e)
      (cl-cc.lib:debug-log "~A" (%session-unhandled-error-log-message e))
      nil)))
