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

(defun %session-tool-result-json-section (output tool-id)
  (let ((marker (format nil "\"toolId\":~A" (cl-cc::%cli-json-string tool-id))))
    (or (let ((start (search marker output)))
          (and start (subseq output start)))
        output)))

(test main-help-output
  (let ((output (capture-output (lambda () (cl-cc:main "--help")))))
    (is (search "Usage:" output))
    (is (search "元信息命令:" output))
    (is (search "交互命令:" output))
    (is (search "会话命令:" output))
    (is (search "自动化命令:" output))
    (is (search "文档命令:" output))
    (is (search "help [--auth-scope <auth-scope>] [--group-scope <group-scope>]" output))
    (is (search "chat [<session-id-or-path>] [--session-path <session-path>] [--session-id <session-id>] [--tool <tool-id>]" output))
    (is (search "metadata: group=meta; source=builtin" output))
    (is (search "metadata: group=chat; source=builtin; requires-auth" output))
    (is (search "docs sync-reference [<output-path>] [--check] [--auth-scope <auth-scope>] [--group-scope <group-scope>] [--output-format <output-format>]" output))
    (is (search "metadata: group=docs; source=builtin" output))
    (is (search "session list [--session-dir <session-dir>] [--output-format <output-format>]" output))
    (is (search "session start [--session-id <session-id>] [--session-path <session-path>] [--history-index <history-index>]" output))
    (is (search "run --fixture <fixture-id>... [--output-format <output-format>]" output))
    (is (search "metadata: group=automation; source=builtin; requires-auth" output))
    (is (search "metadata: group=session; source=builtin; requires-auth" output))
    (is (search "aliases: cl-cc r --fixture" output))
    (is (search "options:" output))
    (is (search "--auth-scope <auth-scope>" output))
    (is (search "--group-scope <group-scope>" output))
    (is (search "--check" output))
    (is (search "--output-format <output-format>" output))
    (is (search "-i, --session-id <session-id>" output))
    (is (search "-o, --output-format <output-format>" output))
    (is (search "--pretty" output))
    (is (search "--compact" output))
    (is (search "-t, --tool <tool-id>" output))))

(test main-help-output-can-filter-session-group
  (let ((output (capture-output (lambda () (cl-cc:main "help" "--group-scope" "session")))))
    (is (search "会话命令:" output))
    (is (not (search "元信息命令:" output)))
    (is (not (search "交互命令:" output)))
    (is (not (search "文档命令:" output)))
    (is (search "cl-cc session start" output))
    (is (search "cl-cc session list" output))
    (is (search "cl-cc session resume" output))
    (is (search "cl-cc session run" output))
    (is (not (search "cl-cc help" output)))))

(test docs-sync-json-output-contract-remains-valid-with-group-scope-filter
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "generated-reference-group-json-test.md"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "before~%<!-- BEGIN GENERATED COMMAND REFERENCE -->~%old~%<!-- END GENERATED COMMAND REFERENCE -->~%after~%")
                           stream))
           (let ((output (capture-output (lambda () (cl-cc:main "docs" "sync" path "--group-scope" "session" "--output-format" "json")))))
             (is (search "\"status\":\"synced\"" output))
             (is (search "\"checkOnly\":false" output))
             (is (search "\"updated\":true" output))
             (is (search "\"needsSync\":false" output))))
      (when (probe-file path)
        (delete-file path)))))

(test docs-sync-json-output-contract-remains-valid-with-auth-scope-filter
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "generated-reference-public-json-test.md"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "before~%<!-- BEGIN GENERATED COMMAND REFERENCE -->~%old~%<!-- END GENERATED COMMAND REFERENCE -->~%after~%")
                           stream))
           (let ((output (capture-output (lambda () (cl-cc:main "docs" "sync" path "--auth-scope" "public" "--output-format" "json")))))
             (is (search "\"status\":\"synced\"" output))
             (is (search "\"checkOnly\":false" output))
             (is (search "\"updated\":true" output))
             (is (search "\"needsSync\":false" output))))
      (when (probe-file path)
        (delete-file path)))))

(test main-help-output-can-filter-public-commands
  (let ((output (capture-output (lambda () (cl-cc:main "help" "--auth-scope" "public")))))
    (is (search "元信息命令:" output))
    (is (search "会话命令:" output))
    (is (search "文档命令:" output))
    (is (not (search "交互命令:" output)))
    (is (not (search "自动化命令:" output)))
    (is (search "cl-cc help [--auth-scope <auth-scope>] [--group-scope <group-scope>]" output))
    (is (search "cl-cc docs sync-reference" output))
    (is (search "cl-cc session list" output))
    (is (not (search "cl-cc chat" output)))
    (is (not (search "cl-cc run --fixture" output)))))

