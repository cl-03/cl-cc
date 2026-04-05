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

(test save-load-session-preserves-task-snapshots
  (let* ((tasks '((:task-id "shell-task-123"
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
         (session (make-instance 'cl-cc.models:session-state
                                 :session-id "sid-with-tasks"
                                 :created-at "now"
                                 :updated-at "now"
                                 :history-index 2
                                 :context-summary '(:result "ok")
                                 :tasks tasks
                                 :permission-snapshot nil
                                 :status :active
                                 :version "0.1"))
         (save-ok (cl-cc.session:save-session session "tmp.session"))
         (loaded (cl-cc.session:load-session "tmp.session")))
    (is (not (null save-ok)))
    (is (equal (cl-cc.models:session-tasks loaded) tasks))))

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

(test list-session-snapshots-returns-stable-metadata-and-skips-invalid-files
  (let* ((directory (uiop:ensure-directory-pathname
                     (uiop:merge-pathnames* "cl-cc-session-list-store-test/"
                                            (uiop:temporary-directory))))
         (alpha-path (uiop:native-namestring (merge-pathnames "alpha.session" directory)))
         (beta-path (uiop:native-namestring (merge-pathnames "beta.session" directory)))
         (invalid-path (uiop:native-namestring (merge-pathnames "invalid.session" directory))))
    (unwind-protect
         (progn
           (ensure-directories-exist directory)
           (is (cl-cc.session:save-session
                (make-instance 'cl-cc.models:session-state
                               :session-id "alpha"
                               :created-at "2026-04-05T00:00:00Z"
                               :updated-at "2026-04-05T00:10:00Z"
                               :history-index 3
                               :context-summary '(:input "alpha input" :result "alpha result")
                               :tasks '((:task-id "shell-task-1"))
                               :permission-snapshot alpha-path
                               :status :active
                               :version "0.1")
                alpha-path))
           (is (cl-cc.session:save-session
                (make-instance 'cl-cc.models:session-state
                               :session-id "beta"
                               :created-at "2026-04-05T01:00:00Z"
                               :updated-at "2026-04-05T01:05:00Z"
                               :history-index nil
                               :context-summary nil
                               :tasks nil
                               :permission-snapshot beta-path
                               :status :active
                               :version "0.1")
                beta-path))
           (with-open-file (stream invalid-path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "(:version \"9.9\" :session-id \"broken\")" stream))
           (multiple-value-bind (snapshots resolved-directory used-default-directory)
               (cl-cc.session:list-session-snapshots (uiop:native-namestring directory))
             (is (not used-default-directory))
             (is (string= resolved-directory (uiop:native-namestring directory)))
             (is (= (length snapshots) 2))
             (is (equal (mapcar (lambda (entry) (getf entry :session-id)) snapshots)
                        '("alpha" "beta")))
             (let ((alpha (first snapshots)))
               (is (equal (truename (getf alpha :session-path))
                          (truename alpha-path)))
               (is (string= (getf alpha :created-at) "2026-04-05T00:00:00Z"))
               (is (string= (getf alpha :updated-at) "2026-04-05T00:10:00Z"))
               (is (= (getf alpha :history-index) 3))
               (is (eq (getf alpha :session-status) :active))
               (is (= (getf alpha :task-count) 1))
               (is (string= (getf alpha :last-input) "alpha input"))
               (is (string= (getf alpha :last-result) "alpha result"))
               (is (integerp (getf alpha :file-size-bytes)))
               (is (stringp (getf alpha :file-updated-at)))
               (is (string= (getf alpha :version) "0.1")))))
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
