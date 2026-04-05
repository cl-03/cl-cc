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
  (let ((session-start-saved-result (cl-cc.lib:make-result
                                     :status :success
                                     :payload (list :session-id "schema-session"
                                                    :history-index 3
                                                    :session-status :active
                                                    :session-path "tmp/schema-session.session"
                                                    :saved t
                                                    :duration-seconds 0.01d0
                                                    :exit-code 0)
                                     :message "saved")))
    (expect-command-schema-valid "session start" session-start-saved-result)
    (is (cl-cc.services:session-start-result-conforms-p session-start-saved-result)))
  (let* ((directory (uiop:ensure-directory-pathname
                     (uiop:merge-pathnames* "result-schema-session-list-test/"
                                            (uiop:temporary-directory))))
         (path (uiop:native-namestring (merge-pathnames "schema.session" directory))))
    (unwind-protect
         (progn
           (ensure-directories-exist directory)
           (is (cl-cc.session:save-session
                (make-instance 'cl-cc.models:session-state
                               :session-id "schema-listed"
                               :created-at "2026-04-05T06:00:00Z"
                               :updated-at "2026-04-05T06:05:00Z"
                               :history-index 6
                               :context-summary '(:input "schema list input" :result "schema list result")
                               :tasks '((:task-id "shell-task-15"))
                               :permission-snapshot path
                               :status :active
                               :version "0.1")
                path))
           (let ((session-list-result (cl-cc.services:list-sessions-result :session-dir (uiop:native-namestring directory))))
             (expect-command-schema-valid "session list" session-list-result)
             (is (cl-cc.services:session-list-result-conforms-p session-list-result))))
      (when (probe-file directory)
        (uiop:delete-directory-tree directory :validate t :if-does-not-exist :ignore))))
  (let ((session-resume-result (cl-cc.services:resume-session-result "schema-session")))
    (expect-command-schema-valid "session resume" session-resume-result)
    (is (numberp (getf (cl-cc.lib:result-payload session-resume-result) :duration-seconds)))
    (is (cl-cc.services:session-resume-result-conforms-p session-resume-result)))
  (let ((session-run-result (cl-cc.services:run-session-result "schema-session" :input "schema input")))
    (expect-command-schema-valid "session run" session-run-result)
    (is (numberp (getf (cl-cc.lib:result-payload session-run-result) :duration-seconds)))
    (is (string= (getf (cl-cc.lib:result-payload session-run-result) :input) "schema input"))
    (is (eq (getf (cl-cc.lib:result-payload session-run-result) :execution-status) :success))
    (is (string= (getf (cl-cc.lib:result-payload session-run-result) :result)
                 "tool:echo-tool result:schema input"))
    (is (equal (getf (cl-cc.lib:result-payload session-run-result) :selected-tools)
               '("echo-tool" "failing-tool")))
    (is (equal (getf (cl-cc.lib:result-payload session-run-result) :execution-plan)
               '((:tool "echo-tool" :input "schema input")
                 (:tool "failing-tool" :input "schema input"))))
    (is (= (length (getf (cl-cc.lib:result-payload session-run-result) :tool-results)) 1))
    (is (cl-cc.services:session-run-result-conforms-p session-run-result)))
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "schema-write-tool.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let ((session-run-write-result (cl-cc.services:run-session-result
                                          "schema-session"
                                          :input (format nil "write file ~A :: schema-write" path))))
           (expect-command-schema-valid "session run" session-run-write-result)
           (is (string= (getf (cl-cc.lib:result-payload session-run-write-result) :result)
                        (format nil "tool:file-write-tool result:写入文件: ~A" path)))
           (is (cl-cc.services:session-run-result-conforms-p session-run-write-result)))
      (when (probe-file path)
        (delete-file path))))
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "schema-edit-tool.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before anchor after" stream))
           (let ((session-run-edit-result (cl-cc.services:run-session-result
                                           "schema-session"
                                           :input (format nil "edit file ~A :: anchor :: changed" path))))
             (expect-command-schema-valid "session run" session-run-edit-result)
             (is (string= (getf (cl-cc.lib:result-payload session-run-edit-result) :result)
                          (format nil "tool:file-edit-tool result:编辑文件: ~A" path)))
             (is (cl-cc.services:session-run-result-conforms-p session-run-edit-result))))
      (when (probe-file path)
        (delete-file path))))
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "schema-grep-tool/"
                                                 (uiop:temporary-directory))))
         (match-file (merge-pathnames "schema.txt" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist directory-path)
           (with-open-file (stream match-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "schema keyword" stream))
           (let ((session-run-grep-result (cl-cc.services:run-session-result
                                           "schema-session"
                                           :input (format nil "grep keyword :: ~A" (uiop:native-namestring directory-path)))))
             (expect-command-schema-valid "session run" session-run-grep-result)
             (is (search "tool:grep-tool result:schema.txt:1:schema keyword"
                         (getf (cl-cc.lib:result-payload session-run-grep-result) :result)))
             (is (cl-cc.services:session-run-result-conforms-p session-run-grep-result))))
      (when (probe-file match-file)
        (delete-file match-file))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore))))
  (let ((session-run-todo-result (cl-cc.services:run-session-result
                                  "schema-session"
                                  :input "todo write Implement todo tool | in_progress | Implementing todo tool ;; Run tests | pending | Running tests")))
    (expect-command-schema-valid "session run" session-run-todo-result)
    (is (equal (getf (cl-cc.lib:result-payload session-run-todo-result) :todo-list)
               '((:content "Implement todo tool" :status "in_progress" :active-form "Implementing todo tool")
                 (:content "Run tests" :status "pending" :active-form "Running tests"))))
    (is (cl-cc.services:session-run-result-conforms-p session-run-todo-result)))
  (let ((session-run-override-result (cl-cc.services:run-session-result "schema-session"
                                                                        :input "read file README.md"
                                                                        :tool-ids '("echo-tool"))))
    (expect-command-schema-valid "session run" session-run-override-result)
    (is (equal (getf (cl-cc.lib:result-payload session-run-override-result) :selected-tools)
               '("echo-tool")))
    (is (equal (getf (cl-cc.lib:result-payload session-run-override-result) :execution-plan)
               '((:tool "echo-tool" :input "read file README.md")))))
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
  (let ((invalid-session-list-type-result (cl-cc.lib:make-result
                                           :status :success
                                           :payload (list :session-directory "tmp/sessions"
                                                          :used-default-directory nil
                                                          :session-count "1"
                                                          :sessions nil
                                                          :duration-seconds 0.01d0
                                                          :exit-code 0)
                                           :message "invalid")))
    (expect-command-schema-error-containing "session list"
                                            invalid-session-list-type-result
                                            "payload.sessionCount: expected value of type INTEGER"))
  (let ((invalid-session-path-type-result (cl-cc.lib:make-result
                                           :status :success
                                           :payload (list :session-id "schema-session"
                                                          :history-index 3
                                                          :session-status :active
                                                          :session-path 42
                                                          :saved t
                                                          :duration-seconds 0.01d0
                                                          :exit-code 0)
                                           :message "invalid")))
    (expect-command-schema-error-containing "session start"
                                            invalid-session-path-type-result
                                            "payload.sessionPath: expected value of type STRING"))
  (let ((invalid-session-saved-type-result (cl-cc.lib:make-result
                                            :status :success
                                            :payload (list :session-id "schema-session"
                                                           :history-index 3
                                                           :session-status :active
                                                           :session-path "tmp/schema-session.session"
                                                           :saved "yes"
                                                           :duration-seconds 0.01d0
                                                           :exit-code 0)
                                            :message "invalid")))
    (expect-command-schema-error-containing "session start"
                                            invalid-session-saved-type-result
                                            "payload.saved: expected value of type BOOLEAN"))
  (let ((invalid-session-run-saved-type-result (cl-cc.lib:make-result
                                                :status :success
                                                :payload (list :session-id "schema-session"
                                                               :history-index 3
                                                               :session-status :active
                                                               :input "schema input"
                                                               :execution-status :success
                                                               :result "tool:echo-tool result:schema input"
                                                               :tool-results '((:tool "echo-tool"
                                                                                :status :success
                                                                                :duration-seconds 0.1d0
                                                                                :output (:result "schema input")
                                                                                :error nil
                                                                                :error-code nil))
                                                               :session-path "tmp/schema-session.session"
                                                               :saved "yes"
                                                               :duration-seconds 0.01d0
                                                               :exit-code 0)
                                                :message "invalid")))
    (expect-command-schema-error-containing "session run"
                                            invalid-session-run-saved-type-result
                                            "payload.saved: expected value of type BOOLEAN"))
  (let ((invalid-session-run-input-type-result (cl-cc.lib:make-result
                                                :status :success
                                                :payload (list :session-id "schema-session"
                                                               :history-index 3
                                                               :session-status :active
                                                               :input 42
                                                               :execution-status :success
                                                               :result "tool:echo-tool result:schema input"
                                                               :tool-results '((:tool "echo-tool"
                                                                                :status :success
                                                                                :duration-seconds 0.1d0
                                                                                :output (:result "schema input")
                                                                                :error nil
                                                                                :error-code nil))
                                                               :duration-seconds 0.01d0
                                                               :exit-code 0)
                                                :message "invalid")))
    (expect-command-schema-error-containing "session run"
                                            invalid-session-run-input-type-result
                                            "payload.input: expected value of type STRING"))
  (let ((invalid-session-run-execution-status-result (cl-cc.lib:make-result
                                                      :status :success
                                                      :payload (list :session-id "schema-session"
                                                                     :history-index 3
                                                                     :session-status :active
                                                                     :input "schema input"
                                                                     :execution-status :partial
                                                                     :result "tool:echo-tool result:schema input"
                                                                     :tool-results '((:tool "echo-tool"
                                                                                      :status :success
                                                                                      :duration-seconds 0.1d0
                                                                                      :output (:result "schema input")
                                                                                      :error nil
                                                                                      :error-code nil))
                                                                     :duration-seconds 0.01d0
                                                                     :exit-code 0)
                                                      :message "invalid")))
    (expect-command-schema-error-containing "session run"
                                            invalid-session-run-execution-status-result
                                            "payload.executionStatus: expected one of"))
  (let ((invalid-session-run-tool-results-result (cl-cc.lib:make-result
                                                  :status :success
                                                  :payload (list :session-id "schema-session"
                                                                 :history-index 3
                                                                 :session-status :active
                                                                 :input "schema input"
                                                                 :execution-status :success
                                                                 :result "tool:echo-tool result:schema input"
                                                                 :tool-results '()
                                                                 :duration-seconds 0.01d0
                                                                 :exit-code 0)
                                                  :message "invalid")))
    (expect-command-schema-error-containing "session run"
                                            invalid-session-run-tool-results-result
                                            "payload.toolResults: expected at least 1 item"))
  (let ((invalid-session-run-selected-tools-result (cl-cc.lib:make-result
                                                    :status :success
                                                    :payload (list :session-id "schema-session"
                                                                   :history-index 3
                                                                   :session-status :active
                                                                   :input "schema input"
                                                                   :execution-status :success
                                                                   :selected-tools #()
                                                                   :execution-plan '((:tool "echo-tool" :input "schema input"))
                                                                   :result "tool:echo-tool result:schema input"
                                                                   :tool-results '((:tool "echo-tool"
                                                                                    :status :success
                                                                                    :duration-seconds 0.1d0
                                                                                    :output (:result "schema input")
                                                                                    :error nil
                                                                                    :error-code nil))
                                                                   :duration-seconds 0.01d0
                                                                   :exit-code 0)
                                                    :message "invalid")))
    (expect-command-schema-error-containing "session run"
                                            invalid-session-run-selected-tools-result
                                            "payload.selectedTools: expected at least 1 item"))
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
