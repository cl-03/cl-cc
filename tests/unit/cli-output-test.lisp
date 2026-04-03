;;;; tests/unit/cli-output-test.lisp - CLI 输出单元测试
(in-package :cl-cc/tests)

(def-suite cli-output-test :in cl-cc-suite)

(in-suite cli-output-test)

(defun invoke-main-capturing-stderr (&rest argv)
  (let ((stderr nil)
        (exit-code nil))
    (setf stderr
          (with-output-to-string (stream)
            (let ((*error-output* stream))
              (setf exit-code (apply #'cl-cc:main argv)))))
    (values exit-code stderr)))

(test main-help-output
  (let ((output (capture-output (lambda () (cl-cc:main "--help")))))
    (is (search "Usage:" output))
    (is (search "chat [<session-id-or-path>] [--session-path <session-path>] [--session-id <session-id>] [--tool <tool-id>]" output))
    (is (search "docs sync-reference [<output-path>] [--check] [--output-format <output-format>]" output))
    (is (search "session start [--session-id <session-id>] [--session-path <session-path>] [--history-index <history-index>]" output))
    (is (search "run --fixture <fixture-id>... [--output-format <output-format>]" output))
    (is (search "aliases: cl-cc r --fixture" output))
    (is (search "options:" output))
    (is (search "--check" output))
    (is (search "--output-format <output-format>" output))
    (is (search "-i, --session-id <session-id>" output))
    (is (search "-o, --output-format <output-format>" output))
    (is (search "--pretty" output))
    (is (search "--compact" output))
    (is (search "-t, --tool <tool-id>" output))))

(test session-start-output
  (let ((output (capture-output (lambda () (cl-cc:handle-session-start)))))
    (is (search "新会话已创建" output))))

(test session-start-json-output
  (let ((output (capture-output (lambda () (cl-cc:handle-session-start "json-session" 2 "json")))))
    (is (search "\"status\":\"success\"" output))
    (is (search "\"sessionId\":\"json-session\"" output))
    (is (search "\"durationSeconds\":" output))
    (is (search "\"historyIndex\":2" output))))

(test session-start-save-output
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-start-output-test.session"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let ((output (capture-output (lambda () (cl-cc:handle-session-start "save-session" 4 "text" path)))))
           (is (search "新会话已创建: save-session" output))
           (is (search "历史索引: 4" output))
           (is (search "快照已保存:" output))
           (is (probe-file path)))
      (when (probe-file path)
        (delete-file path)))))

(test session-start-save-json-output
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-start-json-output-test.session"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let ((output (capture-output (lambda () (cl-cc:handle-session-start "saved-json-session" 2 "json" path)))))
           (is (search "\"status\":\"success\"" output))
           (is (search "\"sessionId\":\"saved-json-session\"" output))
           (is (search "\"sessionPath\":" output))
           (is (search "\"saved\":true" output))
           (is (probe-file path)))
      (when (probe-file path)
        (delete-file path)))))

(test session-resume-output
  (let ((output (capture-output (lambda () (cl-cc:handle-session-resume "resume-user")))))
    (is (search "会话已恢复: resume-user" output))))

(test session-resume-json-output
  (let ((output (capture-output (lambda () (cl-cc:handle-session-resume "resume-user" "json")))))
    (is (search "\"status\":\"success\"" output))
    (is (search "\"sessionId\":\"resume-user\"" output))
    (is (search "\"durationSeconds\":" output))
    (is (search "\"historyIndex\":null" output))))

(test session-run-json-output
  (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user" "hello json" "json")))))
    (is (search "\"status\":\"success\"" output))
    (is (search "\"sessionId\":\"resume-user\"" output))
    (is (search "\"input\":\"hello json\"" output))
    (is (search "\"executionStatus\":\"success\"" output))
    (is (search "\"selectedTools\":[\"echo-tool\",\"failing-tool\"]" output))
    (is (search "\"executionPlan\":[{\"tool\":\"echo-tool\",\"input\":\"hello json\"},{\"tool\":\"failing-tool\",\"input\":\"hello json\"}]" output))
    (is (search "\"result\":\"tool:echo-tool result:hello json\"" output))
    (is (search "\"toolResults\":[{\"toolId\":\"echo-tool\"" output))
    (is (search "\"durationSeconds\":" output))
    (is (search "\"historyIndex\":1" output))))

