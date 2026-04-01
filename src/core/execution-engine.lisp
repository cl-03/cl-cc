;;;; src/core/execution-engine.lisp - 执行循环推进器骨架
(in-package :cl-cc.core)


(defun %execution-error-status (condition)
  (case (cl-cc.lib:error-code condition)
    (:permission-denied :denied)
    (:tool-not-found :not-found)
    (t :failed)))

(defun %schema-field-keyword (field)
  (intern (string-upcase (cl-cc::%output-schema-json-field-name field)) :keyword))

(defun %schema-field-source (field default-source)
  (getf field :source default-source))

(defun %schema-source-value (source raw-result condition)
  (case source
    (:raw-result raw-result)
    (:error-message (and condition (cl-cc.lib:error-message condition)))
    (:error-code (and condition (string-upcase (string (cl-cc.lib:error-code condition)))))
    (t nil)))

(defun %materialize-schema-output (schema &key raw-result condition)
  (let ((json-fields (and schema (getf schema :json)))
        (output nil))
    (dolist (field json-fields output)
      (let* ((field-key (%schema-field-keyword field))
             (field-value (%schema-source-value (%schema-field-source field :raw-result)
                                                raw-result
                                                condition)))
        (setf output (append output (list field-key field-value)))))))

(defun %tool-success-output (tool-id raw-result)
  (let* ((definition (cl-cc.tools:find-tool-definition tool-id))
         (schema (and definition (cl-cc.models:tool-output-schema definition)))
         (json-fields (and schema (getf schema :json))))
    (cond
      ((null json-fields) nil)
      (t (%materialize-schema-output schema :raw-result raw-result)))))

(defun %tool-error-output (tool-id condition)
  (let* ((definition (cl-cc.tools:find-tool-definition tool-id))
         (schema (and definition (cl-cc.models:tool-error-output-schema definition))))
    (when schema
      (%materialize-schema-output schema :condition condition))))

(defun %elapsed-seconds (start-time end-time)
  (/ (- end-time start-time)
     (float internal-time-units-per-second 1d0)))

;;; 支持多工具循环执行与结果归档
(defun run-execution-cycle (context &rest tool-ids)
  "依次执行 tool-ids，归档所有结果，遇到成功即返回，否则归档所有错误。"
  (let ((results '())
        (input (execution-context-input context)))
    (dolist (tool-id tool-ids)
      (let ((action (if (string= input "restricted") 'delete-file tool-id)))
      (let ((tool-fn (cl-cc.tools:find-tool tool-id)))
        (if tool-fn
            (let ((started-at (get-internal-real-time)))
              (handler-case
                  (let* ((result (cl-cc.services:run-tool tool-id (format nil "fixture-input-~A" input)
                                                          :context (list :action action :fixture input)))
                         (duration-seconds (%elapsed-seconds started-at (get-internal-real-time))))
                    (push (list :tool tool-id
                                :status :success
                                :result result
                                :duration-seconds duration-seconds
                                :output (%tool-success-output tool-id result))
                          results)
                    (setf (execution-context-output context) result)
                    (setf (execution-context-status context) :success)
                    (setf (execution-context-results context) (reverse results))
                    (return-from run-execution-cycle (format nil "tool:~A result:~A" tool-id result)))
                (cl-cc.lib:cl-cc-error (e)
                  (let ((duration-seconds (%elapsed-seconds started-at (get-internal-real-time))))
                    (push (list :tool tool-id
                                :status (%execution-error-status e)
                                :error (cl-cc.lib:error-message e)
                                :error-code (cl-cc.lib:error-code e)
                                :duration-seconds duration-seconds
                                :output (%tool-error-output tool-id e))
                          results)))))
          (push (list :tool tool-id
                :status :not-found
                :error "tool not found"
                :error-code :tool-not-found
                :duration-seconds 0d0
                :output nil)
            results)))))
    (setf (execution-context-status context) :failed)
    (setf (execution-context-output context) nil)
    (setf (execution-context-results context) (reverse results))
    (format nil "all tools failed: ~A" (reverse results))))
