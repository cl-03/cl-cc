;;;; tests/unit/command-schema-builders-test.lisp
(in-package :cl-cc/tests)

(def-suite command-schema-builders-test :in cl-cc-suite)
(in-suite command-schema-builders-test)

(test closed-json-output-schema-wraps-fields
  (let* ((json-fields (list (cl-cc:schema-field "status" "状态" :type :string)))
         (schema (cl-cc.core::%closed-json-output-schema "summary text" json-fields)))
    (is (string= (getf schema :text) "summary text"))
    (is (getf schema :closed))
    (is (equal (getf schema :json) json-fields))))

(test duration-and-exit-code-output-fields-append-stable-tail
  (let ((fields (cl-cc.core::%duration-and-exit-code-output-fields "执行时长（秒）")))
    (is (= 2 (length fields)))
    (is (equal (mapcar (lambda (field) (getf field :name)) fields)
               '("durationSeconds" "exitCode")))
    (is (string= (getf (first fields) :summary) "执行时长（秒）"))
    (is (equal (getf (second fields) :type) :integer))))

(test session-output-schema-builders-compose-shared-shape
  (let* ((extra-fields (cl-cc.core::%session-persistence-output-fields))
         (schema (cl-cc.core::%session-output-schema "session start message"
                                                     "新会话 ID"
                                                     "初始历史索引，未指定时为 null"
                                                     "会话状态，当前通常为 active"
                                                     "本次 session start 执行时长（秒）"
                                                     :extra-fields extra-fields))
         (json-fields (getf schema :json)))
    (is (string= (getf schema :text) "session start message"))
    (is (getf schema :closed))
    (is (equal (mapcar (lambda (field) (getf field :name)) json-fields)
               '("status" "sessionId" "historyIndex" "sessionStatus"
                 "sessionPath" "saved" "durationSeconds" "exitCode")))))

(test session-output-schema-builders-support-no-extra-fields
  (let* ((schema (cl-cc.core::%session-output-schema "session resume message"
                                                     "恢复后的会话 ID"
                                                     "恢复快照中的历史索引，缺失时为 null"
                                                     "恢复后的会话状态"
                                                     "本次 session resume 执行时长（秒）"))
         (json-fields (getf schema :json)))
    (is (string= (getf schema :text) "session resume message"))
    (is (getf schema :closed))
    (is (equal (mapcar (lambda (field) (getf field :name)) json-fields)
               '("status" "sessionId" "historyIndex" "sessionStatus"
                 "durationSeconds" "exitCode")))))

(test docs-sync-status-and-check-option-builders-stay-stable
  (let ((status-field (cl-cc.core::%docs-sync-status-schema-field))
        (check-option (cl-cc.core::%docs-sync-reference-check-option)))
    (is (equal (getf status-field :name) "status"))
    (is (equal (getf status-field :enum) '("synced" "in-sync" "drift")))
    (is (equal (getf check-option :flags) '("--check")))
    (is (eq (getf check-option :key) :check-only))
    (is (getf check-option :flag))))

(test positional-and-check-option-builders-stay-stable
  (let ((resume-positional (cl-cc.core::%single-required-positional "<session-id-or-path>"))
        (fixture-positional (cl-cc.core::%repeatable-required-positional "<fixture-id>")))
    (is (equal resume-positional '(:name "<session-id-or-path>" :required t)))
    (is (equal fixture-positional '(:name "<fixture-id>" :required t :repeatable t)))))

(test run-fixture-output-format-defaults-remain-json-switches
  (is (equal (cl-cc.core::%run-fixture-output-format-defaults)
             '((:when ((:key :pretty-json)) :value "json")
               (:when ((:key :compact-json)) :value "json")))))

(test output-format-option-defaults
  (let ((option (cl-cc.core::%output-format-option)))
    (is (equal (getf option :flags) '("-o" "--output-format")))
    (is (eq (getf option :key) :output-format))
    (is (equal (getf option :type) '(:enum "text" "json")))
    (is (string= (getf option :default) "text"))
    (is (string= (getf option :value-name) "<output-format>"))
    (is (string= (getf option :summary) "指定输出格式: text 或 json"))))

(test value-option-builders-preserve-types
  (let ((session-id-option (cl-cc.core::%session-id-option))
        (history-index-option (cl-cc.core::%history-index-option))
        (tool-ids-option (cl-cc.core::%tool-ids-option)))
    (is (equal (getf session-id-option :flags) '("-i" "--session-id")))
    (is (eq (getf session-id-option :type) :string))
    (is (equal (getf history-index-option :flags) '("--history-index")))
    (is (eq (getf history-index-option :type) :integer))
    (is (equal (getf tool-ids-option :flags) '("-t" "--tool")))
    (is (eq (getf tool-ids-option :type) :string))
    (is (getf tool-ids-option :repeatable))))

(test run-status-builders-preserve-enums
  (let ((top-level-status (cl-cc.core::%run-top-level-status-schema-field))
        (result-status (cl-cc.core::%run-result-status-schema-field))
        (tool-status (cl-cc.core::%run-tool-status-schema-field))
        (error-code (cl-cc.core::%run-error-code-schema-field)))
    (is (equal (getf top-level-status :enum)
               '("success" "partial" "failed" "denied" "not-found")))
    (is (equal (getf result-status :enum)
               '("success" "partial" "failed" "denied" "not-found")))
    (is (equal (getf tool-status :enum)
               '("success" "failed" "denied" "not-found")))
    (is (equal (getf error-code :enum)
               '("FAIL" "PERMISSION-DENIED" "TOOL-NOT-FOUND" "FILE-READ-FAILED" "DIRECTORY-LIST-FAILED"
                 "FILE-WRITE-FAILED" "FILE-EDIT-FAILED" "GREP-SEARCH-FAILED")))))

(test run-fixture-schema-builders-retain-nested-shape
  (let* ((json-fields (cl-cc.core::%run-fixture-output-json-fields))
         (results-field (find "results" json-fields :key (lambda (field) (getf field :name)) :test #'string=))
         (tool-results-field (find "toolResults"
                                  (getf results-field :fields)
                                  :key (lambda (field) (getf field :name))
                                  :test #'string=)))
    (is (equal (getf (first json-fields) :name) "status"))
    (is (not (null results-field)))
    (is (equal (getf results-field :type) :array))
    (is (getf results-field :collection))
    (is (not (null tool-results-field)))
    (is (equal (getf tool-results-field :type) :array))
    (is (getf tool-results-field :collection))))