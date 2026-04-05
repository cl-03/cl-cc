;;;; src/cli/help-command.lisp - CLI 帮助命令骨架
(in-package :cl-cc)

(defparameter +command-reference-start-marker+ "<!-- BEGIN GENERATED COMMAND REFERENCE -->")
(defparameter +command-reference-end-marker+ "<!-- END GENERATED COMMAND REFERENCE -->")

(defun %documentation-markers-not-found-message ()
        "command reference markers not found in target document")

(defun %documentation-markers-not-found-error ()
        (cl-cc.lib:make-cl-cc-error :documentation-markers-not-found
                                    (%documentation-markers-not-found-message)))

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

(defun %metadata-value-string (value)
        (typecase value
                (keyword (string-downcase (symbol-name value)))
                (symbol (string-downcase (symbol-name value)))
                (t (format nil "~A" value))))

(defun %command-metadata-parts (definition)
        (let ((parts nil))
                (let ((group (cl-cc.models:command-group definition)))
                        (when group
                                (push (format nil "group=~A" (%metadata-value-string group)) parts)))
                (let ((source (cl-cc.models:command-source definition)))
                        (when source
                                (push (format nil "source=~A" (%metadata-value-string source)) parts)))
                (when (cl-cc.models:command-requires-auth-p definition)
                        (push "requires-auth" parts))
                (when (cl-cc.models:command-beta-p definition)
                        (push "beta" parts))
                (nreverse parts)))

(defun %format-command-help-metadata (definition)
        (let ((parts (%command-metadata-parts definition)))
                (when parts
                        (format nil "    metadata: ~{~A~^; ~}" parts))))

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

(defun %format-command-reference-metadata (definition)
        (let ((parts (%command-metadata-parts definition)))
                (when parts
                        (format nil "~{`~A`~^, ~}" parts))))

(defun %plist-property (plist key)
        (cl-cc.services::%plist-property plist key))

(defun %schema-field-property (field key)
        (cl-cc.services::%schema-field-property field key))

(defun %relation-property (relation key)
        (cl-cc.services::%relation-property relation key))

(defun %schema-field-name (field)
        (if (stringp field)
                field
                (%schema-field-property field :name)))

(defun %output-schema-json-field-name (field)
        (%schema-field-name field))

(defun %schema-field-required-p (field)
        (cl-cc.services::%schema-field-required-p field))

(defun %schema-closed-p (schema)
        (cl-cc.services::%schema-closed-p schema))

(defun %schema-field-closed-p (field)
        (if (and (listp field)
                 (not (eq (getf field :closed :missing) :missing)))
                (getf field :closed)
                (let* ((schema-refs (%schema-field-property field :tool-schema-refs))
                       (schema (%tool-schema-from-ref (first schema-refs))))
                        (%schema-closed-p schema))))

(defun %format-conditional-enum-summary (label relation)
        (let ((field-name (%relation-property relation :field))
              (values (%relation-property relation :values)))
                (when (and field-name values)
                        (format nil "[~A: `~A` => ~{`~A`~^, ~}]"
                                label
                                field-name
                                values))))

(defun %format-conditional-equals-summary (relation)
        (let ((when-field (%relation-property relation :when-field))
              (when-value (%relation-property relation :value))
              (field-name (%relation-property relation :field)))
                (when (and when-field field-name (not (null when-value)))
                        (format nil "[matches-when: `~A` = `~A` => `~A`]"
                                when-field
                                when-value
                                field-name))))

(defun %format-sum-of-fields-summary (relation)
        (let ((fields (%relation-property relation :fields)))
                (when fields
                        (format nil "[sum-of: ~{`~A`~^, ~}]"
                                fields))))

(defun %tool-schema-from-ref (ref)
        (let* ((definition (cl-cc.tools:find-tool-definition (getf ref :tool-id)))
               (kind (getf ref :kind :output)))
                (when definition
                        (case kind
                                (:error-output (cl-cc.models:tool-error-output-schema definition))
                                (t (cl-cc.models:tool-output-schema definition))))))

