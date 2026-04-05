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
                                                 :line-context 1
                                                 :ignore-case nil
                                                 :use-regex nil
                                                 :multiline nil
                                                 :dot-all nil
                                                 :whole-word nil
                                                 :left-word-boundary nil
                                                 :right-word-boundary nil
                                                 :match-start-line 1
                                                 :match-start-column 8
                                                 :match-end-line 1
                                                 :match-end-column 15
                                                 :match-start 7
                                                 :match-end 14
                                                 :matched-text "preview"
                                                 :replacement-text "value"
                                                 :before-preview "before preview after"
                                                 :after-preview "before value after"
                                                 :diff-preview "@@ match 7..14 @@
-before preview after
+before value after"
                                                 :line-diff-preview "@@ lines 1..1 -> 1..1 @@
before:
- 1| before preview after
after:
+ 1| before value after"
                                                 :unified-diff-preview "--- a/tmp.txt
+++ b/tmp.txt
@@ -1 +1 @@
-before preview after
+before value after"
                                                 :write-applied nil))
             '(:RESULT "预览编辑文件: tmp.txt"
               :PATH "tmp.txt"
               :PREVIEW T
               :MATCH-COUNT 1
               :TOTAL-MATCHES 1
               :SELECTED-OCCURRENCE 1
               :LINE-CONTEXT 1
               :IGNORE-CASE NIL
               :USE-REGEX NIL
               :MULTILINE NIL
               :DOT-ALL NIL
               :WHOLE-WORD NIL
               :LEFT-WORD-BOUNDARY NIL
               :RIGHT-WORD-BOUNDARY NIL
               :MATCH-START 7
               :MATCH-END 14
               :MATCH-START-LINE 1
               :MATCH-START-COLUMN 8
               :MATCH-END-LINE 1
               :MATCH-END-COLUMN 15
               :MATCHED-TEXT "preview"
               :REPLACEMENT-TEXT "value"
               :BEFORE-PREVIEW "before preview after"
               :AFTER-PREVIEW "before value after"
               :DIFF-PREVIEW "@@ match 7..14 @@
-before preview after
+before value after"
               :LINE-DIFF-PREVIEW "@@ lines 1..1 -> 1..1 @@
before:
- 1| before preview after
after:
+ 1| before value after"
               :UNIFIED-DIFF-PREVIEW "--- a/tmp.txt
+++ b/tmp.txt
@@ -1 +1 @@
-before preview after
+before value after"
               :WRITE-APPLIED NIL))))

(test tool-success-output-materializes-shell-tool-fields
  (is (equal (cl-cc.core::%tool-success-output "shell-tool"
                                               '(:summary "shell exit 0: git status"
                                                 :command "git status"
                                                 :directory "D:/VSCode/cl-cc/cl-cc/"
                                                 :stdout "clean"
                                                 :stderr ""
                                                 :exit-code 0
                                                 :timed-out nil))
             '(:RESULT "shell exit 0: git status"
               :COMMAND "git status"
               :DIRECTORY "D:/VSCode/cl-cc/cl-cc/"
               :BACKGROUND NIL
               :BACKGROUND-TASK-ID NIL
               :OUTPUT-PATH NIL
               :PROCESS-ID NIL
               :STDOUT "clean"
               :STDERR ""
               :EXIT-CODE 0
               :TIMED-OUT NIL))))

