;;;; src/cli/session-command.lisp - session start 命令骨架
(in-package :cl-cc)

(defun handle-session-start (&optional session-id history-index output-format)
  (let ((result-object (cond
                         (session-id
                          (cl-cc.services:start-session-result session-id :history-index history-index))
                         (history-index
                          (cl-cc.services:start-session-result :history-index history-index))
                         (t
                          (cl-cc.services:start-session-result)))))
    (format t "~A~%" (render-session-command-result result-object :output-format output-format))
    0))

(defun handle-session-start-command (&optional argv parsed-arguments)
  (declare (ignore argv))
  (let ((session-id (cl-cc.core:command-option-value parsed-arguments :session-id)))
    (handle-session-start session-id
                          (cl-cc.core:command-option-value parsed-arguments :history-index)
                          (cl-cc.core:command-option-value parsed-arguments :output-format "text"))))
