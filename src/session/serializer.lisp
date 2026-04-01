;;;; src/session/serializer.lisp - 会话序列化
(in-package :cl-cc.session)

(defun serialize-session (session)
  "将 session-state 对象序列化为可读 s-expression 字符串。"
  (with-standard-io-syntax
    (prin1-to-string
     (list :version (cl-cc.models:session-version session)
           :session-id (cl-cc.models:session-id session)
           :created-at (cl-cc.models:session-created-at session)
           :updated-at (cl-cc.models:session-updated-at session)
           :history-index (cl-cc.models:session-history-index session)
           :context-summary (cl-cc.models:session-context-summary session)
           :permission-snapshot (cl-cc.models:session-permission-snapshot session)
           :status (cl-cc.models:session-status session)))))

(defun deserialize-session (str)
  "从字符串反序列化为 session-state 对象。"
  (handler-case
      (let* ((data (with-standard-io-syntax (read-from-string str)))
             (version (getf data :version))
             (session-id (getf data :session-id)))
        (unless (and (listp data) session-id)
          (error 'cl-cc.lib:cl-cc-error :code :invalid-session :message "invalid session snapshot"))
        (unless (string= version "0.1")
          (error 'cl-cc.lib:cl-cc-error :code :session-version-mismatch :message (format nil "unsupported session version: ~A" version)))
        (make-instance 'cl-cc.models:session-state
                       :session-id session-id
                       :created-at (getf data :created-at)
                       :updated-at (getf data :updated-at)
                       :history-index (getf data :history-index)
                       :context-summary (getf data :context-summary)
                       :permission-snapshot (getf data :permission-snapshot)
                       :status (getf data :status)
                       :version version))
    (cl-cc.lib:cl-cc-error (e)
      (error e))
    (error ()
      (error 'cl-cc.lib:cl-cc-error :code :invalid-session :message "invalid session snapshot"))))