(test tool-success-output-materializes-shell-task-list-tool-fields
  (is (equal (cl-cc.core::%tool-success-output "shell-task-list-tool"
                                               '(:summary "shell 后台任务列表(2个)"
                                                 :status-filter "all"
                                                 :task-id-prefix-filter nil
                                                 :directory-contains-filter nil
                                                 :termination-reason-filter nil
                                                 :total-count 2
                                                 :running-count 1
                                                 :stopped-count 0
                                                 :completed-count 1
                                                 :failed-count 0
                                                 :tasks ((:task-id "shell-task-1"
                                                          :status "running"
                                                          :running t
                                                          :stopped nil
                                                          :command "git status"
                                                          :directory "D:/VSCode/cl-cc/cl-cc/"
                                                          :output-path "D:/Temp/shell-task-1.log"
                                                          :process-id 42
                                                          :exit-code nil
                                                          :stall-detected nil
                                                          :stall-detected-at nil
                                                          :stall-prompt-line nil
                                                          :termination-reason nil
                                                          :ended-at nil)
                                                         (:task-id "shell-task-2"
                                                          :status "completed"
                                                          :running nil
                                                          :stopped nil
                                                          :command "dir"
                                                          :directory "D:/VSCode/cl-cc/cl-cc/"
                                                          :output-path "D:/Temp/shell-task-2.log"
                                                          :process-id 43
                                                          :exit-code 0
                                                          :stall-detected nil
                                                          :stall-detected-at nil
                                                          :stall-prompt-line nil
                                                          :termination-reason "exit"
                                                          :ended-at "2026-04-05T03:00:12Z"))))
             '(:RESULT "shell 后台任务列表(2个)"
               :STATUS-FILTER "all"
               :TASK-ID-PREFIX-FILTER NIL
               :DIRECTORY-CONTAINS-FILTER NIL
               :TERMINATION-REASON-FILTER NIL
               :TOTAL-COUNT 2
               :RUNNING-COUNT 1
               :STOPPED-COUNT 0
               :COMPLETED-COUNT 1
               :FAILED-COUNT 0
               :TASKS ((:TASK-ID "shell-task-1"
                        :STATUS "running"
                        :RUNNING T
                        :STOPPED NIL
                        :COMMAND "git status"
                        :DIRECTORY "D:/VSCode/cl-cc/cl-cc/"
                        :OUTPUT-PATH "D:/Temp/shell-task-1.log"
                        :PROCESS-ID 42
                        :EXIT-CODE NIL
                        :STALL-DETECTED NIL
                        :STALL-DETECTED-AT NIL
                        :STALL-PROMPT-LINE NIL
                        :TERMINATION-REASON NIL
                        :ENDED-AT NIL)
                       (:TASK-ID "shell-task-2"
                        :STATUS "completed"
                        :RUNNING NIL
                        :STOPPED NIL
                        :COMMAND "dir"
                        :DIRECTORY "D:/VSCode/cl-cc/cl-cc/"
                        :OUTPUT-PATH "D:/Temp/shell-task-2.log"
                        :PROCESS-ID 43
                        :EXIT-CODE 0
                        :STALL-DETECTED NIL
                        :STALL-DETECTED-AT NIL
                        :STALL-PROMPT-LINE NIL
                        :TERMINATION-REASON "exit"
                        :ENDED-AT "2026-04-05T03:00:12Z"))))))

(test tool-success-output-materializes-shell-task-tool-fields
  (is (equal (cl-cc.core::%tool-success-output "shell-task-tool"
                                               '(:summary "shell 后台任务 running: shell-task-123"
                                                 :task-id "shell-task-123"
                                                 :task-ids nil
                                                 :task-count nil
                                                 :action "status"
                                                 :status "running"
                                                 :running t
                                                 :stopped nil
                                                 :command "git status"
                                                 :directory "D:/VSCode/cl-cc/cl-cc/"
                                                 :output-path "D:/Temp/shell-task-123.log"
                                                 :process-id 42
                                                 :exit-code nil
                                                 :stall-detected nil
                                                 :stall-detected-at nil
                                                 :stall-prompt-line nil
                                                 :termination-reason nil
                                                 :ended-at nil
                                                 :running-count nil
                                                 :stopped-count nil
                                                 :completed-count nil
                                                 :failed-count nil
                                                 :tasks nil
                                                 :timed-out nil))
             '(:RESULT "shell 后台任务 running: shell-task-123"
               :TASK-ID "shell-task-123"
               :TASK-IDS NIL
               :TASK-COUNT NIL
               :ACTION "status"
               :STATUS "running"
               :RUNNING T
               :STOPPED NIL
               :COMMAND "git status"
               :DIRECTORY "D:/VSCode/cl-cc/cl-cc/"
               :OUTPUT-PATH "D:/Temp/shell-task-123.log"
               :PROCESS-ID 42
               :EXIT-CODE NIL
               :STALL-DETECTED NIL
               :STALL-DETECTED-AT NIL
               :STALL-PROMPT-LINE NIL
               :TERMINATION-REASON NIL
               :ENDED-AT NIL
               :RUNNING-COUNT NIL
               :STOPPED-COUNT NIL
               :COMPLETED-COUNT NIL
               :FAILED-COUNT NIL
               :TASKS NIL
               :TIMED-OUT NIL))))

