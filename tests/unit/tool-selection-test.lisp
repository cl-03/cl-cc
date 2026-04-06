;;;; tests/unit/tool-selection-test.lisp - 工具选择逻辑单元测试
(in-package :cl-cc/tests)

(def-suite tool-selection-test :in cl-cc-suite)

(in-suite tool-selection-test)

(test select-tools-prefers-failing-tool-for-failure-keywords
  (is (equal (cl-cc.services:select-tools "Please FAIL loudly")
             '("failing-tool" "echo-tool")))
  (is (equal (cl-cc.services:select-tools "这里会报错吗")
             '("failing-tool" "echo-tool"))))

(test select-tools-prefers-file-read-tool-for-file-intent
  (is (equal (cl-cc.services:select-tools "read file README.md")
             '("file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "请读取文件 docs/spec.txt")
             '("file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-file-write-tool-for-write-intent
  (is (equal (cl-cc.services:select-tools "write file notes.txt :: hello")
             '("file-write-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "请写入文件 docs/spec.txt :: updated")
             '("file-write-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-file-edit-tool-for-edit-intent
  (is (equal (cl-cc.services:select-tools "edit file notes.txt :: old :: new")
             '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "patch file notes.txt :: old :: new")
             '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "replace all in file notes.txt :: old :: new")
             '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "请替换文件 docs/spec.txt :: before :: after")
             '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-grep-tool-for-code-search-intent
  (is (equal (cl-cc.services:select-tools "grep session-loop")
             '("grep-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "搜索代码 permission")
             '("grep-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-glob-tool-for-file-discovery-intent
  (is (equal (cl-cc.services:select-tools "glob **/*.lisp")
             '("glob-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "查找文件 src/**/*.lisp")
             '("glob-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-todo-write-tool-for-todo-intent
  (is (equal (cl-cc.services:select-tools "todo write Implement todo tool | in_progress | Implementing todo tool")
             '("todo-write-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "更新待办列表 Implement todo tool | in_progress | Implementing todo tool")
             '("todo-write-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-shell-tool-for-shell-intent
  (is (equal (cl-cc.services:select-tools "run shell git status")
             '("shell-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "执行命令 dir")
             '("shell-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-shell-task-list-tool-for-background-task-list-intent
  (is (equal (cl-cc.services:select-tools "shell task list")
             '("shell-task-list-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "后台任务列表")
             '("shell-task-list-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "列出运行中的后台任务")
             '("shell-task-list-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-shell-task-cleanup-tool-for-background-task-cleanup-intent
  (is (equal (cl-cc.services:select-tools "cleanup shell tasks")
             '("shell-task-cleanup-tool" "shell-task-list-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "清理已完成后台任务")
             '("shell-task-cleanup-tool" "shell-task-list-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-shell-task-tool-for-background-task-intent
  (is (equal (cl-cc.services:select-tools "shell task shell-task-123")
             '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "inspect shell task shell-task-123")
             '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "wait shell task shell-task-123")
             '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "interrupt task shell-task-123")
             '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "wait tasks shell-task-123, shell-task-456")
             '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "join task shell-task-123")
             '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "cancel task shell-task-123")
             '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "停止后台任务 shell-task-123")
             '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-shell-task-output-tool-for-background-task-output-intent
  (is (equal (cl-cc.services:select-tools "shell task output shell-task-123")
             '("shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "follow shell task output shell-task-123")
             '("shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "wait shell task output shell-task-123")
             '("shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "wait shell task outputs shell-task-123, shell-task-456")
             '("shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "读取后台任务输出 shell-task-123")
             '("shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-shell-task-detail-tool-for-background-task-detail-intent
  (is (equal (cl-cc.services:select-tools "shell task detail shell-task-123")
             '("shell-task-detail-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "查看后台任务详情shell-task-123")
             '("shell-task-detail-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test plan-session-execution-builds-background-shell-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "background shell git status"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-tool"))
    (is (equal (getf first-step :input)
               '(:command "git status" :background t)))))

(test plan-session-execution-builds-shell-task-list-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "list shell tasks"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-list-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-list-tool"))
    (is (equal (getf first-step :input)
               '(:status :all :task-id-prefix nil :directory-contains nil :termination-reason nil)))))

(test plan-session-execution-builds-glob-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "glob src/**/*.lisp :: tests") )
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("glob-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "glob-tool"))
    (is (equal (getf first-step :input)
               '(:pattern "src/**/*.lisp" :root "tests")))))

(test plan-session-execution-builds-todo-write-specific-inputs
  (let* ((input "todo write Implement todo tool | in_progress | Implementing todo tool ;; Run tests | pending | Running tests")
         (plan (cl-cc.services:plan-session-execution input))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("todo-write-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "todo-write-tool"))
    (is (equal (getf first-step :input)
               '(:todos ((:content "Implement todo tool" :status "in_progress" :active-form "Implementing todo tool")
                         (:content "Run tests" :status "pending" :active-form "Running tests")))))))

(test plan-session-execution-builds-shell-task-cleanup-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "cleanup shell tasks :: completed"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-cleanup-tool" "shell-task-list-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-cleanup-tool"))
    (is (equal (getf first-step :input)
               '(:status :completed :termination-reason nil)))))

(test plan-session-execution-builds-shell-task-cleanup-termination-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "cleanup shell tasks :: termination=interrupt"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (string= (getf first-step :tool) "shell-task-cleanup-tool"))
    (is (equal (getf first-step :input)
               '(:status :all :termination-reason "interrupt")))))

(test plan-session-execution-builds-filtered-shell-task-list-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "shell task list :: failed"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (string= (getf first-step :tool) "shell-task-list-tool"))
    (is (equal (getf first-step :input)
               '(:status :failed :task-id-prefix nil :directory-contains nil :termination-reason nil)))))

(test plan-session-execution-builds-multi-filter-shell-task-list-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "shell task list :: status=running :: task=shell-task-123 :: dir=temp"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (string= (getf first-step :tool) "shell-task-list-tool"))
    (is (equal (getf first-step :input)
               '(:status :running :task-id-prefix "shell-task-123" :directory-contains "temp" :termination-reason nil)))))

(test plan-session-execution-builds-shell-task-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "stop shell task shell-task-123"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-tool"))
    (is (equal (getf first-step :input)
               '(:task-id "shell-task-123" :task-ids nil :action :stop :timeout-seconds nil)))))

(test plan-session-execution-builds-shell-task-interrupt-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "interrupt task shell-task-123"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-tool"))
    (is (equal (getf first-step :input)
               '(:task-id "shell-task-123" :task-ids nil :action :interrupt :timeout-seconds nil)))))

(test plan-session-execution-builds-shell-task-cancel-alias-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "cancel task shell-task-123"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-tool"))
    (is (equal (getf first-step :input)
               '(:task-id "shell-task-123" :task-ids nil :action :stop :timeout-seconds nil)))))

(test plan-session-execution-builds-shell-task-wait-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "wait shell task shell-task-123 :: 2"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-tool"))
    (is (equal (getf first-step :input)
               '(:task-id "shell-task-123" :task-ids nil :action :wait :timeout-seconds 2)))))

(test plan-session-execution-builds-batch-shell-task-wait-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "wait tasks shell-task-123, shell-task-456 :: 2"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-tool"))
    (is (equal (getf first-step :input)
               '(:task-id nil :task-ids ("shell-task-123" "shell-task-456") :action :wait :timeout-seconds 2)))))

(test plan-session-execution-builds-shell-task-join-alias-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "join task shell-task-123"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-tool"))
    (is (equal (getf first-step :input)
               '(:task-id "shell-task-123" :task-ids nil :action :wait :timeout-seconds nil)))))

(test plan-session-execution-builds-shell-task-output-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "shell task output shell-task-123 :: 5"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-output-tool"))
    (is (equal (getf first-step :input)
               '(:task-id "shell-task-123" :lines 5 :start-line nil :end-line nil :follow-seconds nil :wait-until-finished nil)))))

(test plan-session-execution-builds-follow-shell-task-output-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "follow shell task output shell-task-123 :: start=3 :: lines=2"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-output-tool"))
    (is (equal (getf first-step :input)
               '(:task-id "shell-task-123" :lines 2 :start-line 3 :end-line nil :follow-seconds 2 :wait-until-finished nil)))))

(test plan-session-execution-builds-blocking-shell-task-output-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "wait shell task output shell-task-123 :: start=3 :: lines=2"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-output-tool"))
    (is (equal (getf first-step :input)
               '(:task-id "shell-task-123" :lines 2 :start-line 3 :end-line nil :follow-seconds nil :wait-until-finished t)))))

(test plan-session-execution-builds-batch-shell-task-output-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "wait shell task outputs shell-task-123, shell-task-456 :: start=3 :: lines=2"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-output-tool"))
    (is (equal (getf first-step :input)
               '(:task-id nil :task-ids ("shell-task-123" "shell-task-456") :lines 2 :start-line 3 :end-line nil :follow-seconds nil :wait-until-finished t)))))

(test plan-session-execution-builds-shell-task-detail-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "shell task detail shell-task-123"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("shell-task-detail-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "shell-task-detail-tool"))
    (is (equal (getf first-step :input)
               '(:task-id "shell-task-123")))))

(test plan-session-execution-builds-directory-list-recursive-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "list directory docs :: recursive :: depth=2"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("directory-list-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "directory-list-tool"))
    (is (equal (getf first-step :input)
               '(:path "docs" :recursive t :depth 2)))))

(test plan-session-execution-builds-directory-list-contains-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "list directory docs :: recursive :: contains=note"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("directory-list-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "directory-list-tool"))
    (is (equal (getf first-step :input)
               '(:path "docs" :recursive t :depth nil :contains "note")))))

(test select-tools-prefers-directory-list-tool-for-directory-intent
  (is (equal (cl-cc.services:select-tools "list directory docs")
             '("directory-list-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "请列出目录 fixtures")
             '("directory-list-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-echo-tool-for-echo-keywords
  (is (equal (cl-cc.services:select-tools "echo this back")
             '("echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "请回显当前输入")
             '("echo-tool" "failing-tool"))))

(test select-tools-defaults-to-echo-tool-for-generic-or-empty-input
  (is (equal (cl-cc.services:select-tools "hello world")
             '("echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools nil)
             '("echo-tool" "failing-tool"))))

(test plan-session-execution-builds_tool_specific_inputs
  (let* ((plan (cl-cc.services:plan-session-execution "write file tmp/demo.txt :: hello world"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-write-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-write-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :content " hello world" :mode :overwrite)))
    (is (equal (cdr (assoc "file-write-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :content " hello world" :mode :overwrite)))))

(test plan-session-execution-builds-file-edit-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "edit file tmp/demo.txt :: before :: after"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))))

(test plan-session-execution-builds-file-edit-search-replace-block-inputs
  (let* ((plan (cl-cc.services:plan-session-execution
                (format nil "preview patch file tmp/demo.txt~%<<<<<<< SEARCH~%before~%=======~%after~%>>>>>>> REPLACE")))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text "before" :new-text "after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))))

(test plan-session-execution-builds-file-edit-multi-search-replace-block-inputs
  (let* ((plan (cl-cc.services:plan-session-execution
                (format nil "preview patch file tmp/demo.txt~%<<<<<<< SEARCH~%before~%=======~%after~%>>>>>>> REPLACE~%<<<<<<< SEARCH~%alpha~%=======~%beta~%>>>>>>> REPLACE")))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :edits ((:old-text "before" :new-text "after")
                                              (:old-text "alpha" :new-text "beta"))
                 :preview t :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))))

(test plan-session-execution-builds-file-edit-occurrence-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview ignore case 2nd occurrence patch file tmp/demo.txt :: before :: after"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence 2 :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil)))))

(test plan-session-execution-builds-file-edit-synonym-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex replace all case-insensitive patch file tmp/demo.txt :: token-[0-9]+ :: value"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))))

(test plan-session-execution-builds-file-edit-boundary-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex left word boundary edit file tmp/demo.txt :: token-[0-9]+ :: value"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary t :right-word-boundary nil :use-regex t)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary t :right-word-boundary nil :use-regex t)))))

(test plan-session-execution-builds-file-edit-order-independent-plain-flag-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview whole word ignore case edit file tmp/demo.txt :: before :: after"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word t :left-word-boundary nil :right-word-boundary nil)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word t :left-word-boundary nil :right-word-boundary nil)))))

(test plan-session-execution-builds-file-edit-order-independent-plain-replace-all-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview replace all ignore case edit file tmp/demo.txt :: before :: after"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :replace-all t)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :replace-all t)))))

(test plan-session-execution-builds-file-edit-chinese-legacy-plain-replace-all-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "预览全部替换文件 tmp/demo.txt :: before :: after"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :replace-all t)))))

(test plan-session-execution-builds-file-edit-chinese-plain-flag-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "预览忽略大小写左边界编辑文件 tmp/demo.txt :: before :: after"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary t :right-word-boundary nil)))))

(test plan-session-execution-builds-file-edit-ignore-case-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex ignore case edit file tmp/demo.txt :: token-[a-z]+ :: value"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " token-[a-z]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " token-[a-z]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))))

(test plan-session-execution-builds-file-edit-multiline-and-dot-all-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex multiline dot all edit file tmp/demo.txt :: ^token.*value$ :: done"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " ^token.*value$" :new-text " done" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " ^token.*value$" :new-text " done" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))))

(test plan-session-execution-builds-file-edit-chinese-regex-flag-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "预览正则多行模式点号跨行编辑文件 tmp/demo.txt :: ^token.*value$ :: done"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " ^token.*value$" :new-text " done" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))))

(test plan-session-execution-builds-file-edit-ignore-case-multiline-dot-all-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "预览正则忽略大小写多行模式点号跨行编辑文件 tmp/demo.txt :: ^token.*value$ :: done"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " ^token.*value$" :new-text " done" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))))

(test plan-session-execution-builds-file-edit-order-independent-regex-flag-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex dot all ignore case multiline edit file tmp/demo.txt :: ^token.*value$ :: done"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " ^token.*value$" :new-text " done" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))))

(test plan-session-execution-builds-file-edit-order-independent-replace-all-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex replace all ignore case edit file tmp/demo.txt :: token-[0-9]+ :: value"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))))

(test plan-session-execution-builds-file-edit-order-independent-boundary-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex right word boundary left word boundary edit file tmp/demo.txt :: token-[0-9]+ :: value"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary t :right-word-boundary t :use-regex t)))))

(test plan-session-execution-builds-file-edit-replace-all-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex replace all in file tmp/demo.txt :: token-[0-9]+ :: value"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))))

(test plan-session-execution-builds-file-edit-chinese-legacy-regex-replace-all-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "预览正则全部替换文件 tmp/demo.txt :: token-[0-9]+ :: value"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))))

(test plan-session-execution-builds-file-edit-line-context-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex context 0 edit file tmp/demo.txt :: token-[0-9]+ :: value"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context 0 :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context 0 :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))))

(test plan-session-execution-builds-file-edit-combinable-line-context-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "preview regex ignore case context 0 patch file tmp/demo.txt :: token-[0-9]+ :: value"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-edit-tool"))
    (is (equal (getf first-step :input)
               '(:path "tmp/demo.txt" :old-text " token-[0-9]+" :new-text " value" :preview t :occurrence nil :line-context 0 :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))))

(test plan-session-execution-builds-file-read-line-range-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "read file src/core/session-loop.lisp :: 10-12"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-read-tool"))
    (is (equal (getf first-step :input)
               '(:path "src/core/session-loop.lisp" :start-line 10 :end-line 12)))
    (is (equal (cdr (assoc "file-read-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "src/core/session-loop.lisp" :start-line 10 :end-line 12)))))

(test plan-session-execution-builds-file-read-multi-range-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "read file src/core/session-loop.lisp :: 10-12,20,25-26"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "file-read-tool"))
    (is (equal (getf first-step :input)
               '(:path "src/core/session-loop.lisp" :start-line nil :end-line nil
                 :ranges ((:start-line 10 :end-line 12)
                          (:start-line 20 :end-line 20)
                          (:start-line 25 :end-line 26)))))
    (is (equal (cdr (assoc "file-read-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "src/core/session-loop.lisp" :start-line nil :end-line nil
                 :ranges ((:start-line 10 :end-line 12)
                          (:start-line 20 :end-line 20)
                          (:start-line 25 :end-line 26)))))))

  (test plan-session-execution-builds-shell-specific-inputs
    (let* ((plan (cl-cc.services:plan-session-execution "run shell git status :: ."))
      (steps (getf plan :steps))
      (first-step (first steps)))
      (is (equal (getf plan :tool-ids)
       '("shell-tool" "echo-tool" "failing-tool")))
      (is (string= (getf first-step :tool) "shell-tool"))
      (is (equal (getf first-step :input)
       (list :command "git status"
        :directory (uiop:native-namestring (uiop:ensure-directory-pathname "."))
        :background nil)))
      (is (equal (cdr (assoc "shell-tool" (getf plan :tool-inputs) :test #'string=))
       (list :command "git status"
        :directory (uiop:native-namestring (uiop:ensure-directory-pathname "."))
        :background nil)))))

(test plan-session-execution-builds-grep-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "grep permission :: src"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("grep-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "grep-tool"))
    (is (equal (getf first-step :input)
               '(:queries ("permission") :query "permission" :root "src")))
    (is (equal (cdr (assoc "grep-tool" (getf plan :tool-inputs) :test #'string=))
               '(:queries ("permission") :query "permission" :root "src")))))

(test plan-session-execution-builds-multi-query-grep-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "grep permission || audit :: src"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("grep-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "grep-tool"))
    (is (equal (getf first-step :input)
               '(:queries ("permission" "audit") :query "permission" :root "src")))
    (is (equal (cdr (assoc "grep-tool" (getf plan :tool-inputs) :test #'string=))
               '(:queries ("permission" "audit") :query "permission" :root "src")))))

(test plan-session-execution-honors-tool-overrides
  (let* ((plan (cl-cc.services:plan-session-execution "read file README.md"
                                                      :tool-ids-override '("echo-tool")))
         (steps (getf plan :steps)))
    (is (equal (getf plan :tool-ids) '("echo-tool")))
    (is (equal steps '((:tool "echo-tool" :input "read file README.md"))))))