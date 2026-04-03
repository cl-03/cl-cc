;;;; src/cli/main.lisp - CL-CC CLI 主入口
(in-package :cl-cc)

(defun %handle-cli-error (condition)
  (cl-cc.lib:debug-log "~A" (%cli-error-log-message condition))
  1)

(defun %handle-unexpected-cli-error (condition)
  (cl-cc.lib:debug-log "~A" (%cli-unhandled-error-log-message condition))
  2)

(defun %unknown-command-message (argv)
  (format nil "Unknown command: ~{~A~^ ~}" argv))

(defun %unknown-command-error (argv)
  (cl-cc.lib:make-cl-cc-error :unknown-command
                              (%unknown-command-message argv)))

(defun main (&rest argv)
  "CL-CC CLI 启动入口。参数 argv 为命令行参数列表。"
  (handler-case
      (let ((dispatch-result (cl-cc.core:dispatch-command argv)))
        (when dispatch-result
          (return-from main dispatch-result))
        (error (%unknown-command-error argv)))
    (cl-cc.lib:cl-cc-error (e)
      (%handle-cli-error e))
    (error (e)
      (%handle-unexpected-cli-error e))))
