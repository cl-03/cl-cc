;;;; tests/unit/shell-task-cleanup-tool-test.lisp - shell-task-cleanup-tool 单元测试
(in-package :cl-cc/tests)

(def-suite shell-task-cleanup-tool-test :in cl-cc-suite)

(in-suite shell-task-cleanup-tool-test)

(test normalized-shell-task-cleanup-input-parses-natural-language-and-structured-input
  (is (equal (cl-cc.tools::%normalized-shell-task-cleanup-input "cleanup shell tasks")
             '(:status :all :termination-reason nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-cleanup-input "cleanup shell tasks :: completed")
             '(:status :completed :termination-reason nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-cleanup-input "cleanup shell tasks :: status=failed")
             '(:status :failed :termination-reason nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-cleanup-input "cleanup shell tasks :: termination=interrupt")
             '(:status :all :termination-reason "interrupt")))
  (is (equal (cl-cc.tools::%normalized-shell-task-cleanup-input "清理已停止后台任务")
             '(:status :stopped :termination-reason nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-cleanup-input '(:status "completed"))
             '(:status :completed :termination-reason nil)))
  (is (equal (cl-cc.tools::%normalized-shell-task-cleanup-input '(:terminationReason "stop"))
             '(:status :all :termination-reason "stop"))))

(test shell-task-cleanup-tool-removes-only-non-running-tasks-by-default
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (running-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('cleanup-running')"
                                                         :directory directory
                                                         :background t)))
           (completed-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('cleanup-completed')"
                                                           :directory directory
                                                           :background t)))
           (stopped-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('cleanup-stopped')"
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
             (let ((result (cl-cc.tools:shell-task-cleanup-tool nil)))
               (is (string= (getf result :status-filter) "all"))
               (is (= (getf result :removed-count) 2))
               (is (equal (getf result :removed-task-ids)
                          (sort (list completed-task-id stopped-task-id) #'string<)))
               (is (= (getf result :remaining-count) 1))
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

(test shell-task-cleanup-tool-can-filter-cleanup-status
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (completed-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('cleanup-filter-completed')"
                                                           :directory directory
                                                           :background t)))
           (stopped-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('cleanup-filter-stopped')"
                                                         :directory directory
                                                         :background t)))
           (completed-task-id (getf completed-result :background-task-id))
           (stopped-task-id (getf stopped-result :background-task-id))
           (completed-output-path (getf completed-result :output-path))
           (stopped-output-path (getf stopped-result :output-path)))
      (unwind-protect
           (progn
             (sleep 0.4)
             (cl-cc.tools:shell-task-tool (list :task-id stopped-task-id :action :stop))
             (let ((result (cl-cc.tools:shell-task-cleanup-tool '(:status :completed))))
               (is (string= (getf result :status-filter) "completed"))
               (is (= (getf result :removed-count) 1))
               (is (equal (getf result :removed-task-ids)
                          (list completed-task-id)))
               (is (null (gethash completed-task-id cl-cc.tools::*shell-background-task-registry*)))
               (is (not (null (gethash stopped-task-id cl-cc.tools::*shell-background-task-registry*))))
               (is (not (probe-file completed-output-path)))
               (is (probe-file stopped-output-path))))
        (when stopped-task-id
          (ignore-errors (cl-cc.tools:shell-task-tool (list :task-id stopped-task-id :action :stop)))
          (remhash stopped-task-id cl-cc.tools::*shell-background-task-registry*))
        (when completed-task-id
          (remhash completed-task-id cl-cc.tools::*shell-background-task-registry*))
        (sleep 0.2)
        (when (and completed-output-path (probe-file completed-output-path))
          (ignore-errors (delete-file completed-output-path)))
        (when (and stopped-output-path (probe-file stopped-output-path))
          (ignore-errors (delete-file stopped-output-path)))))))

(test shell-task-cleanup-tool-can-filter-cleanup-termination-reason
  (let ((cl-cc.tools::*shell-background-task-registry* (make-hash-table :test 'equal)))
    (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
           (completed-result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('cleanup-term-completed')"
                                                           :directory directory
                                                           :background t)))
           (stopped-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('cleanup-term-stopped')"
                                                         :directory directory
                                                         :background t)))
           (interrupted-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('cleanup-term-interrupted')"
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
             (let ((result (cl-cc.tools:shell-task-cleanup-tool '(:termination-reason "interrupt"))))
               (is (string= (getf result :status-filter) "all"))
               (is (string= (getf result :termination-reason-filter) "interrupt"))
               (is (= (getf result :removed-count) 1))
               (is (equal (getf result :removed-task-ids)
                          (list interrupted-task-id)))
               (is (not (null (gethash completed-task-id cl-cc.tools::*shell-background-task-registry*))))
               (is (not (null (gethash stopped-task-id cl-cc.tools::*shell-background-task-registry*))))
               (is (null (gethash interrupted-task-id cl-cc.tools::*shell-background-task-registry*)))
               (is (probe-file completed-output-path))
               (is (probe-file stopped-output-path))
               (is (not (probe-file interrupted-output-path))))))
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
          (ignore-errors (delete-file interrupted-output-path))))))