;;;; tests/unit/shell-task-output-tool-test.lisp - shell-task-output-tool 单元测试
(in-package :cl-cc/tests)

(def-suite shell-task-output-tool-test :in cl-cc-suite)

(in-suite shell-task-output-tool-test)

(test normalized-shell-task-output-input-parses-natural-language-and-structured-input
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input "shell task output shell-task-123")
             '(:task-id "shell-task-123" :lines 20 :start-line nil :end-line nil :follow-seconds nil :wait-until-finished nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input "读取后台任务输出 shell-task-123 :: 5")
             '(:task-id "shell-task-123" :lines 5 :start-line nil :end-line nil :follow-seconds nil :wait-until-finished nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input "shell task output shell-task-123 :: start=2 :: end=4")
             '(:task-id "shell-task-123" :lines 3 :start-line 2 :end-line 4 :follow-seconds nil :wait-until-finished nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input "follow shell task output shell-task-123 :: start=2")
             '(:task-id "shell-task-123" :lines 20 :start-line 2 :end-line nil :follow-seconds 2 :wait-until-finished nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input "wait shell task output shell-task-123 :: start=2")
             '(:task-id "shell-task-123" :lines 20 :start-line 2 :end-line nil :follow-seconds nil :wait-until-finished t)))
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input "wait shell task outputs shell-task-123, shell-task-456 :: start=2 :: lines=3")
             '(:task-id nil :task-ids ("shell-task-123" "shell-task-456") :lines 3 :start-line 2 :end-line nil :follow-seconds nil :wait-until-finished t)))
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input '(:taskId "shell-task-123" :startLine 3 :lines 2 :follow t))
             '(:task-id "shell-task-123" :lines 2 :start-line 3 :end-line nil :follow-seconds 2 :wait-until-finished nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input '(:taskIds ("shell-task-123" "shell-task-456") :startLine 3 :lines 2 :waitUntilFinished t))
             '(:task-id nil :task-ids ("shell-task-123" "shell-task-456") :lines 2 :start-line 3 :end-line nil :follow-seconds nil :wait-until-finished t)))
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input '(:lines 4
                                                                  :tasks ((:taskId "shell-task-123" :startLine 3)
                                                                          (:taskId "shell-task-456" :lines 2 :waitUntilFinished t))))
             '(:task-id nil
               :task-requests ((:task-id "shell-task-123" :lines 4 :start-line 3 :end-line nil :follow-seconds nil :wait-until-finished nil)
                               (:task-id "shell-task-456" :lines 2 :start-line nil :end-line nil :follow-seconds nil :wait-until-finished t))
               :lines 4 :start-line nil :end-line nil :follow-seconds nil :wait-until-finished nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-output-input '(:taskId "shell-task-123" :startLine 3 :lines 2 :waitUntilFinished t))
             '(:task-id "shell-task-123" :lines 2 :start-line 3 :end-line nil :follow-seconds nil :wait-until-finished t)))
  (is (null (cl-cc.tools::%normalized-shell-task-output-input "   "))))

(test shell-task-output-tool-signals-stable-error-for-missing-task
  (handler-case
      (progn
        (cl-cc.tools:shell-task-output-tool '(:task-id "shell-task-missing"))
        (fail "expected shell-task-output-tool error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :shell-execution-failed))
      (is (search "未找到后台任务" (cl-cc.lib:error-message condition))))))

(test shell-task-output-tool-reads-recent-output-with-absolute-line-numbers
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('alpha'); [Console]::Out.WriteLine('beta'); [Console]::Out.WriteLine('gamma')"
                                                       :directory directory
                                                       :background t)))
           (task-id (getf start-result :background-task-id))
           (output-path (getf start-result :output-path)))
      (unwind-protect
           (progn
             (sleep 0.4)
             (let ((result (cl-cc.tools:shell-task-output-tool (list :task-id task-id :lines 2))))
               (is (string= (getf result :task-id) task-id))
               (is (string= (getf result :mode) "tail"))
               (is (string= (getf result :output-path) output-path))
               (is (= (getf result :lines-requested) 2))
               (is (null (getf result :requested-start-line)))
               (is (null (getf result :requested-end-line)))
               (is (null (getf result :follow-seconds)))
               (is (not (getf result :wait-until-finished)))
               (is (= (getf result :start-line) 2))
               (is (= (getf result :end-line) 3))
               (is (= (getf result :total-lines) 3))
               (is (string= (getf result :content)
                            (format nil "2:beta~%3:gamma")))))
        (when task-id
          (remhash task-id cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and output-path (probe-file output-path))
          (ignore-errors (delete-file output-path)))))))

