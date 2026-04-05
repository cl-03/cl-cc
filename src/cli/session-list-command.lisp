;;;; src/cli/session-list-command.lisp - session list 命令
(in-package :cl-cc)

(defun handle-session-list (&optional session-dir output-format)
  (let ((result-object (cl-cc.services:list-sessions-result :session-dir session-dir)))
    (format t "~A~%" (render-session-list-result result-object :output-format output-format))
    0))

(defun handle-session-list-command (&optional argv parsed-arguments)
  (declare (ignore argv))
  (handle-session-list (cl-cc.core:command-option-value parsed-arguments :session-dir)
                       (cl-cc.core:command-option-value parsed-arguments :output-format "text")))