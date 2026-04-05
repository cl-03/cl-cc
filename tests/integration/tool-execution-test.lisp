;;;; tests/integration/tool-execution-test.lisp - 工具执行集成测试
(in-package :cl-cc/tests)

(def-suite tool-execution-test :in cl-cc-suite)

(in-suite tool-execution-test)

(defun %tool-execution-test-power-shell-literal (value)
  (cl-ppcre:regex-replace-all "'" value "''"))

(defun %tool-execution-test-child-survival-command (marker-path)
  (let ((quoted-path (%tool-execution-test-power-shell-literal marker-path)))
    (format nil
            (concatenate 'string
                         "$child = Start-Process powershell -WindowStyle Hidden -PassThru "
                         "-ArgumentList '-NoProfile','-NonInteractive','-Command',"
                         "\"Start-Sleep -Seconds 2; Set-Content -Path ''~A'' -Value ''child-alive''\"; "
                         "Start-Sleep -Seconds 30")
            quoted-path)))


(test tool-execution-success
  (is (equal (cl-cc.tools:echo-tool "hi") "hi"))
  (is (equal (funcall (cl-cc.tools:find-tool "echo-tool") "ok") "ok")))

(test file-read-tool-reads-file-content
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-read-tool-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "file-read-ok" stream))
           (is (string= (cl-cc.tools:file-read-tool path) "file-read-ok"))
           (is (string= (funcall (cl-cc.tools:find-tool "file-read-tool") path) "file-read-ok")))
      (when (probe-file path)
        (delete-file path)))))

(test file-read-tool-reads-selected-line-range
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-read-tool-range-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "one~%two~%three~%four") stream))
           (is (string= (cl-cc.tools:file-read-tool (list :path path :start-line 2 :end-line 3))
                        (format nil "2:two~%3:three")))
           (is (string= (funcall (cl-cc.tools:find-tool "file-read-tool")
                                 (format nil "~A:4" path))
                        "4:four")))
      (when (probe-file path)
        (delete-file path)))))

(test file-write-tool-writes-file-content
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-write-tool-integration.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (is (string= (cl-cc.tools:file-write-tool (list :path path :content "file-write-ok"))
                        (format nil "写入文件: ~A" path)))
           (is (string= (uiop:read-file-string path) "file-write-ok"))
           (is (string= (funcall (cl-cc.tools:find-tool "file-write-tool")
                                 (list :path path :content "file-write-registry-ok"))
                        (format nil "写入文件: ~A" path)))
           (is (string= (uiop:read-file-string path) "file-write-registry-ok")))
      (when (probe-file path)
        (delete-file path)))))

(test shell-tool-executes-command-and-captures-output
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (direct-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('shell-ok')"
                                                      :directory directory)))
         (registry-result (funcall (cl-cc.tools:find-tool "shell-tool")
                                   (list :command "[Console]::Error.Write('shell-err'); exit 3"
                                         :directory directory))))
    (is (string= (getf direct-result :command) "[Console]::Out.Write('shell-ok')"))
    (is (string= (getf direct-result :directory) directory))
    (is (string= (getf direct-result :stdout) "shell-ok"))
    (is (string= (getf direct-result :stderr) ""))
    (is (= (getf direct-result :exit-code) 0))
    (is (not (getf direct-result :timed-out)))
    (is (search "shell exit 0" (getf direct-result :summary)))
    (is (string= (getf registry-result :stderr) "shell-err"))
    (is (= (getf registry-result :exit-code) 3))
    (is (not (getf registry-result :timed-out)))))

