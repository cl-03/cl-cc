(test directory-list-tool-entries-extreme-and-abnormal-cases
  (let* ((tmp-root (uiop:ensure-directory-pathname
                    (uiop:merge-pathnames* "directory-list-tool-extreme-test/"
                                           (uiop:temporary-directory))))
         (file-a (merge-pathnames "a.txt" tmp-root))
         (dir-b (merge-pathnames "b/" tmp-root))
         (deep-dir (merge-pathnames "b/c/d/e/" tmp-root)))
    (unwind-protect
         (progn
           ;; 空目录
           (ensure-directories-exist tmp-root)
           (let* ((result (cl-cc.tools:directory-list-tool (list :path (uiop:native-namestring tmp-root))))
                  (parsed (ignore-errors (jsown:parse result)))
                  (entries (and parsed (jsown:val parsed "entries"))))
             (is (listp entries))
             (is (null entries)))

           ;; 仅有文件
           (with-open-file (stream file-a :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "a" stream))
           (let* ((result (cl-cc.tools:directory-list-tool (list :path (uiop:native-namestring tmp-root))))
                  (parsed (ignore-errors (jsown:parse result)))
                  (entries (and parsed (jsown:val parsed "entries"))))
             (is (= (length entries) 1))
             (is (string= (jsown:val (first entries) "type") ":file")))

           ;; 仅有目录
           (ensure-directories-exist dir-b)
           (delete-file file-a)
           (let* ((result (cl-cc.tools:directory-list-tool (list :path (uiop:native-namestring tmp-root))))
                  (parsed (ignore-errors (jsown:parse result)))
                  (entries (and parsed (jsown:val parsed "entries"))))
             (is (= (length entries) 1))
             (is (string= (jsown:val (first entries) "type") ":dir")))

           ;; 深层嵌套
           (ensure-directories-exist deep-dir)
           (let* ((result (cl-cc.tools:directory-list-tool (list :path (uiop:native-namestring tmp-root) :recursive t)))
                  (parsed (ignore-errors (jsown:parse result)))
                  (entries (and parsed (jsown:val parsed "entries"))))
             (is (find ":dir" (mapcar (lambda (e) (jsown:val e "type")) entries) :test #'string=)))

           ;; type 字段缺失/非法值
           (let* ((bad-json (jsown:to-json (jsown:new-js "result" "bad" "entries" (list (jsown:new-js "name" "foo")))))
                  (parsed (ignore-errors (jsown:parse bad-json)))
                  (entries (and parsed (jsown:val parsed "entries"))))
             (is (listp entries))
             (dolist (entry entries)
               (is (not (jsown:keyp entry "type")))))
           (let* ((bad-json2 (jsown:to-json (jsown:new-js "result" "bad" "entries" (list (jsown:new-js "name" "foo" "type" 123)))))
                  (parsed (ignore-errors (jsown:parse bad-json2)))
                  (entries (and parsed (jsown:val parsed "entries"))))
             (is (listp entries))
             (is (numberp (jsown:val (first entries) "type"))))

           ;; entries 字段缺失/非 list
           (let* ((bad-json3 (jsown:to-json (jsown:new-js "result" "bad")))
                  (parsed (ignore-errors (jsown:parse bad-json3))))
             (is (not (jsown:keyp parsed "entries"))))
           (let* ((bad-json4 (jsown:to-json (jsown:new-js "result" "bad" "entries" 42)))
                  (parsed (ignore-errors (jsown:parse bad-json4))))
             (is (numberp (jsown:val parsed "entries"))))

           ;; 非法输入类型
           (is (null (cl-cc.tools:directory-list-tool 123)))
           (is (null (cl-cc.tools:directory-list-tool nil)))
           (is (null (cl-cc.tools:directory-list-tool '(:foo "bar"))))
           )
      (when (probe-file file-a)
        (delete-file file-a))
      (when (probe-file deep-dir)
        (uiop:delete-directory-tree deep-dir :validate t :if-does-not-exist :ignore))
      (when (probe-file dir-b)
        (uiop:delete-directory-tree dir-b :validate t :if-does-not-exist :ignore))
      (when (probe-file tmp-root)
        (uiop:delete-directory-tree tmp-root :validate t :if-does-not-exist :ignore)))))
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

(test normalized-directory-list-input-supports-recursive-and-depth-options
  (is (equal (cl-cc.tools::%normalized-directory-list-input "list directory C:/tmp/demo :: recursive :: depth=2")
             '(:path "C:/tmp/demo" :recursive t :depth 2)))
  (is (equal (cl-cc.tools::%normalized-directory-list-input "列出目录 C:/tmp/demo :: 深度=3")
             '(:path "C:/tmp/demo" :recursive t :depth 3)))
  (is (equal (cl-cc.tools::%normalized-directory-list-input "list directory C:/tmp/demo :: recursive :: contains=note")
             '(:path "C:/tmp/demo" :recursive t :depth nil :contains "note")))
  (is (equal (cl-cc.tools::%normalized-directory-list-input '(:path "C:/tmp/demo" :recursive t :depth 1))
             '(:path "C:/tmp/demo" :recursive t :depth 1))))

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

(test directory-list-tool-can-render-recursive-entry-lines-with-depth-limit
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "directory-list-tool-recursive-test/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "a.txt" directory-path))
         (child-dir (merge-pathnames "child/" directory-path))
         (child-file (merge-pathnames "note.txt" child-dir))
         (grandchild-dir (merge-pathnames "nested/" child-dir))
         (grandchild-file (merge-pathnames "deep.txt" grandchild-dir)))
    (unwind-protect
         (progn
           (ensure-directories-exist grandchild-dir)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "root" stream))
           (with-open-file (stream child-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "child" stream))
           (with-open-file (stream grandchild-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "deep" stream))
           (is (string= (cl-cc.tools:directory-list-tool (format nil "list directory ~A :: recursive"
                                                                 (uiop:native-namestring directory-path)))
                        (format nil "a.txt~%child/~%child/nested/~%child/nested/deep.txt~%child/note.txt")))
           (is (string= (cl-cc.tools:directory-list-tool (list :path (uiop:native-namestring directory-path)
                                                                :depth 1))
                        (format nil "a.txt~%child/"))))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file child-file)
        (delete-file child-file))
      (when (probe-file grandchild-file)
        (delete-file grandchild-file))
      (when (probe-file grandchild-dir)
        (uiop:delete-directory-tree grandchild-dir :validate t :if-does-not-exist :ignore))
      (when (probe-file child-dir)
        (uiop:delete-directory-tree child-dir :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

(test directory-list-tool-supports-contains-filter
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "directory-list-tool-contains-test/"
                                                 (uiop:temporary-directory))))
         (root-file (merge-pathnames "alpha.txt" directory-path))
         (child-dir (merge-pathnames "child/" directory-path))
         (child-file (merge-pathnames "note.txt" child-dir))
         (other-file (merge-pathnames "other.md" child-dir)))
    (unwind-protect
         (progn
           (ensure-directories-exist child-dir)
           (with-open-file (stream root-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "alpha" stream))
           (with-open-file (stream child-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "note" stream))
           (with-open-file (stream other-file :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "other" stream))
           (is (string= (cl-cc.tools:directory-list-tool (format nil "list directory ~A :: recursive :: contains=note"
                                                                 (uiop:native-namestring directory-path)))
                        "child/note.txt"))
           (is (string= (cl-cc.tools:directory-list-tool (list :path (uiop:native-namestring directory-path)
                                                                :recursive t
                                                                :contains "child"))
                        (format nil "child/~%child/note.txt~%child/other.md")))
           (is (string= (cl-cc.tools:directory-list-tool (list :path (uiop:native-namestring directory-path)
                                                                :recursive t
                                                                :contains "missing"))
                        "(no matching entries)")))
      (when (probe-file root-file)
        (delete-file root-file))
      (when (probe-file child-file)
        (delete-file child-file))
      (when (probe-file other-file)
        (delete-file other-file))
      (when (probe-file child-dir)
        (uiop:delete-directory-tree child-dir :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore)))))

;;; 新增：断言 entries 每项都含 type 字段且为 :file 或 :dir
(test directory-list-tool-entries-have-type-field
  (let* ((directory-path (uiop:ensure-directory-pathname
                          (uiop:merge-pathnames* "directory-list-tool-type-test/"
                                                 (uiop:temporary-directory))))
         (file-a (merge-pathnames "a.txt" directory-path))
         (dir-b (merge-pathnames "b/" directory-path)))
    (unwind-protect
         (progn
           (ensure-directories-exist dir-b)
           (with-open-file (stream file-a :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "a" stream))
           ;; 调用工具，假定新版实现返回 entries 字段
           (let* ((result (cl-cc.tools:directory-list-tool (list :path (uiop:native-namestring directory-path))))
                  (parsed (ignore-errors (jsown:parse result)))
                  (entries (and parsed (jsown:val parsed "entries"))))
             (is (listp entries))
             (dolist (entry entries)
               (is (and (jsown:keyp entry "type")
                        (member (jsown:val entry "type") '(":file" ":dir") :test #'string=)))))
           )
      (when (probe-file file-a)
        (delete-file file-a))
      (when (probe-file dir-b)
        (uiop:delete-directory-tree dir-b :validate t :if-does-not-exist :ignore))
      (when (probe-file directory-path)
        (uiop:delete-directory-tree directory-path :validate t :if-does-not-exist :ignore))))