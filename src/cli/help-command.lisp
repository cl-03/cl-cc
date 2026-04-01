;;;; src/cli/help-command.lisp - CLI 帮助命令骨架
(in-package :cl-cc)

(defparameter +command-reference-start-marker+ "<!-- BEGIN GENERATED COMMAND REFERENCE -->")
(defparameter +command-reference-end-marker+ "<!-- END GENERATED COMMAND REFERENCE -->")

(defun %format-command-usage (definition)
        (let ((usage-tail (cl-cc.core::command-usage-tail definition)))
                (if (> (length usage-tail) 0)
                        (format nil "  cl-cc ~A ~A" (cl-cc.models:command-name definition) usage-tail)
                        (format nil "  cl-cc ~A" (cl-cc.models:command-name definition)))))

(defun %format-command-aliases (definition)
        (let ((aliases (cl-cc.models:command-aliases definition)))
                (when aliases
                        (format nil "    aliases: ~{~A~^, ~}"
                                (mapcar (lambda (alias)
                                                  (format nil "cl-cc ~{~A~^ ~}" alias))
                                        aliases)))))

(defun %format-command-reference-usage (definition)
        (let ((usage-tail (cl-cc.core::command-usage-tail definition)))
                (if (> (length usage-tail) 0)
                        (format nil "`cl-cc ~A ~A`" (cl-cc.models:command-name definition) usage-tail)
                        (format nil "`cl-cc ~A`" (cl-cc.models:command-name definition)))))

(defun %format-command-reference-aliases (definition)
        (let ((aliases (cl-cc.models:command-aliases definition)))
                (when aliases
                        (format nil "`~{~A~^`, `~}`"
                                (mapcar (lambda (alias)
                                                  (format nil "cl-cc ~{~A~^ ~}" alias))
                                        aliases)))))

(defun %output-schema-json-field-name (field)
        (if (stringp field)
                field
                (getf field :name)))

(defun %output-schema-json-field-summary (field)
        (and (listp field)
             (getf field :summary)))

(defun %output-schema-json-field-enum (field)
        (and (listp field)
             (getf field :enum)))

(defun %output-schema-json-field-nullable-p (field)
        (and (listp field)
             (getf field :nullable)))

(defun %output-schema-json-field-required-p (field)
        (if (and (listp field)
                 (not (eq (getf field :required :missing) :missing)))
                (getf field :required)
                t))

(defun %output-schema-closed-p (schema)
        (and (listp schema)
             (getf schema :closed)))

(defun %output-schema-json-field-closed-p (field)
        (if (and (listp field)
                 (not (eq (getf field :closed :missing) :missing)))
                (getf field :closed)
                (let* ((schema-refs (%output-schema-json-field-tool-schema-refs field))
                       (schema (%tool-schema-from-ref (first schema-refs))))
                        (%output-schema-closed-p schema))))

(defun %output-schema-json-field-type (field)
        (and (listp field)
             (getf field :type)))

(defun %output-schema-json-field-minimum (field)
        (and (listp field)
             (getf field :minimum)))

(defun %output-schema-json-field-min-items (field)
        (and (listp field)
             (getf field :min-items)))

(defun %output-schema-json-field-equals-field (field)
        (and (listp field)
             (getf field :equals-field)))

(defun %output-schema-json-field-equals-collection-size-of (field)
        (and (listp field)
             (getf field :equals-collection-size-of)))

(defun %output-schema-json-field-equals-sum-of-fields (field)
        (and (listp field)
             (getf field :equals-sum-of-fields)))

(defun %output-schema-json-field-equals-field-when-value (field)
        (and (listp field)
             (getf field :equals-field-when-value)))

(defun %output-schema-json-field-true-when-zero-field (field)
        (and (listp field)
             (getf field :true-when-zero-field)))

(defun %output-schema-json-field-enum-when-zero-field (field)
        (and (listp field)
             (getf field :enum-when-zero-field)))

(defun %output-schema-json-field-enum-when-nonzero-field (field)
        (and (listp field)
             (getf field :enum-when-nonzero-field)))

(defun %output-schema-relation-field-name (relation)
        (and (listp relation)
             (getf relation :field)))

(defun %output-schema-relation-when-field-name (relation)
        (and (listp relation)
             (getf relation :when-field)))

(defun %output-schema-relation-value (relation)
        (and (listp relation)
             (getf relation :value)))

(defun %output-schema-relation-values (relation)
        (and (listp relation)
             (getf relation :values)))

