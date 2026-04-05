;;;; tests/integration/session-resume-test.lisp - 会话恢复与损坏快照集成测试
(in-package :cl-cc/tests)

(def-suite session-resume-test :in cl-cc-suite)

(in-suite session-resume-test)

(test session-resume-message-rendering
  (let ((session (make-instance 'cl-cc.models:session-state
                                :session-id "resume-user"
                                :created-at "restored"
                                :updated-at "restored"
                                :history-index nil
                                :context-summary nil
                                :permission-snapshot nil
                                :status :active
                                :version "0.1")))
    (is (string= (cl-cc.services::%session-resume-message session)
                 "会话已恢复: resume-user"))))

(test session-resume-success
  (let* ((path "resume-ok.session")
         (session (cl-cc.services:start-session "resume-user")))
    (setf (cl-cc.models:session-tasks session)
          '((:task-id "shell-task-123"
             :type "shell"
             :status "running"
             :running t
             :stopped nil
             :command "Start-Sleep -Seconds 5"
             :directory "D:/VSCode/cl-cc/cl-cc/"
             :output-path "C:/Temp/shell-task-123.log"
             :process-id 1234
             :exit-code nil
             :started-at "2026-04-05T00:00:00Z"
             :stopped-at nil
             :finished-at nil
             :stall-detected nil
             :stall-detected-at nil
             :stall-prompt-line nil
             :termination-reason nil
             :ended-at nil)))
    (cl-cc.session:save-session session path)
    (let ((restored (cl-cc.services:resume-session path)))
      (is (typep restored 'cl-cc.models:session-state))
      (is (string= (cl-cc.models:session-id restored) "resume-user"))
      (is (= (length (cl-cc.models:session-tasks restored)) 1)))
    (let ((result-object (cl-cc.services:resume-session-result path)))
      (is (typep result-object 'cl-cc.lib:result))
      (is (eq (cl-cc.lib:result-status result-object) :success))
      (is (equal (getf (cl-cc.lib:result-payload result-object) :session-id) "resume-user"))
      (is (= (length (getf (cl-cc.lib:result-payload result-object) :tasks)) 1))
      (is (search "会话已恢复: resume-user" (cl-cc.lib:result-message result-object))))))

(test session-resume-corrupted
  (with-open-file (stream "resume-bad.session" :direction :output :if-exists :supersede :if-does-not-exist :create)
    (write-line "not-a-session" stream))
  (signals cl-cc.lib:cl-cc-error
    (cl-cc.services:resume-session "resume-bad.session")))

(test session-resume-directory-path-signals-stable-error
  (handler-case
      (progn
        (cl-cc.services:resume-session ".")
        (fail "expected invalid session directory path error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :invalid-session-path))
      (is (string= (cl-cc.lib:error-message condition)
                   "session snapshot path is a directory: .")))))