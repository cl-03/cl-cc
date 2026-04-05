;;;; tests/unit/glob-tool-test.lisp - glob-tool 单元测试
(in-package :cl-cc/tests)

(def-suite glob-tool-test :in cl-cc-suite)

(in-suite glob-tool-test)

(test normalized-glob-input-supports-structured-and-natural-language-input
  (is (equal (cl-cc.tools::%normalized-glob-input '(:pattern "**/*.lisp" :root "src"))
             '(:pattern "**/*.lisp" :root "src")))
  (is (equal (cl-cc.tools::%normalized-glob-input "glob **/*.lisp")
             '(:pattern "**/*.lisp" :root nil)))
  (is (equal (cl-cc.tools::%normalized-glob-input "find files src/**/*.lisp :: tests")
             '(:pattern "src/**/*.lisp" :root "tests")))
  (is (equal (cl-cc.tools::%normalized-glob-input "fixture-input-glob *.asd")
             '(:pattern "*.asd" :root nil)))
  (is (null (cl-cc.tools::%normalized-glob-input "   "))))

(test glob-tool-signals-stable-error-for-invalid-input
  (handler-case
      (progn
        (cl-cc.tools:glob-tool "")
        (fail "expected glob-tool invalid-input error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :glob-search-failed))
      (is (search "请求格式无效" (cl-cc.lib:error-message condition)))))
  (handler-case
      (progn
        (cl-cc.tools:glob-tool "glob *.lisp :: missing-glob-root")
        (fail "expected glob-tool missing-root error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :glob-search-failed))
      (is (search "搜索根路径不存在" (cl-cc.lib:error-message condition))))))

(test glob-tool-renders-recursive-matches-as-relative-paths
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "glob-tool-test/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "root.lisp" directory-path))
         (nested-directory (merge-pathnames "nested/" directory-path))
         (nested-file (merge-pathnames "nested/result.lisp" directory-path))
         (ignored-file (merge-pathnames "nested/result.txt" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested-directory)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "root" stream))
           (with-open-file (stream nested-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "nested" stream))
           (with-open-file (stream ignored-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "ignore" stream))
           (let ((result (cl-cc.tools:glob-tool (list :pattern "**/*.lisp"
                                                      :root (uiop:native-namestring directory-path)))))
             (is (search "nested/result.lisp" result))
             (is (search "root.lisp" result))
             (is (not (search "result.txt" result)))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file nested-file)
        (delete-file nested-file))
      (when (probe-file ignored-file)
        (delete-file ignored-file))
      (when (probe-file nested-directory)
        (uiop:delete-directory-tree nested-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test glob-tool-truncates-large-result-sets
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "glob-tool-truncation-test/"
                                                 (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (ensure-directories-exist directory-path)
           (loop for index from 1 to 101
                 for file = (merge-pathnames (format nil "file-~3,'0D.lisp" index) directory-path)
                 do (with-open-file (stream file :direction :output :if-exists :supersede :if-does-not-exist :create)
                      (write-string "content" stream)))
           (let ((result (cl-cc.tools:glob-tool (list :pattern "*.lisp"
                                                      :root (uiop:native-namestring directory-path)))))
             (is (search "... (truncated to 100 matches)" result))))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))