(defun %output-schema-relation-fields (relation)
        (and (listp relation)
             (getf relation :fields)))

(defun %format-conditional-enum-summary (label relation)
        (let ((field-name (%output-schema-relation-field-name relation))
              (values (%output-schema-relation-values relation)))
                (when (and field-name values)
                        (format nil "[~A: `~A` => ~{`~A`~^, ~}]"
                                label
                                field-name
                                values))))

(defun %format-conditional-equals-summary (relation)
        (let ((when-field (%output-schema-relation-when-field-name relation))
              (when-value (%output-schema-relation-value relation))
              (field-name (%output-schema-relation-field-name relation)))
                (when (and when-field field-name (not (null when-value)))
                        (format nil "[matches-when: `~A` = `~A` => `~A`]"
                                when-field
                                when-value
                                field-name))))

(defun %format-sum-of-fields-summary (relation)
        (let ((fields (%output-schema-relation-fields relation)))
                (when fields
                        (format nil "[sum-of: ~{`~A`~^, ~}]"
                                fields))))

(defun %output-schema-json-field-maximum (field)
        (and (listp field)
             (getf field :maximum)))

(defun %output-schema-json-field-children (field)
        (and (listp field)
             (getf field :fields)))

(defun %output-schema-json-field-tool-schema-refs (field)
        (and (listp field)
             (getf field :tool-schema-refs)))

(defun %tool-schema-from-ref (ref)
        (let* ((definition (cl-cc.tools:find-tool-definition (getf ref :tool-id)))
               (kind (getf ref :kind :output)))
                (when definition
                        (case kind
                                (:error-output (cl-cc.models:tool-error-output-schema definition))
                                (t (cl-cc.models:tool-output-schema definition))))))

(defun %prefixed-schema-fields (ref)
        (let* ((schema (%tool-schema-from-ref ref))
               (tool-id (getf ref :tool-id))
               (json-fields (and schema (%schema-json-fields schema))))
                (when json-fields
                        (mapcar (lambda (field)
                                          (list :name (format nil "~A.~A" tool-id (%output-schema-json-field-name field))
                                                :summary (%output-schema-json-field-summary field)
                                                :type (%output-schema-json-field-type field)
                                                                :minimum (%output-schema-json-field-minimum field)
                                                :min-items (%output-schema-json-field-min-items field)
                                                :equals-field (%output-schema-json-field-equals-field field)
                                                :equals-collection-size-of (%output-schema-json-field-equals-collection-size-of field)
                                                                :equals-sum-of-fields (%output-schema-json-field-equals-sum-of-fields field)
                                                                :equals-field-when-value (%output-schema-json-field-equals-field-when-value field)
                                                :true-when-zero-field (%output-schema-json-field-true-when-zero-field field)
                                                :enum-when-zero-field (%output-schema-json-field-enum-when-zero-field field)
                                                :enum-when-nonzero-field (%output-schema-json-field-enum-when-nonzero-field field)
                                                                                    :maximum (%output-schema-json-field-maximum field)
                                                :enum (%output-schema-json-field-enum field)
                                                :closed (%output-schema-json-field-closed-p field)
                                                                                :required (%output-schema-json-field-required-p field)
                                                :nullable (%output-schema-json-field-nullable-p field)
                                                :fields (%output-schema-json-field-children field)))
                                json-fields))))