(test shell-task-list-tool-lists-background-tasks-via-registry
  (let* ((directory-root (uiop:temporary-directory))
         (directory-a-path (uiop:merge-pathnames* "shell-task-list-int-a/" directory-root))
         (directory-b-path (uiop:merge-pathnames* "shell-task-list-int-b/" directory-root))
         (directory-setup-a (ensure-directories-exist (uiop:merge-pathnames* "touch.txt" directory-a-path)))
         (directory-setup-b (ensure-directories-exist (uiop:merge-pathnames* "touch.txt" directory-b-path)))
         (directory-a (uiop:native-namestring (uiop:ensure-directory-pathname directory-a-path)))
         (directory-b (uiop:native-namestring (uiop:ensure-directory-pathname directory-b-path)))
         (running-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-list-running')"
                                                       :directory directory-a
                                                       :background t)))
         (completed-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('shell-task-list-completed')"
                                                         :directory directory-b
                                                         :background t)))
         (stopped-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-list-stopped')"
                                                       :directory directory-a
                                                       :background t)))
         (interrupted-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-list-interrupted')"
                                                           :directory directory-b
                                                           :background t)))
         (running-task-id (getf running-result :background-task-id))
         (completed-task-id (getf completed-result :background-task-id))
         (stopped-task-id (getf stopped-result :background-task-id))
         (interrupted-task-id (getf interrupted-result :background-task-id))
         (running-output-path (getf running-result :output-path))
         (completed-output-path (getf completed-result :output-path))
         (stopped-output-path (getf stopped-result :output-path))
         (interrupted-output-path (getf interrupted-result :output-path)))
          (declare (ignore directory-setup-a directory-setup-b))
    (unwind-protect
         (progn
           (sleep 0.4)
           (cl-cc.tools:shell-task-tool (list :task-id stopped-task-id :action :stop))
           (cl-cc.tools:shell-task-tool (list :task-id interrupted-task-id :action :interrupt))
           (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-list-tool"))
                  (result (funcall tool-fn nil))
                  (tasks (getf result :tasks))
                  (running-task (find running-task-id tasks :key (lambda (task)
                                                                   (getf task :task-id))
                                      :test #'string=))
                  (completed-task (find completed-task-id tasks :key (lambda (task)
                                                                       (getf task :task-id))
                                        :test #'string=))
                  (stopped-task (find stopped-task-id tasks :key (lambda (task)
                                                                   (getf task :task-id))
                                      :test #'string=))
                  (interrupted-task (find interrupted-task-id tasks :key (lambda (task)
                                                                          (getf task :task-id))
                                         :test #'string=)))
             (is (>= (getf result :total-count) 4))
             (is (string= (getf result :status-filter) "all"))
             (is (null (getf result :task-id-prefix-filter)))
             (is (null (getf result :directory-contains-filter)))
             (is (null (getf result :termination-reason-filter)))
             (is (not (null running-task)))
             (is (not (null completed-task)))
             (is (not (null stopped-task)))
             (is (not (null interrupted-task)))
             (is (string= (getf running-task :status) "running"))
             (is (not (getf running-task :stall-detected)))
             (is (null (getf running-task :termination-reason)))
             (is (null (getf running-task :ended-at)))
             (is (string= (getf completed-task :status) "completed"))
             (is (not (getf completed-task :stall-detected)))
             (is (string= (getf completed-task :termination-reason) "exit"))
             (is (stringp (getf completed-task :ended-at)))
             (is (string= (getf stopped-task :status) "stopped"))
             (is (not (getf stopped-task :stall-detected)))
             (is (string= (getf stopped-task :termination-reason) "stop"))
             (is (stringp (getf stopped-task :ended-at)))
             (is (string= (getf interrupted-task :status) "stopped"))
             (is (not (getf interrupted-task :stall-detected)))
             (is (string= (getf interrupted-task :termination-reason) "interrupt"))
             (is (stringp (getf interrupted-task :ended-at)))
             (let ((running-only (funcall tool-fn '(:status :running))))
               (is (string= (getf running-only :status-filter) "running"))
               (is (= (getf running-only :total-count)
                      (getf running-only :running-count))))
             (let ((task-filtered (funcall tool-fn (list :task-id-prefix running-task-id))))
               (is (string= (getf task-filtered :task-id-prefix-filter) running-task-id))
               (is (= (getf task-filtered :total-count) 1)))
             (let ((directory-filtered (funcall tool-fn (list :directory-contains "shell-task-list-int-b"))))
               (is (string= (getf directory-filtered :directory-contains-filter) "shell-task-list-int-b"))
               (is (= (getf directory-filtered :total-count) 2)))
             (let ((termination-filtered (funcall tool-fn '(:termination-reason "interrupt"))))
               (is (string= (getf termination-filtered :termination-reason-filter) "interrupt"))
               (is (= (getf termination-filtered :total-count) 1))
               (is (string= (getf (first (getf termination-filtered :tasks)) :task-id)
                            interrupted-task-id)))))
      (when running-task-id
        (remhash running-task-id cl-cc.tools::*shell-background-task-registry*))
      (when completed-task-id
        (remhash completed-task-id cl-cc.tools::*shell-background-task-registry*))
      (when stopped-task-id
        (remhash stopped-task-id cl-cc.tools::*shell-background-task-registry*))
      (when interrupted-task-id
        (remhash interrupted-task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and running-output-path (probe-file running-output-path))
        (ignore-errors (delete-file running-output-path)))
      (when (and completed-output-path (probe-file completed-output-path))
        (ignore-errors (delete-file completed-output-path)))
      (when (and stopped-output-path (probe-file stopped-output-path))
        (ignore-errors (delete-file stopped-output-path)))
      (when (and interrupted-output-path (probe-file interrupted-output-path))
        (ignore-errors (delete-file interrupted-output-path))))))

(test shell-task-cleanup-tool-cleans-non-running-background-tasks-via-registry
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (running-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-cleanup-running')"
                                                         :directory directory
                                                         :background t)))
           (completed-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('shell-task-cleanup-completed')"
                                                           :directory directory
                                                           :background t)))
           (stopped-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-cleanup-stopped')"
                                                         :directory directory
                                                         :background t)))
           (running-task-id (getf running-result :background-task-id))
           (completed-task-id (getf completed-result :background-task-id))
           (stopped-task-id (getf stopped-result :background-task-id))
           (running-output-path (getf running-result :output-path))
           (completed-output-path (getf completed-result :output-path))
           (stopped-output-path (getf stopped-result :output-path)))
      (unwind-protect
           (progn
             (sleep 0.4)
             (cl-cc.tools:shell-task-tool (list :task-id stopped-task-id :action :stop))
             (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-cleanup-tool"))
                    (result (funcall tool-fn nil)))
               (is (string= (getf result :status-filter) "all"))
               (is (= (getf result :removed-count) 2))
               (is (= (getf result :remaining-count) 1))
               (is (equal (getf result :removed-task-ids)
                          (sort (list completed-task-id stopped-task-id) #'string<)))
               (is (not (null (gethash running-task-id cl-cc.tools::*shell-background-task-registry*))))
               (is (null (gethash completed-task-id cl-cc.tools::*shell-background-task-registry*)))
               (is (null (gethash stopped-task-id cl-cc.tools::*shell-background-task-registry*)))
               (is (probe-file running-output-path))
               (is (not (probe-file completed-output-path)))
               (is (not (probe-file stopped-output-path)))))
        (when running-task-id
          (ignore-errors (cl-cc.tools:shell-task-tool (list :task-id running-task-id :action :stop)))
          (remhash running-task-id cl-cc.tools::*shell-background-task-registry*))
        (when completed-task-id
          (remhash completed-task-id cl-cc.tools::*shell-background-task-registry*))
        (when stopped-task-id
          (remhash stopped-task-id cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and running-output-path (probe-file running-output-path))
          (ignore-errors (delete-file running-output-path)))
        (when (and completed-output-path (probe-file completed-output-path))
          (ignore-errors (delete-file completed-output-path)))
        (when (and stopped-output-path (probe-file stopped-output-path))
          (ignore-errors (delete-file stopped-output-path)))))))

(test shell-task-cleanup-tool-cleans-background-tasks-by-termination-reason-via-registry
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (completed-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('shell-task-cleanup-term-completed')"
                                                           :directory directory
                                                           :background t)))
           (stopped-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-cleanup-term-stopped')"
                                                         :directory directory
                                                         :background t)))
           (interrupted-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-cleanup-term-interrupted')"
                                                             :directory directory
                                                             :background t)))
           (completed-task-id (getf completed-result :background-task-id))
           (stopped-task-id (getf stopped-result :background-task-id))
           (interrupted-task-id (getf interrupted-result :background-task-id))
           (completed-output-path (getf completed-result :output-path))
           (stopped-output-path (getf stopped-result :output-path))
           (interrupted-output-path (getf interrupted-result :output-path)))
      (unwind-protect
           (progn
             (sleep 0.4)
             (cl-cc.tools:shell-task-tool (list :task-id stopped-task-id :action :stop))
             (cl-cc.tools:shell-task-tool (list :task-id interrupted-task-id :action :interrupt))
             (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-cleanup-tool"))
                    (result (funcall tool-fn '(:termination-reason "interrupt"))))
               (is (string= (getf result :status-filter) "all"))
               (is (string= (getf result :termination-reason-filter) "interrupt"))
               (is (= (getf result :removed-count) 1))
               (is (= (getf result :remaining-count) 2))
               (is (equal (getf result :removed-task-ids)
                          (list interrupted-task-id)))
               (is (not (null (gethash completed-task-id cl-cc.tools::*shell-background-task-registry*))))
               (is (not (null (gethash stopped-task-id cl-cc.tools::*shell-background-task-registry*))))
               (is (null (gethash interrupted-task-id cl-cc.tools::*shell-background-task-registry*)))
               (is (probe-file completed-output-path))
               (is (probe-file stopped-output-path))
               (is (not (probe-file interrupted-output-path)))))
        (when stopped-task-id
          (ignore-errors (cl-cc.tools:shell-task-tool (list :task-id stopped-task-id :action :stop)))
          (remhash stopped-task-id cl-cc.tools::*shell-background-task-registry*))
        (when interrupted-task-id
          (remhash interrupted-task-id cl-cc.tools::*shell-background-task-registry*))
        (when completed-task-id
          (remhash completed-task-id cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and completed-output-path (probe-file completed-output-path))
          (ignore-errors (delete-file completed-output-path)))
        (when (and stopped-output-path (probe-file stopped-output-path))
          (ignore-errors (delete-file stopped-output-path)))
        (when (and interrupted-output-path (probe-file interrupted-output-path))
          (ignore-errors (delete-file interrupted-output-path)))))))

