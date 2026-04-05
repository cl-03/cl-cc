;;;; src/services/schema-validation.lisp - registry-driven schema conformance checks
(in-package :cl-cc.services)

(defparameter +missing-schema-value+ (gensym "MISSING-SCHEMA-VALUE"))

(defun %json-null-p (value)
  (cl-cc.lib:json-null-p value))

(defun %schema-nullish-p (value)
  (or (null value)
      (%json-null-p value)))

(defun %missing-schema-value-p (value)
  (eq value +missing-schema-value+))

(defun %json-name-to-keyword (name)
  (intern (with-output-to-string (stream)
            (loop for character across name
                  for first-character = t then nil do
              (when (and (upper-case-p character)
                         (not first-character))
                (write-char #\- stream))
              (write-char (char-upcase character) stream)))
          :keyword))

(defun %schema-field-candidate-keys (field-name)
  (cond
    ((string= field-name "toolId") '(:tool-id :tool))
    (t (list (%json-name-to-keyword field-name)))))

(defun %schema-field-value (payload field-name)
  (dolist (candidate-key (%schema-field-candidate-keys field-name)
                         (values +missing-schema-value+ nil))
    (let ((value (getf payload candidate-key +missing-schema-value+)))
      (unless (eq value +missing-schema-value+)
        (return (values value t))))))

(defun %schema-error (path message)
  (format nil "~A: ~A" path message))

(defun %plist-property (plist key)
  (and (listp plist)
       (getf plist key)))

(defun %schema-field-property (field key)
  (%plist-property field key))

(defun %relation-property (relation key)
  (%plist-property relation key))

(defmacro %define-unary-plist-accessors (base-accessor &body definitions)
  `(progn
     ,@(mapcar (lambda (definition)
                 (destructuring-bind (name key) definition
                   `(defun ,name (value)
                      (,base-accessor value ,key))))
               definitions)))

(defun %parse-json-document (text)
  (cl-cc.lib:parse-json-document text))

