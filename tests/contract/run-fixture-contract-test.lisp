;;;; tests/contract/run-fixture-contract-test.lisp - run --fixture 契约测试
(in-package :cl-cc/tests)

(def-suite run-fixture-contract-test :in cl-cc-suite)

(in-suite run-fixture-contract-test)

(defun status-count (payload status-name)
  (cdr (assoc status-name (getf payload :status-counts) :test #'string=)))

(defun expect-schema-valid (result)
  (let ((errors (cl-cc.services:run-fixture-result-schema-errors result)))
    (is (null errors))))

(defun expect-schema-error-containing (result expected-substring)
  (let ((errors (cl-cc.services:run-fixture-result-schema-errors result)))
    (is (not (null errors)))
    (is (some (lambda (error)
                (search expected-substring error))
              errors))))

(test run-fixture-contract
  (let* ((result (cl-cc.services:run-fixture "test"))
         (payload (cl-cc.lib:result-payload result)))
    (expect-schema-valid result)
    (is (typep result 'cl-cc.lib:result))
    (is (eq (cl-cc.lib:result-status result) :success))
    (is (search "[SUCCESS]" (cl-cc.lib:result-message result)))
    (is (search "tool:echo-tool" (cl-cc.lib:result-message result)))
    (is (= (getf payload :fixture-count) 1))
    (is (= (getf payload :successful-count) 1))
    (is (= (getf payload :failed-count) 0))
    (is (numberp (getf payload :duration-seconds)))
    (is (getf payload :ok))
    (is (= (getf payload :exit-code) 0))
    (is (= (status-count payload "success") 1))
    (is (= (status-count payload "failed") 0))
    (is (equal (getf (first (getf payload :results)) :fixture-id) "test"))
    (is (numberp (getf (first (getf payload :results)) :duration-seconds)))
    (is (equal (getf (first (getf (first (getf payload :results)) :tool-results)) :tool) "echo-tool"))
    (is (numberp (getf (first (getf (first (getf payload :results)) :tool-results)) :duration-seconds)))
    (is (equal (getf (getf (first (getf (first (getf payload :results)) :tool-results)) :output) :result)
           "fixture-input-test")))
  (multiple-value-bind (result exit-code)
      (cl-cc.services:run-fixture "test" :output-format "json")
    (declare (ignore result))
    (is (= exit-code 0)))
  (let* ((tool-override-result (cl-cc.services:run-fixture "fail" :tool-ids '("failing-tool" "echo-tool")))
         (payload (cl-cc.lib:result-payload tool-override-result)))
    (expect-schema-valid tool-override-result)
    (is (eq (cl-cc.lib:result-status tool-override-result) :success))
    (is (search "[SUCCESS]" (cl-cc.lib:result-message tool-override-result)))
    (is (= (getf payload :successful-count) 1)))
  (let* ((multiple-result (cl-cc.services:run-fixtures '("test" "fail")))
         (payload (cl-cc.lib:result-payload multiple-result)))
    (expect-schema-valid multiple-result)
    (is (eq (cl-cc.lib:result-status multiple-result) :success))
    (is (search "test: [SUCCESS] tool:echo-tool" (cl-cc.lib:result-message multiple-result)))
    (is (search "fail: [SUCCESS] tool:echo-tool" (cl-cc.lib:result-message multiple-result)))
    (is (= (getf payload :fixture-count) 2))
    (is (= (status-count payload "success") 2)))
  (let* ((partial-result (cl-cc.services:run-fixtures '("test" "restricted") :tool-ids '("echo-tool")))
         (payload (cl-cc.lib:result-payload partial-result)))
    (expect-schema-valid partial-result)
    (is (eq (cl-cc.lib:result-status partial-result) :partial))
    (is (= (getf payload :successful-count) 1))
    (is (= (status-count payload "denied") 1))
    (is (not (getf payload :ok)))
    (is (= (getf payload :exit-code) 1)))
  (let* ((failed-result (cl-cc.services:run-fixture "test" :tool-ids '("failing-tool")))
         (payload (cl-cc.lib:result-payload failed-result)))
    (expect-schema-valid failed-result)
    (is (eq (cl-cc.lib:result-status failed-result) :failed))
    (is (= (getf payload :fixture-count) 1))
    (is (= (getf payload :successful-count) 0))
    (is (= (getf payload :failed-count) 1))
    (is (= (status-count payload "failed") 1))
    (is (= (getf payload :exit-code) 1))
    (is (not (getf payload :ok)))
    (is (equal (getf (first (getf (first (getf payload :results)) :tool-results)) :error) "工具执行失败"))
    (is (equal (getf (getf (first (getf (first (getf payload :results)) :tool-results)) :output) :code) "FAIL")))
  (let* ((denied-result (cl-cc.services:run-fixture "restricted" :tool-ids '("echo-tool")))
         (payload (cl-cc.lib:result-payload denied-result)))
    (expect-schema-valid denied-result)
    (is (eq (cl-cc.lib:result-status denied-result) :denied))
    (is (= (status-count payload "denied") 1))
    (is (= (getf payload :exit-code) 1))
    (is (not (getf payload :ok)))
       (is (null (getf (first (getf (first (getf payload :results)) :tool-results)) :output)))
       (is (equal (getf (first (getf (first (getf payload :results)) :tool-results)) :error-code)
                        :permission-denied)))
  (let* ((not-found-result (cl-cc.services:run-fixture "test" :tool-ids '("missing-tool")))
         (payload (cl-cc.lib:result-payload not-found-result)))
    (expect-schema-valid not-found-result)
    (is (eq (cl-cc.lib:result-status not-found-result) :not-found))
    (is (= (status-count payload "not-found") 1))
    (is (= (getf payload :exit-code) 1))
    (is (not (getf payload :ok)))
    (is (equal (getf (first (getf (first (getf payload :results)) :tool-results)) :error-code)
       :tool-not-found)))
     (let ((invalid-results-array-result
            (cl-cc.lib:make-result
             :status :failed
             :payload (list :fixture-count 1
                            :successful-count 0
                            :failed-count 1
                            :status-counts '(("success" . 0)
                                             ("failed" . 1)
                                             ("partial" . 0)
                                             ("denied" . 0)
                                             ("not-found" . 0)
                                             ("unknown" . 0))
                            :ok nil
                            :exit-code 1
                            :results (list :fixture-id "invalid"
                                           :status :failed
                                           :result "broken"
                                           :tool-results nil))
             :message "invalid")))
       (expect-schema-error-containing invalid-results-array-result
                                       "payload.results: expected value of type ARRAY"))
     (let ((invalid-tool-results-array-result
            (cl-cc.lib:make-result
             :status :failed
             :payload (list :fixture-count 1
                            :successful-count 0
                            :failed-count 1
                            :status-counts '(("success" . 0)
                                             ("failed" . 1)
                                             ("partial" . 0)
                                             ("denied" . 0)
                                             ("not-found" . 0)
                                             ("unknown" . 0))
                            :ok nil
                            :exit-code 1
                            :results (list (list :fixture-id "invalid"
                                                 :status :failed
                                                 :result "broken"
                                                 :tool-results (list :tool "failing-tool"
                                                                     :status :failed
                                                                     :output (list :error "broken" :code "FAIL")
                                                                     :error "broken"
                                                                     :error-code :fail))))
             :message "invalid")))
       (expect-schema-error-containing invalid-tool-results-array-result
                                       "payload.results[0].toolResults: expected value of type ARRAY"))
     (let ((empty-results-array-result
            (cl-cc.lib:make-result
             :status :failed
             :payload (list :fixture-count 0
                            :successful-count 0
                            :failed-count 0
                            :duration-seconds 0.01d0
                            :status-counts '(("success" . 0)
                                             ("failed" . 0)
                                             ("partial" . 0)
                                             ("denied" . 0)
                                             ("not-found" . 0)
                                             ("unknown" . 0))
                            :ok nil
                            :exit-code 1
                            :results '())
             :message "invalid")))
       (expect-schema-error-containing empty-results-array-result
                                       "payload.results: expected at least 1 item"))
     (let ((empty-tool-results-result
            (cl-cc.lib:make-result
             :status :failed
             :payload (list :fixture-count 1
                            :successful-count 0
                            :failed-count 1
                            :duration-seconds 0.01d0
                            :status-counts '(("success" . 0)
                                             ("failed" . 1)
                                             ("partial" . 0)
                                             ("denied" . 0)
                                             ("not-found" . 0)
                                             ("unknown" . 0))
                            :ok nil
                            :exit-code 1
                            :results (list (list :fixture-id "invalid"
                                                 :status :failed
                                                 :duration-seconds 0.01d0
                                                 :result "broken"
                                                 :tool-results '())))
             :message "invalid")))
       (expect-schema-error-containing empty-tool-results-result
                                       "payload.results[0].toolResults: expected at least 1 item"))
     (let ((mismatched-fixture-count-result
            (cl-cc.lib:make-result
             :status :success
             :payload (list :fixture-count 2
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
                                                                          :output (list :result "ok"))))))
             :message "invalid")))
       (expect-schema-error-containing mismatched-fixture-count-result
                                       "payload.fixtureCount: expected value matching item count of results"))
             (let ((mismatched-status-count-sum-result
            (cl-cc.lib:make-result
             :status :success
             :payload (list :fixture-count 1
                    :successful-count 1
                    :failed-count 0
                    :duration-seconds 0.01d0
                    :status-counts '(("success" . 2)
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
                                  :output (list :result "ok"))))))
             :message "invalid")))
           (expect-schema-error-containing mismatched-status-count-sum-result
                       "payload.fixtureCount: expected value matching sum of statusCounts.success, statusCounts.failed, statusCounts.partial, statusCounts.denied, statusCounts.not-found, statusCounts.unknown"))
     (let ((mismatched-success-count-result
            (cl-cc.lib:make-result
             :status :success
             :payload (list :fixture-count 1
                            :successful-count 0
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
                                                                          :output (list :result "ok"))))))
             :message "invalid")))
       (expect-schema-error-containing mismatched-success-count-result
                                       "payload.successfulCount: expected value matching statusCounts.success"))
     (let ((mismatched-failed-count-result
            (cl-cc.lib:make-result
             :status :failed
             :payload (list :fixture-count 1
                            :successful-count 0
                            :failed-count 0
                            :duration-seconds 0.01d0
                            :status-counts '(("success" . 0)
                                             ("failed" . 1)
                                             ("partial" . 0)
                                             ("denied" . 0)
                                             ("not-found" . 0)
                                             ("unknown" . 0))
                            :ok nil
                            :exit-code 1
                            :results (list (list :fixture-id "test"
                                                 :status :failed
                                                 :duration-seconds 0.01d0
                                                 :result "broken"
                                                 :tool-results (list (list :tool "failing-tool"
                                                                          :status :failed
                                                                          :duration-seconds 0.01d0
                                                                          :output (list :error "broken" :code "FAIL")
                                                                          :error "broken"
                                              :error-code :fail)))))
                         :message "invalid")))
       (expect-schema-error-containing mismatched-failed-count-result
                                       "payload.failedCount: expected value matching statusCounts.failed"))
                (let ((mismatched-ok-result
                    (cl-cc.lib:make-result
                     :status :failed
                     :payload (list :fixture-count 1
                           :successful-count 0
                           :failed-count 1
                           :duration-seconds 0.01d0
                           :status-counts '(("success" . 0)
                                ("failed" . 1)
                                ("partial" . 0)
                                ("denied" . 0)
                                ("not-found" . 0)
                                ("unknown" . 0))
                           :ok t
                           :exit-code 1
                           :results (list (list :fixture-id "test"
                                    :status :failed
                                    :duration-seconds 0.01d0
                                    :result "broken"
                                    :tool-results (list (list :tool "failing-tool"
                                              :status :failed
                                              :duration-seconds 0.01d0
                                              :output (list :error "broken" :code "FAIL")
                                              :error "broken"
                                              :error-code :fail)))))
                     :message "invalid")))
                  (expect-schema-error-containing mismatched-ok-result
                                "payload.ok: expected boolean matching zero value of exitCode"))
     (let ((mismatched-status-result
            (cl-cc.lib:make-result
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
                            :ok nil
                            :exit-code 1
                            :results (list (list :fixture-id "test"
                                                 :status :success
                                                 :duration-seconds 0.01d0
                                                 :result "ok"
                                                 :tool-results (list (list :tool "echo-tool"
                                                                          :status :success
                                                                          :duration-seconds 0.01d0
                                                                          :output (list :result "ok"))))))
             :message "invalid")))
       (expect-schema-error-containing mismatched-status-result
                                       "payload.status: expected one of (\"partial\" \"failed\" \"denied\" \"not-found\") when exitCode is non-zero"))
             (let ((mismatched-success-aggregate-result
            (cl-cc.lib:make-result
             :status :success
             :payload (list :fixture-count 2
                    :successful-count 1
                    :failed-count 1
                    :duration-seconds 0.01d0
                    :status-counts '( ("success" . 1)
                          ("failed" . 1)
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
                                  :output (list :result "ok"))))
                       (list :fixture-id "fail"
                         :status :failed
                         :duration-seconds 0.01d0
                         :result "broken"
                         :tool-results (list (list :tool "failing-tool"
                                  :status :failed
                                  :duration-seconds 0.01d0
                                  :output (list :error "broken" :code "FAIL")
                                  :error "broken"
                                  :error-code :fail)))))
             :message "invalid")))
           (expect-schema-error-containing mismatched-success-aggregate-result
                       "payload.statusCounts.success: expected value matching fixtureCount when status is \"success\""))
             (let ((mismatched-denied-aggregate-result
            (cl-cc.lib:make-result
             :status :denied
             :payload (list :fixture-count 1
                    :successful-count 0
                    :failed-count 1
                    :duration-seconds 0.01d0
                    :status-counts '( ("success" . 0)
                          ("failed" . 1)
                          ("partial" . 0)
                          ("denied" . 0)
                          ("not-found" . 0)
                          ("unknown" . 0))
                    :ok nil
                    :exit-code 1
                    :results (list (list :fixture-id "restricted"
                         :status :failed
                         :duration-seconds 0.01d0
                         :result "broken"
                         :tool-results (list (list :tool "failing-tool"
                                  :status :failed
                                  :duration-seconds 0.01d0
                                  :output (list :error "broken" :code "FAIL")
                                  :error "broken"
                                  :error-code :fail)))))
             :message "invalid")))
           (expect-schema-error-containing mismatched-denied-aggregate-result
                       "payload.statusCounts.denied: expected value matching fixtureCount when status is \"denied\""))
     (let ((invalid-duration-type-result
       (cl-cc.lib:make-result
        :status :success
        :payload (list :fixture-count 1
           :successful-count 1
           :failed-count 0
           :duration-seconds "fast"
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
                                          :output (list :result "ok")
                                          :error nil
                                          :error-code nil)))))
        :message "invalid")))
      (expect-schema-error-containing invalid-duration-type-result
                            "payload.durationSeconds: expected value of type NUMBER"))
       (let ((invalid-negative-count-result
         (cl-cc.lib:make-result
          :status :success
          :payload (list :fixture-count -1
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
                                :output (list :result "ok")
                                :error nil
                                :error-code nil)))))
          :message "invalid")))
        (expect-schema-error-containing invalid-negative-count-result
                       "payload.fixtureCount: expected value >= 0"))
       (let ((invalid-negative-tool-duration-result
         (cl-cc.lib:make-result
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
                                :duration-seconds -0.01d0
                                :output (list :result "ok")
                                :error nil
                                :error-code nil)))))
          :message "invalid")))
        (expect-schema-error-containing invalid-negative-tool-duration-result
                       "payload.results[0].toolResults[0].durationSeconds: expected value >= 0"))
    (let ((invalid-status-result
       (cl-cc.lib:make-result
        :status :mystery
        :payload (list :fixture-count 1
             :successful-count 0
             :failed-count 1
             :status-counts '(("success" . 0)
               ("failed" . 1)
               ("partial" . 0)
               ("denied" . 0)
               ("not-found" . 0)
               ("unknown" . 0))
             :ok nil
             :exit-code 1
             :results (list (list :fixture-id "invalid"
                   :status :failed
                   :result "broken"
                   :tool-results (list (list :tool "failing-tool"
                         :status :failed
                         :output (list :error "broken" :code "BOGUS")
                         :error "broken"
                         :error-code :bogus)))))
        :message "invalid")))
      (expect-schema-error-containing invalid-status-result "payload.status: expected one of")
      (expect-schema-error-containing invalid-status-result "payload.results[0].toolResults[0].errorCode: expected one of")))