(test shell-task-tool-queries-and-stops-background-task-via-registry
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-registry-ok')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-tool"))
                (status-result (funcall tool-fn (list :task-id task-id)))
                (stop-result (funcall tool-fn (list :task-id task-id :action :stop))))
           (is (string= (getf status-result :status) "running"))
           (is (getf status-result :running))
           (is (string= (getf status-result :output-path) output-path))
           (is (not (getf status-result :timed-out)))
           (is (string= (getf stop-result :status) "stopped"))
           (is (getf stop-result :stopped))
           (is (not (getf stop-result :running)))
           (is (string= (getf stop-result :termination-reason) "stop"))
           (is (stringp (getf stop-result :ended-at)))
           (is (not (getf stop-result :timed-out))))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test shell-task-detail-tool-detects-stalled-background-task-via-registry
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
             (let* ((detail-tool (cl-cc.tools:find-tool "shell-task-detail-tool"))
                    (status-tool (cl-cc.tools:find-tool "shell-task-tool"))
                    (list-tool (cl-cc.tools:find-tool "shell-task-list-tool"))
                    (detail-result (funcall detail-tool (list :task-id task-id)))
                    (status-result (funcall status-tool (list :task-id task-id)))
                    (list-task (find task-id
                                     (getf (funcall list-tool nil) :tasks)
                                     :key (lambda (task) (getf task :task-id))
                                     :test #'string=)))
               (is (getf detail-result :stall-detected))
               (is (stringp (getf detail-result :stall-detected-at)))
               (is (string= (getf detail-result :stall-prompt-line) "Continue?"))
               (is (getf status-result :stall-detected))
               (is (stringp (getf status-result :stall-detected-at)))
               (is (string= (getf status-result :stall-prompt-line) "Continue?"))
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

(test shell-task-tool-waits-for-background-task-via-registry
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Milliseconds 300; [Console]::Out.Write('shell-task-wait-registry-ok')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-tool"))
                (wait-result (funcall tool-fn (list :task-id task-id :action :wait))))
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

(test shell-task-tool-interrupts-background-task-via-registry
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('shell-task-interrupt-registry-ok')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-tool"))
                (interrupt-result (funcall tool-fn (list :task-id task-id :action :interrupt))))
           (is (string= (getf interrupt-result :action) "interrupt"))
           (is (string= (getf interrupt-result :status) "stopped"))
           (is (getf interrupt-result :stopped))
           (is (not (getf interrupt-result :running)))
           (is (string= (getf interrupt-result :termination-reason) "interrupt"))
           (is (stringp (getf interrupt-result :ended-at)))
           (is (not (getf interrupt-result :timed-out))))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test shell-task-tool-stop-recursively-terminates-child-processes-via-registry
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (marker-path (uiop:native-namestring
                       (uiop:merge-pathnames* "shell-task-registry-child-alive.txt"
                                              (uiop:temporary-directory))))
         (start-result (cl-cc.tools:shell-tool (list :command (%tool-execution-test-child-survival-command marker-path)
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (when (probe-file marker-path)
      (delete-file marker-path))
    (unwind-protect
         (progn
           (sleep 0.4)
           (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-tool"))
                  (stop-result (funcall tool-fn (list :task-id task-id :action :stop))))
             (is (string= (getf stop-result :action) "stop"))
             (is (string= (getf stop-result :status) "stopped"))
             (is (getf stop-result :stopped))
             (is (not (getf stop-result :running))))
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

(test shell-task-detail-tool-reads-background-task-details-via-registry
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('shell-task-detail-registry-1'); [Console]::Out.WriteLine('shell-task-detail-registry-2'); Start-Sleep -Seconds 5"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (progn
           (sleep 0.4)
           (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-detail-tool"))
                  (result (funcall tool-fn (list :task-id task-id))))
           (is (string= (getf result :task-id) task-id))
           (is (string= (getf result :status) "running"))
           (is (getf result :running))
           (is (string= (getf result :output-path) output-path))
           (is (stringp (getf result :started-at)))
           (is (null (getf result :stopped-at)))
           (is (null (getf result :finished-at)))
           (is (null (getf result :termination-reason)))
           (is (null (getf result :ended-at)))
           (is (numberp (getf result :duration-seconds)))
           (is (integerp (getf result :output-bytes)))
           (is (> (getf result :output-bytes) 0))
           (is (= (getf result :output-line-count) 2))
           (is (stringp (getf result :output-updated-at)))))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test shell-task-output-tool-reads-background-task-output-via-registry
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (start-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('line-1'); [Console]::Out.WriteLine('line-2'); [Console]::Out.WriteLine('line-3')"
                                                       :directory directory
                                                       :background t)))
           (task-id (getf start-result :background-task-id))
           (output-path (getf start-result :output-path)))
      (unwind-protect
           (progn
             (sleep 0.4)
             (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-output-tool"))
                    (result (funcall tool-fn (list :task-id task-id :lines 2))))
               (is (string= (getf result :status) "completed"))
               (is (string= (getf result :mode) "tail"))
               (is (not (getf result :running)))
               (is (string= (getf result :output-path) output-path))
               (is (= (getf result :start-line) 2))
               (is (= (getf result :end-line) 3))
               (is (string= (getf result :content) (format nil "2:line-2~%3:line-3")))))
        (when task-id
          (remhash task-id cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and output-path (probe-file output-path))
          (ignore-errors (delete-file output-path)))))))

