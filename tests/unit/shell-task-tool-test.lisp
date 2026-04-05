;;;; tests/unit/shell-task-tool-test.lisp - shell-task-tool 单元测试
(in-package :cl-cc/tests)

(def-suite shell-task-tool-test :in cl-cc-suite)

(in-suite shell-task-tool-test)

(defun %shell-task-test-power-shell-literal (value)
  (cl-ppcre:regex-replace-all "'" value "''"))

(defun %shell-task-test-child-survival-command (marker-path)
  (let ((quoted-path (%shell-task-test-power-shell-literal marker-path)))
    (format nil
            (concatenate 'string
                         "$child = Start-Process powershell -WindowStyle Hidden -PassThru "
                         "-ArgumentList '-NoProfile','-NonInteractive','-Command',"
                         "\"Start-Sleep -Seconds 2; Set-Content -Path ''~A'' -Value ''child-alive''\"; "
                         "Start-Sleep -Seconds 30")
            quoted-path)))

(test normalized-shell-task-input-parses-natural-language-and-structured-input
  (is (equal (cl-cc.tools::%normalized-shell-task-input "shell task shell-task-123")
             '(:task-id "shell-task-123" :task-ids nil :action :status :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input "inspect shell task shell-task-123")
             '(:task-id "shell-task-123" :task-ids nil :action :status :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input "stop shell task shell-task-123")
             '(:task-id "shell-task-123" :task-ids nil :action :stop :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input "interrupt task shell-task-123")
             '(:task-id "shell-task-123" :task-ids nil :action :interrupt :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input "ctrl-c tasks shell-task-123, shell-task-456")
             '(:task-id nil :task-ids ("shell-task-123" "shell-task-456") :action :interrupt :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input "cancel task shell-task-123")
             '(:task-id "shell-task-123" :task-ids nil :action :stop :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input "wait shell task shell-task-123 :: 1.5")
             '(:task-id "shell-task-123" :task-ids nil :action :wait :timeout-seconds 1.5)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input "wait tasks shell-task-123, shell-task-456 :: 1.5")
             '(:task-id nil :task-ids ("shell-task-123" "shell-task-456") :action :wait :timeout-seconds 1.5)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input "join task shell-task-123")
             '(:task-id "shell-task-123" :task-ids nil :action :wait :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input '(:task-id "shell-task-123" :action "stop"))
             '(:task-id "shell-task-123" :task-ids nil :action :stop :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input '(:taskId "shell-task-123" :action "interrupt"))
             '(:task-id "shell-task-123" :task-ids nil :action :interrupt :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input '(:taskId "shell-task-123" :action "cancel"))
             '(:task-id "shell-task-123" :task-ids nil :action :stop :timeout-seconds nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input '(:taskId "shell-task-123" :action "wait" :timeoutSeconds 2))
             '(:task-id "shell-task-123" :task-ids nil :action :wait :timeout-seconds 2)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input '(:taskIds ("shell-task-123" "shell-task-456") :action "wait" :timeoutSeconds 2))
             '(:task-id nil :task-ids ("shell-task-123" "shell-task-456") :action :wait :timeout-seconds 2)))
  (is (equal (cl-cc.tools::%normalized-shell-task-input '(:taskId "shell-task-123"))
             '(:task-id "shell-task-123" :task-ids nil :action :status :timeout-seconds nil))))

(test shell-task-tool-signals-stable-error-for-missing-task
  (handler-case
      (progn
        (cl-cc.tools:shell-task-tool '(:task-id "shell-task-missing"))
        (fail "expected shell-task-tool error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :shell-execution-failed))
      (is (search "未找到后台任务" (cl-cc.lib:error-message condition))))))

(test shell-task-tool-can-query-and-stop-background-task
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-ok')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let* ((status-result (cl-cc.tools:shell-task-tool (list :task-id task-id)))
                (stop-result (cl-cc.tools:shell-task-tool (list :task-id task-id :action :stop)))
                (final-result (cl-cc.tools:shell-task-tool (list :task-id task-id))))
           (is (string= (getf status-result :task-id) task-id))
           (is (string= (getf status-result :status) "running"))
           (is (getf status-result :running))
           (is (not (getf status-result :stopped)))
           (is (not (getf status-result :stall-detected)))
           (is (null (getf status-result :stall-detected-at)))
           (is (null (getf status-result :stall-prompt-line)))
           (is (not (getf status-result :timed-out)))
           (is (string= (getf status-result :output-path) output-path))
           (is (string= (getf stop-result :status) "stopped"))
           (is (not (getf stop-result :running)))
           (is (getf stop-result :stopped))
           (is (string= (getf stop-result :action) "stop"))
           (is (string= (getf stop-result :termination-reason) "stop"))
           (is (stringp (getf stop-result :ended-at)))
           (is (not (getf stop-result :timed-out)))
           (is (string= (getf final-result :status) "stopped"))
           (is (getf final-result :stopped))
           (is (string= (getf final-result :termination-reason) "stop"))
           (is (stringp (getf final-result :ended-at))))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test shell-task-tool-can-interrupt-background-task
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-interrupt-ok')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let* ((interrupt-result (cl-cc.tools:shell-task-tool (list :task-id task-id :action :interrupt)))
                (final-result (cl-cc.tools:shell-task-tool (list :task-id task-id))))
           (is (string= (getf interrupt-result :action) "interrupt"))
           (is (string= (getf interrupt-result :status) "stopped"))
           (is (not (getf interrupt-result :running)))
           (is (getf interrupt-result :stopped))
           (is (string= (getf interrupt-result :termination-reason) "interrupt"))
           (is (stringp (getf interrupt-result :ended-at)))
           (is (not (getf interrupt-result :timed-out)))
           (is (string= (getf final-result :status) "stopped"))
           (is (getf final-result :stopped))
           (is (string= (getf final-result :termination-reason) "interrupt"))
           (is (stringp (getf final-result :ended-at))))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test shell-task-tool-can-wait-for-background-task
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Milliseconds 300; [Console]::Out.Write('shell-task-wait-ok')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let ((wait-result (cl-cc.tools:shell-task-tool (list :task-id task-id :action :wait))))
           (is (string= (getf wait-result :task-id) task-id))
           (is (string= (getf wait-result :action) "wait"))
           (is (string= (getf wait-result :status) "completed"))
           (is (not (getf wait-result :running)))
           (is (not (getf wait-result :timed-out)))
           (is (string= (getf wait-result :output-path) output-path))
           (is (string= (getf wait-result :termination-reason) "exit"))
           (is (stringp (getf wait-result :ended-at)))
           (is (= (getf wait-result :exit-code) 0)))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test shell-task-tool-wait-can-time-out-without-stopping-task
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 2; [Console]::Out.Write('shell-task-wait-timeout')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let ((wait-result (cl-cc.tools:shell-task-tool (list :task-id task-id :action :wait :timeout-seconds 0.1))))
           (is (string= (getf wait-result :action) "wait"))
           (is (string= (getf wait-result :status) "running"))
           (is (getf wait-result :running))
           (is (getf wait-result :timed-out))
           (is (not (getf wait-result :stall-detected)))
           (is (null (getf wait-result :stall-detected-at)))
           (is (null (getf wait-result :stall-prompt-line)))
           (is (null (getf wait-result :termination-reason)))
           (is (null (getf wait-result :ended-at)))
           (is (null (getf wait-result :exit-code))))
      (when task-id
        (ignore-errors (cl-cc.tools:shell-task-tool (list :task-id task-id :action :stop)))
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test shell-task-tool-can-stop-multiple-background-tasks
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result-a (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-batch-stop-a')"
                                                       :directory directory
                                                       :background t)))
         (start-result-b (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-batch-stop-b')"
                                                       :directory directory
                                                       :background t)))
         (task-id-a (getf start-result-a :background-task-id))
         (task-id-b (getf start-result-b :background-task-id))
         (output-path-a (getf start-result-a :output-path))
         (output-path-b (getf start-result-b :output-path)))
    (unwind-protect
         (let ((stop-result (cl-cc.tools:shell-task-tool (list :task-ids (list task-id-a task-id-b) :action :stop))))
           (is (null (getf stop-result :task-id)))
           (is (equal (getf stop-result :task-ids) (list task-id-a task-id-b)))
           (is (= (getf stop-result :task-count) 2))
           (is (= (getf stop-result :stopped-count) 2))
           (is (string= (getf stop-result :status) "stopped"))
           (is (getf stop-result :stopped))
           (is (not (getf stop-result :running)))
           (is (not (getf stop-result :timed-out)))
           (is (= (length (getf stop-result :tasks)) 2))
           (is (every (lambda (task) (string= (getf task :status) "stopped"))
                      (getf stop-result :tasks))))
      (when task-id-a
        (remhash task-id-a cl-cc.tools::*shell-background-task-registry*))
      (when task-id-b
        (remhash task-id-b cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path-a (probe-file output-path-a))
        (ignore-errors (delete-file output-path-a)))
      (when (and output-path-b (probe-file output-path-b))
        (ignore-errors (delete-file output-path-b))))))

