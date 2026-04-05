;;;; src/tools/shell-tool.lisp - 最小可用 shell 执行工具
(in-package :cl-cc.tools)

(defparameter +shell-tool-trim-characters+
  '(#\Space #\Tab #\Newline #\Return)
  "shell-tool 共享裁剪字符集。")

(defparameter +shell-tool-input-prefixes+
  '("run shell " "shell " "bash " "execute command " "run command "
    "执行命令" "运行命令" "执行shell" "运行shell")
  "允许 shell-tool 直接消费的自然语言前缀。")

(defparameter +shell-tool-background-input-prefixes+
  '("background shell " "background bash " "run shell background "
    "后台执行命令" "后台运行命令" "后台执行shell" "后台运行shell")
  "允许 shell-tool 以后台模式消费的自然语言前缀。")

(defparameter +shell-background-stall-check-interval-seconds+ 5
  "后台 shell 任务 stall watchdog 的轮询间隔（秒）。")

(defparameter +shell-background-stall-threshold-seconds+ 45
  "后台 shell 任务输出停止增长多少秒后开始检查是否疑似卡在交互提示。")

(defparameter +shell-background-stall-tail-bytes+ 1024
  "后台 shell 任务做 stall 检测时读取的输出尾部字节数。")

(defparameter *shell-background-task-registry* (make-hash-table :test 'equal)
  "后台 shell 任务注册表。")

(defun %shell-tool-message (detail)
  (format nil "shell 执行失败: ~A" detail))

(defun %shell-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :shell-execution-failed
                              (%shell-tool-message detail)))

(defun %trim-shell-text (value)
  (and value
       (string-trim +shell-tool-trim-characters+ (string value))))

(defun %trim-shell-output (value)
  (string-right-trim '(#\Newline #\Return)
                     (or value "")))

