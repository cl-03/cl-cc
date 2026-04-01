;;;; src/services/schema-validation.lisp - registry-driven schema conformance checks
(in-package :cl-cc.services)

(defparameter +missing-schema-value+ (gensym "MISSING-SCHEMA-VALUE"))
(defparameter +json-null+ (gensym "JSON-NULL"))

(defun %json-null-p (value)
  (eq value +json-null+))

(defun %schema-nullish-p (value)
  (or (null value)
      (%json-null-p value)))

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

(defun %json-whitespace-p (character)
  (member character '(#\Space #\Tab #\Newline #\Return) :test #'char=))

(defun %skip-json-whitespace (text index)
  (loop with length = (length text)
        while (and (< index length)
                   (%json-whitespace-p (char text index))) do
    (incf index)
        finally (return index)))

(defun %json-parser-error (text index message)
  (declare (ignore text))
  (error "JSON parse error at character ~D: ~A" index message))

(defun %parse-json-literal (text index literal value)
  (let ((end-index (+ index (length literal))))
    (when (> end-index (length text))
      (%json-parser-error text index (format nil "expected ~A" literal)))
    (unless (string= text literal :start1 index :end1 end-index)
      (%json-parser-error text index (format nil "expected ~A" literal)))
    (values value end-index)))

(defun %parse-json-string (text index)
  (unless (char= (char text index) #\")
    (%json-parser-error text index "expected string"))
  (let ((stream (make-string-output-stream))
        (cursor (1+ index))
        (length (length text)))
    (loop while (< cursor length) do
      (let ((character (char text cursor)))
        (cond
          ((char= character #\")
           (return-from %parse-json-string
             (values (get-output-stream-string stream) (1+ cursor))))
          ((char= character #\\)
           (incf cursor)
           (when (>= cursor length)
             (%json-parser-error text cursor "unterminated escape sequence"))
           (let ((escaped (char text cursor)))
             (case escaped
               (#\" (write-char #\" stream))
               (#\\ (write-char #\\ stream))
               (#\/ (write-char #\/ stream))
               (#\b (write-char #\Backspace stream))
               (#\f (write-char #\Page stream))
               (#\n (write-char #\Newline stream))
               (#\r (write-char #\Return stream))
               (#\t (write-char #\Tab stream))
               (#\u
                (let ((hex-end (+ cursor 5)))
                  (when (> hex-end length)
                    (%json-parser-error text cursor "incomplete unicode escape"))
                  (let* ((hex-digits (subseq text (1+ cursor) hex-end))
                         (code-point (parse-integer hex-digits :radix 16 :junk-allowed nil)))
                    (write-char (or (code-char code-point)
                                    (%json-parser-error text cursor "invalid unicode code point"))
                                stream)
                    (setf cursor (1- hex-end)))))
               (t
                (%json-parser-error text cursor (format nil "unsupported escape ~C" escaped))))))
          (t
           (write-char character stream))))
      (incf cursor))
    (%json-parser-error text cursor "unterminated string")))

(defun %json-number-character-p (character)
  (or (digit-char-p character)
      (member character '(#\- #\+ #\. #\e #\E) :test #'char=)))

(defun %parse-json-number (text index)
  (let* ((length (length text))
         (end-index index))
    (loop while (and (< end-index length)
                     (%json-number-character-p (char text end-index))) do
      (incf end-index))
    (let ((token (subseq text index end-index)))
      (handler-case
          (multiple-value-bind (value position)
              (let ((*read-eval* nil))
                (read-from-string token nil nil))
            (unless (and value
                         (numberp value)
                         (= position (length token)))
              (%json-parser-error text index "invalid number"))
            (values value end-index))
        (error ()
          (%json-parser-error text index "invalid number"))))))

(defun %parse-json-array (text index)
  (unless (char= (char text index) #\[)
    (%json-parser-error text index "expected array"))
  (let ((cursor (%skip-json-whitespace text (1+ index)))
        (items '()))
    (when (>= cursor (length text))
      (%json-parser-error text cursor "unterminated array"))
    (if (char= (char text cursor) #\])
        (values '() (1+ cursor))
        (loop
          (multiple-value-bind (item next-index)
              (%parse-json-value text cursor)
            (push item items)
            (setf cursor (%skip-json-whitespace text next-index))
            (when (>= cursor (length text))
              (%json-parser-error text cursor "unterminated array"))
            (cond
              ((char= (char text cursor) #\])
               (return-from %parse-json-array
                 (values (nreverse items) (1+ cursor))))
              ((char= (char text cursor) #\,)
               (setf cursor (%skip-json-whitespace text (1+ cursor))))
              (t
               (%json-parser-error text cursor "expected ',' or ']' in array"))))))))

(defun %parse-json-object (text index)
  (unless (char= (char text index) #\{)
    (%json-parser-error text index "expected object"))
  (let ((cursor (%skip-json-whitespace text (1+ index)))
        (plist '()))
    (when (>= cursor (length text))
      (%json-parser-error text cursor "unterminated object"))
    (if (char= (char text cursor) #\})
        (values '() (1+ cursor))
        (loop
          (multiple-value-bind (key after-key)
              (%parse-json-string text cursor)
            (setf cursor (%skip-json-whitespace text after-key))
            (when (or (>= cursor (length text))
                      (not (char= (char text cursor) #\:)))
              (%json-parser-error text cursor "expected ':' after object key"))
            (setf cursor (%skip-json-whitespace text (1+ cursor)))
            (multiple-value-bind (value next-index)
                (%parse-json-value text cursor)
              (setf plist (append plist (list (%json-name-to-keyword key) value)))
              (setf cursor (%skip-json-whitespace text next-index))
              (when (>= cursor (length text))
                (%json-parser-error text cursor "unterminated object"))
              (cond
                ((char= (char text cursor) #\})
                 (return-from %parse-json-object
                   (values plist (1+ cursor))))
                ((char= (char text cursor) #\,)
                 (setf cursor (%skip-json-whitespace text (1+ cursor))))
                (t
                 (%json-parser-error text cursor "expected ',' or '}' in object")))))))))

(defun %parse-json-value (text index)
  (let ((cursor (%skip-json-whitespace text index)))
    (when (>= cursor (length text))
      (%json-parser-error text cursor "unexpected end of input"))
    (case (char text cursor)
      (#\{ (%parse-json-object text cursor))
      (#\[ (%parse-json-array text cursor))
      (#\" (%parse-json-string text cursor))
      (#\t (%parse-json-literal text cursor "true" t))
      (#\f (%parse-json-literal text cursor "false" nil))
      (#\n (%parse-json-literal text cursor "null" +json-null+))
      (t
       (if (or (char= (char text cursor) #\-)
               (digit-char-p (char text cursor)))
           (%parse-json-number text cursor)
           (%json-parser-error text cursor "unexpected token"))))))

(defun %parse-json-document (text)
  (multiple-value-bind (value next-index)
      (%parse-json-value text 0)
    (let ((cursor (%skip-json-whitespace text next-index)))
      (when (< cursor (length text))
        (%json-parser-error text cursor "trailing content after JSON value"))
      value)))

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
  (and (listp schema)
       (getf schema :closed)))

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

(defun %schema-field-enum-values (field)
  (and (listp field)
       (getf field :enum)))

(defun %schema-field-nullable-p (field)
  (and (listp field)
       (getf field :nullable)))

(defun %schema-field-required-p (field)
  (if (and (listp field)
           (not (eq (getf field :required :missing) :missing)))
      (getf field :required)
      t))

(defun %schema-field-type (field)
  (and (listp field)
       (getf field :type)))

(defun %schema-field-minimum (field)
  (and (listp field)
       (getf field :minimum)))

(defun %schema-field-min-items (field)
  (and (listp field)
       (getf field :min-items)))

(defun %schema-field-equals-field (field)
  (and (listp field)
       (getf field :equals-field)))

(defun %schema-field-equals-collection-size-of (field)
  (and (listp field)
       (getf field :equals-collection-size-of)))

(defun %schema-field-equals-sum-of-fields (field)
  (and (listp field)
       (getf field :equals-sum-of-fields)))

(defun %schema-field-equals-field-when-value (field)
  (and (listp field)
       (getf field :equals-field-when-value)))

(defun %schema-field-true-when-zero-field (field)
  (and (listp field)
       (getf field :true-when-zero-field)))

(defun %schema-field-enum-when-zero-field (field)
  (and (listp field)
       (getf field :enum-when-zero-field)))

(defun %schema-field-enum-when-nonzero-field (field)
  (and (listp field)
       (getf field :enum-when-nonzero-field)))

(defun %schema-relation-field-name (relation)
  (and (listp relation)
       (getf relation :field)))

(defun %schema-relation-when-field-name (relation)
  (and (listp relation)
       (getf relation :when-field)))

(defun %schema-relation-value (relation)
  (and (listp relation)
       (getf relation :value)))

(defun %schema-relation-values (relation)
  (and (listp relation)
       (getf relation :values)))

(defun %schema-relation-fields (relation)
  (and (listp relation)
       (getf relation :fields)))

(defun %schema-field-maximum (field)
  (and (listp field)
       (getf field :maximum)))

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
  (string-downcase (string key)))

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
  (string-downcase (string status)))

(defun %error-code-json-name (error-code)
  (and error-code
       (string-upcase (string error-code))))

(defun %json-field-name-to-keyword (name)
  (intern (string-upcase name) :keyword))

(defun %normalized-status-counts (status-counts)
  (loop for (status-name . count) in status-counts
        append (list (%json-field-name-to-keyword status-name) count)))

(defun %append-schema-field (payload key value present-p)
  (if present-p
      (append payload (list key value))
      payload))

(defun %normalized-tool-record (record)
  (if (%property-list-p record)
  (let* ((output (getf record :output +missing-schema-value+))
         (error (getf record :error +missing-schema-value+))
         (error-code (getf record :error-code +missing-schema-value+))
         (payload (list :tool-id (or (getf record :tool-id) (getf record :tool))
                        :tool (or (getf record :tool) (getf record :tool-id))
                        :status (%result-status-json-name (getf record :status))
                        :duration-seconds (getf record :duration-seconds))))
    (setf payload (%append-schema-field payload :output output (not (eq output +missing-schema-value+))))
    (setf payload (%append-schema-field payload :error error (not (eq error +missing-schema-value+))))
    (setf payload (%append-schema-field payload :error-code
                                        (%error-code-json-name error-code)
                                        (not (eq error-code +missing-schema-value+))))
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
  (let ((payload (cl-cc.lib:result-payload result-object)))
    (list :status (%result-status-json-name (cl-cc.lib:result-status result-object))
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
  (let ((payload (cl-cc.lib:result-payload result-object)))
    (list :path (getf payload :path)
          :status (%result-status-json-name (cl-cc.lib:result-status result-object))
          :check-only (getf payload :check-only)
          :updated (getf payload :updated)
          :needs-sync (getf payload :needs-sync)
          :duration-seconds (getf payload :duration-seconds)
          :exit-code (getf payload :exit-code))))

(defun %session-result-envelope (result-object)
  (let* ((payload (cl-cc.lib:result-payload result-object))
      (history-index (getf payload :history-index +missing-schema-value+))
      (session-status (getf payload :session-status +missing-schema-value+))
      (envelope (list :status (%result-status-json-name (cl-cc.lib:result-status result-object))
          :session-id (getf payload :session-id)
          :duration-seconds (getf payload :duration-seconds)
          :exit-code (getf payload :exit-code))))
    (setf envelope (%append-schema-field envelope
                 :history-index
                 history-index
                 (not (eq history-index +missing-schema-value+))))
    (setf envelope (%append-schema-field envelope
                 :session-status
                 (and (not (%schema-nullish-p session-status))
                   (%result-status-json-name session-status))
                 (not (eq session-status +missing-schema-value+))))
    envelope))

(defun %command-result-envelope (command-name result-object)
  (cond
    ((string= command-name "run --fixture")
     (%run-fixture-result-envelope result-object))
    ((string= command-name "docs sync-reference")
     (%docs-sync-result-envelope result-object))
    ((or (string= command-name "session start")
         (string= command-name "session resume"))
     (%session-result-envelope result-object))
    (t
     (cl-cc.lib:result-payload result-object))))

(defun %validate-schema-field-value (field value field-path root-payload)
  (let ((errors '())
        (enum-values (%schema-field-enum-values field))
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
  (maximum-value (%schema-field-maximum field)))
    (cond
  ((and (%schema-nullish-p value) nullable-p)
       nil)
      ((and field-type
            (not (case field-type
                   (:string (stringp value))
                   (:integer (integerp value))
           (:number (numberp value))
                   (:boolean (or (eq value t) (null value)))
           (:object (%schema-object-p value))
           (:array (%schema-array-p value))
                   (t t))))
       (push (%schema-error field-path
                            (format nil "expected value of type ~A" field-type))
             errors))
      ((and enum-values
            (not (member value enum-values :test #'equal)))
       (push (%schema-error field-path
                            (format nil "expected one of ~S" enum-values))
         errors))
      ((and enum-when-zero-field
        (not (eq (%schema-reference-value root-payload (%schema-relation-field-name enum-when-zero-field))
           +missing-schema-value+))
        (numberp (%schema-reference-value root-payload (%schema-relation-field-name enum-when-zero-field)))
        (zerop (%schema-reference-value root-payload (%schema-relation-field-name enum-when-zero-field)))
        (not (member value (%schema-relation-values enum-when-zero-field) :test #'equal)))
       (push (%schema-error field-path
          (format nil "expected one of ~S when ~A is zero"
            (%schema-relation-values enum-when-zero-field)
            (%schema-relation-field-name enum-when-zero-field)))
         errors))
      ((and enum-when-nonzero-field
        (not (eq (%schema-reference-value root-payload (%schema-relation-field-name enum-when-nonzero-field))
           +missing-schema-value+))
        (numberp (%schema-reference-value root-payload (%schema-relation-field-name enum-when-nonzero-field)))
        (not (zerop (%schema-reference-value root-payload (%schema-relation-field-name enum-when-nonzero-field))))
        (not (member value (%schema-relation-values enum-when-nonzero-field) :test #'equal)))
       (push (%schema-error field-path
          (format nil "expected one of ~S when ~A is non-zero"
            (%schema-relation-values enum-when-nonzero-field)
            (%schema-relation-field-name enum-when-nonzero-field)))
         errors))
      ((and minimum-value
        (numberp value)
        (< value minimum-value))
       (push (%schema-error field-path
                (format nil "expected value >= ~A" minimum-value))
         errors))
      ((and minimum-items
            (%schema-array-p value)
            (< (%schema-collection-size value) minimum-items))
       (push (%schema-error field-path
                            (format nil "expected at least ~A item~:P" minimum-items))
             errors))
      ((and equals-field
        (not (eq (%schema-reference-value root-payload equals-field) +missing-schema-value+))
        (not (equal value (%schema-reference-value root-payload equals-field))))
       (push (%schema-error field-path
                (format nil "expected value matching ~A" equals-field))
         errors))
      ((and equals-collection-size-of
        (not (eq (%schema-reference-value root-payload equals-collection-size-of) +missing-schema-value+))
        (not (= value (%schema-collection-size (%schema-reference-value root-payload equals-collection-size-of)))))
       (push (%schema-error field-path
                (format nil "expected value matching item count of ~A" equals-collection-size-of))
         errors))
            ((and equals-sum-of-fields
         (every (lambda (reference)
             (let ((reference-value (%schema-reference-value root-payload reference)))
               (and (not (eq reference-value +missing-schema-value+))
               (numberp reference-value))))
           (%schema-relation-fields equals-sum-of-fields))
         (not (= value
            (reduce #'+ (%schema-relation-fields equals-sum-of-fields)
               :key (lambda (reference)
                 (%schema-reference-value root-payload reference))
               :initial-value 0))))
        (push (%schema-error field-path
            (format nil "expected value matching sum of ~{~A~^, ~}"
               (%schema-relation-fields equals-sum-of-fields)))
          errors))
      ((and equals-field-when-value
        (not (eq (%schema-reference-value root-payload (%schema-relation-when-field-name equals-field-when-value))
                 +missing-schema-value+))
        (equal (%schema-reference-value root-payload (%schema-relation-when-field-name equals-field-when-value))
               (%schema-relation-value equals-field-when-value))
        (not (eq (%schema-reference-value root-payload (%schema-relation-field-name equals-field-when-value))
                 +missing-schema-value+))
        (not (equal value (%schema-reference-value root-payload (%schema-relation-field-name equals-field-when-value)))))
       (push (%schema-error field-path
                (format nil "expected value matching ~A when ~A is ~S"
                        (%schema-relation-field-name equals-field-when-value)
                        (%schema-relation-when-field-name equals-field-when-value)
                        (%schema-relation-value equals-field-when-value)))
         errors))
      ((and true-when-zero-field
        (not (eq (%schema-reference-value root-payload true-when-zero-field) +missing-schema-value+))
        (numberp (%schema-reference-value root-payload true-when-zero-field))
        (not (eql value (zerop (%schema-reference-value root-payload true-when-zero-field)))))
       (push (%schema-error field-path
                (format nil "expected boolean matching zero value of ~A" true-when-zero-field))
         errors))
      ((and maximum-value
        (numberp value)
        (> value maximum-value))
       (push (%schema-error field-path
                (format nil "expected value <= ~A" maximum-value))
         errors)))
    (nreverse errors)))

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
            (setf errors (nconc (nreverse (%validate-schema-field-value field value field-path root-payload))
                               errors))
            (let* ((collection-p (getf field :collection))
                   (child-fields (%schema-field-children-for-record field payload))
                   (child-closed-p (%schema-field-closed-p field payload)))
              (cond
                (collection-p
                 (unless (%schema-array-p value)
                   (push (%schema-error field-path "expected list value") errors))
                 (when (%schema-array-p value)
                   (loop for item in (%schema-collection-items value)
                         for index from 0 do
                     (if (listp item)
                       (setf errors (nconc (nreverse (%validate-schema-fields item child-fields
                                                  (format nil "~A[~D]" field-path index)
                                                  child-closed-p
                                                  root-payload))
                                            errors))
                         (push (%schema-error (format nil "~A[~D]" field-path index)
                                              "expected property list item")
                               errors)))))
                (child-fields
                 (cond
                   ((null child-fields)
                    nil)
                   ((null value)
                    (push (%schema-error field-path "expected structured value") errors))
                   ((listp value)
                    (setf errors (nconc (nreverse (%validate-schema-fields value child-fields field-path child-closed-p root-payload))
                                       errors)))
                   (t
                    (push (%schema-error field-path "expected property list value") errors))))))))))))

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