(defun %format-json-schema-summary-part (json-fields closed-p)
        (format nil "`json`: `~{~A~^`, `~}`~:[~; [closed]~]"
                (mapcar #'%output-schema-json-field-name json-fields)
                closed-p))

(defun %output-schema-json-field-derived-children (field)
        (let ((children (%output-schema-json-field-children field))
              (schema-refs (%output-schema-json-field-tool-schema-refs field)))
                (append children
                        (loop for ref in schema-refs
                              append (%prefixed-schema-fields ref)))))

(defun %format-command-reference-output-schema (definition)
        (let ((output-schema (cl-cc.models:command-output-schema definition)))
                (when output-schema
                        (let ((text-schema (getf output-schema :text))
                              (json-fields (getf output-schema :json))
                              (parts nil))
                                (when text-schema
                                        (push (format nil "`text`: ~A" text-schema) parts))
                                (when json-fields
                                        (push (%format-json-schema-summary-part json-fields
                                                                                (%output-schema-closed-p output-schema))
                                              parts))
                                (format nil "~{~A~^; ~}" (nreverse parts))))))

(defun %format-command-reference-json-field-lines (definition)
        (let ((json-fields (getf (cl-cc.models:command-output-schema definition) :json)))
                (when json-fields
                        (%format-json-field-lines json-fields))))

(defun %schema-text-description (schema)
        (getf schema :text))

(defun %schema-json-fields (schema)
        (getf schema :json))

(defun %format-schema-summary (schema)
        (when schema
                (let ((text-schema (%schema-text-description schema))
                      (json-fields (%schema-json-fields schema))
                      (parts nil))
                        (when text-schema
                                (push (format nil "`text`: ~A" text-schema) parts))
                        (when json-fields
                                (push (%format-json-schema-summary-part json-fields
                                                                        (%output-schema-closed-p schema))
                                      parts))
                        (format nil "~{~A~^; ~}" (nreverse parts)))))

(defun %format-schema-json-field-lines (schema)
        (let ((json-fields (%schema-json-fields schema)))
                (when json-fields
                        (%format-json-field-lines json-fields))))

(defun %format-json-field-line (field)
        (let ((field-name (%output-schema-json-field-name field))
              (field-summary (%output-schema-json-field-summary field))
              (enum-values (%output-schema-json-field-enum field))
              (closed-p (%output-schema-json-field-closed-p field))
              (required-p (%output-schema-json-field-required-p field))
              (nullable-p (%output-schema-json-field-nullable-p field))
              (field-type (%output-schema-json-field-type field))
              (minimum-value (%output-schema-json-field-minimum field))
              (minimum-items (%output-schema-json-field-min-items field))
              (equals-field (%output-schema-json-field-equals-field field))
              (equals-collection-size-of (%output-schema-json-field-equals-collection-size-of field))
              (equals-sum-of-fields-summary (%format-sum-of-fields-summary (%output-schema-json-field-equals-sum-of-fields field)))
              (equals-field-when-value-summary (%format-conditional-equals-summary (%output-schema-json-field-equals-field-when-value field)))
              (true-when-zero-field (%output-schema-json-field-true-when-zero-field field))
              (enum-when-zero-summary (%format-conditional-enum-summary "allowed-when-zero" (%output-schema-json-field-enum-when-zero-field field)))
              (enum-when-nonzero-summary (%format-conditional-enum-summary "allowed-when-nonzero" (%output-schema-json-field-enum-when-nonzero-field field)))
              (maximum-value (%output-schema-json-field-maximum field)))
                (if field-summary
                        (format nil "`~A`: ~A~@[ [type: `~(~A~)`]~]~@[ [min: `~A`]~]~@[ [min-items: `~A`]~]~@[ [count-of: `~A`]~]~@[ [matches: `~A`]~]~@[ ~A~]~@[ ~A~]~@[ [true-when-zero: `~A`]~]~@[ ~A~]~@[ ~A~]~@[ [max: `~A`]~]~@[ [allowed: ~{`~A`~^, ~}]~]~:[ [optional]~;~]~:[~; [nullable]~]~:[~; [closed]~]"
                                field-name
                                field-summary
                                field-type
                                minimum-value
                                minimum-items
                                equals-collection-size-of
                                equals-field
                                equals-sum-of-fields-summary
                                equals-field-when-value-summary
                                true-when-zero-field
                                enum-when-zero-summary
                                enum-when-nonzero-summary
                                maximum-value
                                enum-values
                                required-p
                                nullable-p
                                closed-p)
                        (format nil "`~A`" field-name))))

(defun %format-json-field-lines (fields &optional (depth 1))
        (let ((lines nil)
              (indent (make-string (* depth 2) :initial-element #\Space)))
                (dolist (field fields (nreverse lines))
                        (push (format nil "~A- ~A" indent (%format-json-field-line field)) lines)
                        (let ((children (%output-schema-json-field-derived-children field)))
                                (when children
                                        (setf lines (nconc (reverse (%format-json-field-lines children (1+ depth)))
                                                           lines)))))))

(defun %format-tool-failure-modes (definition)
        (let ((failure-modes (cl-cc.models:tool-failure-modes definition)))
                (when failure-modes
                        (format nil "~{`~(~A~)`~^, ~}" failure-modes))))

(defun %format-tool-permission-profile (definition)
        (let ((permission-profile (cl-cc.models:tool-permission-profile definition)))
                (when permission-profile
                        (format nil "`~(~A~)`" permission-profile))))

(defun render-tool-reference-markdown ()
        (with-output-to-string (stream)
                (format stream "## 工具参考~%~%")
                (dolist (definition (cl-cc.tools:list-tool-definitions))
                        (format stream "### `~A`~%~%" (cl-cc.models:tool-id definition))
                        (format stream "- Summary: ~A~%" (cl-cc.models:tool-summary definition))
                        (let ((input-schema-line (%format-schema-summary (cl-cc.models:tool-input-schema definition))))
                                (when input-schema-line
                                        (format stream "- Input Schema: ~A~%" input-schema-line)))
                        (let ((input-json-field-lines (%format-schema-json-field-lines (cl-cc.models:tool-input-schema definition))))
                                (when input-json-field-lines
                                        (format stream "- Input JSON Fields:~%")
                                        (dolist (line input-json-field-lines)
                                                (format stream "~A~%" line))))
                        (let ((output-schema-line (%format-schema-summary (cl-cc.models:tool-output-schema definition))))
                                (when output-schema-line
                                        (format stream "- Output Schema: ~A~%" output-schema-line)))
                        (let ((output-json-field-lines (%format-schema-json-field-lines (cl-cc.models:tool-output-schema definition))))
                                (when output-json-field-lines
                                        (format stream "- Output JSON Fields:~%")
                                        (dolist (line output-json-field-lines)
                                                (format stream "~A~%" line))))
                        (let ((error-output-schema-line (%format-schema-summary (cl-cc.models:tool-error-output-schema definition))))
                                (when error-output-schema-line
                                        (format stream "- Error Output Schema: ~A~%" error-output-schema-line)))
                        (let ((error-output-json-field-lines (%format-schema-json-field-lines (cl-cc.models:tool-error-output-schema definition))))
                                (when error-output-json-field-lines
                                        (format stream "- Error JSON Fields:~%")
                                        (dolist (line error-output-json-field-lines)
                                                (format stream "~A~%" line))))
                        (let ((failure-modes-line (%format-tool-failure-modes definition)))
                                (when failure-modes-line
                                        (format stream "- Failure Modes: ~A~%" failure-modes-line)))
                        (let ((permission-profile-line (%format-tool-permission-profile definition)))
                                (when permission-profile-line
                                        (format stream "- Permission Profile: ~A~%" permission-profile-line)))
                        (format stream "~%"))))

(defun %write-command-options (stream definition)
        (let ((option-lines (cl-cc.core::command-option-help-lines definition)))
                (when option-lines
                        (format stream "    options:~%")
                        (dolist (line option-lines)
                                (format stream "~A~%" line)))))

(defun render-command-reference-markdown ()
        (cl-cc.core:ensure-default-commands)
        (with-output-to-string (stream)
                (format stream "## 命令参考~%~%")
                (dolist (definition (cl-cc.core:list-command-definitions))
                        (format stream "### `~A`~%~%" (cl-cc.models:command-name definition))
                        (format stream "- Usage: ~A~%" (%format-command-reference-usage definition))
                        (format stream "- Summary: ~A~%" (cl-cc.models:command-summary definition))
                        (let ((aliases-line (%format-command-reference-aliases definition)))
                                (when aliases-line
                                        (format stream "- Aliases: ~A~%" aliases-line)))
                        (let ((output-schema-line (%format-command-reference-output-schema definition)))
                                (when output-schema-line
                                        (format stream "- Output Schema: ~A~%" output-schema-line)))
                        (let ((json-field-lines (%format-command-reference-json-field-lines definition)))
                                (when json-field-lines
                                        (format stream "- JSON Fields:~%")
                                        (dolist (line json-field-lines)
                                                (format stream "~A~%" line))))
                        (let ((option-lines (cl-cc.core::command-option-help-lines definition)))
                                (when option-lines
                                        (format stream "- Options:~%")
                                        (dolist (line option-lines)
                                                (format stream "  - ~A~%" (string-trim '(#\Space) line)))))
                        (format stream "~%"))
                (format stream "~A" (render-tool-reference-markdown))))

(defun %replace-command-reference-section (contents rendered-reference)
        (let ((start (search +command-reference-start-marker+ contents))
              (end (search +command-reference-end-marker+ contents)))
                (unless (and start end)
                        (error 'cl-cc.lib:cl-cc-error
                               :code :documentation-markers-not-found
                               :message "command reference markers not found in target document"))
                (format nil "~A~A~%~A~%~A~A"
                        (subseq contents 0 start)
                        +command-reference-start-marker+
                        rendered-reference
                        +command-reference-end-marker+
                        (subseq contents (+ end (length +command-reference-end-marker+))))))

(defun %updated-command-reference-contents (path)
        (%replace-command-reference-section (uiop:read-file-string path)
                                            (render-command-reference-markdown)))

(defun %command-reference-sync-state (path)
        (let* ((current-contents (uiop:read-file-string path))
               (updated-contents (%replace-command-reference-section current-contents
                                                                    (render-command-reference-markdown)))
               (needs-sync (not (string= current-contents updated-contents))))
                (values needs-sync updated-contents)))

(defun sync-command-reference-file (&optional (path "README.md"))
        (multiple-value-bind (needs-sync updated-contents)
                (%command-reference-sync-state path)
                (when needs-sync
                        (with-open-file (stream path
                                                :direction :output
                                                :if-exists :supersede
                                                :if-does-not-exist :create)
                                (write-string updated-contents stream)))
                path))

(defun command-reference-file-needs-sync-p (&optional (path "README.md"))
        (nth-value 0 (%command-reference-sync-state path)))

(defun %make-docs-sync-result (path status check-only updated needs-sync duration-seconds exit-code)
        (cl-cc.lib:make-result :status (intern (string-upcase status) :keyword)
                               :payload (list :path path
                                              :check-only check-only
                                              :updated updated
                                              :needs-sync needs-sync
                                              :duration-seconds duration-seconds
                                              :exit-code exit-code)
                               :message (cond
                                           ((string= status "drift")
                                            (format nil "命令参考需要同步: ~A" path))
                                           ((string= status "in-sync")
                                            (format nil "命令参考已是最新: ~A" path))
                                           (t
                                            (format nil "命令参考已同步: ~A" path)))))

(defun handle-docs-sync-reference-command (&optional argv parsed-arguments)
        (declare (ignore argv))
        (let ((path (or (cl-cc.core:command-positional-argument parsed-arguments 0) "README.md"))
              (check-only (cl-cc.core:command-option-value parsed-arguments :check-only nil))
              (output-format (cl-cc.core:command-option-value parsed-arguments :output-format "text")))
                (let ((started-at (get-internal-real-time)))
                        (labels ((elapsed-seconds ()
                                           (/ (- (get-internal-real-time) started-at)
                                              (float internal-time-units-per-second 1d0))))
                                (multiple-value-bind (needs-sync updated-contents)
                                        (%command-reference-sync-state path)
                                        (declare (ignore updated-contents))
                                        (cond
                                                (check-only
                                                 (let* ((status (if needs-sync "drift" "in-sync"))
                                                        (exit-code (if needs-sync 1 0))
                                                        (result-object (%make-docs-sync-result path status t nil needs-sync
                                                                                               (elapsed-seconds)
                                                                                               exit-code)))
                                                        (format t "~A~%"
                                                                (if (string= output-format "json")
                                                                    (render-docs-sync-result result-object)
                                                                    (cl-cc.lib:result-message result-object)))
                                                        exit-code))
                                                (needs-sync
                                                 (sync-command-reference-file path)
                                                 (let ((result-object (%make-docs-sync-result path "synced" nil t nil
                                                                                              (elapsed-seconds)
                                                                                              0)))
                                                   (format t "~A~%"
                                                           (if (string= output-format "json")
                                                               (render-docs-sync-result result-object)
                                                               (cl-cc.lib:result-message result-object))))
                                                 0)
                                                (t
                                                 (let ((result-object (%make-docs-sync-result path "in-sync" nil nil nil
                                                                                              (elapsed-seconds)
                                                                                              0)))
                                                   (format t "~A~%"
                                                           (if (string= output-format "json")
                                                               (render-docs-sync-result result-object)
                                                               (cl-cc.lib:result-message result-object))))
                                                 0)))))))

(defun render-help ()
        (cl-cc.core:ensure-default-commands)
        (with-output-to-string (stream)
                (format stream "Usage:~%")
                (dolist (definition (cl-cc.core:list-command-definitions))
                        (format stream "~A~%" (%format-command-usage definition))
                        (format stream "    ~A~%" (cl-cc.models:command-summary definition))
                        (let ((aliases-line (%format-command-aliases definition)))
                                (when aliases-line
                                        (format stream "~A~%" aliases-line)))
                        (%write-command-options stream definition))))

(defun print-help ()
        (format t "~A" (render-help)))

(defun handle-help-command (&optional argv parsed-arguments)
        (declare (ignore argv parsed-arguments))
        (print-help)
        0)
