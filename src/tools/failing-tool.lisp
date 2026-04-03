;;;; src/tools/failing-tool.lisp - 失败工具示例
(in-package :cl-cc.tools)

(defun %failing-tool-message ()
  "工具执行失败")

(defun %failing-tool-error ()
  (cl-cc.lib:make-cl-cc-error :fail
                              (%failing-tool-message)))

(defun failing-tool (input)
  "始终抛出错误。"
  (declare (ignore input))
  (error (%failing-tool-error)))
