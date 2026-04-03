;;;; tests/unit/session-store-test.lisp - 会话存储单元测试
(in-package :cl-cc/tests)

(def-suite session-store-test :in cl-cc-suite)

(in-suite session-store-test)

(test make-cl-cc-error-preserves-code-and-message
  (let ((condition (cl-cc.lib:make-cl-cc-error :session-not-found
                                               "session snapshot not found: missing.session")))
    (is (typep condition 'cl-cc.lib:cl-cc-error))
    (is (eq (cl-cc.lib:error-code condition) :session-not-found))
    (is (string= (cl-cc.lib:error-message condition)
                 "session snapshot not found: missing.session"))))

(test save-load-session
  (let* ((session (make-instance 'cl-cc.models:session-state :session-id "sid" :created-at "now" :updated-at "now" :history-index nil :context-summary nil :permission-snapshot nil :status :active :version "0.1"))
         (save-ok (cl-cc.session:save-session session "tmp.session"))
         (loaded (cl-cc.session:load-session "tmp.session")))
    (is (not (null save-ok)))
    (is (typep loaded 'cl-cc.models:session-state))
    (is (string= (cl-cc.models:session-id loaded) "sid"))))

(test save-session-creates-parent-directories
  (let* ((directory (uiop:merge-pathnames* "cl-cc-session-store-test/nested/"
                                           (uiop:temporary-directory)))
         (path (uiop:native-namestring (merge-pathnames "saved.session" directory)))
         (session (make-instance 'cl-cc.models:session-state
                                 :session-id "nested-sid"
                                 :created-at "now"
                                 :updated-at "now"
                                 :history-index nil
                                 :context-summary nil
                                 :permission-snapshot path
                                 :status :active
                                 :version "0.1")))
    (unwind-protect
         (progn
           (is (not (null (cl-cc.session:save-session session path))))
           (is (probe-file path))
           (let ((loaded (cl-cc.session:load-session path)))
             (is (string= (cl-cc.models:session-id loaded) "nested-sid"))
             (is (string= (cl-cc.models:session-permission-snapshot loaded) path))))
      (when (probe-file directory)
        (uiop:delete-directory-tree directory :validate t :if-does-not-exist :ignore)))))

(test deserialize-session-rejects-invalid-snapshot
  (handler-case
      (progn
        (cl-cc.session:deserialize-session "(:version \"0.1\")")
        (fail "expected invalid session snapshot error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :invalid-session))
      (is (string= (cl-cc.lib:error-message condition)
                   "invalid session snapshot")))))

(test deserialize-session-reports-version-mismatch
  (handler-case
      (progn
        (cl-cc.session:deserialize-session "(:version \"9.9\" :session-id \"sid\")")
        (fail "expected session version mismatch error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :session-version-mismatch))
      (is (string= (cl-cc.lib:error-message condition)
                   "unsupported session version: 9.9")))))

(test session-snapshot-not-found-message-rendering
  (is (string= (cl-cc.session::%session-snapshot-not-found-message "missing.session")
               "session snapshot not found: missing.session")))

(test load-session-signals-session-not-found
  (handler-case
      (progn
        (cl-cc.session:load-session "missing.session")
        (fail "expected session not found error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :session-not-found))
      (is (string= (cl-cc.lib:error-message condition)
                   "session snapshot not found: missing.session")))))
