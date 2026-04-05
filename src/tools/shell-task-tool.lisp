;;;; src/tools/shell-task-tool.lisp - 后台 shell 任务状态/停止工具
(in-package :cl-cc.tools)

(defparameter +shell-task-tool-input-prefixes+
  '("shell task " "background task " "task status "
    "status shell task " "status background task "
    "inspect shell task " "inspect background task "
    "show shell task " "show background task "
    "后台任务" "查询后台任务" "查看后台任务")
  "允许 shell-task-tool 直接消费的自然语言前缀。")

(defparameter +shell-task-tool-stop-input-prefixes+
  '("stop shell task " "stop background task "
    "stop shell tasks " "stop background tasks "
    "kill shell task " "kill background task "
    "kill shell tasks " "kill background tasks "
    "terminate shell task " "terminate background task "
    "terminate shell tasks " "terminate background tasks "
    "cancel shell task " "cancel background task "
    "cancel shell tasks " "cancel background tasks "
    "stop task " "kill task " "terminate task " "cancel task "
    "stop tasks " "kill tasks " "terminate tasks " "cancel tasks "
    "停止后台任务" "终止后台任务" "取消后台任务"
    "停止任务" "终止任务" "取消任务")
  "允许 shell-task-tool 执行停止动作的自然语言前缀。")

(defparameter +shell-task-tool-interrupt-input-prefixes+
  '("interrupt shell task " "interrupt background task "
    "interrupt shell tasks " "interrupt background tasks "
    "interrupt task " "interrupt tasks "
    "sigint shell task " "sigint background task "
    "sigint shell tasks " "sigint background tasks "
    "sigint task " "sigint tasks "
    "ctrl-c shell task " "ctrl-c background task "
    "ctrl-c shell tasks " "ctrl-c background tasks "
    "ctrl-c task " "ctrl-c tasks "
    "ctrl+c shell task " "ctrl+c background task "
    "ctrl+c shell tasks " "ctrl+c background tasks "
    "ctrl+c task " "ctrl+c tasks "
    "中断后台任务" "中断任务")
  "允许 shell-task-tool 执行中断动作的自然语言前缀。")

(defparameter +shell-task-tool-wait-input-prefixes+
  '("wait shell task " "join shell task " "await shell task "
    "wait shell tasks " "join shell tasks " "await shell tasks "
    "wait background task " "join background task " "await background task "
    "wait background tasks " "join background tasks " "await background tasks "
    "wait task " "join task " "await task "
    "wait tasks " "join tasks " "await tasks "
    "等待后台任务" "等待 shell 任务" "等待任务")
  "允许 shell-task-tool 执行等待动作的自然语言前缀。")

(defun %shell-task-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :shell-execution-failed
                              (format nil "shell 后台任务失败: ~A" detail)))

(defun %normalized-shell-task-action (value)
  (cond
    ((null value) :status)
    ((keywordp value)
     (case value
       (:status :status)
       (:interrupt :interrupt)
       (:stop :stop)
       (:wait :wait)
       (otherwise nil)))
    ((stringp value)
     (let ((text (%trim-shell-text value)))
       (cond
         ((member text '("status" "query" "inspect" "state" "状态" "查询") :test #'string-equal) :status)
         ((member text '("interrupt" "sigint" "ctrl-c" "ctrl+c" "中断") :test #'string-equal) :interrupt)
         ((member text '("stop" "kill" "terminate" "cancel" "停止" "终止" "取消") :test #'string-equal) :stop)
         ((member text '("wait" "join" "await" "等待") :test #'string-equal) :wait)
         (t nil))))
    (t nil)))

