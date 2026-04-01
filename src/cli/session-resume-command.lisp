;;;; src/cli/session-resume-command.lisp - session resume 命令骨架
(in-package :cl-cc)

(defun handle-session-resume (session-id &optional output-format)
  (let ((result-object (cl-cc.services:resume-session-result session-id)))
    (format t "~A~%" (render-session-command-result result-object :output-format output-format))
    0))

(defun handle-session-resume-command (argv &optional parsed-arguments)
  (handle-session-resume (or (cl-cc.core:command-positional-argument parsed-arguments 0)
                             (third argv))
                         (cl-cc.core:command-option-value parsed-arguments :output-format "text")))
