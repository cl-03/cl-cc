;;;; tests/unit/help-command-rendering-test.lisp
(in-package :cl-cc/tests)

(def-suite help-command-rendering-test :in cl-cc-suite)
(in-suite help-command-rendering-test)

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
    (is (search "- Input Schema:" tool-reference))
    (is (search "- Output JSON Fields:" tool-reference))
    (is (search "- Error Output Schema:" tool-reference))
    (is (search "- Output Schema:" command-reference))
    (is (search "- JSON Fields:" command-reference))
    (is (search "- Options:" command-reference))))

(test documentation-markers-not-found-message-rendering
  (is (string= (cl-cc::%documentation-markers-not-found-message)
               "command reference markers not found in target document")))

(test replace-command-reference-section-signals-marker-error
  (handler-case
      (progn
        (cl-cc::%replace-command-reference-section "no generated markers here" "generated content")
        (fail "expected documentation marker error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :documentation-markers-not-found))
      (is (string= (cl-cc.lib:error-message condition)
                   "command reference markers not found in target document")))))