(test tool-success-output-materializes-batch-shell-task-tool-fields
  (is (equal (cl-cc.core::%tool-success-output "shell-task-tool"
                                               '(:summary "shell 后台任务批量 wait(2个): shell-task-1, shell-task-2"
                                                 :task-id nil
                                                 :task-ids ("shell-task-1" "shell-task-2")
                                                 :task-count 2
                                                 :action "wait"
                                                 :status "completed"
                                                 :running nil
                                                 :stopped nil
                                                 :command nil
                                                 :directory nil
                                                 :output-path nil
                                                 :process-id nil
                                                 :exit-code nil
                                                 :running-count 0
                                                 :stopped-count 0
                                                 :completed-count 2
                                                 :failed-count 0
                                                 :tasks ((:task-id "shell-task-1"
                                                          :action "wait"
                                                          :status "completed"
                                                          :running nil
                                                          :stopped nil
                                                          :command "cmd-a"
                                                          :directory "D:/Temp/"
                                                          :output-path "D:/Temp/a.log"
                                                          :process-id 11
                                                          :exit-code 0
                                                          :stall-detected nil
                                                          :stall-detected-at nil
                                                          :stall-prompt-line nil
                                                           :termination-reason "exit"
                                                           :ended-at "2026-04-05T03:00:11Z"
                                                          :timed-out nil)
                                                         (:task-id "shell-task-2"
                                                          :action "wait"
                                                          :status "completed"
                                                          :running nil
                                                          :stopped nil
                                                          :command "cmd-b"
                                                          :directory "D:/Temp/"
                                                          :output-path "D:/Temp/b.log"
                                                          :process-id 12
                                                          :exit-code 0
                                                          :stall-detected nil
                                                          :stall-detected-at nil
                                                          :stall-prompt-line nil
                                                          :termination-reason "exit"
                                                          :ended-at "2026-04-05T03:00:12Z"
                                                          :timed-out nil))
                                                 :timed-out nil))
             '(:RESULT "shell 后台任务批量 wait(2个): shell-task-1, shell-task-2"
               :TASK-ID NIL
               :TASK-IDS ("shell-task-1" "shell-task-2")
               :TASK-COUNT 2
               :ACTION "wait"
               :STATUS "completed"
               :RUNNING NIL
               :STOPPED NIL
               :COMMAND NIL
               :DIRECTORY NIL
               :OUTPUT-PATH NIL
               :PROCESS-ID NIL
               :EXIT-CODE NIL
               :STALL-DETECTED NIL
               :STALL-DETECTED-AT NIL
               :STALL-PROMPT-LINE NIL
               :TERMINATION-REASON NIL
               :ENDED-AT NIL
               :RUNNING-COUNT 0
               :STOPPED-COUNT 0
               :COMPLETED-COUNT 2
               :FAILED-COUNT 0
               :TASKS ((:TASK-ID "shell-task-1"
                        :ACTION "wait"
                        :STATUS "completed"
                        :RUNNING NIL
                        :STOPPED NIL
                        :COMMAND "cmd-a"
                        :DIRECTORY "D:/Temp/"
                        :OUTPUT-PATH "D:/Temp/a.log"
                        :PROCESS-ID 11
                        :EXIT-CODE 0
                        :STALL-DETECTED NIL
                        :STALL-DETECTED-AT NIL
                        :STALL-PROMPT-LINE NIL
                        :TERMINATION-REASON "exit"
                        :ENDED-AT "2026-04-05T03:00:11Z"
                        :TIMED-OUT NIL)
                       (:TASK-ID "shell-task-2"
                        :ACTION "wait"
                        :STATUS "completed"
                        :RUNNING NIL
                        :STOPPED NIL
                        :COMMAND "cmd-b"
                        :DIRECTORY "D:/Temp/"
                        :OUTPUT-PATH "D:/Temp/b.log"
                        :PROCESS-ID 12
                        :EXIT-CODE 0
                        :STALL-DETECTED NIL
                        :STALL-DETECTED-AT NIL
                        :STALL-PROMPT-LINE NIL
                        :TERMINATION-REASON "exit"
                        :ENDED-AT "2026-04-05T03:00:12Z"
                        :TIMED-OUT NIL))
               :TIMED-OUT NIL))))

