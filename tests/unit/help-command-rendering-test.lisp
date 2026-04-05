;;;; tests/unit/help-command-rendering-test.lisp
(in-package :cl-cc/tests)

(def-suite help-command-rendering-test :in cl-cc-suite)
(in-suite help-command-rendering-test)

(defun %help-rendering-hidden-command-handler (&optional argv parsed-arguments)
  (declare (ignore argv parsed-arguments))
  0)

(defun %write-generated-reference-fixture (path contents)
  (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
    (write-string contents stream)))

(test format-schema-summary-renders-text-and-json
  (let ((schema '(:text "result message"
                  :closed t
                  :json ((:name "status" :summary "状态" :type :string)
                         (:name "exitCode" :summary "退出码" :type :integer)))))
    (is (string= (cl-cc::%format-schema-summary schema)
                 "`text`: result message; `json`: `status`, `exitCode` [closed]"))))

(test command-reference-schema-formatters-delegate-to-generic-schema-formatters
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command "run --fixture"))
         (schema (cl-cc.models:command-output-schema definition)))
    (is (string= (cl-cc::%format-command-reference-output-schema definition)
                 (cl-cc::%format-schema-summary schema)))
    (is (equal (cl-cc::%format-command-reference-json-field-lines definition)
               (cl-cc::%format-schema-json-field-lines schema)))))

(test format-json-field-line-renders-annotations
  (let ((field '(:name "status"
                 :summary "聚合结果状态"
                 :type :string
                 :enum ("success" "failed")
                 :nullable t
                 :required nil)))
    (is (string= (cl-cc::%format-json-field-line field)
                 "`status`: 聚合结果状态 [type: `string`] [allowed: `success`, `failed`] [optional] [nullable]"))))