(test main-help-output-can-filter-requires-auth-commands-through-help-alias
  (let ((output (capture-output (lambda () (cl-cc:main "--help" "--auth-scope" "requires-auth")))))
    (is (search "交互命令:" output))
    (is (search "会话命令:" output))
    (is (search "自动化命令:" output))
    (is (not (search "元信息命令:" output)))
    (is (not (search "文档命令:" output)))
    (is (search "cl-cc chat" output))
    (is (search "cl-cc session run" output))
    (is (search "cl-cc run --fixture" output))
    (is (not (search "cl-cc help [--auth-scope <auth-scope>] [--group-scope <group-scope>]" output)))
    (is (not (search "cl-cc docs sync-reference" output)))))

(test session-start-output
  (let ((output (capture-output (lambda () (cl-cc:handle-session-start)))))
    (is (search "新会话已创建" output))))

(test session-list-output
  (let* ((directory (uiop:ensure-directory-pathname
                     (uiop:merge-pathnames* "cli-output-session-list-test/"
                                            (uiop:temporary-directory))))
         (path (uiop:native-namestring (merge-pathnames "listed.session" directory))))
    (unwind-protect
         (progn
           (ensure-directories-exist directory)
           (is (cl-cc.session:save-session
                (make-instance 'cl-cc.models:session-state
                               :session-id "cli-listed"
                               :created-at "2026-04-05T04:00:00Z"
                               :updated-at "2026-04-05T04:05:00Z"
                               :history-index 5
                               :context-summary '(:input "cli input" :result "cli result")
                               :tasks nil
                               :permission-snapshot path
                               :status :active
                               :version "0.1")
                path))
           (let ((output (capture-output (lambda () (cl-cc:handle-session-list (uiop:native-namestring directory) "text")))))
             (is (search "会话数量: 1" output))
             (is (search "cli-listed" output))
             (is (search "listed.session" output))))
      (when (probe-file directory)
        (uiop:delete-directory-tree directory :validate t :if-does-not-exist :ignore)))))

