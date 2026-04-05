;;;; tests/unit/session-service-test.lisp - session-service 内部状态聚合测试
(in-package :cl-cc/tests)

(def-suite session-service-test :in cl-cc-suite)

(in-suite session-service-test)

(defun %fixture-status-record (status)
  (list :status status))

(defun %fixture-result-record (fixture-id status duration-seconds)
  (list :fixture-id fixture-id
        :status status
        :duration-seconds duration-seconds
        :result (format nil "result-~A" fixture-id)
        :tool-results nil))

(test records-all-have-status-p-handles-uniform-mixed-and-empty-records
  (is (cl-cc.services::%records-all-have-status-p (list (%fixture-status-record :denied)
                                                        (%fixture-status-record :denied))
                                                  :denied))
  (is (not (cl-cc.services::%records-all-have-status-p (list (%fixture-status-record :denied)
                                                             (%fixture-status-record :failed))
                                                       :denied)))
  (is (not (cl-cc.services::%records-all-have-status-p nil :denied))))

(test aggregate-fixture-status-classifies-uniform-and-mixed-records
  (is (string= (cl-cc.services::%aggregate-fixture-status (list (%fixture-status-record :success)
                                                                (%fixture-status-record :success)))
               "success"))
  (is (string= (cl-cc.services::%aggregate-fixture-status (list (%fixture-status-record :denied)
                                                                (%fixture-status-record :denied)))
               "denied"))
  (is (string= (cl-cc.services::%aggregate-fixture-status (list (%fixture-status-record :not-found)
                                                                (%fixture-status-record :not-found)))
               "not-found"))
  (is (string= (cl-cc.services::%aggregate-fixture-status (list (%fixture-status-record :failed)
                                                                (%fixture-status-record :failed)))
               "failed"))
  (is (string= (cl-cc.services::%aggregate-fixture-status (list (%fixture-status-record :success)
                                                                (%fixture-status-record :denied)))
               "partial")))

(test fixture-result-summary-preserves-derived-counts-and-status
  (let ((summary (cl-cc.services::%fixture-result-summary
                  (list (%fixture-result-record "test" :success 1.25d0)
                        (%fixture-result-record "restricted" :denied 0.75d0)))))
    (is (string= (getf summary :status) "partial"))
    (is (equal (getf summary :status-counts)
               '(("success" . 1)
                 ("failed" . 0)
                 ("partial" . 0)
                 ("denied" . 1)
                 ("not-found" . 0)
                 ("unknown" . 0))))
    (is (= (getf summary :fixture-count) 2))
    (is (= (getf summary :successful-count) 1))
    (is (= (getf summary :failed-count) 0))
    (is (= (getf summary :duration-seconds) 2.0d0))
    (is (= (getf summary :exit-code) 1))
    (is (not (getf summary :ok)))))