(defun %normalized-shell-background (value)
  (cond
    ((null value) nil)
    ((member value '(t nil)) value)
    ((stringp value)
     (let ((text (%trim-shell-text value)))
       (cond
         ((member text '("true" "yes" "1") :test #'string-equal) t)
         ((member text '("false" "no" "0") :test #'string-equal) nil)
         (t nil))))
    (t nil)))

(defun %normalized-shell-timeout-seconds (value)
  (cond
    ((null value) nil)
    ((and (numberp value)
          (> value 0))
     value)
    ((stringp value)
     (let ((parsed (ignore-errors (read-from-string value))))
       (and (numberp parsed)
            (> parsed 0)
            parsed)))
    (t nil)))

(defun %normalized-shell-directory (value)
  (let ((text (%trim-shell-text value)))
    (when (and text
               (> (length text) 0))
      (unless (uiop:directory-exists-p text)
        (error (%shell-tool-error (format nil "目录不存在: ~A" text))))
      (uiop:native-namestring (uiop:ensure-directory-pathname text)))))

(defun %shell-request (command &key directory timeout-seconds background)
  (let ((request (list :command command)))
    (when directory
      (setf request (append request (list :directory directory))))
    (setf request (append request (list :background background)))
    (when timeout-seconds
      (setf request (append request (list :timeout-seconds timeout-seconds))))
    request))

(defun %normalize-shell-request (command &key directory timeout-seconds background)
  (let ((normalized-command (%trim-shell-text command))
        (normalized-directory (%normalized-shell-directory directory))
        (normalized-timeout (%normalized-shell-timeout-seconds timeout-seconds))
        (normalized-background (%normalized-shell-background background)))
    (unless (and normalized-command
                 (> (length normalized-command) 0))
      (error (%shell-tool-error "命令为空")))
    (when (and timeout-seconds
               (null normalized-timeout))
      (error (%shell-tool-error "超时时间必须为正数")))
    (when (and background
               (null normalized-background)
               (not (eq background nil)))
      (error (%shell-tool-error "background 必须为布尔值")))
    (%shell-request normalized-command
                    :directory normalized-directory
                    :timeout-seconds normalized-timeout
                    :background normalized-background)))

(defun %parse-shell-text (text &key background)
  (let ((stripped-text (%strip-input-prefix text +shell-tool-input-prefixes+)))
    (multiple-value-bind (command directory foundp)
        (%split-once stripped-text " :: ")
      (if foundp
          (%normalize-shell-request command :directory directory :background background)
          (%normalize-shell-request stripped-text :background background)))))

(defun %parse-prefixed-shell-text (text)
  (let ((background-text (%strip-input-prefix text +shell-tool-background-input-prefixes+))
        (default-text (%strip-input-prefix text +shell-tool-input-prefixes+)))
    (cond
      ((not (string= background-text text))
       (%parse-shell-text background-text :background t))
      ((not (string= default-text text))
       (%parse-shell-text default-text :background nil))
      (t
       (%parse-shell-text text :background nil)))))

(defun %normalized-shell-input (input)
  (cond
    ((and (listp input)
          (getf input :command))
     (%normalize-shell-request (getf input :command)
                               :directory (getf input :directory)
                               :timeout-seconds (getf input :timeout-seconds)
                               :background (getf input :background)))
    (t
     (let ((text (%trim-shell-text input)))
       (cond
         ((or (null text) (string= text "")) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-shell-input (subseq text (length "fixture-input-"))))
         (t (%parse-prefixed-shell-text text)))))))

(defun %shell-program-and-arguments (command)
  (if (uiop:os-windows-p)
      (values "powershell"
              (list "-NoProfile" "-NonInteractive" "-Command" command))
      (values "sh"
              (list "-lc" command))))

(defun %resolved-shell-directory (directory)
  (or directory
      (uiop:native-namestring (uiop:getcwd))))

(defun %shell-result-summary (command exit-code timed-out-p)
  (if timed-out-p
      (format nil "shell 命令超时: ~A" command)
      (format nil "shell exit ~A: ~A" exit-code command)))

(defun %shell-background-summary (command task-id)
  (format nil "shell 后台启动(~A): ~A" task-id command))

(defun %shell-background-task-id ()
  (format nil "shell-task-~A-~36R"
          (get-universal-time)
          (random (expt 36 6))))

(defun %shell-background-output-path (task-id)
  (uiop:native-namestring
   (uiop:merge-pathnames* (format nil "~A.log" task-id)
                          (uiop:temporary-directory))))

(defun %shell-background-process-id (process)
  (ignore-errors (sb-ext:process-pid process)))

(defun %format-shell-background-task-time (universal-time)
  (when universal-time
    (multiple-value-bind (second minute hour day month year)
        (decode-universal-time universal-time 0)
      (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
              year month day hour minute second))))

(defun %shell-background-monotonic-seconds ()
  (/ (get-internal-real-time)
     internal-time-units-per-second))

(defun %shell-background-task-natural-termination-reason (exit-code)
  (if (and (integerp exit-code)
           (not (zerop exit-code)))
      "error-exit"
      "exit"))

(defun %normalized-shell-background-termination-reason (value)
  (cond
    ((null value) nil)
    ((stringp value)
     (let ((text (%trim-shell-text value)))
       (cond
         ((member text '("exit" "completed" "complete" "正常退出") :test #'string-equal) "exit")
         ((member text '("error-exit" "failed" "fail" "错误退出" "失败退出") :test #'string-equal) "error-exit")
         ((member text '("stop" "stopped" "cancel" "取消" "停止") :test #'string-equal) "stop")
         ((member text '("interrupt" "interrupted" "sigint" "ctrl-c" "ctrl+c" "中断") :test #'string-equal) "interrupt")
         (t nil))))
    (t nil)))

(defun %shell-background-task-ended-at (entry)
  (or (getf entry :stopped-at)
      (getf entry :finished-at)))

(defun %shell-background-task-stall-detected-p (entry)
  (not (null (getf entry :stall-detected-p))))

(defun %shell-background-task-stall-detected-at-string (entry)
  (%format-shell-background-task-time (getf entry :stall-detected-at)))

(defun %shell-background-task-stall-prompt-line (entry)
  (getf entry :stall-prompt-line))

(defun %shell-background-task-clear-stall (entry)
  (setf (getf entry :stall-detected-p) nil
        (getf entry :stall-detected-at) nil
        (getf entry :stall-prompt-line) nil)
  entry)

(defun %record-shell-background-task-stall (entry prompt-line)
  (setf (getf entry :stall-detected-p) t
        (getf entry :stall-detected-at) (or (getf entry :stall-detected-at)
                                            (get-universal-time))
        (getf entry :stall-prompt-line) prompt-line)
  entry)

(defun %shell-background-file-size (path)
  (when (and path (probe-file path))
    (with-open-file (stream path :direction :input :element-type '(unsigned-byte 8))
      (file-length stream))))

(defun %shell-background-octets-ascii-string (octets)
  (coerce (map 'list (lambda (octet)
                       (code-char octet))
               octets)
          'string))

(defun %shell-background-output-tail (path max-bytes)
  (when (and path
             max-bytes
             (> max-bytes 0)
             (probe-file path))
    (with-open-file (stream path :direction :input :element-type '(unsigned-byte 8))
      (let* ((size (file-length stream))
             (start (max 0 (- size max-bytes)))
             (count (- size start))
             (buffer (make-array count :element-type '(unsigned-byte 8))))
        (file-position stream start)
        (read-sequence buffer stream)
        (%shell-background-octets-ascii-string buffer)))))

(defun %shell-background-last-line (text)
  (when text
    (let* ((trimmed (string-right-trim '(#\Newline #\Return) text))
           (position (position #\Newline trimmed :from-end t)))
      (if position
          (subseq trimmed (1+ position))
          trimmed))))

(defun %shell-background-prompt-like-p (line)
  (let ((text (and line (%trim-shell-text line))))
    (when (and text (> (length text) 0))
      (let ((lower (string-downcase text)))
        (or (search "(y/n)" lower)
            (search "[y/n]" lower)
            (search "(yes/no)" lower)
            (search "press any key" lower)
            (search "press enter" lower)
            (search "continue?" lower)
            (search "overwrite?" lower)
            (and (char= (char lower (1- (length lower))) #\?)
                 (or (search "do you" lower)
                     (search "would you" lower)
                     (search "shall i" lower)
                     (search "are you sure" lower)
                     (search "ready to" lower))))))))

#+sbcl
(defun %start-shell-background-stall-watchdog (entry)
  (declare (ignore entry))
  nil)

#-sbcl
(defun %start-shell-background-stall-watchdog (entry)
  (declare (ignore entry))
  nil)

(defun %refresh-shell-background-task-stall-state (entry alive-p)
  (if (not alive-p)
      (%shell-background-task-clear-stall entry)
      (let* ((output-path (getf entry :output-path))
             (current-size (%shell-background-file-size output-path))
             (observed-size (getf entry :observed-output-size))
             (started-at (getf entry :started-at))
             (now (%shell-background-monotonic-seconds))
             (started-at-monotonic (or (getf entry :started-at-monotonic)
                                       now))
             (last-size-change-at (or (getf entry :output-size-changed-at-monotonic)
                                      started-at-monotonic)))
        (cond
          ((null current-size)
           (%shell-background-task-clear-stall entry))
          ((null observed-size)
           (setf (getf entry :observed-output-size) current-size)
           (if (>= (- now last-size-change-at)
                   +shell-background-stall-threshold-seconds+)
               (let* ((tail (%shell-background-output-tail output-path +shell-background-stall-tail-bytes+))
                      (prompt-line (%shell-background-last-line tail)))
                 (if (%shell-background-prompt-like-p prompt-line)
                     (%record-shell-background-task-stall entry prompt-line)
                     (%shell-background-task-clear-stall entry)))
               (%shell-background-task-clear-stall entry)))
          ((/= current-size observed-size)
           (setf (getf entry :observed-output-size) current-size)
               (if (and (zerop observed-size)
                    started-at
                    (= last-size-change-at started-at-monotonic)
                    (>= (- now last-size-change-at)
                        +shell-background-stall-threshold-seconds+))
               (let* ((tail (%shell-background-output-tail output-path +shell-background-stall-tail-bytes+))
                      (prompt-line (%shell-background-last-line tail)))
                 (if (%shell-background-prompt-like-p prompt-line)
                     (%record-shell-background-task-stall entry prompt-line)
                     (%shell-background-task-clear-stall entry)))
               (progn
                 (setf (getf entry :output-size-changed-at-monotonic) now)
                 (%shell-background-task-clear-stall entry))))
          ((>= (- now last-size-change-at)
                +shell-background-stall-threshold-seconds+)
           (let* ((tail (%shell-background-output-tail output-path +shell-background-stall-tail-bytes+))
                  (prompt-line (%shell-background-last-line tail)))
             (if (%shell-background-prompt-like-p prompt-line)
                 (%record-shell-background-task-stall entry prompt-line)
                 (%shell-background-task-clear-stall entry))))
          (t
           (%shell-background-task-clear-stall entry)))))
  entry)

(defun %record-shell-background-task-stop (entry reason)
  (setf (getf entry :stopped-p) t
        (getf entry :stopped-at) (or (getf entry :stopped-at)
                                     (get-universal-time))
    (getf entry :termination-reason) reason)
  (%shell-background-task-clear-stall entry)
  entry)

#+sbcl
(defun %wait-for-shell-background-process-exit (process &key (retries 20) (sleep-seconds 0.05))
  (when process
    (loop repeat retries
          while (%shell-background-process-alive-p process)
          do (sleep sleep-seconds))))

#-sbcl
(defun %wait-for-shell-background-process-exit (process &key (retries 20) (sleep-seconds 0.05))
  (declare (ignore process retries sleep-seconds))
  nil)

#+sbcl
(defun %shell-background-taskkill-process-tree (process-id)
  (when (and process-id
             (uiop:os-windows-p))
    (ignore-errors
      (sb-ext:run-program "taskkill"
                          (list "/PID" (princ-to-string process-id) "/T" "/F")
                          :search t
                          :input nil
                          :output nil
                          :error nil
                          :wait t)
      t)))

#-sbcl
(defun %shell-background-taskkill-process-tree (process-id)
  (declare (ignore process-id))
  nil)

#+sbcl
(defun %terminate-shell-background-task-process-tree (entry &key (signal 9))
  (let* ((process (getf entry :process))
         (process-id (or (getf entry :process-id)
                         (%shell-background-process-id process))))
    (when process-id
      (setf (getf entry :process-id) process-id))
    (when (%shell-background-process-alive-p process)
      (unless (%shell-background-taskkill-process-tree process-id)
        (ignore-errors (sb-ext:process-kill process signal)))
      (%wait-for-shell-background-process-exit process))
    entry))

#-sbcl
(defun %terminate-shell-background-task-process-tree (entry &key (signal 9))
  (declare (ignore signal))
  entry)

(defun %shell-background-task-entry (task-id)
  (and task-id
       (gethash task-id *shell-background-task-registry*)))

#+sbcl
(defun %shell-background-process-alive-p (process)
  (and process
       (ignore-errors (sb-ext:process-alive-p process))))

#-sbcl
(defun %shell-background-process-alive-p (process)
  (declare (ignore process))
  nil)

#+sbcl
(defun %shell-background-process-exit-code (process)
  (and process
       (ignore-errors
         (unless (sb-ext:process-alive-p process)
           (sb-ext:process-exit-code process)))))

#-sbcl
(defun %shell-background-process-exit-code (process)
  (declare (ignore process))
  nil)

(defun %shell-background-task-status (entry)
  (let* ((process (getf entry :process))
      (exit-code (%shell-background-process-exit-code process))
      (alive-p (%shell-background-process-alive-p process)))
    (%refresh-shell-background-task-stall-state entry alive-p)
    (when (and (not alive-p)
      (not (getf entry :stopped-p))
      (null (getf entry :finished-at)))
   (setf (getf entry :finished-at) (get-universal-time))
      (%shell-background-task-clear-stall entry)
      (when (null (getf entry :termination-reason))
        (setf (getf entry :termination-reason)
              (%shell-background-task-natural-termination-reason exit-code))))
    (when (and (getf entry :stopped-p)
               (null (getf entry :termination-reason)))
      (setf (getf entry :termination-reason) "stop"))
    (cond
      ((getf entry :stopped-p) "stopped")
   (alive-p "running")
      ((and (integerp exit-code)
            (not (zerop exit-code)))
       "failed")
      (t "completed"))))

(defun %register-shell-background-task (task-id process command directory output-path)
  (let ((started-at (get-universal-time))
        (started-at-monotonic (%shell-background-monotonic-seconds)))
    (setf (gethash task-id *shell-background-task-registry*)
          (list :task-id task-id
                :process process
                :process-id (%shell-background-process-id process)
                :command command
                :directory (%resolved-shell-directory directory)
                :output-path output-path
                :started-at started-at
                :stopped-p nil
                :stopped-at nil
                :finished-at nil
                :termination-reason nil
                :stall-detected-p nil
                :stall-detected-at nil
                :stall-prompt-line nil
                :started-at-monotonic started-at-monotonic
                :observed-output-size (%shell-background-file-size output-path)
                :output-size-changed-at started-at
                :output-size-changed-at-monotonic started-at-monotonic)))
  (let ((entry (%shell-background-task-entry task-id)))
    (%start-shell-background-stall-watchdog entry)
    entry))

(defun %shell-background-result (task-id process command directory output-path)
  (list :summary (%shell-background-summary command task-id)
        :command command
        :directory (%resolved-shell-directory directory)
        :stdout nil
        :stderr nil
        :exit-code nil
        :timed-out nil
        :background t
        :background-task-id task-id
        :output-path output-path
        :process-id (%shell-background-process-id process)))

#-sbcl
(defun %start-shell-background-command (command directory)
  (declare (ignore command directory))
  (error (%shell-tool-error "当前 Lisp 实现不支持后台 shell")))

#+sbcl
(defun %start-shell-background-command (command directory)
  (multiple-value-bind (program arguments)
      (%shell-program-and-arguments command)
    (handler-case
        (let* ((task-id (%shell-background-task-id))
               (output-path (%shell-background-output-path task-id))
               (process (sb-ext:run-program program
                                            arguments
                                            :search t
                                            :directory directory
                                            :output output-path
                                            :if-output-exists :append
                                            :error output-path
                                            :if-error-exists :append
                                            :input nil
                                            :wait nil)))
          (%register-shell-background-task task-id process command directory output-path)
          (%shell-background-result task-id process command directory output-path))
      (error (condition)
        (error (%shell-tool-error condition))))))

#+sbcl
(defun %wait-for-shell-process (process timeout-seconds)
  (if (null timeout-seconds)
      (progn
        (sb-ext:process-wait process)
        nil)
      (let ((deadline (+ (get-internal-real-time)
                         (round (* timeout-seconds internal-time-units-per-second)))))
        (loop while (sb-ext:process-alive-p process)
              do (when (>= (get-internal-real-time) deadline)
                   (ignore-errors (sb-ext:process-kill process 9))
                   (return t))
                 (sleep 0.05)))))

#+sbcl
(defun %read-shell-process-stream (stream)
  (if stream
      (uiop:slurp-stream-string stream)
      ""))

#+sbcl
(defun %execute-shell-command (command directory timeout-seconds &key background)
  (when background
    (return-from %execute-shell-command
      (%start-shell-background-command command directory)))
  (multiple-value-bind (program arguments)
      (%shell-program-and-arguments command)
    (handler-case
        (let* ((process (sb-ext:run-program program
                                            arguments
                                            :search t
                                            :directory directory
                                            :output :stream
                                            :error :stream
                                            :input nil
                                            :wait nil))
               (timed-out-p (%wait-for-shell-process process timeout-seconds))
               (stdout (%trim-shell-output (%read-shell-process-stream (sb-ext:process-output process))))
               (stderr (%trim-shell-output (%read-shell-process-stream (sb-ext:process-error process))))
               (exit-code (and (not timed-out-p)
                               (sb-ext:process-exit-code process))))
          (list :summary (%shell-result-summary command exit-code timed-out-p)
                :command command
                :directory (%resolved-shell-directory directory)
                :stdout stdout
                :stderr stderr
                :exit-code exit-code
                :timed-out timed-out-p
                :background nil
                :background-task-id nil
                :output-path nil
                :process-id (%shell-background-process-id process)))
      (error (condition)
        (error (%shell-tool-error condition))))))

#-sbcl
(defun %execute-shell-command (command directory timeout-seconds &key background)
  (declare (ignore timeout-seconds))
  (if background
      (%start-shell-background-command command directory)
      (multiple-value-bind (program arguments)
          (%shell-program-and-arguments command)
        (handler-case
            (let ((stdout (uiop:run-program (cons program arguments)
                                            :directory directory
                                            :output '(:string :stripped nil)
                                            :ignore-error-status t
                                            :force-shell nil)))
              (list :summary (%shell-result-summary command 0 nil)
                    :command command
                    :directory (%resolved-shell-directory directory)
                    :stdout (%trim-shell-output stdout)
                    :stderr ""
                    :exit-code 0
                    :timed-out nil
                    :background nil
                    :background-task-id nil
                    :output-path nil
                    :process-id nil))
          (error (condition)
            (error (%shell-tool-error condition)))))))

(defun shell-tool (input)
  "执行 shell 命令并返回结构化结果。"
  (let* ((request (%normalized-shell-input input))
         (command (and request (getf request :command)))
         (directory (and request (getf request :directory)))
         (timeout-seconds (and request (getf request :timeout-seconds)))
         (background (and request (getf request :background))))
    (unless request
      (error (%shell-tool-error "请求格式无效，期望 `run shell <command>` 或 `run shell <command> :: <directory>`")))
    (%execute-shell-command command directory timeout-seconds :background background)))