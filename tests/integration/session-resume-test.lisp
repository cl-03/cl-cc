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
    (cl-cc.session:save-session session path)
    (let ((restored (cl-cc.services:resume-session path)))
      (is (typep restored 'cl-cc.models:session-state))
      (is (string= (cl-cc.models:session-id restored) "resume-user")))
    (let ((result-object (cl-cc.services:resume-session-result path)))
      (is (typep result-object 'cl-cc.lib:result))
      (is (eq (cl-cc.lib:result-status result-object) :success))
      (is (equal (getf (cl-cc.lib:result-payload result-object) :session-id) "resume-user"))
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