(test shell-task-output-tool-supports-range-and-follow-window
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('follow-1'); Start-Sleep -Milliseconds 150; [Console]::Out.WriteLine('follow-2'); Start-Sleep -Milliseconds 150; [Console]::Out.WriteLine('follow-3')"
                                                       :directory directory
                                                       :background t)))
           (task-id (getf start-result :background-task-id))
           (output-path (getf start-result :output-path)))
      (unwind-protect
           (progn
             (sleep 0.05)
             (let ((result (cl-cc.tools:shell-task-output-tool (list :task-id task-id :start-line 2 :lines 5 :follow-seconds 1))))
               (is (string= (getf result :task-id) task-id))
               (is (string= (getf result :mode) "range"))
               (is (= (getf result :lines-requested) 5))
               (is (= (getf result :requested-start-line) 2))
               (is (= (getf result :requested-end-line) 6))
               (is (= (getf result :follow-seconds) 1))
               (is (not (getf result :wait-until-finished)))
               (is (= (getf result :start-line) 2))
               (is (= (getf result :end-line) 3))
               (is (= (getf result :total-lines) 3))
               (is (string= (getf result :output-path) output-path))
               (is (search "2:follow-2" (getf result :content)))
               (is (search "3:follow-3" (getf result :content)))))
        (when task-id
          (remhash task-id cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and output-path (probe-file output-path))
          (ignore-errors (delete-file output-path)))))))

(test shell-task-output-tool-can-wait-until-background-task-finishes
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('block-1'); Start-Sleep -Milliseconds 200; [Console]::Out.WriteLine('block-2'); Start-Sleep -Milliseconds 200; [Console]::Out.WriteLine('block-3')"
                                                       :directory directory
                                                       :background t)))
           (task-id (getf start-result :background-task-id))
           (output-path (getf start-result :output-path)))
      (unwind-protect
           (let ((result (cl-cc.tools:shell-task-output-tool (list :task-id task-id :start-line 1 :lines 5 :wait-until-finished t))))
             (is (string= (getf result :task-id) task-id))
             (is (getf result :wait-until-finished))
             (is (string= (getf result :status) "completed"))
             (is (not (getf result :running)))
             (is (null (getf result :follow-seconds)))
             (is (= (getf result :start-line) 1))
             (is (= (getf result :end-line) 3))
             (is (= (getf result :total-lines) 3))
             (is (search "3:block-3" (getf result :content))))
        (when task-id
          (remhash task-id cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and output-path (probe-file output-path))
          (ignore-errors (delete-file output-path)))))))