(defun %tool-output-schema-for-record (record refs)
  (let* ((tool-id (or (getf record :tool) (getf record :tool-id)))
         (status (getf record :status))
         (matching-ref (find tool-id refs :key (lambda (ref) (getf ref :tool-id)) :test #'string=))
         (definition (and matching-ref (cl-cc.tools:find-tool-definition tool-id))))
    (when definition
      (if (or (eq status :success)
              (and (stringp status)
                   (string= status "success")))
          (cl-cc.models:tool-output-schema definition)
          (cl-cc.models:tool-error-output-schema definition)))))

(defun %schema-closed-p (schema)
  (%plist-property schema :closed))

(defun %schema-field-children-for-record (field record)
  (let ((children (getf field :fields))
        (refs (getf field :tool-schema-refs)))
    (append children
            (let ((tool-schema (%tool-output-schema-for-record record refs)))
              (copy-list (or (and tool-schema (getf tool-schema :json)) '()))))))

(defun %schema-field-closed-p (field record)
  (if (and (listp field)
           (not (eq (getf field :closed :missing) :missing)))
      (getf field :closed)
      (let ((tool-schema (%tool-output-schema-for-record record (getf field :tool-schema-refs))))
        (%schema-closed-p tool-schema))))

(%define-unary-plist-accessors %schema-field-property
  (%schema-field-enum-values :enum)
  (%schema-field-nullable-p :nullable)
  (%schema-field-type :type)
  (%schema-field-minimum :minimum)
  (%schema-field-min-items :min-items)
  (%schema-field-equals-field :equals-field)
  (%schema-field-equals-collection-size-of :equals-collection-size-of)
  (%schema-field-equals-sum-of-fields :equals-sum-of-fields)
  (%schema-field-equals-field-when-value :equals-field-when-value)
  (%schema-field-true-when-zero-field :true-when-zero-field)
  (%schema-field-enum-when-zero-field :enum-when-zero-field)
  (%schema-field-enum-when-nonzero-field :enum-when-nonzero-field)
  (%schema-field-maximum :maximum))

(defun %schema-field-required-p (field)
  (if (and (listp field)
           (not (eq (getf field :required :missing) :missing)))
      (getf field :required)
      t))

(%define-unary-plist-accessors %relation-property
  (%schema-relation-field-name :field)
  (%schema-relation-when-field-name :when-field)
  (%schema-relation-value :value)
  (%schema-relation-values :values)
  (%schema-relation-fields :fields))

(defun %property-list-p (value)
  (and (listp value)
       (evenp (length value))
   (loop for key in value by #'cddr
     always (keywordp key))))

(defun %schema-object-p (value)
  (%property-list-p value))

(defun %schema-array-p (value)
  (or (vectorp value)
      (and (listp value)
           (or (null value)
               (not (%property-list-p value))))))

(defun %schema-collection-items (value)
  (cond
    ((vectorp value) (coerce value 'list))
    ((listp value) value)
    (t nil)))

(defun %schema-collection-size (value)
  (length (%schema-collection-items value)))

(defun %schema-value-matches-type-p (field-type value)
  (case field-type
    (:string (stringp value))
    (:integer (integerp value))
    (:number (numberp value))
    (:boolean (or (eq value t) (null value)))
    (:object (%schema-object-p value))
    (:array (%schema-array-p value))
    (t t)))

(defun %schema-reference-present-p (root-payload reference)
  (not (%missing-schema-value-p (%schema-reference-value root-payload reference))))

(defun %schema-reference-number-zero-p (root-payload reference)
  (let ((reference-value (%schema-reference-value root-payload reference)))
    (and (not (%missing-schema-value-p reference-value))
         (numberp reference-value)
         (zerop reference-value))))

(defun %schema-reference-number-nonzero-p (root-payload reference)
  (let ((reference-value (%schema-reference-value root-payload reference)))
    (and (not (%missing-schema-value-p reference-value))
         (numberp reference-value)
         (not (zerop reference-value)))))

(defun %schema-relation-values-all-numeric-p (root-payload relation)
  (every (lambda (reference)
           (let ((reference-value (%schema-reference-value root-payload reference)))
             (and (not (%missing-schema-value-p reference-value))
                  (numberp reference-value))))
         (%schema-relation-fields relation)))

(defun %schema-relation-values-sum (root-payload relation)
  (reduce #'+ (%schema-relation-fields relation)
          :key (lambda (reference)
                 (%schema-reference-value root-payload reference))
          :initial-value 0))

(defun %schema-reference-value (payload reference)
  (let ((current payload))
    (dolist (segment (uiop:split-string reference :separator '(#\.))
                     +missing-schema-value+)
      (if (%property-list-p current)
          (multiple-value-bind (value present-p)
              (%schema-field-value current segment)
            (unless present-p
              (return +missing-schema-value+))
            (setf current value))
          (return +missing-schema-value+)))
    current))

(defun %command-output-json-fields (command-name)
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command command-name))
         (schema (and definition (cl-cc.models:command-output-schema definition)))
         (json-fields (and schema (getf schema :json))))
    (values definition schema json-fields)))

(defun %schema-known-keys (fields)
  (remove-duplicates
   (loop for field in fields
         append (%schema-field-candidate-keys (cl-cc::%output-schema-json-field-name field)))
   :test #'eq))

(defun %schema-key-display-name (key)
  (cl-cc.lib:string-designator-downcase key))

(defun %unexpected-schema-field-errors (payload fields path)
  (let ((known-keys (%schema-known-keys fields))
        (errors '()))
    (when (%property-list-p payload)
      (loop for key in payload by #'cddr do
        (unless (member key known-keys)
          (push (%schema-error (format nil "~A.~A" path (%schema-key-display-name key))
                               "unexpected field")
                errors))))
    (nreverse errors)))

(defun %result-status-json-name (status)
  (cl-cc.lib:string-designator-downcase status))

(defun %error-code-json-name (error-code)
  (cl-cc.lib:string-designator-upcase error-code))

(defun %json-field-name-to-keyword (name)
  (cl-cc.lib:string-designator-keyword name))

(defun %normalized-status-counts (status-counts)
  (loop for (status-name . count) in status-counts
        append (list (%json-field-name-to-keyword status-name) count)))

(defun %result-payload (result-object)
  (cl-cc.lib:result-payload result-object))

(defun %result-status-name (result-object)
  (%result-status-json-name (cl-cc.lib:result-status result-object)))

(defun %append-schema-field (payload key value present-p)
  (if present-p
      (append payload (list key value))
      payload))

(defun %append-present-schema-field (payload key raw-value present-p &optional (normalizer #'identity))
  (%append-schema-field payload key (funcall normalizer raw-value) present-p))

(defun %append-payload-schema-field (envelope target-key payload source-key &optional (normalizer #'identity))
  (let ((value (getf payload source-key +missing-schema-value+)))
    (%append-present-schema-field envelope
                                  target-key
                                  value
                                  (not (%missing-schema-value-p value))
                                  normalizer)))

(defun %optional-status-json-name (value)
  (and (not (%schema-nullish-p value))
       (%result-status-json-name value)))

(defun %normalized-tool-record (record)
  (if (%property-list-p record)
      (let ((payload (list :tool-id (or (getf record :tool-id) (getf record :tool))
                           :tool (or (getf record :tool) (getf record :tool-id))
                           :status (%result-status-json-name (getf record :status))
                           :duration-seconds (getf record :duration-seconds))))
        (setf payload (%append-payload-schema-field payload :output record :output))
        (setf payload (%append-payload-schema-field payload :error record :error))
        (setf payload (%append-payload-schema-field payload
                                                    :error-code
                                                    record
                                                    :error-code
                                                    #'%error-code-json-name))
        payload)
      record))

(defun %normalized-record-collection (records normalizer)
  (cond
    ((vectorp records)
     (map 'vector normalizer records))
    ((and (listp records)
      (%schema-array-p records))
     (mapcar normalizer records))
    (t
     records)))

(defun %normalized-fixture-record (record)
  (if (%property-list-p record)
  (list :fixture-id (getf record :fixture-id)
    :status (%result-status-json-name (getf record :status))
    :duration-seconds (getf record :duration-seconds)
    :result (getf record :result)
    :tool-results (%normalized-record-collection (getf record :tool-results)
                     #'%normalized-tool-record))
  record))

(defun %run-fixture-result-envelope (result-object)
  (let ((payload (%result-payload result-object)))
    (list :status (%result-status-name result-object)
          :fixture-count (getf payload :fixture-count)
          :successful-count (getf payload :successful-count)
          :failed-count (getf payload :failed-count)
          :duration-seconds (getf payload :duration-seconds)
          :status-counts (%normalized-status-counts (getf payload :status-counts))
          :ok (getf payload :ok)
          :exit-code (getf payload :exit-code)
          :results (%normalized-record-collection (getf payload :results)
                                                  #'%normalized-fixture-record))))

(defun %docs-sync-result-envelope (result-object)
  (let ((payload (%result-payload result-object)))
    (list :path (getf payload :path)
          :status (%result-status-name result-object)
          :check-only (getf payload :check-only)
          :updated (getf payload :updated)
          :needs-sync (getf payload :needs-sync)
          :duration-seconds (getf payload :duration-seconds)
          :exit-code (getf payload :exit-code))))

(defun %session-result-envelope (result-object)
  (let* ((payload (%result-payload result-object))
         (envelope (list :status (%result-status-name result-object)
                         :session-id (getf payload :session-id)
                         :duration-seconds (getf payload :duration-seconds)
                         :exit-code (getf payload :exit-code))))
    (setf envelope (%append-payload-schema-field envelope :history-index payload :history-index))
    (setf envelope (%append-payload-schema-field envelope
                                                :session-status
                                                payload
                                                :session-status
                                                #'%optional-status-json-name))
    (setf envelope (%append-payload-schema-field envelope :input payload :input))
    (setf envelope (%append-payload-schema-field envelope
                                                :execution-status
                                                payload
                                                :execution-status
                                                #'%optional-status-json-name))
    (setf envelope (%append-payload-schema-field envelope :selected-tools payload :selected-tools))
    (setf envelope (%append-payload-schema-field envelope :execution-plan payload :execution-plan))
    (setf envelope (%append-payload-schema-field envelope :result payload :result))
    (setf envelope (%append-payload-schema-field envelope
                                                :tool-results
                                                payload
                                                :tool-results
                                                (lambda (records)
                                                  (%normalized-record-collection records #'%normalized-tool-record))))
    (setf envelope (%append-payload-schema-field envelope :session-path payload :session-path))
    (setf envelope (%append-payload-schema-field envelope :saved payload :saved))
    envelope))

(defun %normalized-session-list-record (record)
  (let ((normalized (copy-list record)))
    (when (getf normalized :session-status)
      (setf (getf normalized :session-status)
            (%optional-status-json-name (getf normalized :session-status))))
    normalized))

(defun %session-list-result-envelope (result-object)
  (let* ((payload (%result-payload result-object))
         (envelope (list :status (%result-status-name result-object)
                         :session-directory (getf payload :session-directory)
                         :used-default-directory (getf payload :used-default-directory)
                         :session-count (getf payload :session-count)
                         :duration-seconds (getf payload :duration-seconds)
                         :exit-code (getf payload :exit-code))))
    (setf envelope (%append-payload-schema-field envelope
                                                :sessions
                                                payload
                                                :sessions
                                                (lambda (records)
                                                  (%normalized-record-collection records #'%normalized-session-list-record))))
    envelope))

(defun %schema-field-basic-validation-error (value field-path field-type nullable-p enum-values)
  (cond
    ((and (%schema-nullish-p value) nullable-p)
     :nullable)
    ((and field-type
          (not (%schema-value-matches-type-p field-type value)))
     (%schema-error field-path
                    (format nil "expected value of type ~A" field-type)))
    ((and enum-values
          (not (member value enum-values :test #'equal)))
     (%schema-error field-path
                    (format nil "expected one of ~S" enum-values)))))

                    (defun %schema-field-conditional-enum-error (value field-path root-payload enum-when-zero-field enum-when-nonzero-field)
                      (cond
                        ((and enum-when-zero-field
                          (%schema-reference-number-zero-p root-payload (%schema-relation-field-name enum-when-zero-field))
                          (not (member value (%schema-relation-values enum-when-zero-field) :test #'equal)))
                         (%schema-error field-path
                            (format nil "expected one of ~S when ~A is zero"
                                (%schema-relation-values enum-when-zero-field)
                                (%schema-relation-field-name enum-when-zero-field))))
                        ((and enum-when-nonzero-field
                          (%schema-reference-number-nonzero-p root-payload (%schema-relation-field-name enum-when-nonzero-field))
                          (not (member value (%schema-relation-values enum-when-nonzero-field) :test #'equal)))
                         (%schema-error field-path
                            (format nil "expected one of ~S when ~A is non-zero"
                                (%schema-relation-values enum-when-nonzero-field)
                                (%schema-relation-field-name enum-when-nonzero-field))))))

                    (defun %schema-field-size-validation-error (value field-path minimum-value minimum-items maximum-value)
                      (cond
                        ((and minimum-value
                          (numberp value)
                          (< value minimum-value))
                         (%schema-error field-path
                            (format nil "expected value >= ~A" minimum-value)))
                        ((and minimum-items
                          (%schema-array-p value)
                          (< (%schema-collection-size value) minimum-items))
                         (%schema-error field-path
                            (format nil "expected at least ~A item~:P" minimum-items)))
                        ((and maximum-value
                          (numberp value)
                          (> value maximum-value))
                         (%schema-error field-path
                            (format nil "expected value <= ~A" maximum-value)))))

                    (defun %schema-field-relation-validation-error (value field-path root-payload
                                         equals-field
                                         equals-collection-size-of
                                         equals-sum-of-fields
                                         equals-field-when-value
                                         true-when-zero-field)
                      (cond
                        ((and equals-field
                          (%schema-reference-present-p root-payload equals-field)
                          (not (equal value (%schema-reference-value root-payload equals-field))))
                         (%schema-error field-path
                            (format nil "expected value matching ~A" equals-field)))
                        ((and equals-collection-size-of
                          (%schema-reference-present-p root-payload equals-collection-size-of)
                          (not (= value (%schema-collection-size (%schema-reference-value root-payload equals-collection-size-of)))))
                         (%schema-error field-path
                            (format nil "expected value matching item count of ~A" equals-collection-size-of)))
                        ((and equals-sum-of-fields
                          (%schema-relation-values-all-numeric-p root-payload equals-sum-of-fields)
                          (not (= value (%schema-relation-values-sum root-payload equals-sum-of-fields))))
                         (%schema-error field-path
                            (format nil "expected value matching sum of ~{~A~^, ~}"
                                (%schema-relation-fields equals-sum-of-fields))))
                        ((and equals-field-when-value
                          (%schema-reference-present-p root-payload (%schema-relation-when-field-name equals-field-when-value))
                          (equal (%schema-reference-value root-payload (%schema-relation-when-field-name equals-field-when-value))
                             (%schema-relation-value equals-field-when-value))
                          (%schema-reference-present-p root-payload (%schema-relation-field-name equals-field-when-value))
                          (not (equal value (%schema-reference-value root-payload (%schema-relation-field-name equals-field-when-value)))))
                         (%schema-error field-path
                            (format nil "expected value matching ~A when ~A is ~S"
                                (%schema-relation-field-name equals-field-when-value)
                                (%schema-relation-when-field-name equals-field-when-value)
                                (%schema-relation-value equals-field-when-value))))
                        ((and true-when-zero-field
                          (%schema-reference-present-p root-payload true-when-zero-field)
                          (numberp (%schema-reference-value root-payload true-when-zero-field))
                          (not (eql value (zerop (%schema-reference-value root-payload true-when-zero-field)))))
                         (%schema-error field-path
                            (format nil "expected boolean matching zero value of ~A" true-when-zero-field)))))

(defun %command-result-envelope (command-name result-object)
  (cond
    ((string= command-name "run --fixture")
     (%run-fixture-result-envelope result-object))
    ((string= command-name "docs sync-reference")
     (%docs-sync-result-envelope result-object))
    ((string= command-name "session list")
     (%session-list-result-envelope result-object))
    ((or (string= command-name "session start")
         (string= command-name "session resume")
         (string= command-name "session run"))
     (%session-result-envelope result-object))
    (t
     (cl-cc.lib:result-payload result-object))))

(defun %validate-schema-field-value (field value field-path root-payload)
  (let* ((enum-values (%schema-field-enum-values field))
         (nullable-p (%schema-field-nullable-p field))
         (field-type (%schema-field-type field))
         (minimum-value (%schema-field-minimum field))
         (minimum-items (%schema-field-min-items field))
         (equals-field (%schema-field-equals-field field))
         (equals-collection-size-of (%schema-field-equals-collection-size-of field))
         (equals-sum-of-fields (%schema-field-equals-sum-of-fields field))
         (equals-field-when-value (%schema-field-equals-field-when-value field))
         (true-when-zero-field (%schema-field-true-when-zero-field field))
         (enum-when-zero-field (%schema-field-enum-when-zero-field field))
         (enum-when-nonzero-field (%schema-field-enum-when-nonzero-field field))
         (maximum-value (%schema-field-maximum field))
         (error (or (%schema-field-basic-validation-error value
                                                          field-path
                                                          field-type
                                                          nullable-p
                                                          enum-values)
                    (%schema-field-conditional-enum-error value
                                                          field-path
                                                          root-payload
                                                          enum-when-zero-field
                                                          enum-when-nonzero-field)
                    (%schema-field-size-validation-error value
                                                         field-path
                                                         minimum-value
                                                         minimum-items
                                                         maximum-value)
                    (%schema-field-relation-validation-error value
                                                             field-path
                                                             root-payload
                                                             equals-field
                                                             equals-collection-size-of
                                                             equals-sum-of-fields
                                                             equals-field-when-value
                                                             true-when-zero-field))))
    (cond
      ((eq error :nullable)
       nil)
      (error
       (list error))
      (t
       nil))))

(defun %validate-schema-collection-field-value (value child-fields field-path child-closed-p root-payload)
  (let ((errors '()))
    (unless (%schema-array-p value)
      (push (%schema-error field-path "expected list value") errors))
    (when (%schema-array-p value)
      (loop for item in (%schema-collection-items value)
            for index from 0 do
        (if (listp item)
            (setf errors (nconc (nreverse (%validate-schema-fields item
                                                                  child-fields
                                                                  (format nil "~A[~D]" field-path index)
                                                                  child-closed-p
                                                                  root-payload))
                                errors))
            (push (%schema-error (format nil "~A[~D]" field-path index)
                                 "expected property list item")
                  errors))))
    (nreverse errors)))

(defun %validate-schema-child-object-value (value child-fields field-path child-closed-p root-payload)
  (cond
    ((null child-fields)
     nil)
    ((null value)
     (list (%schema-error field-path "expected structured value")))
    ((listp value)
     (%validate-schema-fields value child-fields field-path child-closed-p root-payload))
    (t
     (list (%schema-error field-path "expected property list value")))))

(defun %validate-present-schema-field (field value payload field-path root-payload)
  (let ((errors (nreverse (%validate-schema-field-value field value field-path root-payload))))
    (let* ((collection-p (getf field :collection))
           (child-fields (%schema-field-children-for-record field payload))
           (child-closed-p (%schema-field-closed-p field payload)))
      (cond
        (collection-p
         (nconc (nreverse (%validate-schema-collection-field-value value
                                                                   child-fields
                                                                   field-path
                                                                   child-closed-p
                                                                   root-payload))
                errors))
        (child-fields
         (nconc (nreverse (%validate-schema-child-object-value value
                                                              child-fields
                                                              field-path
                                                              child-closed-p
                                                              root-payload))
                errors))
        (t
         errors)))))

(defun %validate-schema-fields (payload fields path &optional closed-p root-payload)
  (let ((errors '()))
    (when (null root-payload)
      (setf root-payload payload))
    (when closed-p
      (setf errors (nconc (nreverse (%unexpected-schema-field-errors payload fields path))
                          errors)))
    (dolist (field fields (nreverse errors))
      (let* ((field-name (cl-cc::%output-schema-json-field-name field))
             (field-path (format nil "~A.~A" path field-name))
             (required-p (%schema-field-required-p field)))
        (multiple-value-bind (value present-p)
            (%schema-field-value payload field-name)
          (unless (or present-p
                      (not required-p))
            (push (%schema-error field-path "missing required field") errors))
          (when present-p
            (setf errors (nconc (%validate-present-schema-field field
                                                                value
                                                                payload
                                                                field-path
                                                                root-payload)
                                errors))))))))

(defun command-result-schema-errors (command-name result-object)
  "Return schema conformance errors for a command result object."
  (multiple-value-bind (definition schema json-fields)
      (%command-output-json-fields command-name)
    (let ((payload (%command-result-envelope command-name result-object)))
      (cond
        ((null definition)
         (list (format nil "unknown command: ~A" command-name)))
        ((null json-fields)
         (list (format nil "~A command has no json output schema" command-name)))
        (t
         (%validate-schema-fields payload json-fields "payload" (%schema-closed-p schema)))))))

(defun command-json-output-schema-errors (command-name json-output)
  "Return schema conformance or parse errors for rendered command JSON output."
  (multiple-value-bind (definition schema json-fields)
      (%command-output-json-fields command-name)
    (cond
      ((null definition)
       (list (format nil "unknown command: ~A" command-name)))
      ((null json-fields)
       (list (format nil "~A command has no json output schema" command-name)))
      (t
       (handler-case
           (%validate-schema-fields (%parse-json-document json-output)
                                    json-fields
                                    "payload"
                                    (%schema-closed-p schema))
         (error (condition)
           (list (princ-to-string condition))))))))

(defun command-result-conforms-p (command-name result-object)
  "Return true when a command result object conforms to the registry schema."
  (null (command-result-schema-errors command-name result-object)))

(defun command-json-output-conforms-p (command-name json-output)
  "Return true when rendered command JSON output conforms to the registry schema."
  (null (command-json-output-schema-errors command-name json-output)))

(defun run-fixture-result-schema-errors (result-object)
  "Return a list of schema conformance errors for a run-fixture result object."
  (command-result-schema-errors "run --fixture" result-object))

(defun run-fixture-result-conforms-p (result-object)
  "Return true when a run-fixture result object conforms to the registry schema."
  (command-result-conforms-p "run --fixture" result-object))

(defun docs-sync-result-schema-errors (result-object)
  "Return a list of schema conformance errors for a docs sync result object."
  (command-result-schema-errors "docs sync-reference" result-object))

(defun docs-sync-result-conforms-p (result-object)
  "Return true when a docs sync result object conforms to the registry schema."
  (command-result-conforms-p "docs sync-reference" result-object))

(defun session-start-result-schema-errors (result-object)
  "Return a list of schema conformance errors for a session start result object."
  (command-result-schema-errors "session start" result-object))

(defun session-start-result-conforms-p (result-object)
  "Return true when a session start result object conforms to the registry schema."
  (command-result-conforms-p "session start" result-object))

(defun session-resume-result-schema-errors (result-object)
  "Return a list of schema conformance errors for a session resume result object."
  (command-result-schema-errors "session resume" result-object))

(defun session-resume-result-conforms-p (result-object)
  "Return true when a session resume result object conforms to the registry schema."
  (command-result-conforms-p "session resume" result-object))

(defun session-run-result-schema-errors (result-object)
  "Return a list of schema conformance errors for a session run result object."
  (command-result-schema-errors "session run" result-object))

(defun session-run-result-conforms-p (result-object)
  "Return true when a session run result object conforms to the registry schema."
  (command-result-conforms-p "session run" result-object))

(defun session-list-result-schema-errors (result-object)
  "Return a list of schema conformance errors for a session list result object."
  (command-result-schema-errors "session list" result-object))

(defun session-list-result-conforms-p (result-object)
  "Return true when a session list result object conforms to the registry schema."
  (command-result-conforms-p "session list" result-object))