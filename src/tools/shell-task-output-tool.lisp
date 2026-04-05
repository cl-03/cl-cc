;;;; src/tools/shell-task-output-tool.lisp - 后台 shell 任务输出读取工具
(in-package :cl-cc.tools)

(defparameter +shell-task-output-tool-wait-input-prefixes+
  '("wait shell task output " "wait background task output "
    "wait shell task outputs " "wait background task outputs "
    "wait until finished shell task output " "wait until finished background task output "
    "wait until finished shell task outputs " "wait until finished background task outputs "
    "等待后台任务输出" "等待后台任务输出完成" "等待后台任务结束输出")
  "触发 shell-task-output-tool 阻塞直到任务结束模式的自然语言前缀。")

(defparameter +shell-task-output-tool-follow-input-prefixes+
  '("follow shell task output " "follow background task output " "follow tail shell task "
    "follow shell task outputs " "follow background task outputs " "follow tail shell tasks "
    "跟随后台任务输出" "持续查看后台任务输出" "持续读取后台任务输出")
  "触发 shell-task-output-tool 短时 follow 模式的自然语言前缀。")

(defparameter +shell-task-output-tool-input-prefixes+
  '("shell task output " "background task output " "read shell task output " "tail shell task "
    "shell task outputs " "background task outputs " "read shell task outputs " "tail shell tasks "
    "查看后台任务输出" "读取后台任务输出" "后台任务输出")
  "允许 shell-task-output-tool 直接消费的自然语言前缀。")

(defparameter +shell-task-output-default-lines+ 20
  "shell-task-output-tool 缺省返回的最近日志行数。")

(defparameter +shell-task-output-default-follow-seconds+ 2
  "自然语言 follow 前缀缺省跟随输出的秒数。")

(defparameter +shell-task-output-follow-poll-interval-seconds+ 0.1d0
  "follow shell-task-output-tool 时的日志轮询间隔。")

(defun %shell-task-output-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :shell-execution-failed
                              (format nil "shell 后台任务输出失败: ~A" detail)))

(defun %positive-integer-or-nil (value)
  (cond
    ((integerp value)
     (and (> value 0) value))
    ((stringp value)
     (let* ((text (%trim-shell-text value))
            (parsed (and text
                         (ignore-errors (parse-integer text :junk-allowed nil)))))
       (and parsed (> parsed 0) parsed)))
    (t nil)))

(defun %non-negative-integer-or-nil (value)
  (cond
    ((integerp value)
     (and (>= value 0) value))
    ((stringp value)
     (let* ((text (%trim-shell-text value))
            (parsed (and text
                         (ignore-errors (parse-integer text :junk-allowed nil)))))
       (and parsed (>= parsed 0) parsed)))
    (t nil)))

(defun %shell-task-output-request (task-id &key task-ids task-requests lines start-line end-line follow-seconds wait-until-finished)
  (let ((request (list :task-id task-id)))
    (when task-ids
      (setf request (append request (list :task-ids task-ids))))
    (when task-requests
      (setf request (append request (list :task-requests task-requests))))
    (append request
            (list :lines lines
                  :start-line start-line
                  :end-line end-line
                  :follow-seconds follow-seconds
                  :wait-until-finished wait-until-finished))))

(defun %shell-task-output-request-defaults (request)
  (list :lines (getf request :lines)
        :start-line (getf request :start-line)
        :end-line (getf request :end-line)
        :follow-seconds (getf request :follow-seconds)
        :wait-until-finished (getf request :wait-until-finished)))

(defun %shell-task-output-requested-end-line (request)
  (or (getf request :end-line)
      (and (getf request :start-line)
           (+ (getf request :start-line)
              (getf request :lines)
              -1))))

