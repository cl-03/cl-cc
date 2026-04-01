;;;; src/cli/run-command.lisp - run --fixture 命令骨架
(in-package :cl-cc)

(defun %print-run-result (result-object output-format pretty-json)
  (if (string= (or output-format "text") "json")
      (format t "~A~%" (render-run-fixture-result result-object :pretty-json pretty-json))
      (format t "夹具执行结果: ~A~%" (cl-cc.lib:result-message result-object))))

(defun handle-run-fixture (fixture-id &optional output-format)
  (multiple-value-bind (result exit-code)
      (cl-cc.services:run-fixture fixture-id :output-format output-format)
    (%print-run-result result output-format nil)
    exit-code))

(defun handle-run-fixture-command (argv &optional parsed-arguments)
  (let ((fixture-ids (or (cl-cc.core:command-positional-arguments parsed-arguments)
                         (list (third argv))))
        (output-format (cl-cc.core:command-option-value parsed-arguments :output-format))
    (tool-ids (cl-cc.core:command-option-values parsed-arguments :tool-ids))
    (pretty-json (cl-cc.core:command-option-value parsed-arguments :pretty-json nil))
    (compact-json (cl-cc.core:command-option-value parsed-arguments :compact-json nil)))
    (declare (ignore compact-json))
    (multiple-value-bind (result exit-code)
      (if (> (length fixture-ids) 1)
        (cl-cc.services:run-fixtures fixture-ids
                      :output-format output-format
                      :pretty-json pretty-json
                      :tool-ids tool-ids)
        (cl-cc.services:run-fixture (first fixture-ids)
                      :output-format output-format
                      :pretty-json pretty-json
                      :tool-ids tool-ids))
      (%print-run-result result output-format pretty-json)
      exit-code)))
