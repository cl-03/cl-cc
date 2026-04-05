;;;; tests/unit/todo-write-tool-test.lisp - todo-write-tool 单元测试
(in-package :cl-cc/tests)

(def-suite todo-write-tool-test :in cl-cc-suite)

(in-suite todo-write-tool-test)

(test normalized-todo-write-input-supports-structured-and-natural-language-input
  (is (equal (cl-cc.tools::%normalized-todo-write-input
              '(:todos ((:content "Implement todo tool" :status :in-progress :active-form "Implementing todo tool")
                        (:content "Run tests" :status :pending :active-form "Running tests"))))
             '(:todos ((:content "Implement todo tool" :status "in_progress" :active-form "Implementing todo tool")
                       (:content "Run tests" :status "pending" :active-form "Running tests")))))
  (is (equal (cl-cc.tools::%normalized-todo-write-input
              "todo write Implement todo tool | in_progress | Implementing todo tool ;; Run tests | pending | Running tests")
             '(:todos ((:content "Implement todo tool" :status "in_progress" :active-form "Implementing todo tool")
                       (:content "Run tests" :status "pending" :active-form "Running tests"))))))

(test todo-write-tool-signals-stable-error-for-invalid-input
  (handler-case
      (progn
        (cl-cc.tools:todo-write-tool "todo write only content")
        (fail "expected todo-write-tool to signal"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :todo-write-failed)))))

(test todo-write-tool-updates-active-session-and-returns-old-and-new-todos
  (let ((session (make-instance 'cl-cc.models:session-state
                                :session-id "todo-session"
                                :created-at "now"
                                :updated-at "now"
                                :history-index nil
                                :context-summary nil
                                :tasks nil
                                :todo-list '((:content "Old task" :status "pending" :active-form "Old task"))
                                :permission-snapshot nil
                                :status :active
                                :version "0.1")))
    (let ((cl-cc.models:*active-session* session))
      (let ((result (cl-cc.tools:todo-write-tool
                     '(:todos ((:content "Implement todo tool" :status :in-progress :active-form "Implementing todo tool")
                               (:content "Run tests" :status :pending :active-form "Running tests"))))))
        (is (string= (getf result :summary)
                     "更新待办列表: 2 项（进行中 1，待处理 1，已完成 0）"))
        (is (equal (getf result :old-todos)
                   '((:content "Old task" :status "pending" :active-form "Old task"))))
        (is (equal (cl-cc.models:session-todo-list session)
                   '((:content "Implement todo tool" :status "in_progress" :active-form "Implementing todo tool")
                     (:content "Run tests" :status "pending" :active-form "Running tests"))))))))