(defun %normalize-shell-task-output-request (task-id &key task-ids task-requests lines start-line end-line follow-seconds wait-until-finished)
  (let* ((normalized-task-ids (%normalized-shell-task-id-list-or-nil (or task-ids task-id)))
         (resolved-task-id (and normalized-task-ids
                                (= (length normalized-task-ids) 1)
                                (first normalized-task-ids)))
         (resolved-task-ids (and normalized-task-ids
                                 (> (length normalized-task-ids) 1)
                                 normalized-task-ids))
         (normalized-lines (%positive-integer-or-nil lines))
         (normalized-start-line (%positive-integer-or-nil start-line))
         (normalized-end-line (%positive-integer-or-nil end-line))
         (normalized-follow-seconds (cond
                                      ((eq follow-seconds t)
                                       +shell-task-output-default-follow-seconds+)
                                      ((null follow-seconds) nil)
                                      (t (%non-negative-integer-or-nil follow-seconds))))
         (normalized-wait-until-finished (not (null (%normalized-shell-background wait-until-finished))))
         (resolved-lines nil))
    (when (and task-requests (or resolved-task-id resolved-task-ids))
      (error (%shell-task-output-tool-error "tasks 与 taskId/taskIds 不能同时指定")))
    (unless (or resolved-task-id resolved-task-ids task-requests)
      (error (%shell-task-output-tool-error "taskId、taskIds 或 tasks 不能为空")))
    (when (and start-line (null normalized-start-line))
      (error (%shell-task-output-tool-error "startLine 必须为正整数")))
    (when (and end-line (null normalized-end-line))
      (error (%shell-task-output-tool-error "endLine 必须为正整数")))
    (when (and follow-seconds (null normalized-follow-seconds))
      (error (%shell-task-output-tool-error "followSeconds 必须为非负整数")))
    (when (and normalized-wait-until-finished normalized-follow-seconds)
      (error (%shell-task-output-tool-error "followSeconds 与 waitUntilFinished 不能同时指定")))
    (when (and normalized-end-line (null normalized-start-line))
      (error (%shell-task-output-tool-error "endLine 不能脱离 startLine 单独使用")))
    (when (and normalized-lines normalized-end-line)
      (error (%shell-task-output-tool-error "lines 与 endLine 不能同时指定")))
    (when (and normalized-start-line
               normalized-end-line
               (> normalized-start-line normalized-end-line))
      (error (%shell-task-output-tool-error "startLine 不能大于 endLine")))
    (setf resolved-lines (cond
                           (normalized-end-line
                            (1+ (- normalized-end-line normalized-start-line)))
                           (normalized-start-line
                            (or normalized-lines +shell-task-output-default-lines+))
                           (t
                            (or normalized-lines +shell-task-output-default-lines+))))
    (when (null resolved-lines)
      (error (%shell-task-output-tool-error "lines 必须为正整数")))
    (%shell-task-output-request resolved-task-id
                                :task-ids resolved-task-ids
                                :task-requests task-requests
                                :lines resolved-lines
                                :start-line normalized-start-line
                                :end-line normalized-end-line
                                :follow-seconds normalized-follow-seconds
                                :wait-until-finished normalized-wait-until-finished)))

(defun %normalize-shell-task-output-task-request (task-request defaults)
  (unless (listp task-request)
    (error (%shell-task-output-tool-error "tasks 仅支持由对象组成的数组")))
  (let* ((task-id (or (getf task-request :task-id)
                      (getf task-request :taskId)))
         (explicit-lines (getf task-request :lines))
         (explicit-start-line (or (getf task-request :start-line)
                                  (getf task-request :startLine)))
         (explicit-end-line (or (getf task-request :end-line)
                                (getf task-request :endLine)))
         (inherited-lines (and (null explicit-end-line)
                               (getf defaults :lines)))
         (inherited-end-line (and (null explicit-lines)
                                  (getf defaults :end-line))))
    (%normalize-shell-task-output-request task-id
                                          :lines (or explicit-lines
                                                     inherited-lines)
                                          :start-line (or explicit-start-line
                                                          (getf defaults :start-line))
                                          :end-line (or explicit-end-line
                                                        inherited-end-line)
                                          :follow-seconds (or (getf task-request :follow-seconds)
                                                              (getf task-request :followSeconds)
                                                              (and (getf task-request :follow) t)
                                                              (getf defaults :follow-seconds))
                                          :wait-until-finished (or (getf task-request :wait-until-finished)
                                                                   (getf task-request :waitUntilFinished)
                                                                   (getf task-request :until-finished)
                                                                   (getf task-request :untilFinished)
                                                                   (getf task-request :block)
                                                                   (getf defaults :wait-until-finished)))))