(test shell-task-output-tool-can-read-multiple-background-task-outputs
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (start-result-a (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('batch-1a'); [Console]::Out.WriteLine('batch-1b'); [Console]::Out.WriteLine('batch-1c')"
                                                         :directory directory
                                                         :background t)))
           (start-result-b (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('batch-2a'); [Console]::Out.WriteLine('batch-2b'); [Console]::Out.WriteLine('batch-2c')"
                                                         :directory directory
                                                         :background t)))
           (task-id-a (getf start-result-a :background-task-id))
           (task-id-b (getf start-result-b :background-task-id))
           (output-path-a (getf start-result-a :output-path))
           (output-path-b (getf start-result-b :output-path)))
      (unwind-protect
           (progn
             (sleep 0.4)
             (let ((result (cl-cc.tools:shell-task-output-tool (list :task-ids (list task-id-a task-id-b)
                                                                     :lines 2))))
               (is (null (getf result :task-id)))
               (is (equal (getf result :task-ids) (list task-id-a task-id-b)))
               (is (= (getf result :task-count) 2))
               (is (string= (getf result :mode) "tail"))
               (is (string= (getf result :status) "completed"))
               (is (not (getf result :running)))
               (is (not (getf result :stopped)))
               (is (null (getf result :output-path)))
               (is (= (getf result :lines-requested) 2))
               (is (null (getf result :requested-start-line)))
               (is (null (getf result :requested-end-line)))
               (is (null (getf result :follow-seconds)))
               (is (not (getf result :wait-until-finished)))
               (is (null (getf result :start-line)))
               (is (null (getf result :end-line)))
               (is (null (getf result :total-lines)))
               (is (= (getf result :completed-count) 2))
               (is (= (length (getf result :tasks)) 2))
               (is (null (getf result :content)))
               (let ((task-a (find task-id-a (getf result :tasks) :key (lambda (task)
                                                                          (getf task :task-id))
                                   :test #'string=))
                     (task-b (find task-id-b (getf result :tasks) :key (lambda (task)
                                                                          (getf task :task-id))
                                   :test #'string=)))
                 (is (string= (getf task-a :output-path) output-path-a))
                 (is (string= (getf task-b :output-path) output-path-b))
                 (is (string= (getf task-a :content) (format nil "2:batch-1b~%3:batch-1c")))
                 (is (string= (getf task-b :content) (format nil "2:batch-2b~%3:batch-2c"))))))
        (when task-id-a
          (remhash task-id-a cl-cc.tools::*shell-background-task-registry*))
        (when task-id-b
          (remhash task-id-b cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and output-path-a (probe-file output-path-a))
          (ignore-errors (delete-file output-path-a)))
        (when (and output-path-b (probe-file output-path-b))
          (ignore-errors (delete-file output-path-b))))))

(test shell-task-output-tool-can-apply-per-task-window-overrides
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (start-result-a (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('task-a1'); [Console]::Out.WriteLine('task-a2'); [Console]::Out.WriteLine('task-a3'); [Console]::Out.WriteLine('task-a4')"
                                                         :directory directory
                                                         :background t)))
           (start-result-b (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('task-b1'); [Console]::Out.WriteLine('task-b2'); [Console]::Out.WriteLine('task-b3'); [Console]::Out.WriteLine('task-b4')"
                                                         :directory directory
                                                         :background t)))
           (task-id-a (getf start-result-a :background-task-id))
           (task-id-b (getf start-result-b :background-task-id))
           (output-path-a (getf start-result-a :output-path))
           (output-path-b (getf start-result-b :output-path)))
      (unwind-protect
           (progn
             (sleep 0.4)
             (let ((result (cl-cc.tools:shell-task-output-tool
                            (list :tasks (list (list :task-id task-id-a :start-line 2 :end-line 3)
                                               (list :task-id task-id-b :lines 1 :wait-until-finished t))))))
               (is (string= (getf result :mode) "mixed"))
               (is (null (getf result :lines-requested)))
               (is (null (getf result :requested-start-line)))
               (is (null (getf result :requested-end-line)))
               (is (null (getf result :wait-until-finished)))
               (is (= (getf result :completed-count) 2))
               (let ((task-a (find task-id-a (getf result :tasks) :key (lambda (task) (getf task :task-id)) :test #'string=))
                     (task-b (find task-id-b (getf result :tasks) :key (lambda (task) (getf task :task-id)) :test #'string=)))
                 (is (string= (getf task-a :mode) "range"))
                 (is (= (getf task-a :requested-start-line) 2))
                 (is (= (getf task-a :requested-end-line) 3))
                 (is (string= (getf task-a :content) (format nil "2:task-a2~%3:task-a3")))
                 (is (string= (getf task-b :mode) "tail"))
                 (is (= (getf task-b :lines-requested) 1))
                 (is (getf task-b :wait-until-finished))
                 (is (string= (getf task-b :content) "4:task-b4"))))))
        (when task-id-a
          (remhash task-id-a cl-cc.tools::*shell-background-task-registry*))
        (when task-id-b
          (remhash task-id-b cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and output-path-a (probe-file output-path-a))
          (ignore-errors (delete-file output-path-a)))
        (when (and output-path-b (probe-file output-path-b))
          (ignore-errors (delete-file output-path-b)))))))