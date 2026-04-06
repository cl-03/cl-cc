;;;; src/core/execution-engine.lisp - 执行循环推进器骨架
(in-package :cl-cc.core)


(defun %execution-error-status (condition)
  (case (cl-cc.lib:error-code condition)
    (:permission-denied :denied)
    (:tool-not-found :not-found)
    (t :failed)))

(defun %schema-field-keyword (field)
  (intern (with-output-to-string (stream)
            (loop for character across (cl-cc::%output-schema-json-field-name field)
                  for first-character = t then nil do
              (when (and (upper-case-p character)
                         (not first-character))
                (write-char #\- stream))
              (write-char (char-upcase character) stream)))
          :keyword))

(defun %schema-field-source (field default-source)
  (getf field :source default-source))

(defun %raw-result-field-value (raw-result field-key)
  (and (listp raw-result)
       (getf raw-result field-key)))

(defun %schema-source-value (source raw-result condition)
  (cond
    ((eq source :raw-result)
     raw-result)
    ((eq source :error-message)
     (and condition (cl-cc.lib:error-message condition)))
    ((eq source :error-code)
     (and condition (cl-cc.lib:string-designator-upcase (cl-cc.lib:error-code condition))))
    ((and (consp source)
          (eq (first source) :raw-result-field))
     (%raw-result-field-value raw-result (second source)))
    (t nil)))

(defun %tool-result-summary (result)
  (cond
    ((and (listp result)
          (stringp (getf result :summary)))
     (getf result :summary))
    ((stringp result)
     result)
    (t
     (princ-to-string result))))

(defun %materialized-schema-field (field &key raw-result condition)
  (let ((field-key (%schema-field-keyword field))
        (field-value (%schema-source-value (%schema-field-source field :raw-result)
                                           raw-result
                                           condition)))
    (list field-key field-value)))

(defun %materialize-schema-output (schema &key raw-result condition)
  (let ((json-fields (and schema (getf schema :json)))
        (output nil))
    (dolist (field json-fields output)
      (setf output (append output (%materialized-schema-field field
                                                             :raw-result raw-result
                                                             :condition condition))))))

(defun %tool-schema-output (tool-id schema-accessor &key raw-result condition)
  (let* ((definition (cl-cc.tools:find-tool-definition tool-id))
         (schema (and definition (funcall schema-accessor definition))))
    (when schema
      (%materialize-schema-output schema
                                  :raw-result raw-result
                                  :condition condition))))

(defun %directory-list-result-entries (summary)
  (cond
    ((or (null summary)
         (string= summary "")
         (string= summary "(empty directory)")
         (string= summary "(no matching entries)"))
     nil)
    (t
     (uiop:split-string summary :separator '(#\Newline)))))

(defun %normalized-tool-success-raw-result (tool-id raw-result)
  (cond
    ((string= tool-id "directory-list-tool")
     (list :summary raw-result
           :entries (%directory-list-result-entries raw-result)))
    ((and (string= tool-id "shell-tool")
          (listp raw-result))
     (append raw-result
             (unless (member :background raw-result)
               (list :background nil))
             (unless (member :background-task-id raw-result)
               (list :background-task-id nil))
             (unless (member :output-path raw-result)
               (list :output-path nil))
             (unless (member :process-id raw-result)
               (list :process-id nil))))
    (t raw-result)))

(defun %tool-success-output (tool-id raw-result)
  (%tool-schema-output tool-id
                       #'cl-cc.models:tool-output-schema
                       :raw-result (%normalized-tool-success-raw-result tool-id raw-result)))

(defun %tool-error-output (tool-id condition)
  (%tool-schema-output tool-id
                       #'cl-cc.models:tool-error-output-schema
                       :condition condition))

(defun %execution-result-record (tool-id status duration-seconds &key result error error-code output)
  (append (list :tool tool-id
                :status status)
          (when result
            (list :result result))
          (when error
            (list :error error))
          (when error-code
            (list :error-code error-code))
          (list :duration-seconds duration-seconds
                :output output)))

(defun %record-execution-result (results tool-id status duration-seconds &key result error error-code output)
  (push (%execution-result-record tool-id
                                  status
                                  duration-seconds
                                  :result result
                                  :error error
                                  :error-code error-code
                                  :output output)
        results)
  results)

(defun %finalize-execution-context (context results status output)
  (setf (execution-context-status context) status)
  (setf (execution-context-output context) output)
  (setf (execution-context-results context) (reverse results))
  context)

(defun %execution-action (input tool-id)
  (if (and (stringp input)
           (string= input "restricted"))
      'delete-file
      (if (member tool-id '("file-read-tool" "directory-list-tool" "grep-tool" "glob-tool") :test #'string=)
          "file-read"
          (if (member tool-id '("file-write-tool" "file-edit-tool") :test #'string=)
              "file-write"
              tool-id))))

(defun %fixture-execution-context-p (context)
  (not (string= (or (execution-context-command context) "") "session-loop")))

(defun %planned-tool-input (context tool-id fallback-input)
  (let ((tool-inputs (execution-context-tool-inputs context)))
    (or (cdr (assoc tool-id tool-inputs :test #'string=))
        fallback-input)))

(defun %execution-tool-input (context input)
  (if (and (%fixture-execution-context-p context)
           (stringp input))
      (format nil "fixture-input-~A" input)
      input))

(defun %execution-context-tool-runner-context (context action input)
  (list :action action
        :fixture input
  :session (execution-context-session context)
        :approval-mode (execution-context-approval-mode context)
        :approval-callback (execution-context-approval-callback context)))

(defun %halt-on-denied-p (context)
  (not (null (execution-context-halt-on-denied context))))

(defun %denied-attempt-should-stop-p (context condition)
  (and (%halt-on-denied-p context)
       (eq (cl-cc.lib:error-code condition) :permission-denied)))

(defun %missing-tool-record-fields ()
  (list :error "tool not found"
        :error-code :tool-not-found
        :output nil))

(defun %successful-tool-attempt-fields (tool-id result)
  (list :result (%tool-result-summary result)
        :output (%tool-success-output tool-id result)))

(defun %failed-tool-attempt-fields (tool-id condition)
  (list :error (cl-cc.lib:error-message condition)
        :error-code (cl-cc.lib:error-code condition)
        :output (%tool-error-output tool-id condition)))

(defun %record-missing-tool-result (results tool-id)
  (apply #'%record-execution-result
         results
         tool-id
         :not-found
         0d0
         (%missing-tool-record-fields)))

(defun %attempt-duration-seconds (started-at)
  (cl-cc.lib:elapsed-seconds started-at (get-internal-real-time)))

(defun %record-successful-tool-attempt (results tool-id result duration-seconds)
  (apply #'%record-execution-result
         results
         tool-id
         :success
         duration-seconds
         (%successful-tool-attempt-fields tool-id result)))

(defun %record-failed-tool-attempt (results tool-id condition duration-seconds)
  (apply #'%record-execution-result
         results
         tool-id
         (%execution-error-status condition)
         duration-seconds
         (%failed-tool-attempt-fields tool-id condition)))

(defun %successful-execution-summary (tool-id result)
  (format nil "tool:~A result:~A" tool-id (%tool-result-summary result)))

(defun %failed-execution-summary (results)
  (format nil "all tools failed: ~A" (reverse results)))

(defun %successful-cycle-outcome (context results tool-id result)
  (%finalize-execution-context context results :success (%tool-result-summary result))
  (%successful-execution-summary tool-id result))

(defun %failed-cycle-outcome (context results)
  (%finalize-execution-context context results :failed nil)
  (%failed-execution-summary results))

(defun %successful-attempt-values (results tool-id result duration-seconds)
  (values (%record-successful-tool-attempt results tool-id result duration-seconds)
          result
          t
          nil))

(defun %failed-attempt-values (results tool-id condition duration-seconds &key stop-p)
  (values (%record-failed-tool-attempt results tool-id condition duration-seconds)
          nil
          nil
          stop-p))

(defun %missing-tool-values (results tool-id)
  (values (%record-missing-tool-result results tool-id)
          nil
          nil
          nil))

(defun %run-tool-attempt (context results tool-id input action)
  (let ((started-at (get-internal-real-time)))
    (handler-case
        (let* ((tool-input (%planned-tool-input context tool-id input))
               (result (cl-cc.services:run-tool tool-id (%execution-tool-input context tool-input)
                                                :context (%execution-context-tool-runner-context context action input)))
               (duration-seconds (%attempt-duration-seconds started-at)))
          (%successful-attempt-values results tool-id result duration-seconds))
      (cl-cc.lib:cl-cc-error (condition)
        (let ((duration-seconds (%attempt-duration-seconds started-at)))
          (%failed-attempt-values results tool-id condition duration-seconds
                                  :stop-p (%denied-attempt-should-stop-p context condition)))))))

(defun %execute-tool-cycle-step (context results tool-id input)
  (let ((tool-fn (cl-cc.tools:find-tool tool-id)))
    (if tool-fn
        (%run-tool-attempt context results tool-id input (%execution-action input tool-id))
        (%missing-tool-values results tool-id))))

;;; 支持多工具循环执行与结果归档
(defun run-execution-cycle (context &rest tool-ids)
  "依次执行 tool-ids，归档所有结果，遇到成功即返回，否则归档所有错误。"
  (let ((results '())
        (input (execution-context-input context)))
    (dolist (tool-id tool-ids)
      (multiple-value-bind (updated-results result success-p stop-p)
          (%execute-tool-cycle-step context results tool-id input)
        (setf results updated-results)
        (when success-p
          (return-from run-execution-cycle
            (%successful-cycle-outcome context results tool-id result)))
        (when stop-p
          (return-from run-execution-cycle
            (%failed-cycle-outcome context results)))))
    (%failed-cycle-outcome context results)))
