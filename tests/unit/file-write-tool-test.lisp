;;;; tests/unit/file-write-tool-test.lisp - file-write-tool 单元测试
(in-package :cl-cc/tests)

(def-suite file-write-tool-test :in cl-cc-suite)

(in-suite file-write-tool-test)

(test normalized-file-write-input-supports-structured-and-natural-language-input
  (is (equal (cl-cc.tools::%normalized-file-write-input '(:path "C:/tmp/demo.txt" :content "hello"))
             '(:path "C:/tmp/demo.txt" :content "hello" :mode :overwrite)))
  (is (equal (cl-cc.tools::%normalized-file-write-input "write file C:/tmp/demo.txt :: hello")
             '(:path "C:/tmp/demo.txt" :content " hello" :mode :overwrite)))
  (is (equal (cl-cc.tools::%normalized-file-write-input "写入文件 C:/tmp/demo.txt :: 内容")
             '(:path "C:/tmp/demo.txt" :content " 内容" :mode :overwrite)))
  (is (equal (cl-cc.tools::%normalized-file-write-input "append file C:/tmp/demo.txt :: tail")
             '(:path "C:/tmp/demo.txt" :content " tail" :mode :append)))
  (is (null (cl-cc.tools::%normalized-file-write-input "   "))))

(test file-write-tool-writes-content-and-signals-stable-errors
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-write-tool-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (is (string= (cl-cc.tools:file-write-tool (list :path path :content "write-ok"))
                        (format nil "写入文件: ~A" path)))
           (is (string= (uiop:read-file-string path) "write-ok"))
           (is (string= (cl-cc.tools:file-write-tool (list :path path :content "-tail" :mode :append))
                        (format nil "追加写入文件: ~A" path)))
           (is (string= (uiop:read-file-string path) "write-ok-tail"))
           (handler-case
               (progn
                 (cl-cc.tools:file-write-tool "write file only-path")
                 (fail "expected invalid file-write-tool request"))
             (cl-cc.lib:cl-cc-error (condition)
               (is (eq (cl-cc.lib:error-code condition) :file-write-failed))
               (is (search "请求格式无效" (cl-cc.lib:error-message condition))))))
      (when (probe-file path)
        (delete-file path)))))