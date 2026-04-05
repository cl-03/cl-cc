;;;; src/tools/shell-task-list-tool.lisp - 后台 shell 任务列表工具
(in-package :cl-cc.tools)

(defparameter +shell-task-list-tool-input-prefixes+
  '("shell task list" "list shell tasks" "list background tasks" "show shell tasks"
    "background task list" "后台任务列表" "列出后台任务" "查看后台任务列表")
  "允许 shell-task-list-tool 直接消费的自然语言前缀。")

(defparameter +shell-task-list-running-input-prefixes+
  '("running shell task list" "list running shell tasks" "list running background tasks"
    "运行中后台任务列表" "列出运行中的后台任务" "查看运行中的后台任务")
  "允许 shell-task-list-tool 直接消费 running 过滤的自然语言前缀。")

(defparameter +shell-task-list-failed-input-prefixes+
  '("failed shell task list" "list failed shell tasks" "list failed background tasks"
    "失败后台任务列表" "列出失败后台任务" "查看失败后台任务")
  "允许 shell-task-list-tool 直接消费 failed 过滤的自然语言前缀。")

(defparameter +shell-task-list-completed-input-prefixes+
  '("completed shell task list" "list completed shell tasks" "list completed background tasks"
    "已完成后台任务列表" "列出已完成后台任务" "查看已完成后台任务")
  "允许 shell-task-list-tool 直接消费 completed 过滤的自然语言前缀。")

(defparameter +shell-task-list-stopped-input-prefixes+
  '("stopped shell task list" "list stopped shell tasks" "list stopped background tasks"
    "已停止后台任务列表" "列出已停止后台任务" "查看已停止后台任务")
  "允许 shell-task-list-tool 直接消费 stopped 过滤的自然语言前缀。")

(defun %shell-task-list-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :shell-execution-failed
                              (format nil "shell 后台任务列表失败: ~A" detail)))

(defun %normalized-shell-task-list-status (value)
  (cond
    ((null value) :all)
    ((keywordp value)
     (case value
       (:all :all)
       (:running :running)
       (:stopped :stopped)
       (:completed :completed)
       (:failed :failed)
       (otherwise nil)))
    ((stringp value)
     (let ((text (%trim-shell-text value)))
       (cond
         ((member text '("all" "全部" "所有") :test #'string-equal) :all)
         ((member text '("running" "active" "运行中") :test #'string-equal) :running)
         ((member text '("stopped" "stopped task" "已停止" "停止") :test #'string-equal) :stopped)
         ((member text '("completed" "done" "已完成" "完成") :test #'string-equal) :completed)
         ((member text '("failed" "error" "失败") :test #'string-equal) :failed)
         (t nil))))
    (t nil)))

(defun %normalize-shell-task-list-filter-text (value)
  (let ((text (%trim-shell-text value)))
    (and text
         (> (length text) 0)
         text)))

(defun %normalized-shell-task-list-termination-reason (value)
  (%normalized-shell-background-termination-reason value))

(defun %shell-task-list-request (&key status task-id-prefix directory-contains termination-reason)
  (list :status (or status :all)
        :task-id-prefix task-id-prefix
        :directory-contains directory-contains
        :termination-reason termination-reason))

(defun %normalize-shell-task-list-request (&key status all task-id-prefix directory-contains termination-reason)
  (let ((normalized-status (%normalized-shell-task-list-status status))
        (normalized-termination-reason (%normalized-shell-task-list-termination-reason termination-reason)))
    (cond
      ((and normalized-status
            (or (null termination-reason)
                normalized-termination-reason)
            (or (null all)
                (eq all t)
                (eq all nil)
                (and (stringp all)
                     (member (%trim-shell-text all) '("true" "yes" "1") :test #'string-equal))))
       (%shell-task-list-request :status normalized-status
                                 :task-id-prefix (%normalize-shell-task-list-filter-text task-id-prefix)
                                 :directory-contains (%normalize-shell-task-list-filter-text directory-contains)
                                 :termination-reason normalized-termination-reason))
      ((null normalized-status)
       (error (%shell-task-list-tool-error "status 仅支持 all、running、stopped、completed 或 failed")))
      ((and termination-reason
            (null normalized-termination-reason))
       (error (%shell-task-list-tool-error "terminationReason 仅支持 exit、error-exit、stop 或 interrupt")))
      (t
       (error (%shell-task-list-tool-error "all 仅支持 true，当前不支持关闭全部列表语义"))))))

(defun %shell-task-list-prefixed-p (text prefixes)
  (not (string= (%strip-input-prefix text prefixes) text)))