(test shell-task-output-tool-reads-multiple-background-task-outputs-via-registry
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (start-result-a (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('multi-line-1'); [Console]::Out.WriteLine('multi-line-2'); [Console]::Out.WriteLine('multi-line-3')"
                                                         :directory directory
                                                         :background t)))
           (start-result-b (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('other-line-1'); [Console]::Out.WriteLine('other-line-2'); [Console]::Out.WriteLine('other-line-3')"
                                                         :directory directory
                                                         :background t)))
           (task-id-a (getf start-result-a :background-task-id))
           (task-id-b (getf start-result-b :background-task-id))
           (output-path-a (getf start-result-a :output-path))
           (output-path-b (getf start-result-b :output-path)))
      (unwind-protect
           (progn
             (sleep 0.4)
             (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-output-tool"))
                    (result (funcall tool-fn (list :task-ids (list task-id-a task-id-b) :lines 2))))
               (is (null (getf result :task-id)))
               (is (equal (getf result :task-ids) (list task-id-a task-id-b)))
               (is (= (getf result :task-count) 2))
               (is (string= (getf result :status) "completed"))
               (is (null (getf result :output-path)))
               (is (= (getf result :completed-count) 2))
               (is (= (length (getf result :tasks)) 2))
               (is (search "2:multi-line-2" (getf (first (getf result :tasks)) :content)))))
        (when task-id-a
          (remhash task-id-a cl-cc.tools::*shell-background-task-registry*))
        (when task-id-b
          (remhash task-id-b cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and output-path-a (probe-file output-path-a))
          (ignore-errors (delete-file output-path-a)))
        (when (and output-path-b (probe-file output-path-b))
          (ignore-errors (delete-file output-path-b)))))))