(defun %schema-field-display-metadata (field &key (name (%schema-field-name field)))
        (list :name name
              :summary (%schema-field-property field :summary)
              :type (%schema-field-property field :type)
              :minimum (%schema-field-property field :minimum)
              :min-items (%schema-field-property field :min-items)
              :equals-field (%schema-field-property field :equals-field)
              :equals-collection-size-of (%schema-field-property field :equals-collection-size-of)
              :equals-sum-of-fields (%schema-field-property field :equals-sum-of-fields)
              :equals-field-when-value (%schema-field-property field :equals-field-when-value)
              :true-when-zero-field (%schema-field-property field :true-when-zero-field)
              :enum-when-zero-field (%schema-field-property field :enum-when-zero-field)
              :enum-when-nonzero-field (%schema-field-property field :enum-when-nonzero-field)
              :maximum (%schema-field-property field :maximum)
              :enum (%schema-field-property field :enum)
              :closed (%schema-field-closed-p field)
              :required (%schema-field-required-p field)
              :nullable (%schema-field-property field :nullable)
              :fields (%schema-field-property field :fields)))

(defun %prefixed-schema-fields (ref)
        (let* ((schema (%tool-schema-from-ref ref))
               (tool-id (getf ref :tool-id))
               (json-fields (and schema (%schema-json-fields schema))))
                (when json-fields
                        (mapcar (lambda (field)
                                                        (%schema-field-display-metadata field
                                                                                        :name (format nil "~A.~A" tool-id (%schema-field-name field))))
                                json-fields))))

(defun %format-json-schema-summary-part (json-fields closed-p)
        (format nil "`json`: `~{~A~^`, `~}`~:[~; [closed]~]"
                (mapcar #'%schema-field-name json-fields)
                closed-p))

(defun %output-schema-json-field-derived-children (field)
        (let ((children (%schema-field-property field :fields))
              (schema-refs (%schema-field-property field :tool-schema-refs)))
                (append children
                        (loop for ref in schema-refs
                              append (%prefixed-schema-fields ref)))))

(defun %format-command-reference-output-schema (definition)
        (%format-schema-summary (cl-cc.models:command-output-schema definition)))

(defun %format-command-reference-json-field-lines (definition)
        (%format-schema-json-field-lines (cl-cc.models:command-output-schema definition)))

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
                                                                        (%schema-closed-p schema))
                                      parts))
                        (format nil "~{~A~^; ~}" (nreverse parts)))))

(defun %format-schema-json-field-lines (schema)
        (let ((json-fields (%schema-json-fields schema)))
                (when json-fields
                        (%format-json-field-lines json-fields))))

(defun %json-field-annotation-parts (field)
          (let ((enum-values (%schema-field-property field :enum))
                  (closed-p (%schema-field-closed-p field))
                  (required-p (%schema-field-required-p field))
                  (nullable-p (%schema-field-property field :nullable))
                  (field-type (%schema-field-property field :type))
                  (minimum-value (%schema-field-property field :minimum))
                  (minimum-items (%schema-field-property field :min-items))
                  (equals-field (%schema-field-property field :equals-field))
                  (equals-collection-size-of (%schema-field-property field :equals-collection-size-of))
                  (equals-sum-of-fields-summary (%format-sum-of-fields-summary (%schema-field-property field :equals-sum-of-fields)))
                  (equals-field-when-value-summary (%format-conditional-equals-summary (%schema-field-property field :equals-field-when-value)))
                  (true-when-zero-field (%schema-field-property field :true-when-zero-field))
                  (enum-when-zero-summary (%format-conditional-enum-summary "allowed-when-zero" (%schema-field-property field :enum-when-zero-field)))
                  (enum-when-nonzero-summary (%format-conditional-enum-summary "allowed-when-nonzero" (%schema-field-property field :enum-when-nonzero-field)))
                  (maximum-value (%schema-field-property field :maximum))
              (parts nil))
                (when field-type
                        (push (format nil "[type: `~(~A~)`]" field-type) parts))
                (when minimum-value
                        (push (format nil "[min: `~A`]" minimum-value) parts))
                (when minimum-items
                        (push (format nil "[min-items: `~A`]" minimum-items) parts))
                (when equals-collection-size-of
                        (push (format nil "[count-of: `~A`]" equals-collection-size-of) parts))
                (when equals-field
                        (push (format nil "[matches: `~A`]" equals-field) parts))
                (when equals-sum-of-fields-summary
                        (push equals-sum-of-fields-summary parts))
                (when equals-field-when-value-summary
                        (push equals-field-when-value-summary parts))
                (when true-when-zero-field
                        (push (format nil "[true-when-zero: `~A`]" true-when-zero-field) parts))
                (when enum-when-zero-summary
                        (push enum-when-zero-summary parts))
                (when enum-when-nonzero-summary
                        (push enum-when-nonzero-summary parts))
                (when maximum-value
                        (push (format nil "[max: `~A`]" maximum-value) parts))
                (when enum-values
                        (push (format nil "[allowed: ~{`~A`~^, ~}]" enum-values) parts))
                (unless required-p
                        (push "[optional]" parts))
                (when nullable-p
                        (push "[nullable]" parts))
                (when closed-p
                        (push "[closed]" parts))
                (nreverse parts)))