(test session-run-json-output-can-render-file-read-tool-result
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-run-json-file-read.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "json-file-ok" stream))
           (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user" path "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"executionStatus\":\"success\"" output))
             (is (search "\"result\":\"tool:file-read-tool result:json-file-ok\"" output))
             (is (search "\"toolResults\":[{\"toolId\":\"file-read-tool\"" output))
             (is (search "\"output\":{\"result\":\"json-file-ok\"}" output))))
      (when (probe-file path)
        (delete-file path)))))

(test session-run-json-output-can-render-file-read-line-range-result
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-run-json-file-read-range.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%beta~%gamma") stream))
           (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                               (format nil "read file ~A :: 2-3" path)
                                                                               "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"executionStatus\":\"success\"" output))
             (is (search "\"result\":\"tool:file-read-tool result:2:beta\\n3:gamma\"" output))
             (is (search "\"toolResults\":[{\"toolId\":\"file-read-tool\"" output))
             (is (search "\"output\":{\"result\":\"2:beta\\n3:gamma\"}" output))))
      (when (probe-file path)
        (delete-file path)))))

(test session-run-json-output-can-render-directory-list-tool-result
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "session-run-json-directory-list/"
                                                 (uiop:temporary-directory))))
         (file-a (merge-pathnames "b.txt" directory-path))
         (file-b (merge-pathnames "a.txt" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist directory-path)
           (with-open-file (stream file-a :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "b" stream))
           (with-open-file (stream file-b :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "a" stream))
           (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                               (format nil "list directory ~A" (uiop:native-namestring directory-path))
                                                                               "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"executionStatus\":\"success\"" output))
             (is (search "\"result\":\"tool:directory-list-tool result:a.txt\\nb.txt\"" output))
             (is (search "\"toolResults\":[{\"toolId\":\"directory-list-tool\"" output))
             (is (search "\"output\":{\"result\":\"a.txt\\nb.txt\"}" output))))
      (when (probe-file file-a)
        (delete-file file-a))
      (when (probe-file file-b)
        (delete-file file-b))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test session-run-json-output-can-render-grep-tool-result
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "session-run-json-grep/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "main.lisp" directory-path))
         (nested-directory (merge-pathnames "src/" directory-path))
         (nested-file (merge-pathnames "src/helper.lisp" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested-directory)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "needle root" stream))
           (with-open-file (stream nested-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "needle nested" stream))
           (let* ((result-text (format nil "main.lisp:1:needle root~%src/helper.lisp:1:needle nested"))
                  (output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                              (format nil "grep needle :: ~A"
                                                                                      (uiop:native-namestring directory-path))
                                                                              "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"executionStatus\":\"success\"" output))
             (is (search (format nil "\"result\":~A"
                                 (cl-cc::%cli-json-string (format nil "tool:grep-tool result:~A" result-text)))
                         output))
             (is (search "\"toolResults\":[{\"toolId\":\"grep-tool\"" output))
             (is (search (format nil "\"output\":{\"result\":~A}"
                                 (cl-cc::%cli-json-string result-text))
                         output))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file nested-file)
        (delete-file nested-file))
      (when (probe-file nested-directory)
        (uiop:delete-directory-tree nested-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test session-run-json-output-can-render-file-write-tool-result
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-run-json-file-write.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let* ((result-text (format nil "写入文件: ~A" path))
                (output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                             (format nil "write file ~A :: json-write-ok" path)
                                                                             "json")))))
           (is (search "\"status\":\"success\"" output))
           (is (search "\"executionStatus\":\"success\"" output))
           (is (search (format nil "\"result\":~A"
                               (cl-cc::%cli-json-string (format nil "tool:file-write-tool result:~A" result-text)))
                       output))
           (is (search "\"toolResults\":[{\"toolId\":\"file-write-tool\"" output))
           (is (search (format nil "\"output\":{\"result\":~A}"
                               (cl-cc::%cli-json-string result-text))
                       output))
           (is (string= (uiop:read-file-string path) " json-write-ok")))
      (when (probe-file path)
        (delete-file path)))))

