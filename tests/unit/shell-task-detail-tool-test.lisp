;;;; tests/unit/shell-task-detail-tool-test.lisp - shell-task-detail-tool 单元测试
(in-package :cl-cc/tests)

(def-suite shell-task-detail-tool-test :in cl-cc-suite)

(in-suite shell-task-detail-tool-test)

(test normalized-shell-task-detail-input-parses-natural-language-and-structured-input
  (is (equal (cl-cc.tools::%normalized-shell-task-detail-input "shell task detail shell-task-123")
             '(:task-id "shell-task-123")))
  (is (equal (cl-cc.tools::%normalized-shell-task-detail-input "后台任务详情shell-task-123")
             '(:task-id "shell-task-123")))
  (is (equal (cl-cc.tools::%normalized-shell-task-detail-input '(:taskId "shell-task-123"))
             '(:task-id "shell-task-123"))))

(test shell-task-detail-tool-signals-stable-error-for-missing-task
  (handler-case
      (progn
        (cl-cc.tools:shell-task-detail-tool '(:task-id "shell-task-missing"))
        (fail "expected shell-task-detail-tool error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :shell-execution-failed))
      (is (search "未找到后台任务" (cl-cc.lib:error-message condition))))))

(test shell-task-detail-tool-returns-lifecycle-fields-for-background-task
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('shell-task-detail-1'); [Console]::Out.WriteLine('shell-task-detail-2'); Start-Sleep -Seconds 5"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (progn
           (sleep 0.4)
           (let ((detail-result (cl-cc.tools:shell-task-detail-tool (list :task-id task-id))))
           (is (string= (getf detail-result :task-id) task-id))
           (is (string= (getf detail-result :status) "running"))
           (is (getf detail-result :running))
           (is (not (getf detail-result :stopped)))
           (is (string= (getf detail-result :output-path) output-path))
           (is (stringp (getf detail-result :started-at)))
           (is (null (getf detail-result :stopped-at)))
           (is (null (getf detail-result :finished-at)))
           (is (not (getf detail-result :stall-detected)))
           (is (null (getf detail-result :stall-detected-at)))
           (is (null (getf detail-result :stall-prompt-line)))
           (is (null (getf detail-result :termination-reason)))
           (is (null (getf detail-result :ended-at)))
           (is (numberp (getf detail-result :duration-seconds)))
           (is (integerp (getf detail-result :output-bytes)))
           (is (> (getf detail-result :output-bytes) 0))
           (is (= (getf detail-result :output-line-count) 2))
           (is (stringp (getf detail-result :output-updated-at)))))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))