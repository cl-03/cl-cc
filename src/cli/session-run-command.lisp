;;;; src/cli/session-run-command.lisp - session run 命令
(in-package :cl-cc)

(defun handle-session-run (session-id-or-path &optional input output-format session-path tool-ids)
  (let ((result-object (cl-cc.services:run-session-result session-id-or-path
                                                          :input input
                                                          :session-path session-path
                                                          :tool-ids tool-ids)))
    (format t "~A~%" (render-session-command-result result-object :output-format output-format))
    0))

(defun handle-session-run-command (argv &optional parsed-arguments)
  (handle-session-run (or (cl-cc.core:command-positional-argument parsed-arguments 0)
                          (third argv))
                      (cl-cc.core:command-positional-argument parsed-arguments 1)
                      (cl-cc.core:command-option-value parsed-arguments :output-format "text")
                      (cl-cc.core:command-option-value parsed-arguments :session-path)
                      (cl-cc.core:command-option-values parsed-arguments :tool-ids)))