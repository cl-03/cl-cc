;;;; tests/unit/grep-tool-test.lisp - grep-tool 单元测试
(in-package :cl-cc/tests)

(def-suite grep-tool-test :in cl-cc-suite)

(in-suite grep-tool-test)

(test normalized-grep-input-supports-structured-and-natural-language-input
  (is (equal (cl-cc.tools::%normalized-grep-input '(:query "session-loop" :root "src"))
             '(:query "session-loop" :root "src")))
  (is (equal (cl-cc.tools::%normalized-grep-input "grep session-loop")
             '(:query "session-loop" :root nil)))
  (is (equal (cl-cc.tools::%normalized-grep-input "search code for permission :: src")
             '(:query "permission" :root "src")))
  (is (equal (cl-cc.tools::%normalized-grep-input "fixture-input-grep file-write-tool")
             '(:query "file-write-tool" :root nil)))
  (is (null (cl-cc.tools::%normalized-grep-input "   "))))

(test grep-tool-signals-stable-error-for-invalid-input
  (handler-case
      (progn
        (cl-cc.tools:grep-tool "")
        (fail "expected grep-tool invalid-input error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :grep-search-failed))
      (is (search "请求格式无效" (cl-cc.lib:error-message condition)))))
  (handler-case
      (progn
        (cl-cc.tools:grep-tool "grep keyword :: missing-grep-root")
        (fail "expected grep-tool missing-root error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :grep-search-failed))
      (is (search "搜索根路径不存在" (cl-cc.lib:error-message condition))))))

(test grep-tool-renders-recursive-matches
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "grep-tool-test/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "root.lisp" directory-path))
         (nested-directory (merge-pathnames "nested/" directory-path))
         (nested-file (merge-pathnames "nested/result.txt" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested-directory)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%needle here") stream))
           (with-open-file (stream nested-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "needle again" stream))
           (let ((result (cl-cc.tools:grep-tool (list :query "needle"
                                                      :root (uiop:native-namestring directory-path)))))
             (is (search "root.lisp:2:needle here" result))
             (is (search "nested/result.txt:1:needle again" result)))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file nested-file)
        (delete-file nested-file))
      (when (probe-file nested-directory)
        (uiop:delete-directory-tree nested-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore))))

(test grep-tool-prefers-command-runner-when-available
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "grep-tool-command-test/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "root.lisp" directory-path))
         (nested-directory (merge-pathnames "nested/" directory-path))
         (nested-file (merge-pathnames "nested/result.txt" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested-directory)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%needle here") stream))
           (with-open-file (stream nested-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "needle again" stream))
           (let ((cl-cc.tools::*grep-command-runner*
                   (lambda (query root max-results)
                     (declare (ignore query root max-results))
                     (list :stdout (format nil "nested/result.txt:1:needle again~%root.lisp:2:needle here~%")
                           :stderr nil
                           :exit-code 0))))
             (let ((result (cl-cc.tools:grep-tool
                            (list :query "needle"
                                  :root (uiop:native-namestring directory-path)))))
               (is (string= result
                            (format nil "nested/result.txt:1:needle again~%root.lisp:2:needle here"))))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file nested-file)
        (delete-file nested-file))
      (when (probe-file nested-directory)
        (uiop:delete-directory-tree nested-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test grep-tool-falls-back-when-command-runner-is-unavailable
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "grep-tool-fallback-test/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "root.lisp" directory-path))
         (nested-directory (merge-pathnames "nested/" directory-path))
         (nested-file (merge-pathnames "nested/result.txt" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist nested-directory)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%needle here") stream))
           (with-open-file (stream nested-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "needle again" stream))
           (let ((cl-cc.tools::*grep-command-runner*
                   (lambda (query root max-results)
                     (declare (ignore query root max-results))
                     nil)))
             (let ((result (cl-cc.tools:grep-tool
                            (list :query "needle"
                                  :root (uiop:native-namestring directory-path)))))
               (is (search "root.lisp:2:needle here" result))
               (is (search "nested/result.txt:1:needle again" result)))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file nested-file)
        (delete-file nested-file))
      (when (probe-file nested-directory)
        (uiop:delete-directory-tree nested-directory :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))