(test shell-task-output-tool-supports-per-task-window-overrides-via-registry
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (start-result-a (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('ov-a1'); [Console]::Out.WriteLine('ov-a2'); [Console]::Out.WriteLine('ov-a3')"
                                                         :directory directory
                                                         :background t)))
           (start-result-b (cl-cc.tools:shell-tool (list :command "[Console]::Out.WriteLine('ov-b1'); [Console]::Out.WriteLine('ov-b2'); [Console]::Out.WriteLine('ov-b3')"
                                                         :directory directory
                                                         :background t)))
           (task-id-a (getf start-result-a :background-task-id))
           (task-id-b (getf start-result-b :background-task-id))
           (output-path-a (getf start-result-a :output-path))
           (output-path-b (getf start-result-b :output-path)))
      (unwind-protect
           (progn
             (sleep 0.4)
             (let* ((tool-fn (cl-cc.tools:find-tool "shell-task-output-tool"))
                    (result (funcall tool-fn (list :tasks (list (list :task-id task-id-a :lines 1)
                                                                (list :task-id task-id-b :start-line 2 :end-line 3))))))
               (is (string= (getf result :mode) "mixed"))
               (is (= (length (getf result :tasks)) 2))
               (let ((task-a (find task-id-a (getf result :tasks) :key (lambda (task) (getf task :task-id)) :test #'string=))
                     (task-b (find task-id-b (getf result :tasks) :key (lambda (task) (getf task :task-id)) :test #'string=)))
                 (is (string= (getf task-a :output-path) output-path-a))
                 (is (string= (getf task-a :content) "3:ov-a3"))
                 (is (string= (getf task-b :output-path) output-path-b))
                 (is (string= (getf task-b :content) (format nil "2:ov-b2~%3:ov-b3"))))))
        (when task-id-a
          (remhash task-id-a cl-cc.tools::*shell-background-task-registry*))
        (when task-id-b
          (remhash task-id-b cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and output-path-a (probe-file output-path-a))
          (ignore-errors (delete-file output-path-a)))
        (when (and output-path-b (probe-file output-path-b))
          (ignore-errors (delete-file output-path-b)))))))

(test file-edit-tool-edits-file-content
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-integration.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before target after" stream))
           (let ((direct-result (cl-cc.tools:file-edit-tool (list :path path :old-text "target" :new-text "updated"))))
             (is (string= (getf direct-result :summary)
                          (format nil "编辑文件: ~A" path)))
             (is (string= (getf direct-result :matched-text) "target"))
             (is (= (getf direct-result :line-context) 1))
             (is (search (format nil "--- a/~A" (substitute #\/ #\\ path))
                         (getf direct-result :unified-diff-preview)))
             (is (search (format nil "+++ b/~A" (substitute #\/ #\\ path))
                         (getf direct-result :unified-diff-preview)))
             (is (search "@@ match 7..13 @@" (getf direct-result :diff-preview)))
             (is (search "@@ lines 1..1 -> 1..1 @@" (getf direct-result :line-diff-preview)))
             (is (search "@@ -1 +1 @@" (getf direct-result :unified-diff-preview)))
             (is (= (getf direct-result :selected-occurrence) 1)))
           (is (string= (uiop:read-file-string path) "before updated after"))
           (let ((registry-result (funcall (cl-cc.tools:find-tool "file-edit-tool")
                                           (list :path path :old-text "updated" :new-text "done"))))
             (is (string= (getf registry-result :summary)
                          (format nil "编辑文件: ~A" path)))
             (is (string= (getf registry-result :replacement-text) "done")))
           (is (string= (uiop:read-file-string path) "before done after")))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-can-edit-selected-occurrence-via-registry
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-occurrence-integration.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "repeat middle repeat" stream))
           (let ((registry-result (funcall (cl-cc.tools:find-tool "file-edit-tool")
                                           (list :path path :old-text "repeat" :new-text "done" :occurrence 2 :preview t))))
             (is (getf registry-result :preview))
             (is (= (getf registry-result :total-matches) 2))
             (is (= (getf registry-result :selected-occurrence) 2))
             (is (= (getf registry-result :line-context) 1))
             (is (search (format nil "--- a/~A" (substitute #\/ #\\ path))
                         (getf registry-result :unified-diff-preview)))
             (is (search (format nil "+++ b/~A" (substitute #\/ #\\ path))
                         (getf registry-result :unified-diff-preview)))
             (is (search "@@ match 14..20 @@" (getf registry-result :diff-preview)))
             (is (search "@@ lines 1..1 -> 1..1 @@" (getf registry-result :line-diff-preview)))
             (is (search "@@ -1 +1 @@" (getf registry-result :unified-diff-preview)))
             (is (search "第 2/2 处命中" (getf registry-result :summary))))
           (is (string= (uiop:read-file-string path) "repeat middle repeat")))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-preview-keeps-file-content-unchanged
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-preview-integration.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before preview after" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path :old-text "preview" :new-text "updated" :preview t))))
             (is (search "预览编辑文件:" (getf result :summary)))
             (is (getf result :preview))
            (is (= (getf result :line-context) 1))
            (is (search (format nil "--- a/~A" (substitute #\/ #\\ path))
                        (getf result :unified-diff-preview)))
            (is (search (format nil "+++ b/~A" (substitute #\/ #\\ path))
                        (getf result :unified-diff-preview)))
             (is (search "@@ match 7..14 @@" (getf result :diff-preview)))
             (is (search "@@ lines 1..1 -> 1..1 @@" (getf result :line-diff-preview)))
            (is (search "@@ -1 +1 @@" (getf result :unified-diff-preview)))
             (is (string= (getf result :after-preview) "before updated after")))
           (is (string= (uiop:read-file-string path) "before preview after")))
      (when (probe-file path)
        (delete-file path)))))

(test grep-tool-searches-directory-content
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "grep-tool-integration/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "main.lisp" directory-path))
         (nested-directory (merge-pathnames "src/" directory-path))
         (nested-file (merge-pathnames "src/helper.lisp" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested-directory)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "(defun main () :needle)" stream))
           (with-open-file (stream nested-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "needle-helper" stream))
           (let ((request (list :query "needle"
                                :root (uiop:native-namestring directory-path))))
             (is (search "main.lisp:1:(defun main () :needle)"
                         (cl-cc.tools:grep-tool request)))
             (is (search "src/helper.lisp:1:needle-helper"
                         (funcall (cl-cc.tools:find-tool "grep-tool") request)))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file nested-file)
        (delete-file nested-file))
      (when (probe-file nested-directory)
        (uiop:delete-directory-tree nested-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test directory-list-tool-reads-directory-content
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "directory-list-tool-integration/"
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
           (is (string= (cl-cc.tools:directory-list-tool (uiop:native-namestring directory-path))
                        (format nil "a.txt~%b.txt")))
           (is (string= (funcall (cl-cc.tools:find-tool "directory-list-tool")
                                 (uiop:native-namestring directory-path))
                        (format nil "a.txt~%b.txt"))))
      (when (probe-file file-a)
        (delete-file file-a))
      (when (probe-file file-b)
        (delete-file file-b))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test directory-list-tool-supports-recursive-directory-content
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "directory-list-tool-recursive-integration/"
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
           (is (string= (cl-cc.tools:directory-list-tool (format nil "list directory ~A :: recursive"
                                                                 (uiop:native-namestring directory-path)))
                        (format nil "a.txt~%child/~%child/note.txt")))
           (is (string= (funcall (cl-cc.tools:find-tool "directory-list-tool")
                                 (list :path (uiop:native-namestring directory-path) :depth 1))
                        (format nil "a.txt~%child/"))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file child-file)
        (delete-file child-file))
      (when (probe-file child-directory)
        (uiop:delete-directory-tree child-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test directory-list-tool-supports-contains-filtered-directory-content
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "directory-list-tool-contains-integration/"
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
           (is (string= (cl-cc.tools:directory-list-tool (format nil "list directory ~A :: recursive :: contains=note"
                                                                 (uiop:native-namestring directory-path)))
                        "child/note.txt"))
           (is (string= (funcall (cl-cc.tools:find-tool "directory-list-tool")
                                 (list :path (uiop:native-namestring directory-path) :recursive t :contains "child"))
                        (format nil "child/~%child/note.txt"))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file child-file)
        (delete-file child-file))
      (when (probe-file child-directory)
        (uiop:delete-directory-tree child-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test tool-execution-failure
  (signals cl-cc.lib:cl-cc-error (cl-cc.tools:failing-tool nil))
  (signals cl-cc.lib:cl-cc-error (funcall (cl-cc.tools:find-tool "failing-tool") nil)))

(test failing-tool-error-helper-rendering
  (is (string= (cl-cc.tools::%failing-tool-message)
               "工具执行失败"))
  (let ((condition (cl-cc.tools::%failing-tool-error)))
    (is (eq (cl-cc.lib:error-code condition) :fail))
    (is (string= (cl-cc.lib:error-message condition)
                 "工具执行失败"))))

(test failing-tool-signals-stable-error
  (handler-case
      (progn
        (cl-cc.tools:failing-tool nil)
        (fail "expected failing-tool error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :fail))
      (is (string= (cl-cc.lib:error-message condition)
                   "工具执行失败")))))

(test run-tool-reports-permission-denied-message
  (handler-case
      (progn
        (cl-cc.services:run-tool "echo-tool" "fixture-input-restricted"
                                 :context '(:action delete-file :fixture "restricted"))
        (fail "expected permission denied error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :permission-denied))
      (is (string= (cl-cc.lib:error-message condition)
                   "permission denied for action: DELETE-FILE")))))

(test run-tool-reports-missing-tool-message
  (handler-case
      (progn
        (cl-cc.services:run-tool "missing-tool" "fixture-input-test"
                                 :context '(:action "echo-tool" :fixture "test"))
        (fail "expected tool not found error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :tool-not-found))
      (is (string= (cl-cc.lib:error-message condition)
                   "tool not found: missing-tool")))))
