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
          (let* ((result-object (cl-cc.services:run-session-result "run-user" :input "hello session" :session-path path))
           (payload (cl-cc.lib:result-payload result-object)))
         (is (eq (cl-cc.lib:result-status result-object) :success))
         (is (string= (getf payload :session-id) "run-user"))
         (is (= (getf payload :history-index) 1))
         (is (eq (getf payload :session-status) :active))
         (is (string= (getf payload :input) "hello session"))
         (is (eq (getf payload :execution-status) :success))
         (is (string= (getf payload :result) "tool:echo-tool result:hello session"))
         (is (= (length (getf payload :tool-results)) 1))
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
       (when (probe-file path)
         (delete-file path)))))

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
              :input (list :path path :old-text " marker" :new-text " updated" :preview nil :occurrence nil))))
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
                  :input (list :path path :old-text " preview" :new-text " value" :preview t :occurrence nil))))
             (is (search "预览编辑文件:" (getf (getf tool-record :output) :result)))
             (is (string= (uiop:read-file-string path) "before preview after"))))
      (when (probe-file path)
        (delete-file path)))))