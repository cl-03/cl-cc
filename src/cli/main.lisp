;;;; src/cli/main.lisp - CL-CC CLI 主入口
(in-package :cl-cc)

(defun main (&rest argv)
  "CL-CC CLI 启动入口。参数 argv 为命令行参数列表。"
  (handler-case
      (let ((dispatch-result (cl-cc.core:dispatch-command argv)))
        (when dispatch-result
          (return-from main dispatch-result))
        (format t "CL-CC CLI 启动成功。~%用法: cl-cc --help~%")
        0)
    (cl-cc.lib:cl-cc-error (e)
      (cl-cc.lib:debug-log "[ERROR] ~A: ~A" (cl-cc.lib:error-code e) (cl-cc.lib:error-message e))
      1)
    (error (e)
      (cl-cc.lib:debug-log "[UNHANDLED ERROR] ~A" e)
      2)))
