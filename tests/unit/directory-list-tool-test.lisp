;;;; tests/unit/directory-list-tool-test.lisp - directory-list-tool 单元测试
(in-package :cl-cc/tests)

(def-suite directory-list-tool-test :in cl-cc-suite)

(in-suite directory-list-tool-test)

(test directory-list-tool-signals-stable-error-for-invalid-input
  (handler-case
      (progn
        (cl-cc.tools:directory-list-tool "")
        (fail "expected directory-list-tool empty-path error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :directory-list-failed))
      (is (search "路径为空" (cl-cc.lib:error-message condition)))))
  (handler-case
      (progn
        (cl-cc.tools:directory-list-tool "missing-directory-list-tool")
        (fail "expected directory-list-tool missing-path error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :directory-list-failed))
      (is (search "目录不存在" (cl-cc.lib:error-message condition))))))

(test normalized-directory-list-input-strips-natural-language-prefixes
  (is (string= (cl-cc.tools::%normalized-directory-list-input "list directory C:/tmp/demo")
               "C:/tmp/demo"))
  (is (string= (cl-cc.tools::%normalized-directory-list-input "列出目录 C:/tmp/demo")
               "C:/tmp/demo"))
  (is (string= (cl-cc.tools::%normalized-directory-list-input "  C:/tmp/demo  ")
               "C:/tmp/demo"))
  (is (null (cl-cc.tools::%normalized-directory-list-input "   "))))

(test directory-list-tool-renders-sorted-entry-lines
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "directory-list-tool-test/"
                                                 (uiop:temporary-directory))))
         (file-a (merge-pathnames "b.txt" directory-path))
         (file-b (merge-pathnames "a.txt" directory-path))
         (nested-dir (merge-pathnames "child/" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested-dir)
           (with-open-file (stream file-a :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "b" stream))
           (with-open-file (stream file-b :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "a" stream))
           (is (string= (cl-cc.tools:directory-list-tool (uiop:native-namestring directory-path))
                        (format nil "a.txt~%b.txt~%child/"))))
      (when (probe-file file-a)
        (delete-file file-a))
      (when (probe-file file-b)
        (delete-file file-b))
      (when (probe-file nested-dir)
        (uiop:delete-directory-tree nested-dir :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))