(defun %split-shell-task-ids (value)
  (let ((text (%trim-shell-text value)))
    (when (and text (> (length text) 0))
      (remove-if #'null
                 (mapcar #'%trim-shell-text
                         (uiop:split-string text :separator '(#\,)))))))

(defun %normalized-shell-task-id-list-or-nil (value)
  (cond
    ((null value) nil)
    ((stringp value)
     (let ((task-ids (%split-shell-task-ids value)))
       (and task-ids
            (every (lambda (task-id) (> (length task-id) 0)) task-ids)
            task-ids)))
    ((listp value)
      (let ((task-ids (remove-if #'null
                  (mapcar #'%trim-shell-text value))))
       (and task-ids
            (every (lambda (task-id) (> (length task-id) 0)) task-ids)
            task-ids)))
    (t nil)))

(defun %shell-task-request (task-id &key task-ids action timeout-seconds)
  (list :task-id task-id
        :task-ids task-ids
        :action (or action :status)
        :timeout-seconds timeout-seconds))

(defun %normalize-shell-task-request (task-id &key task-ids action timeout-seconds)
  (let* ((normalized-task-ids (%normalized-shell-task-id-list-or-nil (or task-ids task-id)))
         (resolved-task-id (and normalized-task-ids
                                (= (length normalized-task-ids) 1)
                                (first normalized-task-ids)))
         (resolved-task-ids (and normalized-task-ids
                                 (> (length normalized-task-ids) 1)
                                 normalized-task-ids))
        (normalized-action (%normalized-shell-task-action action))
        (normalized-timeout (%normalized-shell-timeout-seconds timeout-seconds)))
    (unless (or resolved-task-id resolved-task-ids)
      (error (%shell-task-tool-error "taskId 或 taskIds 不能为空")))
    (when (null normalized-action)
      (error (%shell-task-tool-error "action 仅支持 status、interrupt、stop 或 wait")))
    (when (and timeout-seconds
               (null normalized-timeout))
      (error (%shell-task-tool-error "timeoutSeconds 必须为正数")))
    (when (and normalized-timeout
               (not (eq normalized-action :wait)))
      (error (%shell-task-tool-error "timeoutSeconds 仅支持 wait 动作")))
    (when (and resolved-task-ids
               (eq normalized-action :status))
      (error (%shell-task-tool-error "status 动作仅支持单个 taskId")))
    (%shell-task-request resolved-task-id
                         :task-ids resolved-task-ids
                         :action normalized-action
                         :timeout-seconds normalized-timeout)))

(defun %parse-shell-task-text (text &key action)
  (%normalize-shell-task-request (%trim-shell-text text) :action action))

(defun %parse-shell-task-wait-text (text)
  (multiple-value-bind (task-id timeout-seconds foundp)
      (%split-once text " :: ")
    (if foundp
        (%normalize-shell-task-request task-id :action :wait :timeout-seconds timeout-seconds)
        (%normalize-shell-task-request text :action :wait))))

(defun %parse-prefixed-shell-task-text (text)
  (let ((wait-text (%strip-input-prefix text +shell-task-tool-wait-input-prefixes+))
        (interrupt-text (%strip-input-prefix text +shell-task-tool-interrupt-input-prefixes+))
        (stop-text (%strip-input-prefix text +shell-task-tool-stop-input-prefixes+))
        (default-text (%strip-input-prefix text +shell-task-tool-input-prefixes+)))
    (cond
      ((not (string= wait-text text))
       (%parse-shell-task-wait-text wait-text))
      ((not (string= interrupt-text text))
       (%parse-shell-task-text interrupt-text :action :interrupt))
      ((not (string= stop-text text))
       (%parse-shell-task-text stop-text :action :stop))
      ((not (string= default-text text))
       (%parse-shell-task-text default-text :action :status))
      (t
       (%parse-shell-task-text text :action :status)))))

(defun %normalized-shell-task-input (input)
  (cond
    ((and (listp input)
          (or (getf input :task-id)
              (getf input :taskId)
              (getf input :task-ids)
              (getf input :taskIds)))
     (%normalize-shell-task-request (or (getf input :task-id)
                                        (getf input :taskId))
                                    :task-ids (or (getf input :task-ids)
                                                  (getf input :taskIds))
                                    :action (or (getf input :action)
                                                (getf input :Action))
                                    :timeout-seconds (or (getf input :timeout-seconds)
                                                         (getf input :timeoutSeconds))))
    (t
     (let ((text (%trim-shell-text input)))
       (cond
         ((or (null text) (string= text "")) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-shell-task-input (subseq text (length "fixture-input-"))))
         (t (%parse-prefixed-shell-task-text text)))))))

(defun %shell-task-entry-or-error (task-id)
  (or (%shell-background-task-entry task-id)
      (error (%shell-task-tool-error (format nil "未找到后台任务: ~A" task-id)))))

(defun %shell-task-result (entry status &key (action "status") timed-out)
  (let* ((process (getf entry :process))
         (exit-code (%shell-background-process-exit-code process)))
    (list :summary (if timed-out
                       (format nil "shell 后台任务等待超时: ~A" (getf entry :task-id))
                       (format nil "shell 后台任务 ~A: ~A" status (getf entry :task-id)))
          :task-id (getf entry :task-id)
          :action action
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
          :ended-at (%format-shell-background-task-time (%shell-background-task-ended-at entry))
          :timed-out (and timed-out t))))

(defun %shell-task-status-count (results status)
  (count status results :key (lambda (result) (getf result :status)) :test #'string=))

(defun %shell-task-batch-status (results)
  (let ((statuses (remove-duplicates (mapcar (lambda (result) (getf result :status)) results)
                                     :test #'string=)))
    (if (= (length statuses) 1)
        (first statuses)
        "mixed")))

(defun %shell-task-batch-summary (results action)
  (format nil "shell 后台任务批量 ~A(~D个): ~{~A~^, ~}"
          action
          (length results)
          (mapcar (lambda (result) (getf result :task-id)) results)))

(defun %shell-task-batch-result (results action)
  (list :summary (%shell-task-batch-summary results action)
        :task-id nil
        :task-ids (mapcar (lambda (result) (getf result :task-id)) results)
        :task-count (length results)
        :running-count (%shell-task-status-count results "running")
        :stopped-count (%shell-task-status-count results "stopped")
        :completed-count (%shell-task-status-count results "completed")
        :failed-count (%shell-task-status-count results "failed")
        :tasks results
        :action action
        :status (%shell-task-batch-status results)
        :running (not (null (find-if (lambda (result) (getf result :running)) results)))
        :stopped (every (lambda (result) (getf result :stopped)) results)
        :command nil
        :directory nil
        :output-path nil
        :process-id nil
        :exit-code nil
        :stall-detected nil
        :stall-detected-at nil
        :stall-prompt-line nil
        :termination-reason nil
        :ended-at nil
        :timed-out (not (null (find-if (lambda (result) (getf result :timed-out)) results)))))

#+sbcl
(defun %stop-shell-background-task (entry &key (reason "stop"))
  (%terminate-shell-background-task-process-tree entry)
  (%record-shell-background-task-stop entry reason))

#-sbcl
(defun %stop-shell-background-task (entry &key (reason "stop"))
  (%record-shell-background-task-stop entry reason))

(defun %shell-task-stop-result (entry)
  (%stop-shell-background-task entry)
  (%shell-task-result entry "stopped" :action "stop"))

#+sbcl
(defun %interrupt-shell-background-task (entry)
  (let ((process (getf entry :process)))
    (when (%shell-background-process-alive-p process)
      (ignore-errors (sb-ext:process-kill process 2))
      (loop repeat 10
            while (%shell-background-process-alive-p process)
            do (sleep 0.05))
      (when (%shell-background-process-alive-p process)
        (%stop-shell-background-task entry :reason "interrupt")
        (return-from %interrupt-shell-background-task entry)))
        (%record-shell-background-task-stop entry "interrupt")))

#-sbcl
(defun %interrupt-shell-background-task (entry)
  (%stop-shell-background-task entry :reason "interrupt"))

(defun %shell-task-interrupt-result (entry)
  (%interrupt-shell-background-task entry)
  (%shell-task-result entry "stopped" :action "interrupt"))

#+sbcl
(defun %wait-for-shell-background-task (entry timeout-seconds)
  (let ((process (getf entry :process)))
    (cond
      ((null process)
       (values (%shell-background-task-status entry) nil))
      ((not (%shell-background-process-alive-p process))
       (values (%shell-background-task-status entry) nil))
      ((null timeout-seconds)
       (sb-ext:process-wait process)
       (values (%shell-background-task-status entry) nil))
      (t
       (let ((deadline (+ (get-internal-real-time)
                          (round (* timeout-seconds internal-time-units-per-second)))))
         (loop while (%shell-background-process-alive-p process)
               do (when (>= (get-internal-real-time) deadline)
                    (return-from %wait-for-shell-background-task
                      (values (%shell-background-task-status entry) t)))
                  (sleep 0.05))
         (values (%shell-background-task-status entry) nil))))))

#-sbcl
(defun %wait-for-shell-background-task (entry timeout-seconds)
  (declare (ignore timeout-seconds))
  (values (%shell-background-task-status entry) nil))

(defun %shell-task-wait-result (entry timeout-seconds)
  (multiple-value-bind (status timed-out)
      (%wait-for-shell-background-task entry timeout-seconds)
    (%shell-task-result entry status :action "wait" :timed-out timed-out)))

(defun %shell-task-results-for-entries (entries action timeout-seconds)
  (mapcar (lambda (entry)
            (case action
              (:status (%shell-task-result entry (%shell-background-task-status entry)))
              (:interrupt (%shell-task-interrupt-result entry))
              (:stop (%shell-task-stop-result entry))
              (:wait (%shell-task-wait-result entry timeout-seconds))
              (otherwise
               (error (%shell-task-tool-error (format nil "不支持的动作: ~A" action))))))
          entries))

(defun shell-task-tool (input)
  "查询、中断、停止或等待后台 shell 任务。"
  (let* ((request (%normalized-shell-task-input input))
         (task-id (and request (getf request :task-id)))
         (task-ids (and request (getf request :task-ids)))
         (action (and request (getf request :action)))
         (timeout-seconds (and request (getf request :timeout-seconds))))
    (unless request
      (error (%shell-task-tool-error "请求格式无效，期望 `shell task <task-id>`、`interrupt shell task <task-id>`、`stop shell task <task-id>` 或 `wait shell task <task-id>`")))
    (if task-ids
        (%shell-task-batch-result (%shell-task-results-for-entries (mapcar #'%shell-task-entry-or-error task-ids)
                                                                   action
                                                                   timeout-seconds)
                                  (string-downcase (string action)))
        (let ((entry (%shell-task-entry-or-error task-id)))
          (case action
            (:status (%shell-task-result entry (%shell-background-task-status entry)))
            (:interrupt (%shell-task-interrupt-result entry))
            (:stop (%shell-task-stop-result entry))
            (:wait (%shell-task-wait-result entry timeout-seconds))
            (otherwise
             (error (%shell-task-tool-error (format nil "不支持的动作: ~A" action)))))))))