(test session-list-json-output
  (let* ((directory (uiop:ensure-directory-pathname
                     (uiop:merge-pathnames* "cli-output-session-list-json-test/"
                                            (uiop:temporary-directory))))
         (path (uiop:native-namestring (merge-pathnames "listed-json.session" directory))))
    (unwind-protect
         (progn
           (ensure-directories-exist directory)
           (is (cl-cc.session:save-session
                (make-instance 'cl-cc.models:session-state
                               :session-id "cli-listed-json"
                               :created-at "2026-04-05T04:10:00Z"
                               :updated-at "2026-04-05T04:15:00Z"
                               :history-index nil
                               :context-summary '(:input "json input" :result "json result")
                               :tasks '((:task-id "shell-task-11"))
                               :permission-snapshot path
                               :status :active
                               :version "0.1")
                path))
           (let ((output (capture-output (lambda () (cl-cc:handle-session-list (uiop:native-namestring directory) "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"sessionDirectory\":" output))
             (is (search "\"usedDefaultDirectory\":false" output))
             (is (search "\"sessionCount\":1" output))
             (is (search "\"sessionId\":\"cli-listed-json\"" output))
             (is (search "\"taskCount\":1" output))
             (is (search "\"lastInput\":\"json input\"" output))
             (is (search "\"lastResult\":\"json result\"" output))))
      (when (probe-file directory)
        (uiop:delete-directory-tree directory :validate t :if-does-not-exist :ignore)))))

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
  (let ((cl-cc.lib::*git-command-runner*
          (lambda (arguments &key directory)
            (declare (ignore directory))
            (cond
                ((equal arguments '("rev-parse" "--show-toplevel")) "D:/VSCode/cl-cc/cl-cc")
              ((equal arguments '("branch" "--show-current")) "main")
              ((equal arguments '("status" "--short")) "M src/core/session-loop.lisp")
              ((equal arguments '("log" "--oneline" "-5")) "abc1234 add git context")
              (t nil)))))
    (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user" "hello json" "json")))))
      (is (search "\"status\":\"success\"" output))
      (is (search "\"sessionId\":\"resume-user\"" output))
      (is (search "\"input\":\"hello json\"" output))
      (is (search "\"executionStatus\":\"success\"" output))
      (is (search "\"selectedTools\":[\"echo-tool\",\"failing-tool\"]" output))
      (is (search "\"executionPlan\":[{\"tool\":\"echo-tool\",\"input\":\"hello json\"},{\"tool\":\"failing-tool\",\"input\":\"hello json\"}]" output))
      (is (search "\"gitRoot\":\"D:/VSCode/cl-cc/cl-cc\"" output))
      (is (search "\"gitBranch\":\"main\"" output))
      (is (search "\"gitDirty\":true" output))
      (is (search "\"gitStatusLines\":[\"M src/core/session-loop.lisp\"]" output))
      (is (search "\"gitRecentCommits\":[\"abc1234 add git context\"]" output))
      (is (search "\"result\":\"tool:echo-tool result:hello json\"" output))
      (is (search "\"toolResults\":[{\"toolId\":\"echo-tool\"" output))
      (is (search "\"durationSeconds\":" output))
      (is (search "\"historyIndex\":1" output)))))

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

(test session-run-json-output-can-render-recursive-directory-list-tool-result
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "session-run-json-directory-list-recursive/"
                                                 (uiop:temporary-directory))))
         (child-directory (merge-pathnames "child/" directory-path))
         (root-file (merge-pathnames "a.txt" directory-path))
         (child-file (merge-pathnames "note.txt" child-directory)))
    (unwind-protect
         (progn
           (ensure-directories-exist child-directory)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "a" stream))
           (with-open-file (stream child-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "note" stream))
           (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                               (format nil "list directory ~A :: recursive"
                                                                                       (uiop:native-namestring directory-path))
                                                                               "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"executionStatus\":\"success\"" output))
             (is (search "\"result\":\"tool:directory-list-tool result:a.txt\\nchild/\\nchild/note.txt\"" output))
             (is (search "\"toolResults\":[{\"toolId\":\"directory-list-tool\"" output))
             (is (search "\"output\":{\"result\":\"a.txt\\nchild/\\nchild/note.txt\"}" output))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file child-file)
        (delete-file child-file))
      (when (probe-file child-directory)
        (uiop:delete-directory-tree child-directory :validate t :if-does-not-exist :ignore))
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

(test session-run-json-output-can-render-shell-tool-result
  (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                     "run shell [Console]::Out.Write('json-shell-ok')"
                                                                     "json")))))
    (is (search "\"status\":\"success\"" output))
    (is (search "\"executionStatus\":\"success\"" output))
    (is (search "\"selectedTools\":[\"shell-tool\",\"echo-tool\",\"failing-tool\"]" output))
    (is (search "\"toolResults\":[{\"toolId\":\"shell-tool\"" output))
    (is (search "\"background\":false" output))
    (is (search "\"stdout\":\"json-shell-ok\"" output))
    (is (search "\"stderr\":\"\"" output))
    (is (search "\"exitCode\":0" output))
    (is (search "\"timedOut\":false" output))))

(test session-run-json-output-can-render-background-shell-tool-result
  (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                     "background shell [Console]::Out.Write('json-shell-bg-ok')"
                                                                     "json")))))
    (is (search "\"status\":\"success\"" output))
    (is (search "\"executionStatus\":\"success\"" output))
    (is (search "\"toolResults\":[{\"toolId\":\"shell-tool\"" output))
    (is (search "\"background\":true" output))
    (is (search "\"backgroundTaskId\":\"shell-task-" output))
    (is (search "\"outputPath\":" output))
    (is (search "\"stdout\":null" output))
    (is (search "\"stderr\":null" output))
    (is (search "\"exitCode\":null" output))
    (is (search "\"timedOut\":false" output))))