(defun %normalized-shell-task-output-task-requests-or-nil (value defaults)
  (cond
    ((null value) nil)
    ((and (listp value)
          (every #'listp value))
     (let ((normalized-requests (mapcar (lambda (task-request)
                                         (%normalize-shell-task-output-task-request task-request defaults))
                                       value)))
       (unless (> (length normalized-requests) 0)
         (error (%shell-task-output-tool-error "tasks 不能为空")))
       normalized-requests))
    (t
     (error (%shell-task-output-tool-error "tasks 仅支持对象数组")))))

(defun %split-shell-task-output-segments (text)
  (loop with segments = '()
        with remainder = nil
        for remaining = text then remainder
        do (multiple-value-bind (segment rest foundp)
               (%split-once remaining " :: ")
             (if foundp
                 (progn
                   (push (%trim-shell-text segment) segments)
                   (setf remainder rest))
                 (return (nreverse (cons (%trim-shell-text remaining) segments)))))))

(defun %shell-task-output-option-keyword (key)
  (let ((normalized-key (cl-cc.lib:string-designator-downcase key)))
    (cond
      ((member normalized-key '("lines" "tail" "tail-lines" "line-count") :test #'string=)
       :lines)
      ((member normalized-key '("start" "from" "offset" "start-line") :test #'string=)
       :start-line)
      ((member normalized-key '("end" "to" "end-line") :test #'string=)
       :end-line)
      ((member normalized-key '("follow" "follow-seconds" "wait") :test #'string=)
       :follow-seconds)
      ((member normalized-key '("wait-until-finished" "until-finished" "block") :test #'string=)
       :wait-until-finished)
      (t nil))))

(defun %shell-task-output-option-value (segment)
  (multiple-value-bind (key value foundp)
      (%split-once segment "=")
    (if foundp
        (values (%shell-task-output-option-keyword key)
                (%trim-shell-text value)
                t)
        (values nil nil nil))))

(defun %apply-shell-task-output-option-segment (request segment)
  (let ((normalized-segment (%trim-shell-text segment)))
    (cond
      ((or (null normalized-segment)
           (string= normalized-segment ""))
       request)
      ((string-equal normalized-segment "follow")
       (setf (getf request :follow-seconds) +shell-task-output-default-follow-seconds+)
       request)
      ((member normalized-segment '("wait-until-finished" "until-finished" "block") :test #'string-equal)
       (setf (getf request :wait-until-finished) t)
       request)
      (t
       (multiple-value-bind (option-key option-value foundp)
           (%shell-task-output-option-value normalized-segment)
         (cond
           ((and foundp option-key)
            (setf (getf request option-key) option-value)
            request)
           ((%positive-integer-or-nil normalized-segment)
            (setf (getf request :lines) normalized-segment)
            request)
           (t
            (error (%shell-task-output-tool-error
                    (format nil "无法解析输出选项: ~A" normalized-segment))))))))))

(defun %parse-shell-task-output-text (text &key default-follow-seconds)
  (let* ((segments (%split-shell-task-output-segments text))
         (task-id-text (first segments))
         (request (%shell-task-output-request task-id-text
                                             :follow-seconds default-follow-seconds)))
    (dolist (segment (rest segments))
      (setf request (%apply-shell-task-output-option-segment request segment)))
    (%normalize-shell-task-output-request (getf request :task-id)
                                          :task-ids (getf request :task-ids)
                                          :lines (getf request :lines)
                                          :start-line (getf request :start-line)
                                          :end-line (getf request :end-line)
                                          :follow-seconds (getf request :follow-seconds)
                                          :wait-until-finished (getf request :wait-until-finished))))

(defun %normalized-shell-task-output-structured-input (input)
  (let* ((input-task-id (or (getf input :task-id)
                            (getf input :taskId)))
         (input-task-ids (or (getf input :task-ids)
                             (getf input :taskIds)))
         (input-tasks (or (getf input :tasks)
                          (getf input :Tasks)))
         (defaults (%shell-task-output-request-defaults
                    (%normalize-shell-task-output-request (and (null input-tasks)
                                                               input-task-id)
                                                          :task-ids (and (null input-tasks)
                                                                         input-task-ids)
                                                          :task-requests (and input-tasks
                                                                              '(:placeholder t))
                                                          :lines (or (getf input :lines)
                                                                     (getf input :tail-lines)
                                                                     (getf input :tailLines))
                                                          :start-line (or (getf input :start-line)
                                                                          (getf input :startLine)
                                                                          (getf input :from-line)
                                                                          (getf input :fromLine)
                                                                          (getf input :offset-line)
                                                                          (getf input :offsetLine))
                                                          :end-line (or (getf input :end-line)
                                                                        (getf input :endLine)
                                                                        (getf input :to-line)
                                                                        (getf input :toLine))
                                                          :follow-seconds (or (getf input :follow-seconds)
                                                                              (getf input :followSeconds)
                                                                              (and (getf input :follow) t))
                                                          :wait-until-finished (or (getf input :wait-until-finished)
                                                                                   (getf input :waitUntilFinished)
                                                                                   (getf input :until-finished)
                                                                                   (getf input :untilFinished)
                                                                                   (getf input :block)))))
                                               (task-requests (%normalized-shell-task-output-task-requests-or-nil input-tasks
                                                                            defaults)))
                                            (%normalize-shell-task-output-request input-task-id
                                                                :task-ids input-task-ids
                                          :task-requests task-requests
                                          :lines (getf defaults :lines)
                                          :start-line (getf defaults :start-line)
                                          :end-line (getf defaults :end-line)
                                          :follow-seconds (getf defaults :follow-seconds)
                                          :wait-until-finished (getf defaults :wait-until-finished))))

(defun %parse-shell-task-output-natural-language-input (text)
  (let ((wait-text (%strip-input-prefix text +shell-task-output-tool-wait-input-prefixes+))
        (follow-text (%strip-input-prefix text +shell-task-output-tool-follow-input-prefixes+))
        (default-text (%strip-input-prefix text +shell-task-output-tool-input-prefixes+)))
    (cond
      ((not (string= wait-text text))
       (%parse-shell-task-output-text (format nil "~A :: wait-until-finished" wait-text)))
      ((not (string= follow-text text))
       (%parse-shell-task-output-text follow-text
                                      :default-follow-seconds +shell-task-output-default-follow-seconds+))
      (t
       (%parse-shell-task-output-text default-text)))))

(defun %normalized-shell-task-output-input (input)
  (cond
    ((and (listp input)
          (or (getf input :task-id)
              (getf input :taskId)
              (getf input :task-ids)
          (getf input :taskIds)
          (getf input :tasks)
          (getf input :Tasks)))
     (%normalized-shell-task-output-structured-input input))
    (t
     (let ((text (%trim-shell-text input)))
       (cond
         ((or (null text) (string= text "")) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-shell-task-output-input (subseq text (length "fixture-input-"))))
         (t
          (%parse-shell-task-output-natural-language-input text)))))))

(defun %shell-task-output-all-lines (contents)
  (let ((normalized-contents (%trim-shell-output (%normalized-file-read-lines contents))))
    (if (string= normalized-contents "")
        '()
        (uiop:split-string normalized-contents :separator '(#\Newline)))))

(defun %shell-task-output-content (all-lines start-line end-line)
  (format nil "~{~A~^~%~}"
          (loop for line-number from start-line to end-line
                collect (format nil "~D:~A"
                                line-number
                                (nth (1- line-number) all-lines)))))

(defun %shell-task-output-lines (contents requested-lines &key start-line end-line)
  (let* ((all-lines (%shell-task-output-all-lines contents))
         (total-lines (length all-lines)))
    (if (zerop total-lines)
        (list :content ""
              :start-line nil
              :end-line nil
              :total-lines 0)
        (let* ((resolved-start-line (or start-line
                                        (1+ (- total-lines (min requested-lines total-lines)))))
               (resolved-request-end-line (or end-line
                                             (+ resolved-start-line requested-lines -1))))
          (if (> resolved-start-line total-lines)
              (list :content ""
                    :start-line nil
                    :end-line nil
                    :total-lines total-lines)
              (let* ((resolved-end-line (min resolved-request-end-line total-lines))
                     (content (%shell-task-output-content all-lines
                                                         resolved-start-line
                                                         resolved-end-line)))
                (list :content content
                      :start-line resolved-start-line
                      :end-line resolved-end-line
                      :total-lines total-lines)))))))

(defun %follow-shell-task-output-contents (entry output-path follow-seconds wait-until-finished)
  (let ((initial-contents (uiop:read-file-string output-path)))
    (if (and (not wait-until-finished)
             (or (null follow-seconds)
                 (<= follow-seconds 0)))
        initial-contents
        (let ((deadline (and (not wait-until-finished)
                             (+ (get-internal-real-time)
                                (round (* follow-seconds internal-time-units-per-second))))))
          (loop do (when (or (and deadline
                                  (>= (get-internal-real-time) deadline))
                              (not (string= (%shell-background-task-status entry) "running")))
                     (return (uiop:read-file-string output-path)))
                   (sleep +shell-task-output-follow-poll-interval-seconds+))))))

(defun %shell-task-output-summary (task-id lines-requested &key start-line end-line follow-seconds wait-until-finished)
  (let* ((mode (if start-line "range" "tail"))
         (window-text (if start-line
                          (format nil "~D-~D"
                                  start-line
                                  (or end-line (+ start-line lines-requested -1)))
                          (format nil "最近~D行" lines-requested)))
         (follow-text (cond
                        (wait-until-finished
                         ", wait until finished")
                        (follow-seconds
                         (format nil ", follow ~D秒" follow-seconds))
                        (t ""))))
    (format nil "shell 后台任务输出(~A ~A~A): ~A"
            mode
            window-text
            follow-text
            task-id)))

(defun %shell-task-output-mode (request)
  (if (getf request :start-line)
      "range"
      "tail"))

(defun %shell-task-output-status-count (results status)
  (count status results :key (lambda (result)
                               (getf result :status))
         :test #'string=))

(defun %shell-task-output-batch-status (results)
  (let ((statuses (remove-duplicates (mapcar (lambda (result)
                                               (getf result :status))
                                             results)
                                     :test #'string=)))
    (if (= (length statuses) 1)
        (first statuses)
        "mixed")))

(defun %shell-task-output-common-value-or-nil (results key &key (test #'equal))
  (let ((values (mapcar (lambda (result)
                          (getf result key))
                        results)))
    (if (or (null values)
            (every (lambda (value)
                     (funcall test value (first values)))
                   (rest values)))
        (first values)
        nil)))

(defun %shell-task-output-common-mode (results)
  (or (%shell-task-output-common-value-or-nil results :mode :test #'string=)
      "mixed"))

(defun %shell-task-output-window-label (request)
  (if (getf request :start-line)
      (format nil "~D-~D"
              (getf request :start-line)
              (%shell-task-output-requested-end-line request))
      (format nil "最近~D行" (getf request :lines))))

(defun %shell-task-output-batch-summary (request results)
  (let* ((common-mode (%shell-task-output-common-mode results))
         (shared-window-p (and (%shell-task-output-common-value-or-nil results :lines-requested)
                               (or (%shell-task-output-common-value-or-nil results :requested-start-line)
                                   (%shell-task-output-common-value-or-nil results :requested-end-line)
                                   (%shell-task-output-common-value-or-nil results :lines-requested))))
         (window-label (if shared-window-p
                           (%shell-task-output-window-label request)
                           "mixed windows"))
         (common-wait (%shell-task-output-common-value-or-nil results :wait-until-finished))
         (common-follow-seconds (%shell-task-output-common-value-or-nil results :follow-seconds))
         (follow-text (cond
                        (common-wait
                         ", wait until finished")
                        (common-follow-seconds
                         (format nil ", follow ~D秒" common-follow-seconds))
                        ((every (lambda (result)
                                  (null (getf result :follow-seconds)))
                                results)
                         "")
                        (t ", mixed options"))))
    (format nil "shell 后台任务批量输出(~A ~A~A, ~D个): ~{~A~^, ~}"
            common-mode
            window-label
            follow-text
            (length results)
            (mapcar (lambda (result)
                      (getf result :task-id))
                    results))))

(defun %shell-task-output-batch-result (request results)
  (list :summary (%shell-task-output-batch-summary request results)
        :task-id nil
        :task-ids (mapcar (lambda (result)
                            (getf result :task-id))
                          results)
        :task-count (length results)
        :mode (%shell-task-output-common-mode results)
        :status (%shell-task-output-batch-status results)
        :running (not (null (find-if (lambda (result)
                                       (getf result :running))
                                     results)))
        :stopped (every (lambda (result)
                          (getf result :stopped))
                        results)
        :output-path nil
        :lines-requested (%shell-task-output-common-value-or-nil results :lines-requested)
        :requested-start-line (%shell-task-output-common-value-or-nil results :requested-start-line)
        :requested-end-line (%shell-task-output-common-value-or-nil results :requested-end-line)
        :follow-seconds (%shell-task-output-common-value-or-nil results :follow-seconds)
        :wait-until-finished (%shell-task-output-common-value-or-nil results :wait-until-finished)
        :start-line nil
        :end-line nil
        :total-lines nil
        :running-count (%shell-task-output-status-count results "running")
        :stopped-count (%shell-task-output-status-count results "stopped")
        :completed-count (%shell-task-output-status-count results "completed")
        :failed-count (%shell-task-output-status-count results "failed")
        :tasks results
        :content nil))

(defun %shell-task-output-result (entry request)
  (let* ((task-id (getf entry :task-id))
         (output-path (getf entry :output-path))
         (lines-requested (getf request :lines))
         (requested-start-line (getf request :start-line))
         (requested-end-line (getf request :end-line))
         (follow-seconds (getf request :follow-seconds))
         (wait-until-finished (not (null (getf request :wait-until-finished)))))
    (unless output-path
      (error (%shell-task-output-tool-error (format nil "后台任务缺少输出路径: ~A" task-id))))
    (unless (probe-file output-path)
      (error (%shell-task-output-tool-error (format nil "后台任务输出日志不存在: ~A" output-path))))
    (handler-case
        (let* ((contents (%follow-shell-task-output-contents entry output-path follow-seconds wait-until-finished))
               (window-result (%shell-task-output-lines contents
                                                        lines-requested
                                                        :start-line requested-start-line
                                                        :end-line requested-end-line))
               (status (%shell-background-task-status entry)))
          (list :summary (%shell-task-output-summary task-id
                                                     lines-requested
                                                     :start-line requested-start-line
                                                     :end-line requested-end-line
                         :follow-seconds follow-seconds
                         :wait-until-finished wait-until-finished)
                :task-id task-id
                :mode (%shell-task-output-mode request)
                :status status
                :running (string= status "running")
                :stopped (string= status "stopped")
                :output-path output-path
                :lines-requested lines-requested
                :requested-start-line requested-start-line
                :requested-end-line (%shell-task-output-requested-end-line request)
                :follow-seconds follow-seconds
                :wait-until-finished wait-until-finished
                :start-line (getf window-result :start-line)
                :end-line (getf window-result :end-line)
                :total-lines (getf window-result :total-lines)
                :content (getf window-result :content)))
      (cl-cc.lib:cl-cc-error (condition)
        (error condition))
      (error ()
        (error (%shell-task-output-tool-error (format nil "无法读取后台任务输出: ~A" output-path)))))))

(defun shell-task-output-tool (input)
  "读取后台 shell 任务输出窗口，并支持短时 follow 或阻塞等待直到任务结束。"
  (let* ((request (%normalized-shell-task-output-input input))
         (task-id (and request (getf request :task-id)))
         (task-ids (and request (getf request :task-ids)))
         (task-requests (and request (getf request :task-requests))))
    (unless request
      (error (%shell-task-output-tool-error
              "请求格式无效，期望 `shell task output <task-id>`、`shell task outputs <task-id-1,task-id-2>`、结构化 tasks 数组、`follow shell task output <task-id>` 或 `wait shell task output <task-id>`")))
    (if (or task-ids task-requests)
        (%shell-task-output-batch-result request
                                         (if task-requests
                                             (mapcar (lambda (task-request)
                                                       (%shell-task-output-result (%shell-task-entry-or-error (getf task-request :task-id))
                                                                                  task-request))
                                                     task-requests)
                                             (mapcar (lambda (resolved-task-id)
                                                       (%shell-task-output-result (%shell-task-entry-or-error resolved-task-id)
                                                                                  request))
                                                     task-ids)))
        (%shell-task-output-result (%shell-task-entry-or-error task-id)
                                   request))))