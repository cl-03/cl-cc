;;;; tests/unit/file-edit-tool-test.lisp - file-edit-tool 单元测试
(in-package :cl-cc/tests)

(def-suite file-edit-tool-test :in cl-cc-suite)

(in-suite file-edit-tool-test)

(test normalized-file-edit-input-supports-structured-and-natural-language-input
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after"))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "替换文件 C:/tmp/demo.txt :: 旧内容 :: 新内容")
             '(:path "C:/tmp/demo.txt" :old-text " 旧内容" :new-text " 新内容" :preview nil :occurrence nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "edit file C:/tmp/demo.txt :: before :: after :: 2")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after " :preview nil :occurrence 2)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :occurrence 3))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence 3)))
  (is (null (cl-cc.tools::%normalized-file-edit-input "   "))))

(test file-edit-tool-edits-content-and-signals-stable-errors
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before target after" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path :old-text "target" :new-text "updated"))))
             (is (string= (getf result :summary)
                          (format nil "编辑文件: ~A" path)))
             (is (string= (getf result :path) path))
             (is (null (getf result :preview)))
             (is (= (getf result :match-count) 1))
             (is (= (getf result :total-matches) 1))
             (is (= (getf result :selected-occurrence) 1))
             (is (string= (getf result :matched-text) "target"))
             (is (string= (getf result :replacement-text) "updated"))
             (is (string= (getf result :diff-preview)
                  (format nil "@@ match 7..13 @@~%-~A~%+~A"
                    "before target after"
                    "before updated after")))
             (is (getf result :write-applied)))
           (is (string= (uiop:read-file-string path) "before updated after"))
           (handler-case
               (progn
                 (cl-cc.tools:file-edit-tool "edit file only-path")
                 (fail "expected invalid file-edit-tool request"))
             (cl-cc.lib:cl-cc-error (condition)
               (is (eq (cl-cc.lib:error-code condition) :file-edit-failed))
               (is (search "请求格式无效" (cl-cc.lib:error-message condition)))))
           (handler-case
               (progn
                 (cl-cc.tools:file-edit-tool (list :path path :old-text "missing" :new-text "value"))
                 (fail "expected missing old-text error"))
             (cl-cc.lib:cl-cc-error (condition)
               (is (eq (cl-cc.lib:error-code condition) :file-edit-failed))
               (is (search "未找到待替换内容" (cl-cc.lib:error-message condition))))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-preview-does-not-write-file
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-preview.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before preview after" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path :old-text "preview" :new-text "done" :preview t))))
             (is (search "预览编辑文件:" (getf result :summary)))
             (is (getf result :preview))
             (is (null (getf result :write-applied)))
             (is (= (getf result :match-count) 1))
             (is (string= (getf result :before-preview) "before preview after"))
             (is (string= (getf result :after-preview) "before done after"))
             (is (string= (getf result :diff-preview)
                  (format nil "@@ match 7..14 @@~%-~A~%+~A"
                    "before preview after"
                    "before done after"))))
           (is (string= (uiop:read-file-string path) "before preview after")))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-rejects-ambiguous-replacements
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-ambiguous.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "dup dup" stream))
           (handler-case
               (progn
                 (cl-cc.tools:file-edit-tool (list :path path :old-text "dup" :new-text "done"))
                 (fail "expected ambiguous replacement error"))
             (cl-cc.lib:cl-cc-error (condition)
               (is (eq (cl-cc.lib:error-code condition) :file-edit-failed))
               (is (search "出现多次" (cl-cc.lib:error-message condition)))
               (is (search "occurrence" (cl-cc.lib:error-message condition))))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-can-target-specific-occurrence
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-occurrence.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "dup gap dup tail" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path :old-text "dup" :new-text "done" :occurrence 2))))
             (is (search "第 2/2 处命中" (getf result :summary)))
             (is (= (getf result :match-count) 1))
             (is (= (getf result :total-matches) 2))
             (is (= (getf result :selected-occurrence) 2))
             (is (string= (getf result :before-preview) "dup gap dup tail"))
             (is (string= (getf result :after-preview) "dup gap done tail"))
             (is (string= (getf result :diff-preview)
                  (format nil "@@ match 8..11 @@~%-~A~%+~A"
                    "dup gap dup tail"
                    "dup gap done tail"))))
           (is (string= (uiop:read-file-string path) "dup gap done tail"))
           (handler-case
               (progn
                 (cl-cc.tools:file-edit-tool (list :path path :old-text "dup" :new-text "noop" :occurrence 2))
                 (fail "expected occurrence out-of-range error"))
             (cl-cc.lib:cl-cc-error (condition)
               (is (eq (cl-cc.lib:error-code condition) :file-edit-failed))
               (is (search "指定 occurrence 超出范围" (cl-cc.lib:error-message condition))))))
      (when (probe-file path)
        (delete-file path)))))