(defun %split-shell-task-list-segments (text)
  (let ((segments '())
        (cursor 0)
        (delimiter " :: "))
    (loop for position = (search delimiter text :start2 cursor :test #'char-equal)
          do (if position
                 (progn
                   (push (subseq text cursor position) segments)
                   (setf cursor (+ position (length delimiter))))
                 (progn
                   (push (subseq text cursor) segments)
                   (return))))
    (nreverse segments)))

(defun %shell-task-list-command-request (text)
  (cond
    ((%shell-task-list-prefixed-p text +shell-task-list-running-input-prefixes+)
     (%shell-task-list-request :status :running))
    ((%shell-task-list-prefixed-p text +shell-task-list-failed-input-prefixes+)
     (%shell-task-list-request :status :failed))
    ((%shell-task-list-prefixed-p text +shell-task-list-completed-input-prefixes+)
     (%shell-task-list-request :status :completed))
    ((%shell-task-list-prefixed-p text +shell-task-list-stopped-input-prefixes+)
     (%shell-task-list-request :status :stopped))
    ((%shell-task-list-prefixed-p text +shell-task-list-tool-input-prefixes+)
     (%shell-task-list-request :status :all))
    (t nil)))

(defun %shell-task-list-option-key (key-text)
  (let ((text (%trim-shell-text key-text)))
    (cond
      ((member text '("status") :test #'string-equal) :status)
      ((member text '("task" "taskid" "task-id" "taskidprefix" "task-id-prefix") :test #'string-equal) :task-id-prefix)
      ((member text '("dir" "directory" "directorycontains" "directory-contains") :test #'string-equal) :directory-contains)
      ((member text '("termination" "terminationreason" "termination-reason" "reason") :test #'string-equal) :termination-reason)
      (t nil))))

(defun %apply-shell-task-list-option-segment (request segment)
  (multiple-value-bind (raw-key raw-value foundp)
      (%split-once segment "=")
    (if foundp
        (let ((option-key (%shell-task-list-option-key raw-key)))
          (unless option-key
            (error (%shell-task-list-tool-error (format nil "不支持的筛选键: ~A" raw-key))))
          (case option-key
            (:status
             (setf (getf request :status)
                   (or (%normalized-shell-task-list-status raw-value)
                       (error (%shell-task-list-tool-error "status 仅支持 all、running、stopped、completed 或 failed")))))
            (:task-id-prefix
             (setf (getf request :task-id-prefix)
                   (%normalize-shell-task-list-filter-text raw-value)))
            (:directory-contains
             (setf (getf request :directory-contains)
               (%normalize-shell-task-list-filter-text raw-value)))
            (:termination-reason
             (setf (getf request :termination-reason)
               (or (%normalized-shell-task-list-termination-reason raw-value)
                   (error (%shell-task-list-tool-error "terminationReason 仅支持 exit、error-exit、stop 或 interrupt")))))))
        (let ((normalized-status (%normalized-shell-task-list-status segment)))
          (unless normalized-status
            (error (%shell-task-list-tool-error (format nil "无法解析筛选片段: ~A" segment))))
          (setf (getf request :status) normalized-status)))
    request))

(defun %parse-shell-task-list-text (text)
  (let* ((segments (%split-shell-task-list-segments text))
         (command-segment (%trim-shell-text (first segments)))
         (request (%shell-task-list-command-request command-segment)))
    (when request
      (dolist (segment (rest segments))
        (%apply-shell-task-list-option-segment request (%trim-shell-text segment)))
      (%normalize-shell-task-list-request :status (getf request :status)
                                          :task-id-prefix (getf request :task-id-prefix)
                                          :directory-contains (getf request :directory-contains)
                                          :termination-reason (getf request :termination-reason)))))

(defun %normalized-shell-task-list-input (input)
  (cond
    ((null input)
     (%shell-task-list-request :status :all))
    ((and (listp input)
          (or (member :all input :test #'eq)
              (member :status input :test #'eq)
              (member :status-filter input :test #'eq)
              (member :statusFilter input :test #'eq)
              (member :task-id-prefix input :test #'eq)
              (member :taskIdPrefix input :test #'eq)
              (member :directory-contains input :test #'eq)
              (member :directoryContains input :test #'eq)
              (member :termination-reason input :test #'eq)
              (member :terminationReason input :test #'eq)))
     (%normalize-shell-task-list-request :all (getf input :all)
                                         :status (or (getf input :status)
                                                     (getf input :status-filter)
                                                     (getf input :statusFilter))
                                         :task-id-prefix (or (getf input :task-id-prefix)
                                                             (getf input :taskIdPrefix))
                                         :directory-contains (or (getf input :directory-contains)
                                                                 (getf input :directoryContains))
                                         :termination-reason (or (getf input :termination-reason)
                                                                 (getf input :terminationReason))))
    (t
     (let ((text (%trim-shell-text input)))
       (cond
         ((or (null text) (string= text ""))
          (%shell-task-list-request :status :all))
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-shell-task-list-input (subseq text (length "fixture-input-"))))
         (t (%parse-shell-task-list-text text)))))))

(defun %shell-task-list-status-name (status)
  (string-downcase (string status)))

(defun %shell-task-list-entry-result (entry)
  (let* ((process (getf entry :process))
         (status (%shell-background-task-status entry))
         (exit-code (%shell-background-process-exit-code process)))
    (list :task-id (getf entry :task-id)
          :status status
          :running (string= status "running")
          :stopped (string= status "stopped")
          :command (getf entry :command)
          :directory (getf entry :directory)
          :output-path (getf entry :output-path)
          :process-id (getf entry :process-id)
          :exit-code exit-code
          :stall-detected (%shell-background-task-stall-detected-p entry)
          :stall-detected-at (%shell-background-task-stall-detected-at-string entry)
          :stall-prompt-line (%shell-background-task-stall-prompt-line entry)
          :termination-reason (getf entry :termination-reason)
          :ended-at (%format-shell-background-task-time (%shell-background-task-ended-at entry)))))

(defun %sorted-shell-task-entries ()
  (let ((entries '()))
    (maphash (lambda (_ entry)
               (declare (ignore _))
               (push entry entries))
             *shell-background-task-registry*)
    (sort entries #'string< :key (lambda (entry)
                                   (or (getf entry :task-id) "")))))

(defun %count-shell-task-status (tasks status)
  (count status tasks :key (lambda (task)
                             (getf task :status))
         :test #'string=))

(defun %shell-task-list-prefix-matches-p (text prefix)
  (or (null prefix)
      (let ((position (search prefix (or text "") :test #'char-equal)))
        (and position
             (zerop position)))))

(defun %shell-task-list-contains-p (text fragment)
  (or (null fragment)
      (search fragment (or text "") :test #'char-equal)))

(defun %shell-task-list-matches-p (task request)
  (and (or (eq (getf request :status) :all)
           (string= (getf task :status)
                    (%shell-task-list-status-name (getf request :status))))
       (%shell-task-list-prefix-matches-p (getf task :task-id)
                                          (getf request :task-id-prefix))
       (%shell-task-list-contains-p (getf task :directory)
                      (getf request :directory-contains))
         (or (null (getf request :termination-reason))
           (string= (or (getf task :termination-reason) "")
              (getf request :termination-reason)))))

(defun %shell-task-list-active-filter-labels (request)
  (let ((labels '()))
    (unless (eq (getf request :status) :all)
      (push (format nil "status=~A" (%shell-task-list-status-name (getf request :status))) labels))
    (when (getf request :task-id-prefix)
      (push (format nil "taskIdPrefix=~A" (getf request :task-id-prefix)) labels))
    (when (getf request :directory-contains)
      (push (format nil "directoryContains=~A" (getf request :directory-contains)) labels))
    (when (getf request :termination-reason)
      (push (format nil "terminationReason=~A" (getf request :termination-reason)) labels))
    (nreverse labels)))

(defun %shell-task-list-summary (request total-count)
  (let ((labels (%shell-task-list-active-filter-labels request)))
    (if (null labels)
        (format nil "shell 后台任务列表(~D个)" total-count)
        (format nil "shell 后台任务列表(~A, ~D个)"
                (format nil "~{~A~^, ~}" labels)
                total-count))))

(defun %shell-task-list-result (request)
  (let* ((tasks (remove-if-not (lambda (task)
                                 (%shell-task-list-matches-p task request))
                               (mapcar #'%shell-task-list-entry-result
                                       (%sorted-shell-task-entries))))
         (total-count (length tasks))
         (running-count (%count-shell-task-status tasks "running"))
         (stopped-count (%count-shell-task-status tasks "stopped"))
         (completed-count (%count-shell-task-status tasks "completed"))
         (failed-count (%count-shell-task-status tasks "failed")))
    (list :summary (%shell-task-list-summary request total-count)
          :status-filter (%shell-task-list-status-name (getf request :status))
          :task-id-prefix-filter (getf request :task-id-prefix)
          :directory-contains-filter (getf request :directory-contains)
          :termination-reason-filter (getf request :termination-reason)
          :total-count total-count
          :running-count running-count
          :stopped-count stopped-count
          :completed-count completed-count
          :failed-count failed-count
          :tasks tasks)))

(defun shell-task-list-tool (input)
  "列出当前注册的后台 shell 任务。"
  (let ((request (%normalized-shell-task-list-input input)))
    (unless request
      (error (%shell-task-list-tool-error
              "请求格式无效，期望 `shell task list`、`shell task list :: status=running :: task=shell-task-123` 或 `list failed shell tasks`")))
    (%shell-task-list-result request)))