(test prefixed-schema-fields-preserve-shared-schema-metadata
  (let ((field (first (cl-cc::%prefixed-schema-fields '(:tool-id "echo-tool")))))
    (is (string= (getf field :name) "echo-tool.result"))
    (is (string= (getf field :summary) "工具返回的回显结果"))
    (is (eq (getf field :type) :string))
    (is (eq (getf field :required) t))
    (is (null (getf field :closed)))))

(test schema-field-display-metadata-preserves-shape-with-name-override
  (let* ((field '(:name "status"
                  :summary "聚合结果状态"
                  :type :string
                  :minimum 0
                  :min-items 1
                  :equals-field "fixtureCount"
                  :equals-collection-size-of "results"
                  :equals-sum-of-fields (:fields ("success" "failed"))
                  :equals-field-when-value (:field "fixtureCount" :when-field "status" :value "success")
                  :true-when-zero-field "exitCode"
                  :enum-when-zero-field (:field "exitCode" :values ("success"))
                  :enum-when-nonzero-field (:field "exitCode" :values ("failed" "partial"))
                  :maximum 255
                  :enum ("success" "failed")
                  :nullable t
                  :fields ((:name "child" :summary "子字段"))))
         (metadata (cl-cc::%schema-field-display-metadata field :name "tool.status")))
    (is (string= (getf metadata :name) "tool.status"))
    (is (string= (getf metadata :summary) "聚合结果状态"))
    (is (eq (getf metadata :type) :string))
    (is (= 0 (getf metadata :minimum)))
    (is (= 1 (getf metadata :min-items)))
    (is (string= (getf metadata :equals-field) "fixtureCount"))
    (is (string= (getf metadata :equals-collection-size-of) "results"))
    (is (equal (getf metadata :equals-sum-of-fields)
               '(:fields ("success" "failed"))))
    (is (equal (getf metadata :equals-field-when-value)
               '(:field "fixtureCount" :when-field "status" :value "success")))
    (is (string= (getf metadata :true-when-zero-field) "exitCode"))
    (is (equal (getf metadata :enum-when-zero-field)
               '(:field "exitCode" :values ("success"))))
    (is (equal (getf metadata :enum-when-nonzero-field)
               '(:field "exitCode" :values ("failed" "partial"))))
    (is (= 255 (getf metadata :maximum)))
    (is (equal (getf metadata :enum) '("success" "failed")))
    (is (eq (getf metadata :required) t))
    (is (eq (getf metadata :nullable) t))
    (is (equal (getf metadata :fields)
               '((:name "child" :summary "子字段"))))
    (is (null (getf metadata :closed)))))

(test write-schema-section-emits-summary-and-fields
  (let ((schema '(:text "echoed string"
                  :closed t
                  :json ((:name "result" :summary "工具返回的回显结果" :type :string)))))
    (let ((rendered (with-output-to-string (stream)
                      (cl-cc::%write-schema-section stream "Output Schema" schema "Output JSON Fields"))))
      (is (search "- Output Schema: `text`: echoed string; `json`: `result` [closed]" rendered))
      (is (search "- Output JSON Fields:" rendered))
      (is (search "  - `result`: 工具返回的回显结果 [type: `string`]" rendered)))))

(test render-reference-markdown-keeps-section-headings
  (let ((tool-reference (cl-cc::render-tool-reference-markdown))
        (command-reference (cl-cc:render-command-reference-markdown)))
  (is (search "### 元信息命令" command-reference))
  (is (search "### 交互命令" command-reference))
  (is (search "### 会话命令" command-reference))
  (is (search "### 自动化命令" command-reference))
  (is (search "### 文档命令" command-reference))
  (is (search "#### `chat`" command-reference))
    (is (search "- Metadata:" command-reference))
    (is (search "- Input Schema:" tool-reference))
    (is (search "- Output JSON Fields:" tool-reference))
    (is (search "- Error Output Schema:" tool-reference))
    (is (search "- Output Schema:" command-reference))
    (is (search "- JSON Fields:" command-reference))
    (is (search "- Options:" command-reference))))

    (test render-help-groups-default-commands-by-group
      (let ((help-output (cl-cc:render-help)))
        (is (search "元信息命令:" help-output))
        (is (search "交互命令:" help-output))
        (is (search "会话命令:" help-output))
        (is (search "自动化命令:" help-output))
        (is (search "文档命令:" help-output))
        (is (< (search "元信息命令:" help-output)
          (search "交互命令:" help-output)))
        (is (< (search "交互命令:" help-output)
          (search "会话命令:" help-output)))
        (is (< (search "会话命令:" help-output)
          (search "自动化命令:" help-output)))
        (is (< (search "自动化命令:" help-output)
          (search "文档命令:" help-output)))))

    (test auth-scoped-help-and-reference-filter-default-commands
      (let ((auth-help (cl-cc:render-help :auth-scope :requires-auth))
            (public-help (cl-cc:render-help :auth-scope :public))
            (auth-reference (cl-cc:render-command-reference-markdown :auth-scope :requires-auth))
            (public-reference (cl-cc:render-command-reference-markdown :auth-scope :public)))
        (is (search "交互命令:" auth-help))
        (is (search "会话命令:" auth-help))
        (is (search "自动化命令:" auth-help))
        (is (not (search "元信息命令:" auth-help)))
        (is (not (search "文档命令:" auth-help)))
        (is (search "cl-cc chat" auth-help))
        (is (search "cl-cc session run" auth-help))
        (is (search "cl-cc run --fixture" auth-help))
        (is (not (search "cl-cc help" auth-help)))
        (is (not (search "cl-cc docs sync-reference" auth-help)))
        (is (not (search "cl-cc session list" auth-help)))
        (is (search "元信息命令:" public-help))
        (is (search "会话命令:" public-help))
        (is (search "文档命令:" public-help))
        (is (not (search "交互命令:" public-help)))
        (is (not (search "自动化命令:" public-help)))
        (is (search "cl-cc help" public-help))
        (is (search "cl-cc docs sync-reference" public-help))
        (is (search "cl-cc session start" public-help))
        (is (search "cl-cc session list" public-help))
        (is (search "cl-cc session resume" public-help))
        (is (not (search "cl-cc chat" public-help)))
        (is (not (search "cl-cc session run" public-help)))
        (is (not (search "cl-cc run --fixture" public-help)))
        (is (search "### 交互命令" auth-reference))
        (is (search "### 自动化命令" auth-reference))
        (is (search "#### `chat`" auth-reference))
        (is (search "#### `session run`" auth-reference))
        (is (search "#### `run --fixture`" auth-reference))
        (is (not (search "#### `help`" auth-reference)))
        (is (search "### 元信息命令" public-reference))
        (is (search "### 文档命令" public-reference))
        (is (search "#### `help`" public-reference))
        (is (search "#### `docs sync-reference`" public-reference))
        (is (not (search "#### `chat`" public-reference)))))

(test group-scoped-help-and-reference-filter-default-commands
  (let ((session-help (cl-cc:render-help :group-scope :session))
        (docs-help (cl-cc:render-help :group-scope :docs))
        (session-reference (cl-cc:render-command-reference-markdown :group-scope :session))
        (docs-reference (cl-cc:render-command-reference-markdown :group-scope :docs)))
    (is (search "会话命令:" session-help))
    (is (not (search "元信息命令:" session-help)))
    (is (not (search "交互命令:" session-help)))
    (is (not (search "自动化命令:" session-help)))
    (is (not (search "文档命令:" session-help)))
    (is (search "cl-cc session start" session-help))
    (is (search "cl-cc session list" session-help))
    (is (search "cl-cc session resume" session-help))
    (is (search "cl-cc session run" session-help))
    (is (not (search "cl-cc help" session-help)))
    (is (search "文档命令:" docs-help))
    (is (search "cl-cc docs sync-reference" docs-help))
    (is (not (search "cl-cc session list" docs-help)))
    (is (search "### 会话命令" session-reference))
    (is (search "#### `session start`" session-reference))
    (is (search "#### `session list`" session-reference))
    (is (search "#### `session resume`" session-reference))
    (is (search "#### `session run`" session-reference))
    (is (not (search "#### `help`" session-reference)))
    (is (search "### 文档命令" docs-reference))
    (is (search "#### `docs sync-reference`" docs-reference))
    (is (not (search "#### `chat`" docs-reference)))))

(test hidden-commands-are-omitted-from-help-and-reference
  (cl-cc.core:reset-command-registry)
  (cl-cc.core:ensure-default-commands)
  (cl-cc.core:register-command "visible preview"
                               'cl-cc/tests::%help-rendering-hidden-command-handler
                               :summary "visible preview command"
                               :permission-profile :default
                               :source :custom
                               :group :preview
                               :arguments-schema '(:positionals nil :options nil)
                               :output-schema '(:text "visible output"))
  (cl-cc.core:register-command "hidden preview"
                               'cl-cc/tests::%help-rendering-hidden-command-handler
                               :summary "hidden preview command"
                               :permission-profile :default
                               :source :custom
                               :group :preview
                               :hidden-p t
                               :arguments-schema '(:positionals nil :options nil)
                               :output-schema '(:text "hidden output"))
  (let ((help-output (cl-cc:render-help))
        (reference-output (cl-cc:render-command-reference-markdown)))
    (is (search "cl-cc visible preview" help-output))
    (is (search "metadata: group=preview; source=custom" help-output))
    (is (not (search "cl-cc hidden preview" help-output)))
    (is (search "### preview 命令" reference-output))
    (is (search "#### `visible preview`" reference-output))
    (is (search "- Metadata: `group=preview`, `source=custom`" reference-output))
    (is (not (search "#### `hidden preview`" reference-output)))))

(test beta-command-metadata-is-rendered-in-help-and-reference
  (cl-cc.core:reset-command-registry)
  (cl-cc.core:ensure-default-commands)
  (cl-cc.core:register-command "beta preview"
                               'cl-cc/tests::%help-rendering-hidden-command-handler
                               :summary "beta preview command"
                               :permission-profile :default
                               :source :custom
                               :group :preview
                               :beta-p t
                               :arguments-schema '(:positionals nil :options nil)
                               :output-schema '(:text "beta output"))
  (let ((help-output (cl-cc:render-help))
        (reference-output (cl-cc:render-command-reference-markdown)))
    (is (search "metadata: group=preview; source=custom; beta" help-output))
    (is (search "- Metadata: `group=preview`, `source=custom`, `beta`" reference-output))))

(test requires-auth-command-metadata-is-rendered-in-help-and-reference
  (cl-cc.core:reset-command-registry)
  (cl-cc.core:ensure-default-commands)
  (cl-cc.core:register-command "auth preview"
                               'cl-cc/tests::%help-rendering-hidden-command-handler
                               :summary "auth preview command"
                               :permission-profile :default
                               :source :custom
                               :group :preview
                               :requires-auth-p t
                               :arguments-schema '(:positionals nil :options nil)
                               :output-schema '(:text "auth output"))
  (let ((help-output (cl-cc:render-help))
        (reference-output (cl-cc:render-command-reference-markdown)))
    (is (search "metadata: group=preview; source=custom; requires-auth" help-output))
    (is (search "- Metadata: `group=preview`, `source=custom`, `requires-auth`" reference-output))))

(test custom-group-scope-is-supported-by-renderers
  (cl-cc.core:reset-command-registry)
  (cl-cc.core:ensure-default-commands)
  (cl-cc.core:register-command "preview custom"
                               'cl-cc/tests::%help-rendering-hidden-command-handler
                               :summary "preview custom command"
                               :permission-profile :default
                               :source :custom
                               :group :preview
                               :arguments-schema '(:positionals nil :options nil)
                               :output-schema '(:text "preview output"))
  (let ((help-output (cl-cc:render-help :group-scope :preview))
        (reference-output (cl-cc:render-command-reference-markdown :group-scope :preview)))
    (is (search "preview 命令:" help-output))
    (is (search "cl-cc preview custom" help-output))
    (is (not (search "cl-cc help" help-output)))
    (is (search "### preview 命令" reference-output))
    (is (search "#### `preview custom`" reference-output))
    (is (not (search "#### `chat`" reference-output)))))

(test documentation-markers-not-found-message-rendering
  (is (string= (cl-cc::%documentation-markers-not-found-message)
               "command reference markers not found in target document")))

(test command-reference-sync-helpers-update-and-check-default-view
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "render-help-sync-default-test.md"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (%write-generated-reference-fixture
            path
            (format nil "before~%<!-- BEGIN GENERATED COMMAND REFERENCE -->~%stale~%<!-- END GENERATED COMMAND REFERENCE -->~%after~%"))
           (is (cl-cc:command-reference-file-needs-sync-p path))
           (is (string= (cl-cc:sync-command-reference-file path) path))
           (is (not (cl-cc:command-reference-file-needs-sync-p path)))
           (let ((contents (uiop:read-file-string path)))
             (is (search "#### `chat`" contents))
             (is (search "#### `docs sync-reference`" contents))
             (is (search "before" contents))
             (is (search "after" contents))))
      (when (probe-file path)
        (delete-file path)))))

(test command-reference-sync-helpers-support-auth-scoped-views
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "render-help-sync-public-test.md"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (%write-generated-reference-fixture
            path
            (format nil "before~%<!-- BEGIN GENERATED COMMAND REFERENCE -->~%stale~%<!-- END GENERATED COMMAND REFERENCE -->~%after~%"))
           (is (cl-cc:command-reference-file-needs-sync-p path :auth-scope :public))
           (is (string= (cl-cc:sync-command-reference-file path :auth-scope :public) path))
           (is (not (cl-cc:command-reference-file-needs-sync-p path :auth-scope :public)))
           (let ((contents (uiop:read-file-string path)))
             (is (search "#### `help`" contents))
             (is (search "#### `docs sync-reference`" contents))
             (is (search "#### `session list`" contents))
             (is (not (search "#### `chat`" contents)))
             (is (not (search "#### `run --fixture`" contents))))
           (%write-generated-reference-fixture
            path
            (format nil "before~%<!-- BEGIN GENERATED COMMAND REFERENCE -->~%stale~%<!-- END GENERATED COMMAND REFERENCE -->~%after~%"))
           (is (cl-cc:command-reference-file-needs-sync-p path :auth-scope :requires-auth))
           (is (string= (cl-cc:sync-command-reference-file path :auth-scope :requires-auth) path))
           (let ((contents (uiop:read-file-string path)))
             (is (search "#### `chat`" contents))
             (is (search "#### `session run`" contents))
             (is (search "#### `run --fixture`" contents))
             (is (not (search "#### `help`" contents)))
             (is (not (search "#### `docs sync-reference`" contents))))
           (is (not (cl-cc:command-reference-file-needs-sync-p path :auth-scope :requires-auth))))
      (when (probe-file path)
        (delete-file path)))))

(test command-reference-sync-helpers-support-group-scoped-views
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "render-help-sync-session-test.md"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (%write-generated-reference-fixture
            path
            (format nil "before~%<!-- BEGIN GENERATED COMMAND REFERENCE -->~%stale~%<!-- END GENERATED COMMAND REFERENCE -->~%after~%"))
           (is (cl-cc:command-reference-file-needs-sync-p path :group-scope :session))
           (is (string= (cl-cc:sync-command-reference-file path :group-scope :session) path))
           (is (not (cl-cc:command-reference-file-needs-sync-p path :group-scope :session)))
           (let ((contents (uiop:read-file-string path)))
             (is (search "#### `session start`" contents))
             (is (search "#### `session list`" contents))
             (is (search "#### `session resume`" contents))
             (is (search "#### `session run`" contents))
             (is (not (search "#### `help`" contents)))
             (is (not (search "#### `chat`" contents)))
             (is (not (search "#### `docs sync-reference`" contents)))))
      (when (probe-file path)
        (delete-file path)))))

(test auth-scoped-renderers-and-sync-helpers-reject-unknown-scope
  (handler-case
      (progn
        (cl-cc:render-help :auth-scope :private)
        (fail "expected render-help unknown auth-scope error"))
    (error (condition)
      (is (search "Unknown command auth scope" (princ-to-string condition)))))
  (handler-case
      (progn
        (cl-cc:render-command-reference-markdown :auth-scope :private)
        (fail "expected render-command-reference-markdown unknown auth-scope error"))
    (error (condition)
      (is (search "Unknown command auth scope" (princ-to-string condition)))))
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "render-help-sync-invalid-scope-test.md"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (%write-generated-reference-fixture
            path
            (format nil "before~%<!-- BEGIN GENERATED COMMAND REFERENCE -->~%stale~%<!-- END GENERATED COMMAND REFERENCE -->~%after~%"))
           (let ((before (uiop:read-file-string path)))
             (handler-case
                 (progn
                   (cl-cc:command-reference-file-needs-sync-p path :auth-scope :private)
                   (fail "expected command-reference-file-needs-sync-p unknown auth-scope error"))
               (error (condition)
                 (is (search "Unknown command auth scope" (princ-to-string condition)))))
             (is (string= before (uiop:read-file-string path))))
           (let ((before (uiop:read-file-string path)))
             (handler-case
                 (progn
                   (cl-cc:sync-command-reference-file path :auth-scope :private)
                   (fail "expected sync-command-reference-file unknown auth-scope error"))
               (error (condition)
                 (is (search "Unknown command auth scope" (princ-to-string condition)))))
             (is (string= before (uiop:read-file-string path)))))
      (when (probe-file path)
        (delete-file path)))))

(test replace-command-reference-section-signals-marker-error
  (handler-case
      (progn
        (cl-cc::%replace-command-reference-section "no generated markers here" "generated content")
        (fail "expected documentation marker error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :documentation-markers-not-found))
      (is (string= (cl-cc.lib:error-message condition)
                   "command reference markers not found in target document")))))