(defun %format-json-field-line (field)
        (let ((field-name (%schema-field-name field))
              (field-summary (%schema-field-property field :summary))
              (annotations (%json-field-annotation-parts field)))
                (if field-summary
                        (format nil "`~A`: ~A~@[ ~{~A~^ ~}~]"
                                field-name
                                field-summary
                                annotations)
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

(defun %command-auth-scope-matches-p (definition auth-scope)
        (case auth-scope
                (:all t)
                (:requires-auth (cl-cc.models:command-requires-auth-p definition))
                (:public (not (cl-cc.models:command-requires-auth-p definition)))
                (t (error "Unknown command auth scope: ~S" auth-scope))))

(defun %command-group-scope-matches-p (definition group-scope)
        (or (eq group-scope :all)
            (equal (cl-cc.models:command-group definition) group-scope)))

(defun %command-group-scope-keyword (value)
        (cond
                ((or (null value)
                     (string= value "all")) :all)
                ((string= value "meta") :meta)
                ((string= value "chat") :chat)
                ((string= value "session") :session)
                ((string= value "automation") :automation)
                ((string= value "docs") :docs)
                (t (error "Unknown command group scope option: ~S" value))))

(defun %displayed-command-definitions (&key (auth-scope :all) (group-scope :all))
        (remove-if-not (lambda (definition)
                                 (and (not (cl-cc.models:command-hidden-p definition))
                                      (%command-auth-scope-matches-p definition auth-scope)
                                      (%command-group-scope-matches-p definition group-scope)))
                       (cl-cc.core:list-command-definitions)))

(defun %command-group-order (group)
        (or (position group '(:meta :chat :session :automation :docs) :test #'eq)
            most-positive-fixnum))

(defun %command-group-heading (group)
        (case group
                (:meta "元信息命令")
                (:chat "交互命令")
                (:session "会话命令")
                (:automation "自动化命令")
                (:docs "文档命令")
                (t (format nil "~A 命令" (%metadata-value-string (or group :other))))))

(defun %command-grouped-definitions (&key (auth-scope :all) (group-scope :all))
        (let ((groups nil))
                (dolist (definition (%displayed-command-definitions :auth-scope auth-scope
                                                                   :group-scope group-scope))
                        (let* ((group (cl-cc.models:command-group definition))
                               (entry (assoc group groups :test #'equal)))
                                (if entry
                                        (setf (cdr entry) (append (cdr entry) (list definition)))
                                        (setf groups (append groups (list (cons group (list definition))))))))
                (sort groups
                      (lambda (left right)
                                (< (%command-group-order (car left))
                                   (%command-group-order (car right)))))))

(defun %write-schema-section (stream label schema &optional json-fields-label)
        (let ((schema-line (%format-schema-summary schema))
              (json-field-lines (%format-schema-json-field-lines schema)))
                (when schema-line
                        (format stream "- ~A: ~A~%" label schema-line))
                (when json-field-lines
                        (format stream "- ~A:~%" (or json-fields-label "JSON Fields"))
                        (dolist (line json-field-lines)
                                (format stream "~A~%" line)))))

(defun render-tool-reference-markdown ()
        (with-output-to-string (stream)
                (format stream "## 工具参考~%~%")
                (dolist (definition (cl-cc.tools:list-tool-definitions))
                        (format stream "### `~A`~%~%" (cl-cc.models:tool-id definition))
                        (format stream "- Summary: ~A~%" (cl-cc.models:tool-summary definition))
                        (%write-schema-section stream "Input Schema" (cl-cc.models:tool-input-schema definition) "Input JSON Fields")
                        (%write-schema-section stream "Output Schema" (cl-cc.models:tool-output-schema definition) "Output JSON Fields")
                        (%write-schema-section stream "Error Output Schema" (cl-cc.models:tool-error-output-schema definition) "Error JSON Fields")
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

(defun render-command-reference-markdown (&key (auth-scope :all) (group-scope :all))
        (cl-cc.core:ensure-default-commands)
        (with-output-to-string (stream)
                (format stream "## 命令参考~%~%")
                (dolist (group (%command-grouped-definitions :auth-scope auth-scope
                                                            :group-scope group-scope))
                        (format stream "### ~A~%~%" (%command-group-heading (car group)))
                        (dolist (definition (cdr group))
                                (format stream "#### `~A`~%~%" (cl-cc.models:command-name definition))
                                (format stream "- Usage: ~A~%" (%format-command-reference-usage definition))
                                (format stream "- Summary: ~A~%" (cl-cc.models:command-summary definition))
                                (let ((aliases-line (%format-command-reference-aliases definition)))
                                        (when aliases-line
                                                (format stream "- Aliases: ~A~%" aliases-line)))
                                (let ((metadata-line (%format-command-reference-metadata definition)))
                                        (when metadata-line
                                                (format stream "- Metadata: ~A~%" metadata-line)))
                                (%write-schema-section stream "Output Schema" (cl-cc.models:command-output-schema definition) "JSON Fields")
                                (let ((option-lines (cl-cc.core::command-option-help-lines definition)))
                                        (when option-lines
                                                (format stream "- Options:~%")
                                                (dolist (line option-lines)
                                                        (format stream "  - ~A~%" (string-trim '(#\Space) line)))))
                                (format stream "~%")))
                (format stream "~A" (render-tool-reference-markdown))))

(defun %replace-command-reference-section (contents rendered-reference)
        (let ((start (search +command-reference-start-marker+ contents))
              (end (search +command-reference-end-marker+ contents)))
                (unless (and start end)
                        (error (%documentation-markers-not-found-error)))
                (format nil "~A~A~%~A~%~A~A"
                        (subseq contents 0 start)
                        +command-reference-start-marker+
                        rendered-reference
                        +command-reference-end-marker+
                        (subseq contents (+ end (length +command-reference-end-marker+))))))

(defun %updated-command-reference-contents (path)
        (%replace-command-reference-section (uiop:read-file-string path)
                                            (render-command-reference-markdown)))

(defun %command-auth-scope-keyword (value)
        (cond
                ((or (null value)
                     (string= value "all")) :all)
                ((string= value "public") :public)
                ((string= value "requires-auth") :requires-auth)
                (t (error "Unknown command auth scope option: ~S" value))))

(defun %command-reference-sync-state (path &key (auth-scope :all) (group-scope :all))
        (let* ((current-contents (uiop:read-file-string path))
               (updated-contents (%replace-command-reference-section current-contents
                                                                    (render-command-reference-markdown :auth-scope auth-scope
                                                                                                      :group-scope group-scope)))
               (needs-sync (not (string= current-contents updated-contents))))
                (values needs-sync updated-contents)))

(defun %parse-command-reference-sync-arguments (args)
        (let ((path "README.md")
              (remaining args))
                (when (and remaining
                           (stringp (first remaining)))
                        (setf path (first remaining)
                              remaining (rest remaining)))
                (values path
                        (or (getf remaining :auth-scope) :all)
                        (or (getf remaining :group-scope) :all))))

(defun sync-command-reference-file (&rest args)
        (multiple-value-bind (path auth-scope group-scope)
                (%parse-command-reference-sync-arguments args)
        (multiple-value-bind (needs-sync updated-contents)
                (%command-reference-sync-state path :auth-scope auth-scope :group-scope group-scope)
                (when needs-sync
                        (with-open-file (stream path
                                                :direction :output
                                                :if-exists :supersede
                                                :if-does-not-exist :create)
                                (write-string updated-contents stream)))
                path)))

(defun command-reference-file-needs-sync-p (&rest args)
        (multiple-value-bind (path auth-scope group-scope)
                (%parse-command-reference-sync-arguments args)
                (nth-value 0 (%command-reference-sync-state path :auth-scope auth-scope
                                                            :group-scope group-scope))))

(defun %make-docs-sync-result (path status check-only updated needs-sync duration-seconds exit-code)
        (cl-cc.lib:make-result :status (cl-cc.lib:string-designator-keyword status)
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
              (output-format (cl-cc.core:command-option-value parsed-arguments :output-format "text"))
              (auth-scope (%command-auth-scope-keyword
                           (cl-cc.core:command-option-value parsed-arguments :auth-scope "all")))
              (group-scope (%command-group-scope-keyword
                            (cl-cc.core:command-option-value parsed-arguments :group-scope "all"))))
                (let ((started-at (get-internal-real-time)))
                        (multiple-value-bind (needs-sync updated-contents)
                                        (%command-reference-sync-state path :auth-scope auth-scope
                                                                           :group-scope group-scope)
                                        (declare (ignore updated-contents))
                                        (cond
                                                (check-only
                                                 (let* ((status (if needs-sync "drift" "in-sync"))
                                                        (exit-code (if needs-sync 1 0))
                                                        (result-object (%make-docs-sync-result path status t nil needs-sync
                                                                                               (cl-cc.lib:elapsed-seconds started-at (get-internal-real-time))
                                                                                               exit-code)))
                                                        (format t "~A~%"
                                                                (if (string= output-format "json")
                                                                    (render-docs-sync-result result-object)
                                                                    (cl-cc.lib:result-message result-object)))
                                                        exit-code))
                                                (needs-sync
                                                 (sync-command-reference-file path :auth-scope auth-scope
                                                                                 :group-scope group-scope)
                                                 (let ((result-object (%make-docs-sync-result path "synced" nil t nil
                                                                                              (cl-cc.lib:elapsed-seconds started-at (get-internal-real-time))
                                                                                              0)))
                                                   (format t "~A~%"
                                                           (if (string= output-format "json")
                                                               (render-docs-sync-result result-object)
                                                               (cl-cc.lib:result-message result-object))))
                                                 0)
                                                (t
                                                 (let ((result-object (%make-docs-sync-result path "in-sync" nil nil nil
                                                                                              (cl-cc.lib:elapsed-seconds started-at (get-internal-real-time))
                                                                                              0)))
                                                   (format t "~A~%"
                                                           (if (string= output-format "json")
                                                               (render-docs-sync-result result-object)
                                                               (cl-cc.lib:result-message result-object))))
                                                 0))))))

(defun render-help (&key (auth-scope :all) (group-scope :all))
        (cl-cc.core:ensure-default-commands)
        (with-output-to-string (stream)
                (format stream "Usage:~%")
                (dolist (group (%command-grouped-definitions :auth-scope auth-scope
                                                            :group-scope group-scope))
                        (format stream "~%  ~A:~%" (%command-group-heading (car group)))
                        (dolist (definition (cdr group))
                                (format stream "~A~%" (%format-command-usage definition))
                                (format stream "    ~A~%" (cl-cc.models:command-summary definition))
                                (let ((aliases-line (%format-command-aliases definition)))
                                        (when aliases-line
                                                (format stream "~A~%" aliases-line)))
                                (let ((metadata-line (%format-command-help-metadata definition)))
                                        (when metadata-line
                                                (format stream "~A~%" metadata-line)))
                                (%write-command-options stream definition)))))

(defun print-help ()
        (format t "~A" (render-help)))

(defun handle-help-command (&optional argv parsed-arguments)
        (declare (ignore argv))
        (format t "~A"
                (render-help :auth-scope (%command-auth-scope-keyword
                                          (cl-cc.core:command-option-value parsed-arguments :auth-scope "all"))
                             :group-scope (%command-group-scope-keyword
                                           (cl-cc.core:command-option-value parsed-arguments :group-scope "all"))))
        0)
