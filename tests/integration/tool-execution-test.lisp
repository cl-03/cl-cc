;;;; tests/integration/tool-execution-test.lisp - 工具执行集成测试
(in-package :cl-cc/tests)

(def-suite tool-execution-test :in cl-cc-suite)

(in-suite tool-execution-test)


(test tool-execution-success
  (is (equal (cl-cc.tools:echo-tool "hi") "hi"))
  (is (equal (funcall (cl-cc.tools:find-tool "echo-tool") "ok") "ok")))

(test file-read-tool-reads-file-content
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-read-tool-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "file-read-ok" stream))
           (is (string= (cl-cc.tools:file-read-tool path) "file-read-ok"))
           (is (string= (funcall (cl-cc.tools:find-tool "file-read-tool") path) "file-read-ok")))
      (when (probe-file path)
        (delete-file path)))))

(test file-read-tool-reads-selected-line-range
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-read-tool-range-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "one~%two~%three~%four") stream))
           (is (string= (cl-cc.tools:file-read-tool (list :path path :start-line 2 :end-line 3))
                        (format nil "2:two~%3:three")))
           (is (string= (funcall (cl-cc.tools:find-tool "file-read-tool")
                                 (format nil "~A:4" path))
                        "4:four")))
      (when (probe-file path)
        (delete-file path)))))

(test file-write-tool-writes-file-content
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-write-tool-integration.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (is (string= (cl-cc.tools:file-write-tool (list :path path :content "file-write-ok"))
                        (format nil "写入文件: ~A" path)))
           (is (string= (uiop:read-file-string path) "file-write-ok"))
           (is (string= (funcall (cl-cc.tools:find-tool "file-write-tool")
                                 (list :path path :content "file-write-registry-ok"))
                        (format nil "写入文件: ~A" path)))
           (is (string= (uiop:read-file-string path) "file-write-registry-ok")))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-edits-file-content
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-integration.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before target after" stream))
           (let ((direct-result (cl-cc.tools:file-edit-tool (list :path path :old-text "target" :new-text "updated"))))
             (is (string= (getf direct-result :summary)
                          (format nil "编辑文件: ~A" path)))
             (is (string= (getf direct-result :matched-text) "target"))
             (is (search "@@ match 7..13 @@" (getf direct-result :diff-preview)))
             (is (search "@@ lines 1..1 -> 1..1 @@" (getf direct-result :line-diff-preview)))
             (is (= (getf direct-result :selected-occurrence) 1)))
           (is (string= (uiop:read-file-string path) "before updated after"))
           (let ((registry-result (funcall (cl-cc.tools:find-tool "file-edit-tool")
                                           (list :path path :old-text "updated" :new-text "done"))))
             (is (string= (getf registry-result :summary)
                          (format nil "编辑文件: ~A" path)))
             (is (string= (getf registry-result :replacement-text) "done")))
           (is (string= (uiop:read-file-string path) "before done after")))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-can-edit-selected-occurrence-via-registry
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-occurrence-integration.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "repeat middle repeat" stream))
           (let ((registry-result (funcall (cl-cc.tools:find-tool "file-edit-tool")
                                           (list :path path :old-text "repeat" :new-text "done" :occurrence 2 :preview t))))
             (is (getf registry-result :preview))
             (is (= (getf registry-result :total-matches) 2))
             (is (= (getf registry-result :selected-occurrence) 2))
             (is (search "@@ match 14..20 @@" (getf registry-result :diff-preview)))
             (is (search "@@ lines 1..1 -> 1..1 @@" (getf registry-result :line-diff-preview)))
             (is (search "第 2/2 处命中" (getf registry-result :summary))))
           (is (string= (uiop:read-file-string path) "repeat middle repeat")))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-preview-keeps-file-content-unchanged
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-preview-integration.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before preview after" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path :old-text "preview" :new-text "updated" :preview t))))
             (is (search "预览编辑文件:" (getf result :summary)))
             (is (getf result :preview))
             (is (search "@@ match 7..14 @@" (getf result :diff-preview)))
             (is (search "@@ lines 1..1 -> 1..1 @@" (getf result :line-diff-preview)))
             (is (string= (getf result :after-preview) "before updated after")))
           (is (string= (uiop:read-file-string path) "before preview after")))
      (when (probe-file path)
        (delete-file path)))))

(test grep-tool-searches-directory-content
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "grep-tool-integration/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "main.lisp" directory-path))
         (nested-directory (merge-pathnames "src/" directory-path))
         (nested-file (merge-pathnames "src/helper.lisp" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested-directory)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "(defun main () :needle)" stream))
           (with-open-file (stream nested-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "needle-helper" stream))
           (let ((request (list :query "needle"
                                :root (uiop:native-namestring directory-path))))
             (is (search "main.lisp:1:(defun main () :needle)"
                         (cl-cc.tools:grep-tool request)))
             (is (search "src/helper.lisp:1:needle-helper"
                         (funcall (cl-cc.tools:find-tool "grep-tool") request)))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file nested-file)
        (delete-file nested-file))
      (when (probe-file nested-directory)
        (uiop:delete-directory-tree nested-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test directory-list-tool-reads-directory-content
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "directory-list-tool-integration/"
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
           (is (string= (cl-cc.tools:directory-list-tool (uiop:native-namestring directory-path))
                        (format nil "a.txt~%b.txt")))
           (is (string= (funcall (cl-cc.tools:find-tool "directory-list-tool")
                                 (uiop:native-namestring directory-path))
                        (format nil "a.txt~%b.txt"))))
      (when (probe-file file-a)
        (delete-file file-a))
      (when (probe-file file-b)
        (delete-file file-b))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test tool-execution-failure
  (signals cl-cc.lib:cl-cc-error (cl-cc.tools:failing-tool nil))
  (signals cl-cc.lib:cl-cc-error (funcall (cl-cc.tools:find-tool "failing-tool") nil)))

(test failing-tool-error-helper-rendering
  (is (string= (cl-cc.tools::%failing-tool-message)
               "工具执行失败"))
  (let ((condition (cl-cc.tools::%failing-tool-error)))
    (is (eq (cl-cc.lib:error-code condition) :fail))
    (is (string= (cl-cc.lib:error-message condition)
                 "工具执行失败"))))

(test failing-tool-signals-stable-error
  (handler-case
      (progn
        (cl-cc.tools:failing-tool nil)
        (fail "expected failing-tool error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :fail))
      (is (string= (cl-cc.lib:error-message condition)
                   "工具执行失败")))))

(test run-tool-reports-permission-denied-message
  (handler-case
      (progn
        (cl-cc.services:run-tool "echo-tool" "fixture-input-restricted"
                                 :context '(:action delete-file :fixture "restricted"))
        (fail "expected permission denied error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :permission-denied))
      (is (string= (cl-cc.lib:error-message condition)
                   "permission denied for action: DELETE-FILE")))))

(test run-tool-reports-missing-tool-message
  (handler-case
      (progn
        (cl-cc.services:run-tool "missing-tool" "fixture-input-test"
                                 :context '(:action "echo-tool" :fixture "test"))
        (fail "expected tool not found error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :tool-not-found))
      (is (string= (cl-cc.lib:error-message condition)
                   "tool not found: missing-tool")))))