(test session-run-json-output-can-render-shell-task-list-tool-result
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (running-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('json-shell-task-list-running')"
                                                       :directory directory
                                                       :background t)))
         (completed-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('json-shell-task-list-completed')"
                                                         :directory directory
                                                         :background t)))
         (interrupted-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('json-shell-task-list-interrupt')"
                                                           :directory directory
                                                           :background t)))
         (running-task-id (getf running-result :background-task-id))
         (completed-task-id (getf completed-result :background-task-id))
         (interrupted-task-id (getf interrupted-result :background-task-id))
         (running-output-path (getf running-result :output-path))
         (completed-output-path (getf completed-result :output-path))
         (interrupted-output-path (getf interrupted-result :output-path)))
    (unwind-protect
         (progn
           (sleep 0.4)
           (cl-cc.tools:shell-task-tool (list :task-id interrupted-task-id :action :interrupt))
           (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                              "shell task list"
                                                                              "json")))))
             (let ((tool-output (%session-tool-result-json-section output "shell-task-list-tool")))
               (is (search "\"status\":\"success\"" output))
               (is (search "\"executionStatus\":\"success\"" output))
               (is (search "\"selectedTools\":[\"shell-task-list-tool\",\"shell-task-tool\",\"file-read-tool\",\"echo-tool\",\"failing-tool\"]" output))
               (is (search "\"toolResults\":[{\"toolId\":\"shell-task-list-tool\"" output))
               (is (search "\"statusFilter\":\"all\"" tool-output))
               (is (search "\"taskIdPrefixFilter\":null" tool-output))
               (is (search "\"directoryContainsFilter\":null" tool-output))
               (is (search "\"terminationReasonFilter\":null" tool-output))
               (is (search "\"totalCount\":" tool-output))
               (is (search "\"runningCount\":" tool-output))
               (is (search "\"completedCount\":" tool-output))
               (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string running-task-id)) tool-output))
               (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string completed-task-id)) tool-output))
               (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string interrupted-task-id)) tool-output))
               (is (search "\"stallDetected\":false" tool-output))
               (is (search "\"stallDetectedAt\":null" tool-output))
               (is (search "\"stallPromptLine\":null" tool-output))
               (is (search "\"terminationReason\":\"exit\"" tool-output))
               (is (search "\"terminationReason\":\"interrupt\"" tool-output))
               (is (search "\"endedAt\":" tool-output))))
           (let ((filtered-output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                                         (format nil "shell task list :: status=running :: task=~A" running-task-id)
                                                                                         "json")))))
             (let ((filtered-tool-output (%session-tool-result-json-section filtered-output "shell-task-list-tool")))
               (is (search "\"statusFilter\":\"running\"" filtered-tool-output))
               (is (search (format nil "\"taskIdPrefixFilter\":~A" (cl-cc::%cli-json-string running-task-id)) filtered-tool-output))
               (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string running-task-id)) filtered-tool-output))
               (is (not (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string completed-task-id)) filtered-tool-output))))
             (is (search "\"selectedTools\":[\"shell-task-list-tool\",\"shell-task-tool\",\"file-read-tool\",\"echo-tool\",\"failing-tool\"]" filtered-output)))
           (let ((termination-output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                                            "shell task list :: termination=interrupt"
                                                                                            "json")))))
             (let ((termination-tool-output (%session-tool-result-json-section termination-output "shell-task-list-tool")))
               (is (search "\"terminationReasonFilter\":\"interrupt\"" termination-tool-output))
               (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string interrupted-task-id)) termination-tool-output))
               (is (not (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string completed-task-id)) termination-tool-output))))))
      (when running-task-id
        (remhash running-task-id cl-cc.tools::*shell-background-task-registry*))
      (when completed-task-id
        (remhash completed-task-id cl-cc.tools::*shell-background-task-registry*))
      (when interrupted-task-id
        (remhash interrupted-task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and running-output-path (probe-file running-output-path))
        (ignore-errors (delete-file running-output-path)))
      (when (and completed-output-path (probe-file completed-output-path))
        (ignore-errors (delete-file completed-output-path)))
      (when (and interrupted-output-path (probe-file interrupted-output-path))
        (ignore-errors (delete-file interrupted-output-path))))))