(test shell-task-tool-can-report-stalled-background-task
  (let ((cl-cc.tools::+shell-background-stall-check-interval-seconds+ 0.05)
        (cl-cc.tools::+shell-background-stall-threshold-seconds+ 0.15)
        (cl-cc.tools::+shell-background-stall-tail-bytes+ 256))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('Continue?'); Start-Sleep -Seconds 2"
                                                       :directory directory
                                                       :background t)))
           (task-id (getf start-result :background-task-id))
           (output-path (getf start-result :output-path)))
      (unwind-protect
           (progn
             (sleep 0.45)
             (let* ((status-result (cl-cc.tools:shell-task-tool (list :task-id task-id)))
                    (detail-result (cl-cc.tools:shell-task-detail-tool (list :task-id task-id)))
                    (list-task (find task-id
                                     (getf (cl-cc.tools:shell-task-list-tool nil) :tasks)
                                     :key (lambda (task) (getf task :task-id))
                                     :test #'string=)))
               (is (string= (getf status-result :status) "running"))
               (is (getf status-result :stall-detected))
               (is (stringp (getf status-result :stall-detected-at)))
               (is (string= (getf status-result :stall-prompt-line) "Continue?"))
               (is (string= (getf detail-result :status) "running"))
               (is (getf detail-result :stall-detected))
               (is (stringp (getf detail-result :stall-detected-at)))
               (is (string= (getf detail-result :stall-prompt-line) "Continue?"))
               (is (not (null list-task)))
               (is (getf list-task :stall-detected))
               (is (stringp (getf list-task :stall-detected-at)))
               (is (string= (getf list-task :stall-prompt-line) "Continue?"))))
        (when task-id
          (ignore-errors (cl-cc.tools:shell-task-tool (list :task-id task-id :action :stop)))
          (remhash task-id cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and output-path (probe-file output-path))
          (ignore-errors (delete-file output-path)))))))

