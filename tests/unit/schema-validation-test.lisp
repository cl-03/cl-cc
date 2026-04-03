;;;; tests/unit/schema-validation-test.lisp
(in-package :cl-cc/tests)

(def-suite schema-validation-test :in cl-cc-suite)
(in-suite schema-validation-test)

(test schema-field-key-mapping-supports-camel-case-and-tool-alias
  (is (eq (cl-cc.services::%json-name-to-keyword "checkOnly") :CHECK-ONLY))
  (is (equal (cl-cc.services::%schema-field-candidate-keys "toolId")
             '(:tool-id :tool)))
  (is (equal (cl-cc.services::%schema-field-candidate-keys "sessionId")
             '(:SESSION-ID))))

(test schema-field-and-relation-accessors-preserve-plist-derived-values
  (let ((field '(:enum ("success" "failed")
                 :nullable t
                 :type :string
                 :minimum 1
                 :min-items 2
                 :equals-field "fixtureCount"
                 :equals-collection-size-of "results"
                 :equals-sum-of-fields ("statusCounts.success" "statusCounts.failed")
                 :equals-field-when-value (:field "fixtureCount" :when-field "status" :value "success")
                 :true-when-zero-field "exitCode"
                 :enum-when-zero-field ("success")
                 :enum-when-nonzero-field ("failed" "partial")
                 :maximum 5))
        (relation '(:field "status"
                    :when-field "exitCode"
                    :value 0
                    :values ("success" "partial")
                    :fields ("statusCounts.success" "statusCounts.failed"))))
    (is (equal (cl-cc.services::%schema-field-enum-values field)
               '("success" "failed")))
    (is (eq (cl-cc.services::%schema-field-nullable-p field) t))
    (is (eq (cl-cc.services::%schema-field-type field) :string))
    (is (= 1 (cl-cc.services::%schema-field-minimum field)))
    (is (= 2 (cl-cc.services::%schema-field-min-items field)))
    (is (string= (cl-cc.services::%schema-field-equals-field field) "fixtureCount"))
    (is (string= (cl-cc.services::%schema-field-equals-collection-size-of field) "results"))
    (is (equal (cl-cc.services::%schema-field-equals-sum-of-fields field)
               '("statusCounts.success" "statusCounts.failed")))
    (is (equal (cl-cc.services::%schema-field-equals-field-when-value field)
               '(:field "fixtureCount" :when-field "status" :value "success")))
    (is (string= (cl-cc.services::%schema-field-true-when-zero-field field) "exitCode"))
    (is (equal (cl-cc.services::%schema-field-enum-when-zero-field field)
               '("success")))
    (is (equal (cl-cc.services::%schema-field-enum-when-nonzero-field field)
               '("failed" "partial")))
    (is (= 5 (cl-cc.services::%schema-field-maximum field)))
    (is (string= (cl-cc.services::%schema-relation-field-name relation) "status"))
    (is (string= (cl-cc.services::%schema-relation-when-field-name relation) "exitCode"))
    (is (= 0 (cl-cc.services::%schema-relation-value relation)))
    (is (equal (cl-cc.services::%schema-relation-values relation)
               '("success" "partial")))
    (is (equal (cl-cc.services::%schema-relation-fields relation)
               '("statusCounts.success" "statusCounts.failed")))))

(test schema-value-type-matching-covers-core-primitives
  (is (cl-cc.services::%schema-value-matches-type-p :string "ok"))
  (is (cl-cc.services::%schema-value-matches-type-p :integer 3))
  (is (cl-cc.services::%schema-value-matches-type-p :number 0.1d0))
  (is (cl-cc.services::%schema-value-matches-type-p :boolean t))
  (is (cl-cc.services::%schema-value-matches-type-p :boolean nil))
  (is (cl-cc.services::%schema-value-matches-type-p :object '(:status "success")))
  (is (cl-cc.services::%schema-value-matches-type-p :array '(1 2 3)))
  (is (not (cl-cc.services::%schema-value-matches-type-p :integer "3"))))

(test schema-reference-helpers-detect-presence-zero-and-sums
  (let ((payload '(:exit-code 0
                  :status-counts (:success 1 :failed 0)
                  :fixture-count 1)))
    (is (cl-cc.services::%schema-reference-present-p payload "exitCode"))
    (is (cl-cc.services::%schema-reference-number-zero-p payload "exitCode"))
    (is (not (cl-cc.services::%schema-reference-number-nonzero-p payload "exitCode")))
    (is (cl-cc.services::%schema-relation-values-all-numeric-p
         payload
         '(:fields ("statusCounts.success" "statusCounts.failed"))))
    (is (= 1 (cl-cc.services::%schema-relation-values-sum
              payload
              '(:fields ("statusCounts.success" "statusCounts.failed")))))))

(test schema-field-value-validation-preserves-priority-order
  (is (equal (cl-cc.services::%validate-schema-field-value
              '(:name "status" :type :integer :enum (1 2 3))
              "3"
              "payload.status"
              '(:status "3"))
             '("payload.status: expected value of type INTEGER"))))

(test schema-field-value-validation-gates-conditional-relations
  (is (null (cl-cc.services::%validate-schema-field-value
             '(:name "successfulCount"
               :type :integer
               :equals-field-when-value (:field "fixtureCount"
                                          :when-field "status"
                                          :value "success"))
             0
             "payload.successfulCount"
             '(:status "partial" :fixture-count 2 :successful-count 0))))
  (is (equal (cl-cc.services::%validate-schema-field-value
              '(:name "successfulCount"
                :type :integer
                :equals-field-when-value (:field "fixtureCount"
                                           :when-field "status"
                                           :value "success"))
              1
              "payload.successfulCount"
              '(:status "success" :fixture-count 2 :successful-count 1))
             '("payload.successfulCount: expected value matching fixtureCount when status is \"success\""))))

(test parse-json-document-preserves-objects-arrays-and-null
  (let ((parsed (cl-cc.services::%parse-json-document
                 "{\"status\":\"success\",\"items\":[1,2],\"sessionPath\":null}")))
    (is (string= (getf parsed :STATUS) "success"))
    (is (equal (getf parsed :ITEMS) '(1 2)))
    (is (cl-cc.services::%json-null-p (getf parsed :SESSION-PATH)))))

(test tool-output-schema-selection-follows-status-and-ref-kind
  (let* ((success-record '(:tool "echo-tool" :status :success))
         (failure-record '(:tool "failing-tool" :status :failed))
         (success-schema (cl-cc.services::%tool-output-schema-for-record success-record
                                                                          '((:tool-id "echo-tool" :kind :output))))
         (failure-schema (cl-cc.services::%tool-output-schema-for-record failure-record
                                                                          '((:tool-id "failing-tool" :kind :error)))))
    (is (equal (mapcar (lambda (field) (getf field :name))
                       (getf success-schema :json))
               '("result")))
    (is (equal (mapcar (lambda (field) (getf field :name))
                       (getf failure-schema :json))
               '("error" "code")))))

(test session-result-envelope-preserves-missing-vs-present-fields
  (let* ((result (cl-cc.lib:make-result :status :success
                                        :payload (list :session-id "schema-session"
                                                       :duration-seconds 0.01d0
                                                       :exit-code 0
                                                       :saved nil)
                                        :message "ok"))
         (envelope (cl-cc.services::%session-result-envelope result)))
    (is (string= (getf envelope :status) "success"))
    (is (string= (getf envelope :session-id) "schema-session"))
    (is (null (getf envelope :saved :missing)))
    (is (eq (getf envelope :history-index :missing) :missing))
    (is (eq (getf envelope :session-status :missing) :missing))
    (is (eq (getf envelope :session-path :missing) :missing))))

(test session-result-envelope-preserves-present-null-session-status
  (let* ((result (cl-cc.lib:make-result :status :success
                                        :payload (list :session-id "schema-session"
                                                       :duration-seconds 0.01d0
                                                       :exit-code 0
                                                       :session-status nil)
                                        :message "ok"))
         (envelope (cl-cc.services::%session-result-envelope result)))
    (is (null (getf envelope :session-status :missing)))
    (is (not (eq (getf envelope :session-status :missing) :missing)))))

(test normalized-tool-record-preserves-optional-fields-and-error-codes
  (let ((record (cl-cc.services::%normalized-tool-record
                 '(:tool "failing-tool"
                   :status :failed
                   :duration-seconds 0.02d0
                   :error "工具执行失败"
                   :error-code :fail))))
    (is (string= (getf record :tool-id) "failing-tool"))
    (is (string= (getf record :tool) "failing-tool"))
    (is (string= (getf record :status) "failed"))
    (is (string= (getf record :error) "工具执行失败"))
    (is (string= (getf record :error-code) "FAIL"))))

(test normalized-tool-record-preserves-missing-optional-fields
  (let ((record (cl-cc.services::%normalized-tool-record
                 '(:tool "echo-tool"
                   :status :success
                   :duration-seconds 0.02d0))))
    (is (eq (getf record :output :missing) :missing))
    (is (eq (getf record :error :missing) :missing))
    (is (eq (getf record :error-code :missing) :missing))))

(test run-fixture-result-envelope-normalizes-status-counts-and-nested-records
  (let* ((result (cl-cc.lib:make-result
                  :status :partial
                  :payload (list :fixture-count 1
                                 :successful-count 0
                                 :failed-count 0
                                 :duration-seconds 0.03d0
                                 :status-counts '(("success" . 0)
                                                  ("failed" . 0)
                                                  ("partial" . 1)
                                                  ("denied" . 0)
                                                  ("not-found" . 0)
                                                  ("unknown" . 0))
                                 :ok nil
                                 :exit-code 1
                                 :results (list (list :fixture-id "test"
                                                      :status :partial
                                                      :duration-seconds 0.03d0
                                                      :result "mixed"
                                                      :tool-results (list (list :tool "echo-tool"
                                                                               :status :success
                                                                               :duration-seconds 0.01d0
                                                                               :output (list :result "ok"))))))
                  :message "partial"))
         (envelope (cl-cc.services::%run-fixture-result-envelope result))
         (first-result (first (getf envelope :results)))
         (first-tool (first (getf first-result :tool-results))))
    (is (string= (getf envelope :status) "partial"))
    (is (equal (getf envelope :status-counts)
               '(:SUCCESS 0 :FAILED 0 :PARTIAL 1 :DENIED 0 :NOT-FOUND 0 :UNKNOWN 0)))
    (is (string= (getf first-result :status) "partial"))
    (is (string= (getf first-tool :tool-id) "echo-tool"))
    (is (string= (getf first-tool :status) "success"))))

(test collection-field-validation-reports-non-plist-items
  (let ((errors (cl-cc.services::%validate-schema-collection-field-value
                 '("bad-item")
                 '((:name "toolId" :type :string))
                 "payload.toolResults"
                 nil
                 '(:tool-results ("bad-item")))))
    (is (equal errors
               '("payload.toolResults[0]: expected property list item")))))

(test child-object-validation-reports-null-and-non-object-values
  (is (equal (cl-cc.services::%validate-schema-child-object-value
              nil
              '((:name "status" :type :string))
              "payload.output"
              nil
              '(:output nil))
             '("payload.output: expected structured value")))
  (is (equal (cl-cc.services::%validate-schema-child-object-value
              "bad"
              '((:name "status" :type :string))
              "payload.output"
              nil
              '(:output "bad"))
             '("payload.output: expected property list value"))))