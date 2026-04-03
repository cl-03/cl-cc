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
  (is (equal (cl-cc.services:select-tools "请替换文件 docs/spec.txt :: before :: after")
             '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool"))))

(test select-tools-prefers-grep-tool-for-code-search-intent
  (is (equal (cl-cc.services:select-tools "grep session-loop")
             '("grep-tool" "file-read-tool" "echo-tool" "failing-tool")))
  (is (equal (cl-cc.services:select-tools "搜索代码 permission")
             '("grep-tool" "file-read-tool" "echo-tool" "failing-tool"))))

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
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil)))
    (is (equal (cdr (assoc "file-edit-tool" (getf plan :tool-inputs) :test #'string=))
               '(:path "tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil)))))

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

(test plan-session-execution-builds-grep-specific-inputs
  (let* ((plan (cl-cc.services:plan-session-execution "grep permission :: src"))
         (steps (getf plan :steps))
         (first-step (first steps)))
    (is (equal (getf plan :tool-ids)
               '("grep-tool" "file-read-tool" "echo-tool" "failing-tool")))
    (is (string= (getf first-step :tool) "grep-tool"))
    (is (equal (getf first-step :input)
               '(:query "permission" :root "src")))
    (is (equal (cdr (assoc "grep-tool" (getf plan :tool-inputs) :test #'string=))
               '(:query "permission" :root "src")))))

(test plan-session-execution-honors-tool-overrides
  (let* ((plan (cl-cc.services:plan-session-execution "read file README.md"
                                                      :tool-ids-override '("echo-tool")))
         (steps (getf plan :steps)))
    (is (equal (getf plan :tool-ids) '("echo-tool")))
    (is (equal steps '((:tool "echo-tool" :input "read file README.md"))))))