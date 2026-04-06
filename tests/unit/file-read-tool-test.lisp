;;;; tests/unit/file-read-tool-test.lisp - file-read-tool 单元测试
(in-package :cl-cc/tests)

(def-suite file-read-tool-test :in cl-cc-suite)

(in-suite file-read-tool-test)

(test normalized-file-read-input-strips-fixture-prefix
  (is (equal (cl-cc.tools::%normalized-file-read-input "fixture-input-C:/tmp/test.txt")
             '(:path "C:/tmp/test.txt" :start-line nil :end-line nil)))
  (is (equal (cl-cc.tools::%normalized-file-read-input "read file C:/tmp/test.txt")
             '(:path "C:/tmp/test.txt" :start-line nil :end-line nil)))
  (is (equal (cl-cc.tools::%normalized-file-read-input "读取文件 C:/tmp/test.txt")
             '(:path "C:/tmp/test.txt" :start-line nil :end-line nil)))
  (is (equal (cl-cc.tools::%normalized-file-read-input "  plain.txt  ")
             '(:path "plain.txt" :start-line nil :end-line nil)))
  (is (null (cl-cc.tools::%normalized-file-read-input "   "))))

(test normalized-file-read-input-parses-line-ranges
  (is (equal (cl-cc.tools::%normalized-file-read-input "read file src/main.lisp :: 10-20")
             '(:path "src/main.lisp" :start-line 10 :end-line 20)))
  (is (equal (cl-cc.tools::%normalized-file-read-input "src/main.lisp:7-9")
             '(:path "src/main.lisp" :start-line 7 :end-line 9)))
  (is (equal (cl-cc.tools::%normalized-file-read-input "read file src/main.lisp :: 2-3,7,9-10")
             '(:path "src/main.lisp" :start-line nil :end-line nil
               :ranges ((:start-line 2 :end-line 3)
                        (:start-line 7 :end-line 7)
                        (:start-line 9 :end-line 10)))))
  (is (equal (cl-cc.tools::%normalized-file-read-input "src/main.lisp:11:(defun demo)")
             '(:path "src/main.lisp" :start-line 11 :end-line 11)))
  (is (equal (cl-cc.tools::%normalized-file-read-input "读取文件 src/main.lisp 第 3-4 行")
             '(:path "src/main.lisp" :start-line 3 :end-line 4)))
  (is (equal (cl-cc.tools::%normalized-file-read-input '(:path "src/main.lisp" :ranges ((:startLine 2 :endLine 3)
                                                                                           (:start-line 5 :end-line 5))))
             '(:path "src/main.lisp" :start-line nil :end-line nil
               :ranges ((:start-line 2 :end-line 3)
                        (:start-line 5 :end-line 5)))))
  (is (equal (cl-cc.tools::%normalized-file-read-input '(:path "src/main.lisp"
                                                         :ranges ((:startLine 2 :endLine 3)
                                                                  (:start-line 5 :end-line 5))
                                                         :contextLines 2))
             '(:path "src/main.lisp" :start-line nil :end-line nil
               :ranges ((:start-line 2 :end-line 3)
                        (:start-line 5 :end-line 5))
               :context-lines 2)))
  (is (equal (cl-cc.tools::%normalized-file-read-input '(:path "src/main.lisp" :start-line 2 :end-line 5))
             '(:path "src/main.lisp" :start-line 2 :end-line 5)))
  (is (equal (cl-cc.tools::%normalized-file-read-input '(:path "src/main.lisp" :start-line 2 :end-line 5 :context-lines 1))
             '(:path "src/main.lisp" :start-line 2 :end-line 5 :context-lines 1)))
  (is (null (cl-cc.tools::%normalized-file-read-input "read file src/main.lisp :: 5-2"))))

(test file-read-tool-signals-stable-error-for-invalid-or-missing-file
  (handler-case
      (progn
        (cl-cc.tools:file-read-tool "")
        (fail "expected file-read-tool empty-path error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :file-read-failed))
      (is (search "路径为空" (cl-cc.lib:error-message condition)))))
  (handler-case
      (progn
        (cl-cc.tools:file-read-tool "missing-file-read-tool.txt")
        (fail "expected file-read-tool missing-file error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :file-read-failed))
      (is (search "文件不存在" (cl-cc.lib:error-message condition))))))

(test file-read-tool-context-lines-does-not-mask-out-of-range-requests
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-read-tool-context-lines-invalid-range-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%beta~%gamma~%delta~%epsilon") stream))
           (handler-case
               (progn
                 (cl-cc.tools:file-read-tool (list :path path :start-line 7 :end-line 7 :context-lines 3))
                 (fail "expected file-read-tool out-of-range error for contextual single range"))
             (cl-cc.lib:cl-cc-error (condition)
               (is (eq (cl-cc.lib:error-code condition) :file-read-failed))
               (is (search "请求的起始行超出文件范围: 7" (cl-cc.lib:error-message condition)))))
           (handler-case
               (progn
                 (cl-cc.tools:file-read-tool (list :path path
                                                   :ranges '((:start-line 2 :end-line 2)
                                                             (:start-line 8 :end-line 8))
                                                   :context-lines 2))
                 (fail "expected file-read-tool out-of-range error for contextual multi range"))
             (cl-cc.lib:cl-cc-error (condition)
               (is (eq (cl-cc.lib:error-code condition) :file-read-failed))
               (is (search "请求的起始行超出文件范围: 8" (cl-cc.lib:error-message condition))))))
      (when (probe-file path)
        (delete-file path)))))

(test file-read-tool-renders-selected-lines-with-stable-numbers
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-read-tool-lines-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~C~Cbeta~C~Cgamma~C~Cdelta"
                                   #\Return #\Linefeed
                                   #\Return #\Linefeed
                                   #\Return #\Linefeed)
                           stream))
           (is (string= (cl-cc.tools:file-read-tool (list :path path :start-line 2 :end-line 3))
                        (format nil "2:beta~%3:gamma")))
           (is (string= (cl-cc.tools:file-read-tool (format nil "read file ~A :: 4" path))
                        "4:delta")))
      (when (probe-file path)
        (delete-file path)))))

(test file-read-tool-renders-selected-lines-with-context-lines
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-read-tool-context-lines-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%beta~%gamma~%delta~%epsilon") stream))
           (is (string= (cl-cc.tools:file-read-tool (list :path path :start-line 1 :end-line 1 :context-lines 2))
                        (format nil "1:alpha~%2:beta~%3:gamma")))
           (is (string= (cl-cc.tools:file-read-tool (list :path path :start-line 4 :end-line 4 :contextLines 1))
                        (format nil "3:gamma~%4:delta~%5:epsilon"))))
      (when (probe-file path)
        (delete-file path)))))

(test file-read-tool-renders-multiple-ranges-with-deduplicated-lines
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-read-tool-multi-range-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "first~%second~%third~%fourth~%fifth") stream))
           (is (string= (cl-cc.tools:file-read-tool (format nil "read file ~A :: 2-3,5,3-4" path))
                        (format nil "2:second~%3:third~%5:fifth~%4:fourth")))
           (is (string= (cl-cc.tools:file-read-tool
                         (list :path path
                               :ranges '((:start-line 1 :end-line 2)
                                         (:start-line 4 :end-line 5))))
                        (format nil "1:first~%2:second~%4:fourth~%5:fifth"))))
      (when (probe-file path)
        (delete-file path)))))

(test file-read-tool-renders-contextual-multiple-ranges-with-stable-merged-lines
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-read-tool-contextual-multi-range-test.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "one~%two~%three~%four~%five~%six~%seven~%eight") stream))
           (is (string= (cl-cc.tools:file-read-tool
                         (list :path path
                               :ranges '((:start-line 2 :end-line 3)
                                         (:start-line 5 :end-line 5))
                               :context-lines 1))
                        (format nil "1:one~%2:two~%3:three~%4:four~%5:five~%6:six")))
           (is (string= (cl-cc.tools:file-read-tool
                         (list :path path
                               :ranges '((:start-line 3 :end-line 3)
                                         (:start-line 7 :end-line 7))
                               :context-lines 1))
                (format nil "2:two~%3:three~%4:four~%6:six~%7:seven~%8:eight")))
               (is (string= (cl-cc.tools:file-read-tool
                 (list :path path
                   :ranges '((:start-line 7 :end-line 7)
                         (:start-line 3 :end-line 3))
                   :context-lines 1))
                (format nil "2:two~%3:three~%4:four~%6:six~%7:seven~%8:eight"))))
      (when (probe-file path)
        (delete-file path)))))