(test tool-success-output-materializes-shell-task-cleanup-tool-fields
  (is (equal (cl-cc.core::%tool-success-output "shell-task-cleanup-tool"
                                               '(:summary "shell 后台任务清理(2个): all"
                                                 :status-filter "all"
                                                 :termination-reason-filter nil
                                                 :removed-count 2
                                                 :remaining-count 1
                                                 :removed-task-ids ("shell-task-1" "shell-task-2")))
             '(:RESULT "shell 后台任务清理(2个): all"
               :STATUS-FILTER "all"
               :TERMINATION-REASON-FILTER NIL
               :REMOVED-COUNT 2
               :REMAINING-COUNT 1
               :REMOVED-TASK-IDS ("shell-task-1" "shell-task-2")))))

(test tool-success-output-materializes-shell-task-detail-tool-fields
  (is (equal (cl-cc.core::%tool-success-output "shell-task-detail-tool"
                                               '(:summary "shell 后台任务详情 running: shell-task-123"
                                                 :task-id "shell-task-123"
                                                 :status "running"
                                                 :running t
                                                 :stopped nil
                                                 :command "git status"
                                                 :directory "D:/VSCode/cl-cc/cl-cc/"
                                                 :output-path "D:/Temp/shell-task-123.log"
                                                 :process-id 42
                                                 :exit-code nil
                                                 :stall-detected nil
                                                 :stall-detected-at nil
                                                 :stall-prompt-line nil
                                                 :started-at "2026-04-05T03:00:00Z"
                                                 :stopped-at nil
                                                 :finished-at nil
                                                 :termination-reason nil
                                                 :ended-at nil
                                                 :duration-seconds 12
                                                 :output-bytes 128
                                                 :output-line-count 4
                                                 :output-updated-at "2026-04-05T03:00:12Z"))
             '(:RESULT "shell 后台任务详情 running: shell-task-123"
               :TASK-ID "shell-task-123"
               :STATUS "running"
               :RUNNING T
               :STOPPED NIL
               :COMMAND "git status"
               :DIRECTORY "D:/VSCode/cl-cc/cl-cc/"
               :OUTPUT-PATH "D:/Temp/shell-task-123.log"
               :PROCESS-ID 42
               :EXIT-CODE NIL
               :STALL-DETECTED NIL
               :STALL-DETECTED-AT NIL
               :STALL-PROMPT-LINE NIL
               :STARTED-AT "2026-04-05T03:00:00Z"
               :STOPPED-AT NIL
               :FINISHED-AT NIL
               :TERMINATION-REASON NIL
               :ENDED-AT NIL
               :DURATION-SECONDS 12
               :OUTPUT-BYTES 128
               :OUTPUT-LINE-COUNT 4
               :OUTPUT-UPDATED-AT "2026-04-05T03:00:12Z"))))

(test tool-success-output-materializes-shell-task-output-tool-fields
  (is (equal (cl-cc.core::%tool-success-output "shell-task-output-tool"
                                               '(:summary "shell 后台任务输出(tail 最近5行): shell-task-123"
                                                 :task-id "shell-task-123"
                                                 :mode "tail"
                                                 :status "running"
                                                 :running t
                                                 :stopped nil
                                                 :output-path "D:/Temp/shell-task-123.log"
                                                 :lines-requested 5
                                                 :requested-start-line nil
                                                 :requested-end-line nil
                                                 :follow-seconds nil
                                                 :wait-until-finished nil
                                                 :start-line 3
                                                 :end-line 7
                                                 :total-lines 7
                                                 :content "3:beta~%4:gamma"))
             '(:RESULT "shell 后台任务输出(tail 最近5行): shell-task-123"
               :TASK-ID "shell-task-123"
               :TASK-IDS NIL
               :TASK-COUNT NIL
               :MODE "tail"
               :STATUS "running"
               :RUNNING T
               :STOPPED NIL
               :OUTPUT-PATH "D:/Temp/shell-task-123.log"
               :LINES-REQUESTED 5
               :REQUESTED-START-LINE NIL
               :REQUESTED-END-LINE NIL
               :FOLLOW-SECONDS NIL
               :WAIT-UNTIL-FINISHED NIL
               :START-LINE 3
               :END-LINE 7
               :TOTAL-LINES 7
               :RUNNING-COUNT NIL
               :STOPPED-COUNT NIL
               :COMPLETED-COUNT NIL
               :FAILED-COUNT NIL
               :TASKS NIL
               :CONTENT "3:beta~%4:gamma"))))

