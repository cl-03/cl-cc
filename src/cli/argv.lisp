;;;; src/cli/argv.lisp - CLI 参数解析骨架
(in-package :cl-cc)

(defstruct cli-args
  help)

(defun parse-argv (argv)
  "解析命令行参数，返回 cli-args 结构体。支持 --help 标志。"
  (let ((help-flag (some (lambda (x) (string= x "--help")) argv)))
    (make-cli-args :help help-flag)))
