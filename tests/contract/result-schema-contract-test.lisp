;;;; tests/contract/result-schema-contract-test.lisp - 通用结果 schema 契约测试
(in-package :cl-cc/tests)

(def-suite result-schema-contract-test :in cl-cc-suite)

(in-suite result-schema-contract-test)

(defun expect-command-schema-valid (command-name result-object)
  (let ((errors (cl-cc.services:command-result-schema-errors command-name result-object)))
    (is (null errors))))

(defun expect-command-schema-error-containing (command-name result-object expected-substring)
  (let ((errors (cl-cc.services:command-result-schema-errors command-name result-object)))
    (is (not (null errors)))
    (is (some (lambda (error)
                (search expected-substring error))
              errors))))

(test generic-command-result-schema-contract
  (let ((session-start-result (cl-cc.services:start-session-result "schema-session" :history-index 3)))
    (expect-command-schema-valid "session start" session-start-result)
    (is (numberp (getf (cl-cc.lib:result-payload session-start-result) :duration-seconds)))
    (is (cl-cc.services:session-start-result-conforms-p session-start-result)))
  (let ((session-resume-result (cl-cc.services:resume-session-result "schema-session")))
    (expect-command-schema-valid "session resume" session-resume-result)
    (is (numberp (getf (cl-cc.lib:result-payload session-resume-result) :duration-seconds)))
    (is (cl-cc.services:session-resume-result-conforms-p session-resume-result)))
  (let ((docs-sync-result (cl-cc.lib:make-result
                           :status :drift
                           :payload (list :path "README.md"
                                          :check-only t
                                          :updated nil
                                          :needs-sync t
                                          :duration-seconds 0.01d0
                                          :exit-code 1)
                           :message "drift")))
    (expect-command-schema-valid "docs sync-reference" docs-sync-result)
    (is (cl-cc.services:docs-sync-result-conforms-p docs-sync-result)))
  (let ((invalid-session-result (cl-cc.lib:make-result
                                 :status :success
                                 :payload (list :session-id "schema-session"
                                                :history-index nil
                                                :session-status :paused
                                                :exit-code 0)
                                 :message "invalid")))
    (expect-command-schema-error-containing "session start"
                                            invalid-session-result
                                            "payload.sessionStatus: expected one of"))
  (let ((invalid-docs-result (cl-cc.lib:make-result
                              :status :success
                              :payload (list :path "README.md"
                                             :check-only t
                                             :updated nil
                                             :needs-sync t
                                             :duration-seconds 0.01d0
                                             :exit-code 1)
                              :message "invalid")))
    (expect-command-schema-error-containing "docs sync-reference"
                                            invalid-docs-result
                                            "payload.status: expected one of"))
  (let ((invalid-session-type-result (cl-cc.lib:make-result
                                      :status :success
                                      :payload (list :session-id "schema-session"
                                                     :history-index "3"
                                                     :session-status :active
                                                     :duration-seconds 0.01d0
                                                     :exit-code 0)
                                      :message "invalid")))
    (expect-command-schema-error-containing "session start"
                                            invalid-session-type-result
                                            "payload.historyIndex: expected value of type INTEGER"))
  (let ((invalid-docs-type-result (cl-cc.lib:make-result
                                   :status :drift
                                   :payload (list :path "README.md"
                                                  :check-only "true"
                                                  :updated nil
                                                  :needs-sync t
                                                  :duration-seconds 0.01d0
                                                  :exit-code 1)
                                   :message "invalid")))
    (expect-command-schema-error-containing "docs sync-reference"
                                            invalid-docs-type-result
                                            "payload.checkOnly: expected value of type BOOLEAN"))
  (let ((invalid-session-duration-result (cl-cc.lib:make-result
                                          :status :success
                                          :payload (list :session-id "schema-session"
                                                         :history-index 3
                                                         :session-status :active
                                                         :duration-seconds "fast"
                                                         :exit-code 0)
                                          :message "invalid")))
    (expect-command-schema-error-containing "session start"
                                            invalid-session-duration-result
                                            "payload.durationSeconds: expected value of type NUMBER"))
  (let ((invalid-session-history-index-result (cl-cc.lib:make-result
                                               :status :success
                                               :payload (list :session-id "schema-session"
                                                              :history-index -1
                                                              :session-status :active
                                                              :duration-seconds 0.01d0
                                                              :exit-code 0)
                                               :message "invalid")))
    (expect-command-schema-error-containing "session start"
                                            invalid-session-history-index-result
                                            "payload.historyIndex: expected value >= 0"))
  (let ((invalid-docs-duration-result (cl-cc.lib:make-result
                                       :status :drift
                                       :payload (list :path "README.md"
                                                      :check-only t
                                                      :updated nil
                                                      :needs-sync t
                                                      :duration-seconds -0.01d0
                                                      :exit-code 1)
                                       :message "invalid")))
    (expect-command-schema-error-containing "docs sync-reference"
                                            invalid-docs-duration-result
                                              "payload.durationSeconds: expected value >= 0"))
    (let ((invalid-session-exit-code-result (cl-cc.lib:make-result
                                             :status :success
                                             :payload (list :session-id "schema-session"
                                                            :history-index 3
                                                            :session-status :active
                                                            :duration-seconds 0.01d0
                                                            :exit-code 256)
                                             :message "invalid")))
      (expect-command-schema-error-containing "session start"
                                              invalid-session-exit-code-result
                                              "payload.exitCode: expected value <= 255"))
    (let ((invalid-docs-exit-code-result (cl-cc.lib:make-result
                                          :status :drift
                                          :payload (list :path "README.md"
                                                         :check-only t
                                                         :updated nil
                                                         :needs-sync t
                                                         :duration-seconds 0.01d0
                                                         :exit-code 999)
                                          :message "invalid")))
      (expect-command-schema-error-containing "docs sync-reference"
                                              invalid-docs-exit-code-result
                                              "payload.exitCode: expected value <= 255"))
    (let ((optional-session-fields-result (cl-cc.lib:make-result
                                           :status :success
                                           :payload (list :session-id "schema-session"
                                                          :duration-seconds 0.01d0
                                                          :exit-code 0)
                                           :message "ok")))
      (expect-command-schema-valid "session start" optional-session-fields-result))
    (let ((optional-tool-fields-result (cl-cc.lib:make-result
                                        :status :success
                                        :payload (list :fixture-count 1
                                                       :successful-count 1
                                                       :failed-count 0
                                                       :duration-seconds 0.01d0
                                                       :status-counts '(("success" . 1)
                                                                        ("failed" . 0)
                                                                        ("partial" . 0)
                                                                        ("denied" . 0)
                                                                        ("not-found" . 0)
                                                                        ("unknown" . 0))
                                                       :ok t
                                                       :exit-code 0
                                                       :results (list (list :fixture-id "test"
                                                                            :status :success
                                                                            :duration-seconds 0.01d0
                                                                            :result "ok"
                                                                            :tool-results (list (list :tool "echo-tool"
                                                                                                     :status :success
                                                                                                     :duration-seconds 0.01d0)))))
                                        :message "ok")))
      (expect-command-schema-valid "run --fixture" optional-tool-fields-result))
    (let ((extra-tool-output-field-result (cl-cc.lib:make-result
                                           :status :success
                                           :payload (list :fixture-count 1
                                                          :successful-count 1
                                                          :failed-count 0
                                                          :duration-seconds 0.01d0
                                                          :status-counts '(("success" . 1)
                                                                           ("failed" . 0)
                                                                           ("partial" . 0)
                                                                           ("denied" . 0)
                                                                           ("not-found" . 0)
                                                                           ("unknown" . 0))
                                                          :ok t
                                                          :exit-code 0
                                                          :results (list (list :fixture-id "test"
                                                                               :status :success
                                                                               :duration-seconds 0.01d0
                                                                               :result "ok"
                                                                               :tool-results (list (list :tool "echo-tool"
                                                                                                        :status :success
                                                                                                        :duration-seconds 0.01d0
                                                                                                        :output (list :result "ok"
                                                                                                                      :extra-field "boom"))))))
                                           :message "invalid")))
      (expect-command-schema-error-containing "run --fixture"
                                              extra-tool-output-field-result
                                              "payload.results[0].toolResults[0].output.extra-field: unexpected field")))
