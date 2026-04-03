;;;; tests/integration/session-start-test.lisp - 最小会话启动集成测试
(in-package :cl-cc/tests)

(def-suite session-start-test :in cl-cc-suite)

(in-suite session-start-test)

(test session-start-minimal
  (let ((session (cl-cc.services:start-session "test-user")))
    (is (typep session 'cl-cc.models:session-state))
    (is (string= (cl-cc.models:session-id session) "test-user"))))

(test session-start-message-rendering
  (let ((session (make-instance 'cl-cc.models:session-state
                                :session-id "persisted-user"
                                :created-at "now"
                                :updated-at "now"
                                :history-index 5
                                :context-summary nil
                                :permission-snapshot "saved.session"
                                :status :active
                                :version "0.1")))
    (is (string= (cl-cc.services::%session-start-message session)
                 (format nil "新会话已创建: persisted-user~%历史索引: 5~%快照已保存: saved.session")))))

(test session-start-result-persists-snapshot
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-start-result-test.session"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let ((result-object (cl-cc.services:start-session-result "persisted-user"
                                                                   :history-index 5
                                                                   :session-path path)))
           (is (typep result-object 'cl-cc.lib:result))
           (is (eq (cl-cc.lib:result-status result-object) :success))
           (is (equal (getf (cl-cc.lib:result-payload result-object) :session-path) path))
           (is (getf (cl-cc.lib:result-payload result-object) :saved))
           (is (string= (cl-cc.lib:result-message result-object)
                        (format nil "新会话已创建: persisted-user~%历史索引: 5~%快照已保存: ~A" path)))
           (is (probe-file path))
           (let ((restored (cl-cc.session:load-session path)))
             (is (string= (cl-cc.models:session-id restored) "persisted-user"))
             (is (= (cl-cc.models:session-history-index restored) 5))
             (is (string= (cl-cc.models:session-permission-snapshot restored) path))))
      (when (probe-file path)
        (delete-file path)))))
