;;;; tests/unit/execution-engine-test.lisp
(in-package :cl-cc/tests)

(def-suite execution-engine-test :in cl-cc-suite)
(in-suite execution-engine-test)

(test run-execution-cycle-records-success-and-updates-context
  (let* ((context (cl-cc.core:make-execution-context :input "test"))
         (summary (cl-cc.core:run-execution-cycle context "echo-tool"))
         (results (cl-cc.core:execution-context-results context))
         (first-result (first results)))
    (is (string= summary "tool:echo-tool result:fixture-input-test"))
    (is (eq (cl-cc.core:execution-context-status context) :success))
    (is (string= (cl-cc.core:execution-context-output context) "fixture-input-test"))
    (is (= 1 (length results)))
    (is (string= (getf first-result :tool) "echo-tool"))
    (is (eq (getf first-result :status) :success))
    (is (equal (getf first-result :output)
               '(:RESULT "fixture-input-test")))))

(test run-execution-cycle-preserves-failure-history-before-success
  (let* ((context (cl-cc.core:make-execution-context :input "test"))
         (summary (cl-cc.core:run-execution-cycle context "failing-tool" "echo-tool"))
         (results (cl-cc.core:execution-context-results context)))
    (is (string= summary "tool:echo-tool result:fixture-input-test"))
    (is (eq (cl-cc.core:execution-context-status context) :success))
    (is (= 2 (length results)))
    (is (string= (getf (first results) :tool) "failing-tool"))
    (is (eq (getf (first results) :status) :failed))
    (is (string= (getf (second results) :tool) "echo-tool"))
    (is (eq (getf (second results) :status) :success))))

(test run-execution-cycle-records-denied-and-not-found-failures
  (let* ((context (cl-cc.core:make-execution-context :input "restricted"))
         (summary (cl-cc.core:run-execution-cycle context "echo-tool" "missing-tool"))
         (results (cl-cc.core:execution-context-results context)))
    (is (search "all tools failed:" summary))
    (is (eq (cl-cc.core:execution-context-status context) :failed))
    (is (null (cl-cc.core:execution-context-output context)))
    (is (= 2 (length results)))
    (is (eq (getf (first results) :status) :denied))
    (is (eq (getf (first results) :error-code) :permission-denied))
    (is (eq (getf (second results) :status) :not-found))
    (is (eq (getf (second results) :error-code) :tool-not-found))))

(test materialize-schema-output-uses-raw-result-source-by-default
  (is (equal (cl-cc.core::%materialize-schema-output
              '(:json ((:name "result")))
              :raw-result "ok")
             '(:RESULT "ok"))))

(test materialize-schema-output-supports-error-message-and-code-sources
  (handler-case
      (progn
        (cl-cc.tools:failing-tool "ignored")
        (fail "expected failing-tool to signal cl-cc-error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (equal (cl-cc.core::%materialize-schema-output
                  '(:json ((:name "error" :source :error-message)
                           (:name "code" :source :error-code)))
                  :condition condition)
                 '(:ERROR "工具执行失败" :CODE "FAIL"))))))

(test tool-success-output-materializes-declared-schema
  (is (equal (cl-cc.core::%tool-success-output "echo-tool" "fixture-input-test")
             '(:RESULT "fixture-input-test")))
  (is (null (cl-cc.core::%tool-success-output "missing-tool" "fixture-input-test"))))

(test tool-success-output-materializes-structured-raw-result-fields
  (is (equal (cl-cc.core::%tool-success-output "file-edit-tool"
                                               '(:summary "预览编辑文件: tmp.txt"
                                                 :path "tmp.txt"
                                                 :preview t
                                                 :match-count 1
                                                 :total-matches 1
                                                 :selected-occurrence 1
                                                 :match-start 7
                                                 :match-end 14
                                                 :matched-text "preview"
                                                 :replacement-text "value"
                                                 :before-preview "before preview after"
                                                 :after-preview "before value after"
                                                 :diff-preview "@@ match 7..14 @@
-before preview after
+before value after"
                                                 :write-applied nil))
             '(:RESULT "预览编辑文件: tmp.txt"
               :PATH "tmp.txt"
               :PREVIEW T
               :MATCH-COUNT 1
               :TOTAL-MATCHES 1
               :SELECTED-OCCURRENCE 1
               :MATCH-START 7
               :MATCH-END 14
               :MATCHED-TEXT "preview"
               :REPLACEMENT-TEXT "value"
               :BEFORE-PREVIEW "before preview after"
               :AFTER-PREVIEW "before value after"
               :DIFF-PREVIEW "@@ match 7..14 @@
-before preview after
+before value after"
               :WRITE-APPLIED NIL))))

(test tool-error-output-materializes-declared-error-schema
  (handler-case
      (progn
        (cl-cc.tools:failing-tool "ignored")
        (fail "expected failing-tool to signal cl-cc-error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (equal (cl-cc.core::%tool-error-output "failing-tool" condition)
                 '(:ERROR "工具执行失败" :CODE "FAIL")))
      (is (null (cl-cc.core::%tool-error-output "missing-tool" condition))))))

(test missing-tool-record-fields-preserve-stable-shape
  (is (equal (cl-cc.core::%missing-tool-record-fields)
             '(:ERROR "tool not found" :ERROR-CODE :TOOL-NOT-FOUND :OUTPUT NIL))))

(test successful-tool-attempt-fields-preserve-stable-shape
  (is (equal (cl-cc.core::%successful-tool-attempt-fields "echo-tool" "fixture-input-test")
             '(:RESULT "fixture-input-test" :OUTPUT (:RESULT "fixture-input-test")))))

(test tool-result-summary-prefers-structured-summary-field
  (is (string= (cl-cc.core::%tool-result-summary '(:summary "structured-summary" :path "tmp.txt"))
               "structured-summary")))

(test failed-tool-attempt-fields-preserve-stable-shape
  (handler-case
      (progn
        (cl-cc.tools:failing-tool "ignored")
        (fail "expected failing-tool to signal cl-cc-error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (equal (cl-cc.core::%failed-tool-attempt-fields "failing-tool" condition)
                 '(:ERROR "工具执行失败" :ERROR-CODE :FAIL :OUTPUT (:ERROR "工具执行失败" :CODE "FAIL")))))))

(test successful-attempt-values-return-updated-results-result-and-true
  (multiple-value-bind (updated-results result success-p)
      (cl-cc.core::%successful-attempt-values '() "echo-tool" "fixture-input-test" 0.25d0)
    (is (not (null success-p)))
    (is (string= result "fixture-input-test"))
    (is (= (length updated-results) 1))
    (is (eq (getf (first updated-results) :status) :success))))

(test failed-attempt-values-return-updated-results-nil-and-nil
  (handler-case
      (progn
        (cl-cc.tools:failing-tool "ignored")
        (fail "expected failing-tool to signal cl-cc-error"))
    (cl-cc.lib:cl-cc-error (condition)
      (multiple-value-bind (updated-results result success-p)
          (cl-cc.core::%failed-attempt-values '() "failing-tool" condition 0.25d0)
        (is (null result))
        (is (null success-p))
        (is (= (length updated-results) 1))
        (is (eq (getf (first updated-results) :status) :failed))))))

(test missing-tool-values-return-updated-results-nil-and-nil
  (multiple-value-bind (updated-results result success-p)
      (cl-cc.core::%missing-tool-values '() "missing-tool")
    (is (null result))
    (is (null success-p))
    (is (= (length updated-results) 1))
    (is (eq (getf (first updated-results) :status) :not-found))))

(test successful-cycle-outcome-finalizes-context-and-returns-summary
  (let* ((context (cl-cc.core:make-execution-context :input "test"))
         (results '((:tool "echo-tool" :status :success :output (:result "fixture-input-test"))))
         (summary (cl-cc.core::%successful-cycle-outcome context results "echo-tool" "fixture-input-test")))
    (is (string= summary "tool:echo-tool result:fixture-input-test"))
    (is (eq (cl-cc.core:execution-context-status context) :success))
    (is (string= (cl-cc.core:execution-context-output context) "fixture-input-test"))
    (is (equal (cl-cc.core:execution-context-results context)
               results))))

(test failed-cycle-outcome-finalizes-context-and-returns-summary
  (let* ((context (cl-cc.core:make-execution-context :input "test"))
         (results '((:tool "missing-tool" :status :not-found)
                    (:tool "echo-tool" :status :denied)))
         (summary (cl-cc.core::%failed-cycle-outcome context results)))
    (is (search "all tools failed:" summary))
    (is (eq (cl-cc.core:execution-context-status context) :failed))
    (is (null (cl-cc.core:execution-context-output context)))
    (is (equal (cl-cc.core:execution-context-results context)
               (reverse results)))))

(test execution-action-uses-delete-file-for-restricted-input
  (is (eq (cl-cc.core::%execution-action "restricted" "echo-tool") 'delete-file))
  (is (string= (cl-cc.core::%execution-action "path/to/file.txt" "file-read-tool") "file-read"))
  (is (string= (cl-cc.core::%execution-action "path/to/directory" "directory-list-tool") "file-read"))
  (is (string= (cl-cc.core::%execution-action "grep keyword" "grep-tool") "file-read"))
  (is (string= (cl-cc.core::%execution-action '(:path "out.txt" :content "x") "file-write-tool") "file-write"))
  (is (string= (cl-cc.core::%execution-action '(:path "out.txt" :old-text "x" :new-text "y") "file-edit-tool") "file-write"))
  (is (string= (cl-cc.core::%execution-action "test" "echo-tool") "echo-tool")))

(test execution-tool-input-prefixes-non-session-contexts-only
  (let ((fixture-context (cl-cc.core:make-execution-context :input "abc"))
        (session-context (cl-cc.core:make-execution-context :command "session-loop" :input "abc")))
    (is (string= (cl-cc.core::%execution-tool-input fixture-context "abc") "fixture-input-abc"))
    (is (string= (cl-cc.core::%execution-tool-input session-context "abc") "abc"))
    (is (equal (cl-cc.core::%execution-tool-input fixture-context '(:path "out.txt" :content "x"))
               '(:path "out.txt" :content "x")))))

(test run-execution-cycle-uses_planned_tool_input_when_present
  (let* ((context (cl-cc.core:make-execution-context :command "session-loop"
                                                     :input "ignored"
                                                     :tool-inputs '(("echo-tool" . "planned-input"))))
         (summary (cl-cc.core:run-execution-cycle context "echo-tool"))
         (results (cl-cc.core:execution-context-results context)))
    (is (string= summary "tool:echo-tool result:planned-input"))
    (is (string= (cl-cc.core:execution-context-output context) "planned-input"))
    (is (equal (getf (first results) :output)
               '(:RESULT "planned-input")))))

    (test run-execution-cycle-stops-on-interactive-denial-when-configured
      (let ((path (uiop:native-namestring
          (uiop:merge-pathnames* "execution-engine-approval-stop.txt"
                     (uiop:temporary-directory)))))
        (unwind-protect
          (let* ((request (format nil "write file ~A :: blocked" path))
           (context (cl-cc.core:make-execution-context :command "session-loop"
                            :input request
                            :approval-mode :interactive
                            :approval-callback (lambda (tool-id action input permission-profile)
                                     (declare (ignore tool-id action input permission-profile))
                                     nil)
                            :halt-on-denied t))
           (summary (cl-cc.core:run-execution-cycle context "file-write-tool" "echo-tool"))
           (results (cl-cc.core:execution-context-results context)))
         (is (search "all tools failed:" summary))
         (is (= 1 (length results)))
         (is (string= (getf (first results) :tool) "file-write-tool"))
         (is (eq (getf (first results) :status) :denied))
         (is (eq (getf (first results) :error-code) :permission-denied))
         (is (not (probe-file path))))
       (when (probe-file path)
         (delete-file path)))))

(test execution-error-status-maps-known-error-codes
  (let ((permission-error (make-condition 'cl-cc.lib:cl-cc-error
                                          :code :permission-denied
                                          :message "denied"))
        (missing-tool-error (make-condition 'cl-cc.lib:cl-cc-error
                                            :code :tool-not-found
                                            :message "missing"))
        (generic-error (make-condition 'cl-cc.lib:cl-cc-error
                                       :code :fail
                                       :message "failed")))
    (is (eq (cl-cc.core::%execution-error-status permission-error) :denied))
    (is (eq (cl-cc.core::%execution-error-status missing-tool-error) :not-found))
    (is (eq (cl-cc.core::%execution-error-status generic-error) :failed))))

(test record-missing-tool-result-preserves-stable-shape
  (let* ((results (cl-cc.core::%record-missing-tool-result '() "missing-tool"))
         (record (first results)))
    (is (string= (getf record :tool) "missing-tool"))
    (is (eq (getf record :status) :not-found))
    (is (string= (getf record :error) "tool not found"))
    (is (eq (getf record :error-code) :tool-not-found))
    (is (= (getf record :duration-seconds) 0d0))))

(test successful-execution-summary-preserves-stable-format
  (is (string= (cl-cc.core::%successful-execution-summary "echo-tool" "fixture-input-test")
               "tool:echo-tool result:fixture-input-test")))

(test failed-execution-summary-preserves-result-order
  (let ((results '((:tool "missing-tool" :status :not-found)
                   (:tool "echo-tool" :status :denied))))
    (let ((summary (cl-cc.core::%failed-execution-summary results)))
      (is (search "all tools failed:" summary))
      (is (< (search "TOOL echo-tool STATUS DENIED" summary)
             (search "TOOL missing-tool STATUS NOT-FOUND" summary))))))