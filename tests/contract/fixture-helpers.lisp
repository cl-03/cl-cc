;;;; tests/contract/fixture-helpers.lisp - 契约与夹具辅助函数
(in-package :cl-cc/tests)

(defun fixture-path (&rest parts)
  (format nil "d:/VSCode/cl-cc/cl-cc/fixtures/~{~A~^/~}" parts))

(defun read-fixture-form (&rest parts)
  (with-open-file (stream (apply #'fixture-path parts) :direction :input)
    (read stream nil nil)))

(defun capture-output (thunk)
  (with-output-to-string (stream)
    (let ((*standard-output* stream))
      (funcall thunk))))

(defun expect-command-json-output-valid (command-name json-output)
  (let ((errors (cl-cc.services:command-json-output-schema-errors command-name json-output)))
    (is (null errors))))

(defun expect-command-json-output-error-containing (command-name json-output expected-substring)
  (let ((errors (cl-cc.services:command-json-output-schema-errors command-name json-output)))
    (is (not (null errors)))
    (is (some (lambda (error)
                (search expected-substring error))
              errors))))