(test session-run-json-output-can-render-file-edit-tool-result
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-run-json-file-edit.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before token after" stream))
           (let* ((result-text (format nil "编辑文件: ~A" path))
                  (output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                               (format nil "edit file ~A :: token :: value" path)
                                                                               "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"executionStatus\":\"success\"" output))
             (is (search (format nil "\"result\":~A"
                                 (cl-cc::%cli-json-string (format nil "tool:file-edit-tool result:~A" result-text)))
                         output))
             (is (search "\"toolResults\":[{\"toolId\":\"file-edit-tool\"" output))
                 (is (search (format nil "\"output\":{\"result\":~A"
                                 (cl-cc::%cli-json-string result-text))
                         output))
             (is (search "\"path\":" output))
             (is (search "\"preview\":null" output))
             (is (search "\"totalMatches\":1" output))
             (is (search "\"selectedOccurrence\":1" output))
             (is (search "\"matchStartLine\":1" output))
             (is (search "\"matchStartColumn\":7" output))
             (is (search "\"matchEndLine\":1" output))
             (is (search "\"matchEndColumn\":13" output))
             (is (search "\"diffPreview\":" output))
             (is (search "\"lineDiffPreview\":" output))
             (is (search "\"writeApplied\":true" output))
             (is (string= (uiop:read-file-string path) "before value after"))))
      (when (probe-file path)
        (delete-file path)))))

(test session-run-json-output-can-render-file-edit-tool-preview-result
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-run-json-file-edit-preview.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before preview after" stream))
           (let* ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                                (format nil "preview edit file ~A :: preview :: value" path)
                                                                                "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"toolResults\":[{\"toolId\":\"file-edit-tool\"" output))
             (is (search "预览编辑文件:" output))
             (is (search "\"preview\":true" output))
             (is (search "\"matchCount\":1" output))
             (is (search "\"totalMatches\":1" output))
             (is (search "\"selectedOccurrence\":1" output))
             (is (search "\"matchStartLine\":1" output))
             (is (search "\"matchStartColumn\":7" output))
             (is (search "\"matchEndLine\":1" output))
             (is (search "\"matchEndColumn\":15" output))
             (is (search "\"beforePreview\":" output))
             (is (search "\"afterPreview\":" output))
             (is (search "\"diffPreview\":" output))
             (is (search "\"lineDiffPreview\":" output))
             (is (search "\"writeApplied\":null" output))
             (is (string= (uiop:read-file-string path) "before preview after"))))
      (when (probe-file path)
        (delete-file path)))))

(test session-run-json-output-can-render-file-edit-tool-selected-occurrence
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-run-json-file-edit-occurrence.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "start dup middle dup tail" stream))
           (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                                (format nil "edit file ~A :: dup :: value :: 2" path)
                                                                                "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "第 2/2 处命中" output))
             (is (search "\"totalMatches\":2" output))
             (is (search "\"selectedOccurrence\":2" output))
             (is (search "\"matchStartLine\":1" output))
             (is (search "\"matchStartColumn\":17" output))
             (is (search "\"matchEndLine\":1" output))
             (is (search "\"matchEndColumn\":21" output))
             (is (search "\"diffPreview\":" output))
             (is (search "\"lineDiffPreview\":" output))
             (is (string= (uiop:read-file-string path) "start dup middle value  tail"))))
      (when (probe-file path)
        (delete-file path)))))

(test tool-result-json-rendering-remains-stable
  (let ((record '(:tool "failing-tool"
                  :status :failed
                  :duration-seconds 0.25d0
                  :output (:error "工具执行失败" :code "FAIL")
                  :error "工具执行失败"
                  :error-code :fail)))
    (is (string= (cl-cc::%cli-render-tool-result-json record)
                 "{\"toolId\":\"failing-tool\",\"status\":\"failed\",\"durationSeconds\":0.25,\"output\":{\"error\":\"工具执行失败\",\"code\":\"FAIL\"},\"error\":\"工具执行失败\",\"errorCode\":\"FAIL\"}"))
    (is (string= (cl-cc::%cli-render-tool-result-pretty-json record)
                 (format nil
                         "{~%  \"toolId\": \"failing-tool\",~%  \"status\": \"failed\",~%  \"durationSeconds\": 0.25,~%  \"output\": {\"error\":\"工具执行失败\",\"code\":\"FAIL\"},~%  \"error\": \"工具执行失败\",~%  \"errorCode\": \"FAIL\"~%}")))))