(test tool-success-output-materializes-batch-shell-task-output-tool-fields
  (is (equal (cl-cc.core::%tool-success-output "shell-task-output-tool"
                                               '(:summary "shell 后台任务批量输出(tail 最近2行, 2个): shell-task-123, shell-task-456"
                                                 :task-id nil
                                                 :task-ids ("shell-task-123" "shell-task-456")
                                                 :task-count 2
                                                 :mode "tail"
                                                 :status "completed"
                                                 :running nil
                                                 :stopped nil
                                                 :output-path nil
                                                 :lines-requested 2
                                                 :requested-start-line nil
                                                 :requested-end-line nil
                                                 :follow-seconds nil
                                                 :wait-until-finished nil
                                                 :start-line nil
                                                 :end-line nil
                                                 :total-lines nil
                                                 :running-count 0
                                                 :stopped-count 0
                                                 :completed-count 2
                                                 :failed-count 0
                                                 :tasks ((:task-id "shell-task-123"
                                                          :mode "tail"
                                                          :status "completed"
                                                          :running nil
                                                          :stopped nil
                                                          :output-path "D:/Temp/shell-task-123.log"
                                                          :lines-requested 2
                                                          :requested-start-line nil
                                                          :requested-end-line nil
                                                          :follow-seconds nil
                                                          :wait-until-finished nil
                                                          :start-line 2
                                                          :end-line 3
                                                          :total-lines 3
                                                          :content "2:a~%3:b")
                                                         (:task-id "shell-task-456"
                                                          :mode "tail"
                                                          :status "completed"
                                                          :running nil
                                                          :stopped nil
                                                          :output-path "D:/Temp/shell-task-456.log"
                                                          :lines-requested 2
                                                          :requested-start-line nil
                                                          :requested-end-line nil
                                                          :follow-seconds nil
                                                          :wait-until-finished nil
                                                          :start-line 4
                                                          :end-line 5
                                                          :total-lines 5
                                                          :content "4:c~%5:d"))
                                                 :content nil))
             '(:RESULT "shell 后台任务批量输出(tail 最近2行, 2个): shell-task-123, shell-task-456"
               :TASK-ID NIL
               :TASK-IDS ("shell-task-123" "shell-task-456")
               :TASK-COUNT 2
               :MODE "tail"
               :STATUS "completed"
               :RUNNING NIL
               :STOPPED NIL
               :OUTPUT-PATH NIL
               :LINES-REQUESTED 2
               :REQUESTED-START-LINE NIL
               :REQUESTED-END-LINE NIL
               :FOLLOW-SECONDS NIL
               :WAIT-UNTIL-FINISHED NIL
               :START-LINE NIL
               :END-LINE NIL
               :TOTAL-LINES NIL
               :RUNNING-COUNT 0
               :STOPPED-COUNT 0
               :COMPLETED-COUNT 2
               :FAILED-COUNT 0
               :TASKS ((:TASK-ID "shell-task-123"
                        :MODE "tail"
                        :STATUS "completed"
                        :RUNNING NIL
                        :STOPPED NIL
                        :OUTPUT-PATH "D:/Temp/shell-task-123.log"
                        :LINES-REQUESTED 2
                        :REQUESTED-START-LINE NIL
                        :REQUESTED-END-LINE NIL
                        :FOLLOW-SECONDS NIL
                        :WAIT-UNTIL-FINISHED NIL
                        :START-LINE 2
                        :END-LINE 3
                        :TOTAL-LINES 3
                        :CONTENT "2:a~%3:b")
                       (:TASK-ID "shell-task-456"
                        :MODE "tail"
                        :STATUS "completed"
                        :RUNNING NIL
                        :STOPPED NIL
                        :OUTPUT-PATH "D:/Temp/shell-task-456.log"
                        :LINES-REQUESTED 2
                        :REQUESTED-START-LINE NIL
                        :REQUESTED-END-LINE NIL
                        :FOLLOW-SECONDS NIL
                        :WAIT-UNTIL-FINISHED NIL
                        :START-LINE 4
                        :END-LINE 5
                        :TOTAL-LINES 5
                        :CONTENT "4:c~%5:d"))
               :CONTENT NIL))))

