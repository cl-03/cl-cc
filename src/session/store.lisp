;;;; src/session/store.lisp - 会话快照存储抽象
(in-package :cl-cc.session)

(defun %session-snapshot-not-found-message (path)
  (format nil "session snapshot not found: ~A" path))

(defun %session-snapshot-not-found-error (path)
  (cl-cc.lib:make-cl-cc-error :session-not-found
                              (%session-snapshot-not-found-message path)))

(defun save-session (session path)
  "保存 session-state 到指定路径。"
  (ensure-directories-exist path)
  (with-open-file (stream path
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (write-string (serialize-session session) stream))
  t)

(defun load-session (path)
  "从指定路径加载 session-state。"
  (if (probe-file path)
      (with-open-file (stream path :direction :input)
        (let ((contents (make-string (file-length stream))))
          (read-sequence contents stream)
          (deserialize-session contents)))
      (error (%session-snapshot-not-found-error path))))