(test result-record-json-rendering-remains-stable
  (let ((record '(:fixture-id "test"
                  :status :success
                  :duration-seconds 1.0d0
                  :result "tool:echo-tool result:fixture-input-test"
                  :tool-results ((:tool "echo-tool"
                                  :status :success
                                  :duration-seconds 0.5d0
                                  :output (:result "fixture-input-test")
                                  :error nil
                                  :error-code nil)))))
    (is (string= (cl-cc::%cli-render-result-record-json record)
                 "{\"fixtureId\":\"test\",\"status\":\"success\",\"durationSeconds\":1.0,\"result\":\"tool:echo-tool result:fixture-input-test\",\"toolResults\":[{\"toolId\":\"echo-tool\",\"status\":\"success\",\"durationSeconds\":0.5,\"output\":{\"result\":\"fixture-input-test\"},\"error\":null,\"errorCode\":null}]}"))
    (is (string= (cl-cc::%cli-render-result-record-pretty-json record)
                 (format nil
                         "{~%  \"fixtureId\": \"test\",~%  \"status\": \"success\",~%  \"durationSeconds\": 1.0,~%  \"result\": \"tool:echo-tool result:fixture-input-test\",~%  \"toolResults\": [~%    {~%      \"toolId\": \"echo-tool\",~%      \"status\": \"success\",~%      \"durationSeconds\": 0.5,~%      \"output\": {\"result\":\"fixture-input-test\"},~%      \"error\": null,~%      \"errorCode\": null~%    }~%  ]~%}")))))

(test docs-sync-json-rendering-remains-stable
  (let ((result-object (cl-cc.lib:make-result
                        :status :synced
                        :payload '(:path "README.md"
                                  :check-only nil
                                  :updated t
                                  :needs-sync nil
                                  :duration-seconds 0.125d0
                                  :exit-code 0)
                        :message "ignored")))
                    (is (string= (cl-cc::render-docs-sync-result result-object)
                 "{\"path\":\"README.md\",\"status\":\"synced\",\"checkOnly\":false,\"updated\":true,\"needsSync\":false,\"durationSeconds\":0.125,\"exitCode\":0}"))))

(test session-command-json-rendering-remains-stable
  (let ((result-object (cl-cc.lib:make-result
                        :status :success
                        :payload '(:session-id "saved-json-session"
                                  :history-index 2
                                  :session-status :active
                                  :input "hello json"
              :execution-status :success
              :selected-tools ("echo-tool")
              :execution-plan ((:tool "echo-tool" :input "hello json"))
              :result "tool:echo-tool result:hello json"
              :tool-results ((:tool "echo-tool"
                  :status :success
                  :duration-seconds 0.5d0
                  :output (:result "hello json")
                  :error nil
                  :error-code nil))
                                  :session-path "saved.session"
                                  :saved t
                                  :duration-seconds 0.25d0
                                  :exit-code 0)
                        :message "ignored")))
                    (is (string= (cl-cc::render-session-command-result result-object :output-format "json")
           "{\"status\":\"success\",\"sessionId\":\"saved-json-session\",\"historyIndex\":2,\"sessionStatus\":\"active\",\"input\":\"hello json\",\"executionStatus\":\"success\",\"selectedTools\":[\"echo-tool\"],\"executionPlan\":[{\"tool\":\"echo-tool\",\"input\":\"hello json\"}],\"result\":\"tool:echo-tool result:hello json\",\"toolResults\":[{\"toolId\":\"echo-tool\",\"status\":\"success\",\"durationSeconds\":0.5,\"output\":{\"result\":\"hello json\"},\"error\":null,\"errorCode\":null}],\"sessionPath\":\"saved.session\",\"saved\":true,\"durationSeconds\":0.25,\"exitCode\":0}"))))