(test tool-success-output-materializes-mixed-batch-shell-task-output-tool-fields
  (is (equal (cl-cc.core::%tool-success-output "shell-task-output-tool"
                                               '(:summary "shell 后台任务批量输出(mixed mixed windows, 2个): shell-task-123, shell-task-456"
                                                 :task-id nil
                                                 :task-ids ("shell-task-123" "shell-task-456")
                                                 :task-count 2
                                                 :mode "mixed"
                                                 :status "completed"
                                                 :running nil
                                                 :stopped nil
                                                 :output-path nil
                                                 :lines-requested nil
                                                 :requested-start-line nil
                                                 :requested-end-line nil
                                                 :follow-seconds nil
                                                 :wait-until-finished nil
                                                 :start-line nil
                                                 :end-line nil
                                                 :total-lines nil
                                                 :running-count 0
                                                 :stopped-count 0
                                                 :completed-count 2
                                                 :failed-count 0
                                                 :tasks ((:task-id "shell-task-123"
                                                          :mode "tail"
                                                          :status "completed"
                                                          :running nil
                                                          :stopped nil
                                                          :output-path "D:/Temp/shell-task-123.log"
                                                          :lines-requested 1
                                                          :requested-start-line nil
                                                          :requested-end-line nil
                                                          :follow-seconds nil
                                                          :wait-until-finished nil
                                                          :start-line 3
                                                          :end-line 3
                                                          :total-lines 3
                                                          :content "3:a")
                                                         (:task-id "shell-task-456"
                                                          :mode "range"
                                                          :status "completed"
                                                          :running nil
                                                          :stopped nil
                                                          :output-path "D:/Temp/shell-task-456.log"
                                                          :lines-requested 2
                                                          :requested-start-line 2
                                                          :requested-end-line 3
                                                          :follow-seconds nil
                                                          :wait-until-finished t
                                                          :start-line 2
                                                          :end-line 3
                                                          :total-lines 3
                                                          :content "2:b~%3:c"))
                                                 :content nil))
             '(:RESULT "shell 后台任务批量输出(mixed mixed windows, 2个): shell-task-123, shell-task-456"
               :TASK-ID NIL
               :TASK-IDS ("shell-task-123" "shell-task-456")
               :TASK-COUNT 2
               :MODE "mixed"
               :STATUS "completed"
               :RUNNING NIL
               :STOPPED NIL
               :OUTPUT-PATH NIL
               :LINES-REQUESTED NIL
               :REQUESTED-START-LINE NIL
               :REQUESTED-END-LINE NIL
               :FOLLOW-SECONDS NIL
               :WAIT-UNTIL-FINISHED NIL
               :START-LINE NIL
               :END-LINE NIL
               :TOTAL-LINES NIL
               :RUNNING-COUNT 0
               :STOPPED-COUNT 0
               :COMPLETED-COUNT 2
               :FAILED-COUNT 0
               :TASKS ((:TASK-ID "shell-task-123"
                        :MODE "tail"
                        :STATUS "completed"
                        :RUNNING NIL
                        :STOPPED NIL
                        :OUTPUT-PATH "D:/Temp/shell-task-123.log"
                        :LINES-REQUESTED 1
                        :REQUESTED-START-LINE NIL
                        :REQUESTED-END-LINE NIL
                        :FOLLOW-SECONDS NIL
                        :WAIT-UNTIL-FINISHED NIL
                        :START-LINE 3
                        :END-LINE 3
                        :TOTAL-LINES 3
                        :CONTENT "3:a")
                       (:TASK-ID "shell-task-456"
                        :MODE "range"
                        :STATUS "completed"
                        :RUNNING NIL
                        :STOPPED NIL
                        :OUTPUT-PATH "D:/Temp/shell-task-456.log"
                        :LINES-REQUESTED 2
                        :REQUESTED-START-LINE 2
                        :REQUESTED-END-LINE 3
                        :FOLLOW-SECONDS NIL
                        :WAIT-UNTIL-FINISHED T
                        :START-LINE 2
                        :END-LINE 3
                        :TOTAL-LINES 3
                        :CONTENT "2:b~%3:c"))
               :CONTENT NIL))))

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