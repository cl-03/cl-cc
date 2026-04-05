;;;; src/tools/shell-task-detail-tool.lisp - 后台 shell 任务详情工具
(in-package :cl-cc.tools)

(defparameter +shell-task-detail-tool-input-prefixes+
  '("shell task detail " "background task detail " "show shell task detail "
    "后台任务详情" "查看后台任务详情" "显示后台任务详情")
  "允许 shell-task-detail-tool 直接消费的自然语言前缀。")

(defun %shell-task-detail-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :shell-execution-failed
                              (format nil "shell 后台任务详情失败: ~A" detail)))

(defun %shell-task-detail-request (task-id)
  (list :task-id task-id))

(defun %normalize-shell-task-detail-request (task-id)
  (let ((normalized-task-id (%trim-shell-text task-id)))
    (unless (and normalized-task-id
                 (> (length normalized-task-id) 0))
      (error (%shell-task-detail-tool-error "taskId 不能为空")))
    (%shell-task-detail-request normalized-task-id)))

(defun %parse-prefixed-shell-task-detail-text (text)
  (let ((prefixed-text (%strip-input-prefix text +shell-task-detail-tool-input-prefixes+)))
    (if (string= prefixed-text text)
        nil
        (%normalize-shell-task-detail-request prefixed-text))))

(defun %normalized-shell-task-detail-input (input)
  (cond
    ((and (listp input)
          (or (getf input :task-id)
              (getf input :taskId)))
     (%normalize-shell-task-detail-request (or (getf input :task-id)
                                               (getf input :taskId))))
    (t
     (let ((text (%trim-shell-text input)))
       (cond
         ((or (null text) (string= text "")) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-shell-task-detail-input (subseq text (length "fixture-input-"))))
         (t (%parse-prefixed-shell-task-detail-text text)))))))

(defun %shell-task-detail-duration-seconds (entry status)
  (let* ((started-at (getf entry :started-at))
         (ended-at (cond
                     ((string= status "stopped") (getf entry :stopped-at))
                     ((member status '("completed" "failed") :test #'string=)
                      (getf entry :finished-at))
                     (t (get-universal-time)))))
    (when (and started-at ended-at)
      (max 0 (- ended-at started-at)))))

(defun %shell-task-detail-output-bytes (path)
  (when (and path (probe-file path))
    (with-open-file (stream path :direction :input :element-type '(unsigned-byte 8))
      (file-length stream))))

(defun %shell-task-detail-output-line-count (path)
  (when (and path (probe-file path))
    (with-open-file (stream path :direction :input)
      (loop for line = (read-line stream nil nil)
            while line
            count 1))))

(defun %shell-task-detail-output-updated-at (path)
  (when (and path (probe-file path))
    (%format-shell-background-task-time (file-write-date path))))

(defun %shell-task-detail-result (entry)
  (let* ((status (%shell-background-task-status entry))
         (process (getf entry :process))
         (exit-code (%shell-background-process-exit-code process))
         (output-path (getf entry :output-path)))
    (list :summary (format nil "shell 后台任务详情 ~A: ~A" status (getf entry :task-id))
          :task-id (getf entry :task-id)
          :status status
          :running (string= status "running")
          :stopped (string= status "stopped")
          :command (getf entry :command)
          :directory (getf entry :directory)
          :output-path output-path
          :process-id (getf entry :process-id)
          :exit-code exit-code
          :started-at (%format-shell-background-task-time (getf entry :started-at))
          :stopped-at (%format-shell-background-task-time (getf entry :stopped-at))
          :finished-at (%format-shell-background-task-time (getf entry :finished-at))
          :stall-detected (%shell-background-task-stall-detected-p entry)
          :stall-detected-at (%shell-background-task-stall-detected-at-string entry)
          :stall-prompt-line (%shell-background-task-stall-prompt-line entry)
          :termination-reason (getf entry :termination-reason)
          :ended-at (%format-shell-background-task-time (%shell-background-task-ended-at entry))
          :duration-seconds (%shell-task-detail-duration-seconds entry status)
          :output-bytes (%shell-task-detail-output-bytes output-path)
          :output-line-count (%shell-task-detail-output-line-count output-path)
          :output-updated-at (%shell-task-detail-output-updated-at output-path))))

(defun shell-task-detail-tool (input)
  "读取后台 shell 任务详情。"
  (let* ((request (%normalized-shell-task-detail-input input))
         (task-id (and request (getf request :task-id))))
    (unless request
      (error (%shell-task-detail-tool-error "请求格式无效，期望 `shell task detail <task-id>` 或 `后台任务详情<task-id>`")))
    (let ((entry (%shell-background-task-entry task-id)))
      (unless entry
        (error (%shell-task-detail-tool-error (format nil "未找到后台任务: ~A" task-id))))
      (%shell-task-detail-result entry))))