;;;; src/tools/shell-task-cleanup-tool.lisp - 后台 shell 任务清理工具
(in-package :cl-cc.tools)

(defparameter +shell-task-cleanup-tool-input-prefixes+
  '("cleanup shell tasks" "cleanup background tasks" "prune shell tasks"
    "清理后台任务" "清理后台 shell 任务")
  "允许 shell-task-cleanup-tool 直接消费的自然语言前缀。")

(defparameter +shell-task-cleanup-completed-input-prefixes+
  '("cleanup completed shell tasks" "cleanup completed background tasks"
    "清理已完成后台任务" "清理完成后台任务")
  "允许 shell-task-cleanup-tool 直接消费 completed 过滤的自然语言前缀。")

(defparameter +shell-task-cleanup-failed-input-prefixes+
  '("cleanup failed shell tasks" "cleanup failed background tasks"
    "清理失败后台任务")
  "允许 shell-task-cleanup-tool 直接消费 failed 过滤的自然语言前缀。")

(defparameter +shell-task-cleanup-stopped-input-prefixes+
  '("cleanup stopped shell tasks" "cleanup stopped background tasks"
    "清理已停止后台任务" "清理停止后台任务")
  "允许 shell-task-cleanup-tool 直接消费 stopped 过滤的自然语言前缀。")

(defun %shell-task-cleanup-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :shell-execution-failed
                              (format nil "shell 后台任务清理失败: ~A" detail)))

(defun %normalized-shell-task-cleanup-status (value)
  (cond
    ((null value) :all)
    ((keywordp value)
     (case value
       (:all :all)
       (:stopped :stopped)
       (:completed :completed)
       (:failed :failed)
       (otherwise nil)))
    ((stringp value)
     (let ((text (%trim-shell-text value)))
       (cond
         ((member text '("all" "done" "finished" "全部" "所有") :test #'string-equal) :all)
         ((member text '("stopped" "stop" "已停止" "停止") :test #'string-equal) :stopped)
         ((member text '("completed" "complete" "done-only" "已完成" "完成") :test #'string-equal) :completed)
         ((member text '("failed" "fail" "失败") :test #'string-equal) :failed)
         (t nil))))
    (t nil)))

(defun %shell-task-cleanup-request (&key status termination-reason)
  (list :status (or status :all)
        :termination-reason termination-reason))

(defun %normalize-shell-task-cleanup-request (&key status termination-reason)
  (let ((normalized-status (%normalized-shell-task-cleanup-status status))
        (normalized-termination-reason (%normalized-shell-background-termination-reason termination-reason)))
    (cond
      ((null normalized-status)
       (error (%shell-task-cleanup-tool-error "status 仅支持 all、stopped、completed 或 failed")))
      ((and termination-reason
            (null normalized-termination-reason))
       (error (%shell-task-cleanup-tool-error "terminationReason 仅支持 exit、error-exit、stop 或 interrupt")))
      (t
       (%shell-task-cleanup-request :status normalized-status
                                    :termination-reason normalized-termination-reason)))))

(defun %shell-task-cleanup-option-key (text)
  (let ((normalized (%trim-shell-text text)))
    (cond
      ((member normalized '("status") :test #'string-equal) :status)
      ((member normalized '("termination" "terminationreason" "termination-reason" "reason") :test #'string-equal) :termination-reason)
      (t nil))))

(defun %strip-shell-task-cleanup-leading-separator (text)
  (let ((trimmed (%trim-shell-text text)))
    (if (and trimmed
             (uiop:string-prefix-p "::" trimmed))
        (%trim-shell-text (subseq trimmed 2))
        trimmed)))

(defun %shell-task-cleanup-command-request (text)
  (let ((normalized-text (%strip-shell-task-cleanup-leading-separator text)))
    (cond
      ((or (null normalized-text)
           (string= normalized-text ""))
       (%normalize-shell-task-cleanup-request))
      (t
       (multiple-value-bind (raw-key raw-value foundp)
           (%split-once normalized-text "=")
         (if foundp
             (let ((option-key (%shell-task-cleanup-option-key raw-key)))
               (case option-key
                 (:status (%normalize-shell-task-cleanup-request :status raw-value))
                 (:termination-reason (%normalize-shell-task-cleanup-request :termination-reason raw-value))
                 (otherwise
                  (error (%shell-task-cleanup-tool-error (format nil "不支持的筛选键: ~A" raw-key))))))
             (%normalize-shell-task-cleanup-request :status normalized-text)))))))

(defun %parse-prefixed-shell-task-cleanup-text (text)
  (cond
    ((not (string= (%strip-input-prefix text +shell-task-cleanup-completed-input-prefixes+) text))
     (%normalize-shell-task-cleanup-request :status :completed))
    ((not (string= (%strip-input-prefix text +shell-task-cleanup-failed-input-prefixes+) text))
     (%normalize-shell-task-cleanup-request :status :failed))
    ((not (string= (%strip-input-prefix text +shell-task-cleanup-stopped-input-prefixes+) text))
     (%normalize-shell-task-cleanup-request :status :stopped))
    (t
     (let ((prefixed-text (%strip-input-prefix text +shell-task-cleanup-tool-input-prefixes+)))
       (if (string= prefixed-text text)
           nil
           (%shell-task-cleanup-command-request prefixed-text))))))