(test fixture-result-payload-preserves-summary-derived-fields-and-results
  (let* ((records (list (%fixture-result-record "test" :success 1.25d0)
                        (%fixture-result-record "restricted" :denied 0.75d0)))
         (summary (cl-cc.services::%fixture-result-summary records))
         (payload (cl-cc.services::%fixture-result-payload records summary)))
    (is (= (getf payload :fixture-count) 2))
    (is (= (getf payload :successful-count) 1))
    (is (= (getf payload :failed-count) 0))
    (is (= (getf payload :duration-seconds) 2.0d0))
    (is (equal (getf payload :status-counts)
               (getf summary :status-counts)))
    (is (= (getf payload :exit-code) 1))
    (is (not (getf payload :ok)))
    (is (equal (mapcar (lambda (record) (getf record :fixture-id))
                       (getf payload :results))
               '("test" "restricted")))))

(test collect-fixture-records-preserves-order-and-forwards-tool-overrides
  (let ((original-run-fixture-record (symbol-function 'cl-cc.services::%run-fixture-record)))
    (unwind-protect
         (progn
           (setf (symbol-function 'cl-cc.services::%run-fixture-record)
                 (lambda (fixture-id tool-ids-override)
                   (list :fixture-id fixture-id
                         :tool-ids tool-ids-override)))
           (is (equal (cl-cc.services::%collect-fixture-records '("a" "b") '("echo-tool"))
                      '((:fixture-id "a" :tool-ids ("echo-tool"))
                        (:fixture-id "b" :tool-ids ("echo-tool"))))))
      (setf (symbol-function 'cl-cc.services::%run-fixture-record)
            original-run-fixture-record))))

(test fixture-result-values-returns-result-and-exit-code
  (let ((result-object (cl-cc.lib:make-result :status :success
                                              :payload '(:exit-code 7)
                                              :message "ignored")))
    (multiple-value-bind (returned-result exit-code)
        (cl-cc.services::%fixture-result-values result-object)
      (is (eq returned-result result-object))
      (is (= exit-code 7)))))

(test derived-fixture-record-status-prefers-success-and-classifies-uniform-errors
  (let ((success-context (cl-cc.core:make-execution-context :status :success
                                                            :results (list (%fixture-status-record :denied))))
        (denied-context (cl-cc.core:make-execution-context :status :failed
                                                           :results (list (%fixture-status-record :denied)
                                                                          (%fixture-status-record :denied))))
        (not-found-context (cl-cc.core:make-execution-context :status :failed
                                                              :results (list (%fixture-status-record :not-found)
                                                                             (%fixture-status-record :not-found))))
        (mixed-context (cl-cc.core:make-execution-context :status :failed
                                                          :results (list (%fixture-status-record :denied)
                                                                         (%fixture-status-record :failed)))))
    (is (eq (cl-cc.services::%derived-fixture-record-status success-context) :success))
    (is (eq (cl-cc.services::%derived-fixture-record-status denied-context) :denied))
    (is (eq (cl-cc.services::%derived-fixture-record-status not-found-context) :not-found))
    (is (eq (cl-cc.services::%derived-fixture-record-status mixed-context) :failed))))

    (test run-session-result-preserves-loop-derived-fields-and-optional-save-path
      (let ((path (uiop:native-namestring
          (uiop:merge-pathnames* "run-session-result-test.session"
                     (uiop:temporary-directory)))))
        (unwind-protect
            (let ((cl-cc.lib::*git-command-runner*
                    (lambda (arguments &key directory)
                      (declare (ignore directory))
                      (cond
                        ((equal arguments '("rev-parse" "--show-toplevel")) "D:/VSCode/cl-cc/cl-cc")
                        ((equal arguments '("branch" "--show-current")) "main")
                        ((equal arguments '("status" "--short")) "M src/services/session-service.lisp")
                        ((equal arguments '("log" "--oneline" "-5")) "abc1234 add git snapshot")
                        (t nil)))))
              (clrhash cl-cc.tools::*shell-background-task-registry*)
              (let* ((result-object (cl-cc.services:run-session-result "run-user" :input "hello session" :session-path path))
                     (payload (cl-cc.lib:result-payload result-object)))
                (is (eq (cl-cc.lib:result-status result-object) :success))
                (is (string= (getf payload :session-id) "run-user"))
                (is (= (getf payload :history-index) 1))
                (is (eq (getf payload :session-status) :active))
                (is (string= (getf payload :input) "hello session"))
                (is (eq (getf payload :execution-status) :success))
                (is (equal (getf payload :git-root) "D:/VSCode/cl-cc/cl-cc"))
                (is (equal (getf payload :git-branch) "main"))
                (is (getf payload :git-dirty))
                (is (equal (getf payload :git-status-lines)
                           '("M src/services/session-service.lisp")))
                (is (equal (getf payload :git-recent-commits)
                           '("abc1234 add git snapshot")))
                (is (string= (getf payload :result) "tool:echo-tool result:hello session"))
                (is (= (length (getf payload :tool-results)) 1))
                (is (eq (getf payload :tasks :missing) :missing))
                (is (string= (getf (first (getf payload :tool-results)) :tool) "echo-tool"))
                (is (string= (getf payload :session-path) path))
                (is (getf payload :saved))
                (is (numberp (getf payload :duration-seconds)))
                (is (= (getf payload :exit-code) 0))
                (is (probe-file path))
                (is (search "会话已执行: run-user" (cl-cc.lib:result-message result-object)))
                (is (search "输入: hello session" (cl-cc.lib:result-message result-object)))
                (is (search "执行状态: success" (cl-cc.lib:result-message result-object)))
                (is (search "执行结果: tool:echo-tool result:hello session" (cl-cc.lib:result-message result-object))))
              (clrhash cl-cc.tools::*shell-background-task-registry*))
       (when (probe-file path)
         (delete-file path)))))

(test run-session-result-includes-background-task-snapshots-when-present
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (start-result (cl-cc.tools:shell-tool (list :command "Start-Sleep -Seconds 5; [Console]::Out.Write('session-task-snapshot')"
                                                     :directory directory
                                                     :background t)))
         (task-id (getf start-result :background-task-id))
         (output-path (getf start-result :output-path)))
    (unwind-protect
         (let* ((result-object (cl-cc.services:run-session-result "task-session" :input "hello task snapshot"))
                (payload (cl-cc.lib:result-payload result-object))
                (tasks (getf payload :tasks))
                (task (find task-id tasks :key (lambda (entry) (getf entry :task-id)) :test #'string=)))
           (is (eq (cl-cc.lib:result-status result-object) :success))
           (is (not (null tasks)))
           (is (not (null task)))
           (is (string= (getf task :task-id) task-id))
           (is (string= (getf task :type) "shell"))
           (is (string= (getf task :status) "running"))
           (is (getf task :running))
           (is (string= (getf task :output-path) output-path)))
      (when task-id
        (ignore-errors (cl-cc.tools:shell-task-tool (list :task-id task-id :action :stop)))
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.2)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))

(test list-sessions-result-preserves-session-directory-and-metadata
  (let* ((directory (uiop:ensure-directory-pathname
                     (uiop:merge-pathnames* "session-service-list-test/"
                                            (uiop:temporary-directory))))
         (session-path (uiop:native-namestring (merge-pathnames "service.session" directory))))
    (unwind-protect
         (progn
           (ensure-directories-exist directory)
           (is (cl-cc.session:save-session
                (make-instance 'cl-cc.models:session-state
                               :session-id "service-session"
                               :created-at "2026-04-05T02:00:00Z"
                               :updated-at "2026-04-05T02:05:00Z"
                               :history-index 4
                               :context-summary '(:input "service input" :result "service result")
                               :tasks '((:task-id "shell-task-99"))
                               :permission-snapshot session-path
                               :status :active
                               :version "0.1")
                session-path))
           (let* ((result-object (cl-cc.services:list-sessions-result :session-dir (uiop:native-namestring directory)))
                  (payload (cl-cc.lib:result-payload result-object))
                  (session (first (getf payload :sessions))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (string= (getf payload :session-directory)
                          (uiop:native-namestring directory)))
             (is (not (getf payload :used-default-directory)))
             (is (= (getf payload :session-count) 1))
             (is (string= (getf session :session-id) "service-session"))
             (is (= (getf session :history-index) 4))
             (is (= (getf session :task-count) 1))
             (is (string= (getf session :last-input) "service input"))
             (is (string= (getf session :last-result) "service result"))
             (is (numberp (getf payload :duration-seconds)))
             (is (= (getf payload :exit-code) 0))
             (is (search "会话数量: 1" (cl-cc.lib:result-message result-object)))
             (is (search "service-session" (cl-cc.lib:result-message result-object)))))
      (when (probe-file directory)
        (uiop:delete-directory-tree directory :validate t :if-does-not-exist :ignore)))))

(test run-session-result-can-read-file-content-via-file-read-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-read-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "session-file-ok" stream))
           (let* ((result-object (cl-cc.services:run-session-result "file-session" :input path))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (string= (getf payload :input) path))
             (is (string= (getf payload :result) "tool:file-read-tool result:session-file-ok"))
             (is (= (length (getf payload :tool-results)) 1))
             (is (string= (getf tool-record :tool) "file-read-tool"))
             (is (eq (getf tool-record :status) :success))
             (is (equal (getf tool-record :output) '(:result "session-file-ok")))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-read-file-line-range-via-file-read-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-read-file-range-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "first~%second~%third~%fourth") stream))
           (let* ((input (format nil "read file ~A :: 2-3" path))
                  (result-object (cl-cc.services:run-session-result "file-range-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (string= (getf payload :input) input))
             (is (equal (first (getf payload :execution-plan))
                        (list :tool "file-read-tool"
                              :input (list :path path :start-line 2 :end-line 3))))
             (is (string= (getf payload :result)
                          (format nil "tool:file-read-tool result:2:second~%3:third")))
             (is (string= (getf tool-record :tool) "file-read-tool"))
             (is (eq (getf tool-record :status) :success))
             (is (equal (getf tool-record :output)
                        (list :result (format nil "2:second~%3:third"))))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-list-directory-content-via-directory-list-tool
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "run-session-list-directory-test/"
                                                 (uiop:temporary-directory))))
         (file-a (merge-pathnames "b.txt" directory-path))
         (file-b (merge-pathnames "a.txt" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist directory-path)
           (with-open-file (stream file-a :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "b" stream))
           (with-open-file (stream file-b :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "a" stream))
           (let* ((result-object (cl-cc.services:run-session-result "dir-session" :input (format nil "list directory ~A" (uiop:native-namestring directory-path))))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (eq (getf payload :execution-status) :success))
             (is (string= (getf payload :result) (format nil "tool:directory-list-tool result:a.txt~%b.txt")))
             (is (string= (getf tool-record :tool) "directory-list-tool"))
             (is (eq (getf tool-record :status) :success))
             (is (string= (getf (getf tool-record :output) :result)
                          (format nil "a.txt~%b.txt")))))
      (when (probe-file file-a)
        (delete-file file-a))
      (when (probe-file file-b)
        (delete-file file-b))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test run-session-result-can-search-code-via-grep-tool
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "run-session-grep-test/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "main.lisp" directory-path))
         (nested-directory (merge-pathnames "nested/" directory-path))
         (nested-file (merge-pathnames "nested/notes.txt" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested-directory)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "permission match" stream))
           (with-open-file (stream nested-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "permission nested" stream))
           (let* ((input (format nil "grep permission :: ~A" (uiop:native-namestring directory-path)))
                  (result-object (cl-cc.services:run-session-result "grep-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (string= (getf payload :input) input))
             (is (equal (getf payload :selected-tools)
                        '("grep-tool" "file-read-tool" "echo-tool" "failing-tool")))
             (is (equal (first (getf payload :execution-plan))
                        (list :tool "grep-tool"
                              :input (list :query "permission"
                                           :root (uiop:native-namestring directory-path)))))
             (is (string= (getf tool-record :tool) "grep-tool"))
             (is (eq (getf tool-record :status) :success))
             (is (search "main.lisp:1:permission match" (getf payload :result)))
             (is (search "nested/notes.txt:1:permission nested" (getf payload :result)))
             (is (search "main.lisp:1:permission match" (getf (getf tool-record :output) :result)))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file nested-file)
        (delete-file nested-file))
      (when (probe-file nested-directory)
        (uiop:delete-directory-tree nested-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test run-session-result-can-write-file-content-via-file-write-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-write-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (let* ((input (format nil "write file ~A :: session-write-ok" path))
                (result-object (cl-cc.services:run-session-result "write-session" :input input))
                (payload (cl-cc.lib:result-payload result-object))
                (tool-record (first (getf payload :tool-results))))
           (is (eq (cl-cc.lib:result-status result-object) :success))
           (is (string= (getf payload :input) input))
           (is (string= (getf payload :result)
                        (format nil "tool:file-write-tool result:写入文件: ~A" path)))
           (is (equal (getf payload :selected-tools)
                      '("file-write-tool" "file-read-tool" "echo-tool" "failing-tool")))
           (is (equal (first (getf payload :execution-plan))
                      (list :tool "file-write-tool"
                            :input (list :path path :content " session-write-ok" :mode :overwrite))))
           (is (string= (getf tool-record :tool) "file-write-tool"))
           (is (eq (getf tool-record :status) :success))
           (is (string= (getf (getf tool-record :output) :result)
                        (format nil "写入文件: ~A" path)))
           (is (string= (uiop:read-file-string path) " session-write-ok")))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-supports-tool-overrides
  (let* ((result-object (cl-cc.services:run-session-result "override-session"
                                                           :input "read file README.md"
                                                           :tool-ids '("echo-tool")))
         (payload (cl-cc.lib:result-payload result-object))
         (tool-record (first (getf payload :tool-results))))
    (is (eq (cl-cc.lib:result-status result-object) :success))
    (is (equal (getf payload :selected-tools) '("echo-tool")))
    (is (equal (getf payload :execution-plan)
               '((:tool "echo-tool" :input "read file README.md"))))
    (is (string= (getf tool-record :tool) "echo-tool"))
    (is (string= (getf payload :result) "tool:echo-tool result:read file README.md"))))

(test run-session-result-can-append-file-content-via-file-write-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-append-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "base" stream))
           (let* ((input (format nil "append file ~A :: -tail" path))
                  (result-object (cl-cc.services:run-session-result "append-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object)))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (string= (getf payload :result)
                          (format nil "tool:file-write-tool result:追加写入文件: ~A" path)))
             (is (equal (getf payload :selected-tools)
                        '("file-write-tool" "file-read-tool" "echo-tool" "failing-tool")))
             (is (equal (first (getf payload :execution-plan))
                        (list :tool "file-write-tool"
                              :input (list :path path :content " -tail" :mode :append))))
             (is (string= (uiop:read-file-string path) "base -tail"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-edit-file-content-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before marker after" stream))
           (let* ((input (format nil "edit file ~A :: marker :: updated" path))
                  (result-object (cl-cc.services:run-session-result "edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (string= (getf payload :result)
                          (format nil "tool:file-edit-tool result:编辑文件: ~A" path)))
             (is (equal (getf payload :selected-tools)
                        '("file-edit-tool" "file-read-tool" "echo-tool" "failing-tool")))
             (is (equal (first (getf payload :execution-plan))
                        (list :tool "file-edit-tool"
              :input (list :path path :old-text " marker" :new-text " updated" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil))))
             (is (string= (getf tool-record :tool) "file-edit-tool"))
             (is (eq (getf tool-record :status) :success))
             (is (string= (getf (getf tool-record :output) :result)
                          (format nil "编辑文件: ~A" path)))
             (is (string= (uiop:read-file-string path) "before updated after"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-file-edit-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before preview after" stream))
           (let* ((input (format nil "preview edit file ~A :: preview :: value" path))
                  (result-object (cl-cc.services:run-session-result "preview-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (search "tool:file-edit-tool result:预览编辑文件:"
                         (getf payload :result)))
             (is (equal (first (getf payload :execution-plan))
                        (list :tool "file-edit-tool"
              :input (list :path path :old-text " preview" :new-text " value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil))))
             (is (search "预览编辑文件:" (getf (getf tool-record :output) :result)))
             (is (string= (uiop:read-file-string path) "before preview after"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-regex-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-regex-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before token-42 after" stream))
           (let* ((input (format nil "regex edit file ~A :: token-[0-9]+ :: value" path))
                  (result-object (cl-cc.services:run-session-result "regex-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (string= (getf payload :result)
                          (format nil "tool:file-edit-tool result:编辑文件: ~A" path)))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                          :input (list :path path :old-text " token-[0-9]+" :new-text " value" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t))))
             (is (eq (getf tool-record :status) :success))
             (is (getf (getf tool-record :output) :use-regex))
             (is (not (getf (getf tool-record :output) :multiline)))
             (is (not (getf (getf tool-record :output) :dot-all)))
             (is (not (getf (getf tool-record :output) :whole-word)))
             (is (not (getf (getf tool-record :output) :left-word-boundary)))
             (is (not (getf (getf tool-record :output) :right-word-boundary)))
             (is (search "token-42" (getf (getf tool-record :output) :matched-text)))
             (is (string= (uiop:read-file-string path) "before value after"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-regex-edit-file-with-capture-groups
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-regex-capture-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before token-42 after" stream))
           (let* ((input (format nil "regex edit file ~A :: (token)-([0-9]+) :: $2:$1" path))
                  (result-object (cl-cc.services:run-session-result "regex-capture-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output)))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (getf output :use-regex))
             (is (not (getf output :multiline)))
             (is (not (getf output :dot-all)))
             (is (not (getf output :whole-word)))
             (is (not (getf output :left-word-boundary)))
             (is (not (getf output :right-word-boundary)))
             (is (string= (getf output :matched-text) " token-42"))
             (is (string= (getf output :replacement-text) " 42:token"))
             (is (string= (uiop:read-file-string path) "before 42:token after"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-whole-word-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-whole-word-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "target retarget target_1" stream))
               (let* ((input (format nil "whole word edit file ~A::target::done" path))
                  (result-object (cl-cc.services:run-session-result "whole-word-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                  :input (list :path path :old-text "target" :new-text "done" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word t :left-word-boundary nil :right-word-boundary nil))))
             (is (getf (getf tool-record :output) :whole-word))
             (is (getf (getf tool-record :output) :left-word-boundary))
             (is (getf (getf tool-record :output) :right-word-boundary))
             (is (string= (uiop:read-file-string path) "done retarget target_1"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-order-independent-plain-flags-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-order-independent-plain-flags-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "Target reTarget target_1" stream))
           (let* ((input (format nil "preview whole word ignore case edit file ~A::target::done" path))
                  (result-object (cl-cc.services:run-session-result "preview-order-independent-plain-flags-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "target" :new-text "done" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word t :left-word-boundary nil :right-word-boundary nil))))
             (is (getf output :preview))
             (is (getf output :ignore-case))
             (is (getf output :whole-word))
             (is (getf output :left-word-boundary))
             (is (getf output :right-word-boundary))
             (is (= (getf output :match-count) 1))
             (is (string= (uiop:read-file-string path) "Target reTarget target_1"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-order-independent-plain-replace-all-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-order-independent-plain-replace-all-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "TOKEN token" stream))
           (let* ((input (format nil "preview replace all ignore case edit file ~A::token::done" path))
                  (result-object (cl-cc.services:run-session-result "preview-order-independent-plain-replace-all-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "token" :new-text "done" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :replace-all t))))
             (is (getf output :preview))
             (is (getf output :ignore-case))
             (is (= (getf output :match-count) 2))
             (is (= (getf output :total-matches) 2))
             (is (null (getf output :selected-occurrence)))
             (is (string= (uiop:read-file-string path) "TOKEN token"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-chinese-legacy-plain-replace-all-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-chinese-legacy-plain-replace-all-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "token x token" stream))
           (let* ((input (format nil "预览全部替换文件 ~A::token::done" path))
                  (result-object (cl-cc.services:run-session-result "preview-chinese-legacy-plain-replace-all-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "token" :new-text "done" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :replace-all t))))
             (is (getf output :preview))
             (is (= (getf output :match-count) 2))
             (is (= (getf output :total-matches) 2))
             (is (null (getf output :selected-occurrence)))
             (is (string= (uiop:read-file-string path) "token x token"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-chinese-plain-flags-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-chinese-plain-flags-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "target retarget" stream))
           (let* ((input (format nil "预览忽略大小写左边界编辑文件 ~A::target::done" path))
                  (result-object (cl-cc.services:run-session-result "preview-chinese-plain-flags-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "target" :new-text "done" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary t :right-word-boundary nil))))
             (is (getf output :preview))
             (is (getf output :ignore-case))
             (is (not (getf output :whole-word)))
             (is (getf output :left-word-boundary))
             (is (not (getf output :right-word-boundary)))
             (is (= (getf output :match-count) 1))
             (is (string= (uiop:read-file-string path) "target retarget"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-regex-right-boundary-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-regex-right-boundary-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "id-300x xid-44x id-7" stream))
           (let* ((input (format nil "preview regex right word boundary edit file ~A::id-[0-9]+::item" path))
                  (result-object (cl-cc.services:run-session-result "preview-regex-right-boundary-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "id-[0-9]+" :new-text "item" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary t :use-regex t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (not (getf output :multiline)))
             (is (not (getf output :dot-all)))
             (is (not (getf output :whole-word)))
             (is (not (getf output :left-word-boundary)))
             (is (getf output :right-word-boundary))
             (is (= (getf output :match-count) 1))
             (is (string= (uiop:read-file-string path) "id-300x xid-44x id-7"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-regex-order-independent-boundary-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-regex-order-independent-boundary-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "id-300x xid-44x id-7" stream))
           (let* ((input (format nil "preview regex right word boundary left word boundary edit file ~A::id-[0-9]+::item" path))
                  (result-object (cl-cc.services:run-session-result "preview-regex-order-independent-boundary-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "id-[0-9]+" :new-text "item" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary t :right-word-boundary t :use-regex t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (getf output :whole-word))
             (is (getf output :left-word-boundary))
             (is (getf output :right-word-boundary))
             (is (= (getf output :match-count) 1))
             (is (string= (getf output :matched-text) "id-7"))
             (is (string= (uiop:read-file-string path) "id-300x xid-44x id-7"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-regex-ignore-case-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-regex-ignore-case-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "TOKEN-42 tokenized" stream))
           (let* ((input (format nil "preview regex ignore case edit file ~A::token-[a-z0-9]+::value" path))
                  (result-object (cl-cc.services:run-session-result "preview-regex-ignore-case-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "token-[a-z0-9]+" :new-text "value" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (getf output :ignore-case))
             (is (not (getf output :multiline)))
             (is (not (getf output :dot-all)))
             (is (not (getf output :whole-word)))
             (is (= (getf output :match-count) 1))
             (is (string= (uiop:read-file-string path) "TOKEN-42 tokenized"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-regex-replace-all-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-regex-replace-all-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "token-1 x token-2" stream))
           (let* ((input (format nil "preview regex replace all in file ~A::token-[0-9]+::value" path))
                  (result-object (cl-cc.services:run-session-result "preview-regex-replace-all-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "token-[0-9]+" :new-text "value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (not (getf output :multiline)))
             (is (not (getf output :dot-all)))
             (is (= (getf output :match-count) 2))
             (is (= (getf output :total-matches) 2))
             (is (null (getf output :selected-occurrence)))
             (is (string= (uiop:read-file-string path) "token-1 x token-2"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-chinese-legacy-regex-replace-all-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-chinese-legacy-regex-replace-all-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "token-1 x token-2" stream))
           (let* ((input (format nil "预览正则全部替换文件 ~A::token-[0-9]+::value" path))
                  (result-object (cl-cc.services:run-session-result "preview-chinese-legacy-regex-replace-all-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "token-[0-9]+" :new-text "value" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (= (getf output :match-count) 2))
             (is (= (getf output :total-matches) 2))
             (is (null (getf output :selected-occurrence)))
             (is (string= (uiop:read-file-string path) "token-1 x token-2"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-regex-order-independent-replace-all-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-regex-order-independent-replace-all-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "TOKEN-1 x token-2" stream))
           (let* ((input (format nil "preview regex replace all ignore case edit file ~A::token-[0-9]+::value" path))
                  (result-object (cl-cc.services:run-session-result "preview-regex-order-independent-replace-all-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "token-[0-9]+" :new-text "value" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (getf output :ignore-case))
             (is (= (getf output :match-count) 2))
             (is (= (getf output :total-matches) 2))
             (is (null (getf output :selected-occurrence)))
             (is (string= (uiop:read-file-string path) "TOKEN-1 x token-2"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-regex-line-context-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-regex-line-context-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "token-42" stream))
           (let* ((input (format nil "preview regex context 0 edit file ~A::token-[0-9]+::value" path))
                  (result-object (cl-cc.services:run-session-result "preview-regex-line-context-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "token-[0-9]+" :new-text "value" :preview t :occurrence nil :line-context 0 :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (not (getf output :multiline)))
             (is (not (getf output :dot-all)))
             (is (= (getf output :line-context) 0))
             (is (= (getf output :match-count) 1))
             (is (string= (uiop:read-file-string path) "token-42"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-regex-multiline-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-regex-multiline-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%id-42~%omega") stream))
           (let* ((input (format nil "preview regex multiline edit file ~A::^id-[0-9]+$::item" path))
                  (result-object (cl-cc.services:run-session-result "preview-regex-multiline-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "^id-[0-9]+$" :new-text "item" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (getf output :multiline))
             (is (not (getf output :dot-all)))
             (is (= (getf output :match-count) 1))
             (is (string= (getf output :matched-text) "id-42"))
             (is (string= (getf output :after-preview) (format nil "alpha~%item~%omega")))
             (is (string= (uiop:read-file-string path) (format nil "alpha~%id-42~%omega")))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-regex-dot-all-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-regex-dot-all-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "begin~%middle~%end") stream))
           (let* ((input (format nil "preview regex dot all edit file ~A::begin.*end::block" path))
                  (result-object (cl-cc.services:run-session-result "preview-regex-dot-all-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "begin.*end" :new-text "block" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :dot-all t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (not (getf output :multiline)))
             (is (getf output :dot-all))
             (is (= (getf output :match-count) 1))
             (is (string= (getf output :matched-text) (format nil "begin~%middle~%end")))
             (is (string= (getf output :after-preview) "block"))
             (is (string= (uiop:read-file-string path) (format nil "begin~%middle~%end")))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-chinese-regex-multiline-dot-all-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-chinese-regex-multiline-dot-all-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "id-42" stream))
           (let* ((input (format nil "预览正则多行模式点号跨行编辑文件 ~A::^id-[0-9]+$::item" path))
                  (result-object (cl-cc.services:run-session-result "preview-chinese-regex-multiline-dot-all-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "^id-[0-9]+$" :new-text "item" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (getf output :multiline))
             (is (getf output :dot-all))
             (is (= (getf output :match-count) 1))
             (is (string= (getf output :matched-text) "id-42"))
             (is (string= (getf output :after-preview) "item"))
             (is (string= (uiop:read-file-string path) "id-42"))))
      (when (probe-file path)
        (delete-file path)))))

(test run-session-result-can-preview-chinese-regex-ignore-case-multiline-dot-all-edit-file-via-file-edit-tool
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "run-session-preview-chinese-regex-ignore-case-multiline-dot-all-edit-file-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "ID-42" stream))
           (let* ((input (format nil "预览正则忽略大小写多行模式点号跨行编辑文件 ~A::^id-[0-9]+$::item" path))
                  (result-object (cl-cc.services:run-session-result "preview-chinese-regex-ignore-case-multiline-dot-all-edit-session" :input input))
                  (payload (cl-cc.lib:result-payload result-object))
                  (tool-record (first (getf payload :tool-results)))
                  (output (getf tool-record :output))
                  (first-step (first (getf payload :execution-plan))))
             (is (eq (cl-cc.lib:result-status result-object) :success))
             (is (equal first-step
                        (list :tool "file-edit-tool"
                              :input (list :path path :old-text "^id-[0-9]+$" :new-text "item" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t))))
             (is (getf output :preview))
             (is (getf output :use-regex))
             (is (getf output :ignore-case))
             (is (getf output :multiline))
             (is (getf output :dot-all))
             (is (= (getf output :match-count) 1))
             (is (string= (getf output :matched-text) "ID-42"))
             (is (string= (getf output :after-preview) "item"))
             (is (string= (uiop:read-file-string path) "ID-42"))))
      (when (probe-file path)
        (delete-file path)))))