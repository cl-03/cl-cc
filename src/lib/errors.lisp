;;;; src/lib/errors.lisp - 错误类型与处理
(in-package :cl-cc.lib)

(define-condition cl-cc-error (error)
  ((code :initarg :code :reader error-code :documentation "错误码")
   (message :initarg :message :reader error-message :documentation "错误信息")))

(defun make-cl-cc-error (code message)
  (make-condition 'cl-cc-error
                  :code code
                  :message message))