(test session-run-json-output-can-render-shell-task-cleanup-tool-result
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (running-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('json-shell-task-cleanup-running')"
                                                         :directory directory
                                                         :background t)))
           (completed-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('json-shell-task-cleanup-completed')"
                                                           :directory directory
                                                           :background t)))
           (interrupted-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('json-shell-task-cleanup-interrupted')"
                                                             :directory directory
                                                             :background t)))
           (running-task-id (getf running-result :background-task-id))
           (completed-task-id (getf completed-result :background-task-id))
           (interrupted-task-id (getf interrupted-result :background-task-id))
           (running-output-path (getf running-result :output-path))
           (completed-output-path (getf completed-result :output-path))
           (interrupted-output-path (getf interrupted-result :output-path))
           (fresh-interrupted-task-id nil)
           (fresh-interrupted-output-path nil))
      (unwind-protect
           (progn
             (sleep 0.4)
             (cl-cc.tools:shell-task-tool (list :task-id interrupted-task-id :action :interrupt))
             (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                                "cleanup shell tasks"
                                                                                "json")))))
               (is (search "\"status\":\"success\"" output))
               (is (search "\"executionStatus\":\"success\"" output))
               (is (search "\"selectedTools\":[\"shell-task-cleanup-tool\",\"shell-task-list-tool\",\"shell-task-tool\",\"file-read-tool\",\"echo-tool\",\"failing-tool\"]" output))
               (is (search "\"toolResults\":[{\"toolId\":\"shell-task-cleanup-tool\"" output))
               (is (search "\"statusFilter\":\"all\"" output))
               (is (search "\"terminationReasonFilter\":null" output))
               (is (search "\"removedCount\":2" output))
               (is (search "\"remainingCount\":1" output))
               (is (not (probe-file completed-output-path)))
               (is (not (probe-file interrupted-output-path)))
               (is (probe-file running-output-path))
               (is (not (null (gethash running-task-id cl-cc.tools::*shell-background-task-registry*)))))
             (let* ((fresh-interrupted-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('json-shell-task-cleanup-interrupted-fresh')"
                                                                            :directory directory
                                                                            :background t))))
               (setf fresh-interrupted-task-id (getf fresh-interrupted-result :background-task-id)
                     fresh-interrupted-output-path (getf fresh-interrupted-result :output-path))
               (sleep 0.2)
               (cl-cc.tools:shell-task-tool (list :task-id fresh-interrupted-task-id :action :interrupt))
               (let ((termination-output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                                                 "cleanup shell tasks :: termination=interrupt"
                                                                                                 "json")))))
                 (is (search "\"terminationReasonFilter\":\"interrupt\"" termination-output))
                 (is (search (format nil "\"removedTaskIds\":[~A]" (cl-cc::%cli-json-string fresh-interrupted-task-id)) termination-output))
                 (is (not (search (format nil "\"removedTaskIds\":[~A]" (cl-cc::%cli-json-string completed-task-id)) termination-output))))))
        (when running-task-id
          (ignore-errors (cl-cc.tools:shell-task-tool (list :task-id running-task-id :action :stop)))
          (remhash running-task-id cl-cc.tools::*shell-background-task-registry*))
        (when completed-task-id
          (remhash completed-task-id cl-cc.tools::*shell-background-task-registry*))
        (when interrupted-task-id
          (remhash interrupted-task-id cl-cc.tools::*shell-background-task-registry*))
        (when fresh-interrupted-task-id
          (remhash fresh-interrupted-task-id cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and running-output-path (probe-file running-output-path))
          (ignore-errors (delete-file running-output-path)))
        (when (and completed-output-path (probe-file completed-output-path))
          (ignore-errors (delete-file completed-output-path)))
        (when (and interrupted-output-path (probe-file interrupted-output-path))
          (ignore-errors (delete-file interrupted-output-path)))
        (when (and fresh-interrupted-output-path (probe-file fresh-interrupted-output-path))
          (ignore-errors (delete-file fresh-interrupted-output-path)))))))

(test session-run-json-output-can-render-shell-task-tool-result
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('json-shell-task-ok')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                            (format nil "shell task ~A" task-id)
                                                                            "json")))))
           (let ((tool-output (%session-tool-result-json-section output "shell-task-tool")))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"executionStatus\":\"success\"" output))
             (is (search "\"selectedTools\":[\"shell-task-tool\",\"file-read-tool\",\"echo-tool\",\"failing-tool\"]" output))
             (is (search "\"toolResults\":[{\"toolId\":\"shell-task-tool\"" output))
             (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string task-id)) tool-output))
             (is (search "\"status\":\"running\"" tool-output))
             (is (search "\"running\":true" tool-output))
             (is (search "\"stopped\":false" tool-output))
             (is (search "\"stallDetected\":false" tool-output))
             (is (search "\"stallDetectedAt\":null" tool-output))
             (is (search "\"stallPromptLine\":null" tool-output))
             (is (search "\"terminationReason\":null" tool-output))
             (is (search "\"endedAt\":null" tool-output))
             (is (search "\"timedOut\":false" tool-output))
             (is (search (format nil "\"outputPath\":~A" (cl-cc::%cli-json-string output-path)) tool-output))))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test session-run-json-output-can-render-shell-task-wait-result
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Milliseconds 300; [Console]::Out.Write('json-shell-task-wait-ok')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                            (format nil "wait shell task ~A" task-id)
                                                                            "json")))))
           (is (search "\"status\":\"success\"" output))
           (is (search "\"executionStatus\":\"success\"" output))
           (is (search "\"selectedTools\":[\"shell-task-tool\",\"file-read-tool\",\"echo-tool\",\"failing-tool\"]" output))
           (is (search "\"toolResults\":[{\"toolId\":\"shell-task-tool\"" output))
           (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string task-id)) output))
           (is (search "\"action\":\"wait\"" output))
           (is (search "\"status\":\"completed\"" output))
           (is (search "\"terminationReason\":\"exit\"" output))
           (is (search "\"endedAt\":" output))
           (is (search "\"timedOut\":false" output))
           (is (search (format nil "\"outputPath\":~A" (cl-cc::%cli-json-string output-path)) output)))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test session-run-json-output-can-render-batch-shell-task-wait-result
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result-a (cl-cc.tools:shell-tool (list :command "Start-Sleep -Milliseconds 200; [Console]::Out.Write('json-shell-task-batch-wait-a')"
                                                       :directory directory
                                                       :background t)))
         (start-result-b (cl-cc.tools:shell-tool (list :command "Start-Sleep -Milliseconds 250; [Console]::Out.Write('json-shell-task-batch-wait-b')"
                                                       :directory directory
                                                       :background t)))
         (task-id-a (getf start-result-a :background-task-id))
         (task-id-b (getf start-result-b :background-task-id))
         (output-path-a (getf start-result-a :output-path))
         (output-path-b (getf start-result-b :output-path)))
    (unwind-protect
         (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                            (format nil "wait tasks ~A, ~A" task-id-a task-id-b)
                                                                            "json")))))
           (is (search "\"status\":\"success\"" output))
           (is (search "\"executionStatus\":\"success\"" output))
           (is (search "\"toolResults\":[{\"toolId\":\"shell-task-tool\"" output))
           (is (search (format nil "\"taskIds\":[~A,~A]"
                               (cl-cc::%cli-json-string task-id-a)
                               (cl-cc::%cli-json-string task-id-b))
                       output))
           (is (search "\"taskCount\":2" output))
           (is (search "\"completedCount\":2" output))
           (is (search "\"tasks\":[{" output))
           (is (search "\"terminationReason\":\"exit\"" output))
           (is (search "\"endedAt\":" output))
           (is (search "\"timedOut\":false" output)))
      (when task-id-a
        (remhash task-id-a cl-cc.tools::*shell-background-task-registry*))
      (when task-id-b
        (remhash task-id-b cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path-a (probe-file output-path-a))
        (ignore-errors (delete-file output-path-a)))
      (when (and output-path-b (probe-file output-path-b))
        (ignore-errors (delete-file output-path-b))))))