(defun %normalized-shell-task-cleanup-input (input)
  (cond
    ((and (listp input)
          (or (getf input :status)
          (getf input :Status)
          (getf input :termination-reason)
          (getf input :terminationReason)))
     (%normalize-shell-task-cleanup-request :status (or (getf input :status)
                              (getf input :Status))
                        :termination-reason (or (getf input :termination-reason)
                                    (getf input :terminationReason))))
    ((listp input)
     (%normalize-shell-task-cleanup-request))
    (t
     (let ((text (%trim-shell-text input)))
       (cond
         ((or (null text) (string= text "")) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-shell-task-cleanup-input (subseq text (length "fixture-input-"))))
         (t (%parse-prefixed-shell-task-cleanup-text text)))))))

(defun %shell-task-cleanup-status-string (status)
  (string-downcase (string status)))

(defun %shell-task-cleanup-target-status-p (task-status request-status)
  (and (member task-status '("stopped" "completed" "failed") :test #'string=)
       (or (eq request-status :all)
           (string= task-status (%shell-task-cleanup-status-string request-status)))))

(defun %shell-task-cleanup-target-termination-reason-p (task-termination-reason request-termination-reason)
  (or (null request-termination-reason)
      (string= (or task-termination-reason "") request-termination-reason)))

(defun %shell-task-cleanup-delete-output-path (path)
  (when (and path (probe-file path))
    (ignore-errors (delete-file path))))

(defun %shell-task-cleanup-wait-for-process-exit (process)
  #+sbcl
  (%wait-for-shell-background-process-exit process)
  #-sbcl
  (declare (ignore process)))

(defun %shell-task-cleanup-delete-output-with-retries (path process)
  (%shell-task-cleanup-wait-for-process-exit process)
  (when path
    (loop repeat 10
          while (probe-file path)
          do (%shell-task-cleanup-delete-output-path path)
             (when (probe-file path)
               (sleep 0.05)))))

(defun %shell-task-cleanup-candidates (request)
  (let ((request-status (getf request :status))
        (request-termination-reason (getf request :termination-reason))
        (candidates '()))
    (maphash (lambda (task-id entry)
               (declare (ignore task-id))
               (let ((status (%shell-background-task-status entry)))
                 (when (and (%shell-task-cleanup-target-status-p status request-status)
                            (%shell-task-cleanup-target-termination-reason-p (getf entry :termination-reason)
                                                                             request-termination-reason))
                   (push (list :task-id (getf entry :task-id)
                               :status status
                               :termination-reason (getf entry :termination-reason)
                       :output-path (getf entry :output-path)
                       :process (getf entry :process))
                         candidates))))
             *shell-background-task-registry*)
    (sort candidates #'string< :key (lambda (item) (getf item :task-id)))))

(defun %shell-task-cleanup-active-filter-labels (request)
  (let ((labels '()))
    (unless (eq (getf request :status) :all)
      (push (format nil "status=~A" (%shell-task-cleanup-status-string (getf request :status))) labels))
    (when (getf request :termination-reason)
      (push (format nil "terminationReason=~A" (getf request :termination-reason)) labels))
    (nreverse labels)))

(defun %perform-shell-task-cleanup (request)
  (let* ((candidates (%shell-task-cleanup-candidates request))
         (removed-task-ids (mapcar (lambda (item) (getf item :task-id)) candidates))
         (labels (%shell-task-cleanup-active-filter-labels request)))
    (dolist (candidate candidates)
      (%shell-task-cleanup-delete-output-with-retries (getf candidate :output-path)
                                                      (getf candidate :process))
      (remhash (getf candidate :task-id) *shell-background-task-registry*))
    (list :summary (if labels
                       (format nil "shell 后台任务清理(~A, ~D个)"
                               (format nil "~{~A~^, ~}" labels)
                               (length removed-task-ids))
                       (format nil "shell 后台任务清理(~D个): ~A"
                               (length removed-task-ids)
                               (%shell-task-cleanup-status-string (getf request :status))))
          :status-filter (%shell-task-cleanup-status-string (getf request :status))
          :termination-reason-filter (getf request :termination-reason)
          :removed-count (length removed-task-ids)
          :remaining-count (hash-table-count *shell-background-task-registry*)
          :removed-task-ids removed-task-ids)))

(defun shell-task-cleanup-tool (input)
  "清理后台 shell 任务注册表中已停止、已完成或失败的任务。"
  (let ((request (%normalized-shell-task-cleanup-input input)))
    (unless request
      (error (%shell-task-cleanup-tool-error
              "请求格式无效，期望 `cleanup shell tasks`、`cleanup shell tasks :: completed` 或 `清理后台任务`")))
    (%perform-shell-task-cleanup request)))