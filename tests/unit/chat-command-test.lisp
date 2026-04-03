;;;; tests/unit/chat-command-test.lisp - chat 命令单元测试
(in-package :cl-cc/tests)

(def-suite chat-command-test :in cl-cc-suite)

(in-suite chat-command-test)

(test handle-chat-renders-banner-runs-loop-and-exits
  (let* ((input-stream (make-string-input-stream "hello chat
/exit
"))
         (output (with-output-to-string (stream)
                   (is (= 0 (cl-cc:handle-chat :input-stream input-stream
                                               :output-stream stream))))))
    (is (search "交互式会话已启动: chat-session" output))
    (is (search "输入 /exit 结束会话。" output))
    (is (search "chat-session> => tool:echo-tool result:hello chat" output))
    (is (search "chat-session> " output))))

(test handle-chat-uses-explicit-session-id-and-tool-overrides
  (let* ((input-stream (make-string-input-stream "read file README.md
/exit
"))
         (output (with-output-to-string (stream)
                   (is (= 0 (cl-cc:handle-chat :session-id "named-chat"
                                               :tool-ids '("echo-tool")
                                               :input-stream input-stream
                                               :output-stream stream))))))
    (is (search "交互式会话已启动: named-chat" output))
    (is (search "named-chat> => tool:echo-tool result:read file README.md" output))))

(test handle-chat-prompts-before-file-write-and-can-approve
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "chat-command-approve-write-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let* ((input-stream (make-string-input-stream (format nil "write file ~A :: approved~%y~%/exit~%" path)))
                (output (with-output-to-string (stream)
                          (is (= 0 (cl-cc:handle-chat :session-id "approved-chat"
                                                      :input-stream input-stream
                                                      :output-stream stream))))))
           (is (search "批准工具 file-write-tool 执行? [y/N]" output))
           (is (search (format nil "=> tool:file-write-tool result:写入文件: ~A" path)
                       output))
           (is (probe-file path))
           (is (string= (uiop:read-file-string path) " approved")))
      (when (probe-file path)
        (delete-file path)))))

(test handle-chat-denied-file-write-stops-current-cycle
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "chat-command-deny-write-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let* ((input-stream (make-string-input-stream (format nil "write file ~A :: blocked~%n~%/exit~%" path)))
                (output (with-output-to-string (stream)
                          (is (= 0 (cl-cc:handle-chat :session-id "denied-chat"
                                                      :input-stream input-stream
                                                      :output-stream stream))))))
           (is (search "批准工具 file-write-tool 执行? [y/N]" output))
           (is (search "=> all tools failed:" output))
           (is (search "STATUS DENIED" output))
           (is (not (probe-file path))))
      (when (probe-file path)
        (delete-file path)))))

(test handle-chat-saves-session-snapshot-when-session-path-is-provided
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "chat-command-save-test.session"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let* ((input-stream (make-string-input-stream "/exit
"))
                (output (with-output-to-string (stream)
                          (is (= 0 (cl-cc:handle-chat :session-id "saved-chat"
                                                      :session-path path
                                                      :input-stream input-stream
                            :output-stream stream)))))
                (session (cl-cc.session:load-session path)))
           (is (search "交互式会话已启动: saved-chat" output))
           (is (probe-file path))
           (is (string= (cl-cc.models:session-id session) "saved-chat"))
           (is (string= (cl-cc.models:session-permission-snapshot session) path)))
      (when (probe-file path)
        (delete-file path)))))

(test handle-chat-resumes-session-from-path-and-persists-updated-history
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "chat-command-resume-test.session"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (cl-cc.session:save-session (cl-cc.services:start-session "resume-chat") path)
           (let* ((input-stream (make-string-input-stream "continued
/exit
"))
                  (output (with-output-to-string (stream)
                            (is (= 0 (cl-cc:handle-chat :session-id-or-path path
                                                        :input-stream input-stream
                                                        :output-stream stream)))))
                  (session (cl-cc.session:load-session path))
                  (summary (cl-cc.models:session-context-summary session)))
             (is (search "交互式会话已启动: resume-chat" output))
             (is (= 1 (cl-cc.models:session-history-index session)))
             (is (string= (string-trim '(#\Space #\Tab #\Newline #\Return)
                                       (getf summary :result))
                          "tool:echo-tool result:continued"))
             (is (string= (cl-cc.models:session-permission-snapshot session) path))))
      (when (probe-file path)
        (delete-file path)))))

(test chat-command-dispatch-through-main
  (let* ((*standard-input* (make-string-input-stream "hello via main
/exit
"))
         (output (capture-output (lambda () (cl-cc:main "chat" "-i" "main-chat")))))
    (is (search "交互式会话已启动: main-chat" output))
    (is (search "main-chat> => tool:echo-tool result:hello via main" output))))

(test chat-command-alias-dispatch-through-main
  (let* ((*standard-input* (make-string-input-stream "/exit
"))
         (output (capture-output (lambda () (cl-cc:main "c")))))
    (is (search "交互式会话已启动: chat-session" output))))

(test chat-command-option-only-invocation-does-not-treat-flag-as-session-id
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "chat-command-option-only.session"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let* ((*standard-input* (make-string-input-stream "/exit
"))
                (output (capture-output (lambda () (cl-cc:main "chat" "--session-path" path)))))
           (is (search "交互式会话已启动: chat-session" output))
           (is (probe-file path))
           (let ((session (cl-cc.session:load-session path)))
             (is (string= (cl-cc.models:session-id session) "chat-session"))
             (is (string= (cl-cc.models:session-permission-snapshot session) path))))
      (when (probe-file path)
        (delete-file path)))))

(test handle-chat-directory-target-signals-stable-error
  (handler-case
      (progn
        (cl-cc:handle-chat :session-id-or-path "."
                           :input-stream (make-string-input-stream "/exit
"))
        (fail "expected invalid session directory path error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :invalid-session-path))
      (is (string= (cl-cc.lib:error-message condition)
                   "session snapshot path is a directory: .")))))