(test session-run-json-output-can-render-shell-task-detail-tool-result
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('json-shell-task-detail-1'); [Console]::Out.WriteLine('json-shell-task-detail-2'); Start-Sleep -Seconds 5"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                            (format nil "shell task detail ~A" task-id)
                                                                            "json")))))
           (let ((tool-output (%session-tool-result-json-section output "shell-task-detail-tool")))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"executionStatus\":\"success\"" output))
             (is (search "\"selectedTools\":[\"shell-task-detail-tool\",\"shell-task-tool\",\"file-read-tool\",\"echo-tool\",\"failing-tool\"]" output))
             (is (search "\"toolResults\":[{\"toolId\":\"shell-task-detail-tool\"" output))
             (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string task-id)) tool-output))
             (is (search "\"status\":\"running\"" tool-output))
             (is (search "\"running\":true" tool-output))
             (is (search "\"stopped\":false" tool-output))
             (is (search "\"startedAt\":" tool-output))
             (is (search "\"stallDetected\":false" tool-output))
             (is (search "\"stallDetectedAt\":null" tool-output))
             (is (search "\"stallPromptLine\":null" tool-output))
             (is (search "\"terminationReason\":null" tool-output))
             (is (search "\"endedAt\":null" tool-output))
             (is (search "\"durationSeconds\":" tool-output))
             (is (search "\"outputBytes\":" tool-output))
             (is (search "\"outputLineCount\":2" tool-output))
             (is (search "\"outputUpdatedAt\":" tool-output))
             (is (search (format nil "\"outputPath\":~A" (cl-cc::%cli-json-string output-path)) tool-output))))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test session-run-json-output-can-render-shell-task-output-tool-result
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('json-out-1'); [Console]::Out.WriteLine('json-out-2'); [Console]::Out.WriteLine('json-out-3')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (progn
           (sleep 0.4)
           (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                              (format nil "shell task output ~A :: 2" task-id)
                                                                              "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"executionStatus\":\"success\"" output))
             (is (search "\"selectedTools\":[\"shell-task-output-tool\",\"shell-task-tool\",\"file-read-tool\",\"echo-tool\",\"failing-tool\"]" output))
             (is (search "\"toolResults\":[{\"toolId\":\"shell-task-output-tool\"" output))
             (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string task-id)) output))
             (is (search "\"mode\":\"tail\"" output))
             (is (search "\"running\":false" output))
             (is (search "\"stopped\":false" output))
             (is (search "\"linesRequested\":2" output))
             (is (search "\"requestedStartLine\":null" output))
             (is (search "\"requestedEndLine\":null" output))
             (is (search "\"followSeconds\":null" output))
             (is (search "\"waitUntilFinished\":false" output))
             (is (search "\"startLine\":2" output))
             (is (search "\"endLine\":3" output))
             (is (search "\"totalLines\":3" output))
             (is (search (format nil "\"outputPath\":~A" (cl-cc::%cli-json-string output-path)) output))
             (is (search (format nil "\"content\":~A" (cl-cc::%cli-json-string (format nil "2:json-out-2~%3:json-out-3"))) output))))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test session-run-json-output-can-render-blocking-shell-task-output-tool-result
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('json-block-1'); Start-Sleep -Milliseconds 150; [Console]::Out.WriteLine('json-block-2'); Start-Sleep -Milliseconds 150; [Console]::Out.WriteLine('json-block-3')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                          (format nil "wait shell task output ~A :: start=1 :: lines=5" task-id)
                                                                          "json")))))
           (is (search "\"status\":\"success\"" output))
           (is (search "\"toolResults\":[{\"toolId\":\"shell-task-output-tool\"" output))
           (is (search (format nil "\"taskId\":~A" (cl-cc::%cli-json-string task-id)) output))
           (is (search "\"waitUntilFinished\":true" output))
           (is (search "\"followSeconds\":null" output))
           (is (search "\"running\":false" output))
           (is (search "\"startLine\":1" output))
           (is (search "\"endLine\":3" output))
           (is (search "\"totalLines\":3" output))
           (is (search (format nil "\"outputPath\":~A" (cl-cc::%cli-json-string output-path)) output))
           (is (search (format nil "\"content\":~A" (cl-cc::%cli-json-string (format nil "1:json-block-1~%2:json-block-2~%3:json-block-3"))) output)))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test session-run-json-output-can-render-batch-shell-task-output-tool-result
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result-a (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('json-batch-1'); [Console]::Out.WriteLine('json-batch-2'); [Console]::Out.WriteLine('json-batch-3')"
                                                       :directory directory
                                                       :background t)))
         (start-result-b (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('json-batch-4'); [Console]::Out.WriteLine('json-batch-5'); [Console]::Out.WriteLine('json-batch-6')"
                                                       :directory directory
                                                       :background t)))
         (task-id-a (getf start-result-a :background-task-id))
         (task-id-b (getf start-result-b :background-task-id))
         (output-path-a (getf start-result-a :output-path))
         (output-path-b (getf start-result-b :output-path)))
    (unwind-protect
         (progn
           (sleep 0.4)
           (let ((output (capture-output (lambda () (cl-cc::handle-session-run "resume-user"
                                                                              (format nil "shell task outputs ~A, ~A :: 2" task-id-a task-id-b)
                                                                              "json")))))
             (is (search "\"status\":\"success\"" output))
             (is (search "\"toolResults\":[{\"toolId\":\"shell-task-output-tool\"" output))
             (is (search (format nil "\"taskIds\":[~A,~A]"
                                 (cl-cc::%cli-json-string task-id-a)
                                 (cl-cc::%cli-json-string task-id-b))
                         output))
             (is (search "\"taskCount\":2" output))
             (is (search "\"mode\":\"tail\"" output))
             (is (search "\"outputPath\":null" output))
             (is (search "\"totalLines\":null" output))
             (is (search "\"completedCount\":2" output))
             (is (search "\"tasks\":[{" output))
             (is (search (format nil "\"outputPath\":~A" (cl-cc::%cli-json-string output-path-a)) output))
             (is (search (format nil "\"outputPath\":~A" (cl-cc::%cli-json-string output-path-b)) output))
             (is (search (format nil "\"content\":~A" (cl-cc::%cli-json-string (format nil "2:json-batch-2~%3:json-batch-3"))) output))
             (is (search (format nil "\"content\":~A" (cl-cc::%cli-json-string (format nil "2:json-batch-5~%3:json-batch-6"))) output))))
      (when task-id-a
        (remhash task-id-a cl-cc.tools::*shell-background-task-registry*))
      (when task-id-b
        (remhash task-id-b cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path-a (probe-file output-path-a))
        (ignore-errors (delete-file output-path-a)))
      (when (and output-path-b (probe-file output-path-b))
        (ignore-errors (delete-file output-path-b))))))

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
             (is (search "\"lineContext\":1" output))
             (is (search "\"ignoreCase\":false" output))
             (is (search "\"useRegex\":false" output))
             (is (search "\"multiline\":false" output))
             (is (search "\"dotAll\":false" output))
             (is (search "\"wholeWord\":false" output))
             (is (search "\"leftWordBoundary\":false" output))
             (is (search "\"rightWordBoundary\":false" output))
             (is (search "\"matchStartLine\":1" output))
             (is (search "\"matchStartColumn\":7" output))
             (is (search "\"matchEndLine\":1" output))
             (is (search "\"matchEndColumn\":13" output))
             (is (search "\"diffPreview\":" output))
             (is (search "\"lineDiffPreview\":" output))
             (is (search "\"unifiedDiffPreview\":" output))
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
             (is (search "\"lineContext\":1" output))
             (is (search "\"ignoreCase\":false" output))
             (is (search "\"useRegex\":false" output))
             (is (search "\"multiline\":false" output))
             (is (search "\"dotAll\":false" output))
             (is (search "\"wholeWord\":false" output))
             (is (search "\"leftWordBoundary\":false" output))
             (is (search "\"rightWordBoundary\":false" output))
             (is (search "\"matchStartLine\":1" output))
             (is (search "\"matchStartColumn\":7" output))
             (is (search "\"matchEndLine\":1" output))
             (is (search "\"matchEndColumn\":15" output))
             (is (search "\"beforePreview\":" output))
             (is (search "\"afterPreview\":" output))
             (is (search "\"diffPreview\":" output))
             (is (search "\"lineDiffPreview\":" output))
             (is (search "\"unifiedDiffPreview\":" output))
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
             (is (search "\"lineContext\":1" output))
             (is (search "\"ignoreCase\":false" output))
             (is (search "\"useRegex\":false" output))
             (is (search "\"multiline\":false" output))
             (is (search "\"dotAll\":false" output))
             (is (search "\"wholeWord\":false" output))
             (is (search "\"leftWordBoundary\":false" output))
             (is (search "\"rightWordBoundary\":false" output))
             (is (search "\"matchStartLine\":1" output))
             (is (search "\"matchStartColumn\":17" output))
             (is (search "\"matchEndLine\":1" output))
             (is (search "\"matchEndColumn\":21" output))
             (is (search "\"diffPreview\":" output))
             (is (search "\"lineDiffPreview\":" output))
             (is (search "\"unifiedDiffPreview\":" output))
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
                                  :tasks ((:task-id "shell-task-123"
                                           :type "shell"
                                           :status "running"
                                           :running t
                                           :stopped nil
                                           :command "Start-Sleep -Seconds 5"
                                           :directory "D:/VSCode/cl-cc/cl-cc/"
                                           :output-path "C:/Temp/shell-task-123.log"
                                           :process-id 1234
                                           :exit-code nil
                                           :started-at "2026-04-05T00:00:00Z"
                                           :stopped-at nil
                                           :finished-at nil
                                           :stall-detected nil
                                           :stall-detected-at nil
                                           :stall-prompt-line nil
                                           :termination-reason nil
                                           :ended-at nil))
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
                   "{\"status\":\"success\",\"sessionId\":\"saved-json-session\",\"historyIndex\":2,\"sessionStatus\":\"active\",\"tasks\":[{\"taskId\":\"shell-task-123\",\"type\":\"shell\",\"status\":\"running\",\"running\":true,\"stopped\":false,\"command\":\"Start-Sleep -Seconds 5\",\"directory\":\"D:/VSCode/cl-cc/cl-cc/\",\"outputPath\":\"C:/Temp/shell-task-123.log\",\"processId\":1234,\"exitCode\":null,\"startedAt\":\"2026-04-05T00:00:00Z\",\"stoppedAt\":null,\"finishedAt\":null,\"stallDetected\":false,\"stallDetectedAt\":null,\"stallPromptLine\":null,\"terminationReason\":null,\"endedAt\":null}],\"input\":\"hello json\",\"executionStatus\":\"success\",\"selectedTools\":[\"echo-tool\"],\"executionPlan\":[{\"tool\":\"echo-tool\",\"input\":\"hello json\"}],\"result\":\"tool:echo-tool result:hello json\",\"toolResults\":[{\"toolId\":\"echo-tool\",\"status\":\"success\",\"durationSeconds\":0.5,\"output\":{\"result\":\"hello json\"},\"error\":null,\"errorCode\":null}],\"sessionPath\":\"saved.session\",\"saved\":true,\"durationSeconds\":0.25,\"exitCode\":0}"))))

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

(test main-logs-invalid-help-auth-scope-to-stderr
  (multiple-value-bind (exit-code stderr)
      (invoke-main-capturing-stderr "--help" "--auth-scope" "private")
    (is (= exit-code 1))
    (is (search "[DEBUG] [ERROR] INVALID-ARGUMENTS: Invalid arguments for command help" stderr))))

(test main-logs-invalid-help-group-scope-to-stderr
  (multiple-value-bind (exit-code stderr)
      (invoke-main-capturing-stderr "--help" "--group-scope" "preview")
    (is (= exit-code 1))
    (is (search "[DEBUG] [ERROR] INVALID-ARGUMENTS: Invalid arguments for command help" stderr))))

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