;;;; src/tools/failing-tool.lisp - 失败工具示例
(in-package :cl-cc.tools)

(defun failing-tool (input)
  "始终抛出错误。"
  (declare (ignore input))
  (error 'cl-cc.lib:cl-cc-error :code :fail :message "工具执行失败"))