(test run-fixture-json-rendering-remains-stable
  (let ((result-object (cl-cc.lib:make-result
                        :status :success
                        :payload '(:fixture-count 1
                                  :successful-count 1
                                  :failed-count 0
                                  :duration-seconds 1.5d0
                                  :status-counts (("success" . 1) ("failed" . 0))
                                  :ok t
                                  :exit-code 0
                                  :results ((:fixture-id "test"
                                             :status :success
                                             :duration-seconds 1.0d0
                                             :result "tool:echo-tool result:fixture-input-test"
                                             :tool-results ((:tool "echo-tool"
                                                             :status :success
                                                             :duration-seconds 0.5d0
                                                             :output (:result "fixture-input-test")
                                                             :error nil
                                                             :error-code nil)))))
                        :message "ignored")))
                        (is (string= (cl-cc::render-run-fixture-result result-object)
                 "{\"status\":\"success\",\"fixtureCount\":1,\"successfulCount\":1,\"failedCount\":0,\"durationSeconds\":1.5,\"statusCounts\":{\"success\":1,\"failed\":0},\"ok\":true,\"exitCode\":0,\"results\":[{\"fixtureId\":\"test\",\"status\":\"success\",\"durationSeconds\":1.0,\"result\":\"tool:echo-tool result:fixture-input-test\",\"toolResults\":[{\"toolId\":\"echo-tool\",\"status\":\"success\",\"durationSeconds\":0.5,\"output\":{\"result\":\"fixture-input-test\"},\"error\":null,\"errorCode\":null}]}]}"))))

(test status-counts-json-rendering-remains-stable
  (let ((status-counts '(("success" . 1) ("failed" . 0) ("denied" . 2))))
    (is (string= (cl-cc::%cli-render-status-counts-json status-counts)
                 "{\"success\":1,\"failed\":0,\"denied\":2}"))
    (is (string= (cl-cc::%cli-render-status-counts-pretty-json status-counts)
                 (format nil
                         "{~%    \"success\": 1,~%    \"failed\": 0,~%    \"denied\": 2~%  }")))))

(test plist-json-rendering-remains-stable
  (is (string= (cl-cc::%cli-render-plist-json '(:result "fixture-input-test"
                                               :meta (:attempt 1 :ok t)
                                               :error nil))
               "{\"result\":\"fixture-input-test\",\"meta\":{\"attempt\":1,\"ok\":true},\"error\":null}")))

(test json-string-literal-helpers-preserve-escaping-and-null-semantics
  (is (string= (cl-cc::%cli-json-null)
               "null"))
  (is (string= (cl-cc::%cli-json-string (format nil "a~%b\"c"))
                (coerce (list #\"
                              #\a
                              #\\
                              #\n
                              #\b
                              #\\
                              #\"
                              #\c
                              #\")
                        'string)))
  (is (string= (cl-cc::%cli-json-string-or-null nil)
               "null"))
  (is (string= (cl-cc::%cli-json-string-or-null "ok")
               "\"ok\""))
  (is (string= (cl-cc::%cli-json-value :permission-denied)
               "\"permission-denied\"")))

(test json-field-collection-helper-preserves-order-and-spacing
  (is (equal (cl-cc::%cli-render-json-fields '(("a" "1") ("b" "2")))
             '("\"a\":1" "\"b\":2")))
  (is (equal (cl-cc::%cli-render-json-fields '(("a" "1") ("b" "2")) :spaced t)
             '("\"a\": 1" "\"b\": 2"))))

(test cli-error-log-message-rendering
  (let ((condition (make-condition 'cl-cc.lib:cl-cc-error
                                   :code "INVALID-ARGUMENTS"
                                   :message "Invalid arguments for command run --fixture")))
    (is (string= (cl-cc::%cli-error-log-message condition)
                 "[ERROR] INVALID-ARGUMENTS: Invalid arguments for command run --fixture"))))

(test cli-unhandled-error-log-message-rendering
  (is (string= (cl-cc::%cli-unhandled-error-log-message (make-condition 'simple-error :format-control "boom"))
               "[UNHANDLED ERROR] boom")))

(test main-logs-expected-errors-to-stderr
  (multiple-value-bind (exit-code stderr)
      (invoke-main-capturing-stderr "run" "--fixture")
    (is (= exit-code 1))
    (is (search "[DEBUG] [ERROR] INVALID-ARGUMENTS:" stderr))))

(test main-logs-unhandled-errors-to-stderr
  (let ((original-dispatch (symbol-function 'cl-cc.core:dispatch-command)))
    (unwind-protect
         (progn
           (setf (symbol-function 'cl-cc.core:dispatch-command)
                 (lambda (argv)
                   (declare (ignore argv))
                   (error "boom")))
           (multiple-value-bind (exit-code stderr)
               (invoke-main-capturing-stderr "--help")
             (is (= exit-code 2))
             (is (search "[DEBUG] [UNHANDLED ERROR] boom" stderr))))
      (setf (symbol-function 'cl-cc.core:dispatch-command)
            original-dispatch))))