(test shell-task-tool-stop-recursively-terminates-child-processes
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (marker-path (uiop:native-namestring
                       (uiop:merge-pathnames* "shell-task-child-alive.txt"
                                              (uiop:temporary-directory))))
         (start-result (cl-cc.tools:shell-tool (list :command (%shell-task-test-child-survival-command marker-path)
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (when (probe-file marker-path)
      (delete-file marker-path))
    (unwind-protect
         (progn
           (sleep 0.4)
           (let ((stop-result (cl-cc.tools:shell-task-tool (list :task-id task-id :action :stop))))
             (is (string= (getf stop-result :status) "stopped"))
             (is (string= (getf stop-result :action) "stop")))
           (sleep 3.0)
           (is (not (probe-file marker-path))))
      (when task-id
        (ignore-errors (cl-cc.tools:shell-task-tool (list :task-id task-id :action :stop)))
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path)))
      (when (probe-file marker-path)
        (ignore-errors (delete-file marker-path))))))

(test shell-task-tool-can-wait-for-multiple-background-tasks
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result-a (cl-cc.tools:shell-tool (list :command "Start-Sleep -Milliseconds 200; [Console]::Out.Write('shell-task-batch-wait-a')"
                                                       :directory directory
                                                       :background t)))
         (start-result-b (cl-cc.tools:shell-tool (list :command "Start-Sleep -Milliseconds 250; [Console]::Out.Write('shell-task-batch-wait-b')"
                                                       :directory directory
                                                       :background t)))
         (task-id-a (getf start-result-a :background-task-id))
         (task-id-b (getf start-result-b :background-task-id))
         (output-path-a (getf start-result-a :output-path))
         (output-path-b (getf start-result-b :output-path)))
    (unwind-protect
         (let ((wait-result (cl-cc.tools:shell-task-tool (list :task-ids (list task-id-a task-id-b) :action :wait))))
           (is (null (getf wait-result :task-id)))
           (is (equal (getf wait-result :task-ids) (list task-id-a task-id-b)))
           (is (= (getf wait-result :task-count) 2))
           (is (= (getf wait-result :completed-count) 2))
           (is (string= (getf wait-result :action) "wait"))
           (is (string= (getf wait-result :status) "completed"))
           (is (not (getf wait-result :running)))
           (is (not (getf wait-result :timed-out)))
           (is (= (length (getf wait-result :tasks)) 2))
           (is (every (lambda (task) (string= (getf task :status) "completed"))
                      (getf wait-result :tasks))))
      (when task-id-a
        (remhash task-id-a cl-cc.tools::*shell-background-task-registry*))
      (when task-id-b
        (remhash task-id-b cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path-a (probe-file output-path-a))
        (ignore-errors (delete-file output-path-a)))
      (when (and output-path-b (probe-file output-path-b))
        (ignore-errors (delete-file output-path-b))))))