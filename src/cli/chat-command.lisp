;;;; src/cli/chat-command.lisp - 最小交互式 chat 命令
(in-package :cl-cc)

(defparameter +chat-exit-commands+
  '("/exit" "/quit" "exit" "quit")
  "触发交互式 chat 循环退出的命令。")

(defparameter +chat-approval-yes-responses+
  '("y" "yes")
  "在交互式 chat 中视为批准工具执行的输入。")

(defun %chat-command-banner (session)
  (format nil "交互式会话已启动: ~A~%输入 /exit 结束会话。"
          (cl-cc.models:session-id session)))

(defun %chat-command-result-line (summary)
  (let ((result (and (listp summary) (getf summary :result))))
    (if result
        (format nil "=> ~A" result)
        "=> (no result)")))

(defun %chat-command-explicit-session-id (parsed-arguments)
  (cl-cc.core:command-option-value parsed-arguments :session-id))

(defun %chat-command-session-path (parsed-arguments)
  (cl-cc.core:command-option-value parsed-arguments :session-path))

(defun %chat-command-tool-ids (parsed-arguments)
  (cl-cc.core:command-option-values parsed-arguments :tool-ids))

(defun %chat-command-target (argv parsed-arguments)
  (declare (ignore argv))
  (cl-cc.core:command-positional-argument parsed-arguments 0))

(defun %chat-command-exit-input-p (input)
  (member (cl-cc.lib:string-designator-downcase
           (string-trim '(#\Space #\Tab #\Newline #\Return) input))
          +chat-exit-commands+
          :test #'string=))

(defun %chat-command-empty-input-p (input)
  (string= (string-trim '(#\Space #\Tab #\Newline #\Return) input) ""))

(defun %chat-command-approval-granted-p (input)
  (member (cl-cc.lib:string-designator-downcase
           (string-trim '(#\Space #\Tab #\Newline #\Return) (or input "")))
          +chat-approval-yes-responses+
          :test #'string=))

(defun %chat-command-approval-callback (input-stream output-stream)
  (lambda (tool-id action input permission-profile)
    (declare (ignore action input permission-profile))
    (format output-stream "~&批准工具 ~A 执行? [y/N] " tool-id)
    (finish-output output-stream)
    (%chat-command-approval-granted-p (read-line input-stream nil ""))))

(defun %chat-command-resume-target-p (target)
  (cl-cc.services::%session-snapshot-file-p target))

(defun %chat-command-invalid-target-directory-error (target)
  (cl-cc.services::%session-snapshot-directory-error target))

(defun %chat-command-new-session-id (target explicit-session-id)
  (or explicit-session-id
      target
      "chat-session"))

(defun %chat-command-save-path (target explicit-session-path session)
  (or explicit-session-path
      (and (%chat-command-resume-target-p target) target)
      (cl-cc.models:session-permission-snapshot session)))

(defun %chat-command-load-session (target explicit-session-id)
  (cond
    ((cl-cc.services::%session-snapshot-directory-p target)
     (error (%chat-command-invalid-target-directory-error target)))
    ((%chat-command-resume-target-p target)
     (cl-cc.services:resume-session target))
    (t
     (cl-cc.services:start-session (%chat-command-new-session-id target explicit-session-id)))))

(defun %chat-command-maybe-save-session (session target explicit-session-path)
  (let ((save-path (%chat-command-save-path target explicit-session-path session)))
    (when save-path
      (setf (cl-cc.models:session-permission-snapshot session) save-path)
      (cl-cc.session:save-session session save-path))
    save-path))

(defun %chat-command-run-loop (session input-stream output-stream tool-ids)
  (let ((approval-callback (%chat-command-approval-callback input-stream output-stream)))
  (loop
    (format output-stream "~&~A> " (cl-cc.models:session-id session))
    (finish-output output-stream)
    (handler-case
        (let ((line (read-line input-stream nil :eof)))
          (cond
            ((eq line :eof)
             (return :eof))
            ((%chat-command-exit-input-p line)
             (return :exit))
            ((%chat-command-empty-input-p line)
             nil)
            (t
             (let ((summary (cl-cc.core:session-loop session
                                                    :input line
                                                    :tool-ids-override tool-ids
                                                    :approval-mode :interactive
                                                    :approval-callback approval-callback
                                                    :halt-on-denied t)))
               (format output-stream "~A~%" (%chat-command-result-line summary))))))
      (end-of-file ()
        (return :eof))))))

(defun handle-chat (&key session-id-or-path session-id session-path tool-ids
                         (input-stream *standard-input*)
                         (output-stream *standard-output*))
  (let ((session (%chat-command-load-session session-id-or-path session-id)))
    (format output-stream "~A~%" (%chat-command-banner session))
    (%chat-command-run-loop session input-stream output-stream tool-ids)
    (%chat-command-maybe-save-session session session-id-or-path session-path)
    0))

(defun handle-chat-command (argv &optional parsed-arguments)
  (handle-chat :session-id-or-path (%chat-command-target argv parsed-arguments)
               :session-id (%chat-command-explicit-session-id parsed-arguments)
               :session-path (%chat-command-session-path parsed-arguments)
               :tool-ids (%chat-command-tool-ids parsed-arguments)))