;;;; tests/unit/file-edit-tool-test.lisp - file-edit-tool 单元测试
(in-package :cl-cc/tests)

(def-suite file-edit-tool-test :in cl-cc-suite)

(in-suite file-edit-tool-test)

(test normalized-file-edit-input-supports-structured-and-natural-language-input
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after"))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "patch file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input
              (format nil "patch file C:/tmp/demo.txt~%<<<<<<< SEARCH~%before~%=======~%after~%>>>>>>> REPLACE"))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input
              (format nil "preview patch file C:/tmp/demo.txt~%<<<<<<< SEARCH~%before~%=======~%after~%>>>>>>> REPLACE~%<<<<<<< SEARCH~%alpha~%=======~%beta~%>>>>>>> REPLACE"))
             '(:path "C:/tmp/demo.txt" :edits ((:old-text "before" :new-text "after")
                                               (:old-text "alpha" :new-text "beta"))
               :preview t :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input
              (format nil "preview regex ignore case patch file C:/tmp/demo.txt~%<<<<<<< SEARCH~%token-[0-9]+~%=======~%value~%>>>>>>> REPLACE"))
             '(:path "C:/tmp/demo.txt" :old-text "token-[0-9]+" :new-text "value" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "update file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "替换文件 C:/tmp/demo.txt :: 旧内容 :: 新内容")
             '(:path "C:/tmp/demo.txt" :old-text " 旧内容" :new-text " 新内容" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "edit file C:/tmp/demo.txt :: before :: after :: 2")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after " :preview nil :occurrence 2 :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "occurrence 2 edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence 2 :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview ignore case 2nd occurrence edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence 2 :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览忽略大小写第2处编辑文件 C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence 2 :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :occurrence 3))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence 3 :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :line-context 2))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence nil :line-context 2 :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "context 2 edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context 2 :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "context 2 patch file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context 2 :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则上下文0行编辑文件 C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context 0 :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :ignore-case t))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "ignore case edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview whole word case-insensitive modify file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word t :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview whole word ignore case edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word t :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览忽略大小写左边界编辑文件 C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary t :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则忽略大小写编辑文件 C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex ignore case multiline edit file C:/tmp/demo.txt :: ^b.*e$ :: after")
             '(:path "C:/tmp/demo.txt" :old-text " ^b.*e$" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex dot all ignore case multiline edit file C:/tmp/demo.txt :: ^b.*e$ :: after")
             '(:path "C:/tmp/demo.txt" :old-text " ^b.*e$" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex replace all ignore case edit file C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex replace all case-insensitive patch file C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex ignore case context 0 edit file C:/tmp/demo.txt :: ^b.*e$ :: after")
             '(:path "C:/tmp/demo.txt" :old-text " ^b.*e$" :new-text " after" :preview t :occurrence nil :line-context 0 :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex replace all context 2 patch file C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context 2 :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则忽略大小写上下文0行编辑文件 C:/tmp/demo.txt :: ^b.*e$ :: after")
             '(:path "C:/tmp/demo.txt" :old-text " ^b.*e$" :new-text " after" :preview t :occurrence nil :line-context 0 :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex ignore case dot all edit file C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :dot-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则忽略大小写多行模式点号跨行编辑文件 C:/tmp/demo.txt :: ^b.*e$ :: after")
             '(:path "C:/tmp/demo.txt" :old-text " ^b.*e$" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex multiline edit file C:/tmp/demo.txt :: ^b.*e$ :: after")
             '(:path "C:/tmp/demo.txt" :old-text " ^b.*e$" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则多行模式编辑文件 C:/tmp/demo.txt :: ^b.*e$ :: after")
             '(:path "C:/tmp/demo.txt" :old-text " ^b.*e$" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "regex dot all edit file C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :dot-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则点号跨行编辑文件 C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :dot-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex multiline dot all edit file C:/tmp/demo.txt :: ^b.*e$ :: after")
             '(:path "C:/tmp/demo.txt" :old-text " ^b.*e$" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex right word boundary left word boundary edit file C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary t :right-word-boundary t :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则整词右边界编辑文件 C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word t :left-word-boundary nil :right-word-boundary t :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则多行模式点号跨行编辑文件 C:/tmp/demo.txt :: ^b.*e$ :: after")
             '(:path "C:/tmp/demo.txt" :old-text " ^b.*e$" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :whole-word t))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word t :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "whole word edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word t :left-word-boundary nil :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "left word boundary ignore case edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary t :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :left-word-boundary t))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary t :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "left word boundary edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary t :right-word-boundary nil)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :right-word-boundary t))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则右边界编辑文件 C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary t :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "b.*e" :new-text "after" :use-regex t))
             '(:path "C:/tmp/demo.txt" :old-text "b.*e" :new-text "after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "^b.*e$" :new-text "after" :use-regex t :multiline t :dot-all t))
             '(:path "C:/tmp/demo.txt" :old-text "^b.*e$" :new-text "after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :multiline t :dot-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "regex edit file C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :replace-all t))
             '(:path "C:/tmp/demo.txt" :old-text "before" :new-text "after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :replace-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "replace all in file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview nil :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :replace-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview replace all ignore case edit file C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case t :whole-word nil :left-word-boundary nil :right-word-boundary nil :replace-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览全部替换文件 C:/tmp/demo.txt :: before :: after")
             '(:path "C:/tmp/demo.txt" :old-text " before" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :replace-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "preview regex replace all in file C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))
  (is (equal (cl-cc.tools::%normalized-file-edit-input "预览正则全部替换文件 C:/tmp/demo.txt :: b.*e :: after")
             '(:path "C:/tmp/demo.txt" :old-text " b.*e" :new-text " after" :preview t :occurrence nil :line-context nil :ignore-case nil :whole-word nil :left-word-boundary nil :right-word-boundary nil :use-regex t :replace-all t)))
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
             (is (= (getf result :line-context) 1))
             (is (not (getf result :ignore-case)))
             (is (not (getf result :whole-word)))
             (is (= (getf result :match-start-line) 1))
             (is (= (getf result :match-start-column) 8))
             (is (= (getf result :match-end-line) 1))
             (is (= (getf result :match-end-column) 14))
             (is (string= (getf result :matched-text) "target"))
             (is (string= (getf result :replacement-text) "updated"))
             (is (string= (getf result :diff-preview)
                  (format nil "@@ match 7..13 @@~%-~A~%+~A"
                    "before target after"
                    "before updated after")))
             (is (string= (getf result :line-diff-preview)
                          (format nil "@@ lines 1..1 -> 1..1 @@~%before:~%- 1| before target after~%after:~%+ 1| before updated after")))
             (is (string= (getf result :unified-diff-preview)
                    (format nil "--- a/~A~%+++ b/~A~%@@ -1 +1 @@~%-before target after~%+before updated after"
                    (substitute #\/ #\\ path)
                    (substitute #\/ #\\ path))))
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
             (is (= (getf result :line-context) 1))
             (is (not (getf result :ignore-case)))
             (is (not (getf result :whole-word)))
             (is (= (getf result :match-start-line) 1))
             (is (= (getf result :match-start-column) 8))
             (is (= (getf result :match-end-line) 1))
             (is (= (getf result :match-end-column) 15))
             (is (string= (getf result :before-preview) "before preview after"))
             (is (string= (getf result :after-preview) "before done after"))
             (is (string= (getf result :diff-preview)
                  (format nil "@@ match 7..14 @@~%-~A~%+~A"
                    "before preview after"
                    "before done after")))
             (is (string= (getf result :line-diff-preview)
                          (format nil "@@ lines 1..1 -> 1..1 @@~%before:~%- 1| before preview after~%after:~%+ 1| before done after")))
             (is (string= (getf result :unified-diff-preview)
                    (format nil "--- a/~A~%+++ b/~A~%@@ -1 +1 @@~%-before preview after~%+before done after"
                    (substitute #\/ #\\ path)
                    (substitute #\/ #\\ path)))))
           (is (string= (uiop:read-file-string path) "before preview after")))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-can-preview-sequential-search-replace-blocks
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-search-replace-blocks.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before alpha tail" stream))
           (let ((result (cl-cc.tools:file-edit-tool
                          (format nil "preview patch file ~A~%<<<<<<< SEARCH~%before~%=======~%after~%>>>>>>> REPLACE~%<<<<<<< SEARCH~%alpha~%=======~%beta~%>>>>>>> REPLACE" path))))
             (is (search "顺序 2 块" (getf result :summary)))
             (is (= (getf result :match-count) 2))
             (is (string= (getf result :matched-text) "before"))
             (is (string= (getf result :replacement-text) "after"))
             (is (search "+after beta tail" (getf result :unified-diff-preview)))
             (is (string= (uiop:read-file-string path) "before alpha tail"))))
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

(test file-edit-tool-can-replace-all-matches-and-render-multiple-unified-hunks
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-replace-all.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%beta target~%gamma~%delta~%beta target~%omega") stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "target"
                                                           :new-text "done"
                                                           :preview t
                                                           :replace-all t
                                                           :line-context 0))))
             (is (search "全部 2 处命中" (getf result :summary)))
             (is (= (getf result :match-count) 2))
             (is (= (getf result :total-matches) 2))
             (is (null (getf result :selected-occurrence)))
             (is (not (getf result :ignore-case)))
             (is (not (getf result :whole-word)))
             (is (= (getf result :match-start-line) 2))
             (is (= (getf result :match-start-column) 6))
             (is (search "@@ -2 +2 @@" (getf result :unified-diff-preview)))
             (is (search "@@ -5 +5 @@" (getf result :unified-diff-preview)))
             (is (string= (getf result :unified-diff-preview)
                          (format nil "--- a/~A~%+++ b/~A~%@@ -2 +2 @@~%-beta target~%+beta done~%@@ -5 +5 @@~%-beta target~%+beta done"
                                  (substitute #\/ #\\ path)
                                  (substitute #\/ #\\ path)))))
           (is (string= (uiop:read-file-string path)
                        (format nil "alpha~%beta target~%gamma~%delta~%beta target~%omega")))
           (handler-case
               (progn
                 (cl-cc.tools:file-edit-tool (list :path path
                                                   :old-text "target"
                                                   :new-text "done"
                                                   :replace-all t
                                                   :occurrence 1))
                 (fail "expected replaceAll and occurrence conflict"))
             (cl-cc.lib:cl-cc-error (condition)
               (is (eq (cl-cc.lib:error-code condition) :file-edit-failed))
               (is (search "replaceAll 与 occurrence 不能同时指定" (cl-cc.lib:error-message condition))))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-case-insensitive-matching
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-case-insensitive.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before Target after" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "target"
                                                           :new-text "done"
                                                           :preview t
                                                           :ignore-case t))))
             (is (getf result :ignore-case))
             (is (not (getf result :whole-word)))
             (is (= (getf result :match-count) 1))
             (is (= (getf result :selected-occurrence) 1))
             (is (string= (getf result :matched-text) "Target"))
             (is (string= (getf result :after-preview) "before done after"))
             (is (string= (getf result :unified-diff-preview)
                          (format nil "--- a/~A~%+++ b/~A~%@@ -1 +1 @@~%-before Target after~%+before done after"
                                  (substitute #\/ #\\ path)
                                  (substitute #\/ #\\ path)))))
           (is (string= (uiop:read-file-string path) "before Target after")))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-regex-matching
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-regex.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before token-42 after" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "token-[0-9]+"
                                                           :new-text "done"
                                                           :preview t
                                                           :use-regex t))))
             (is (getf result :use-regex))
             (is (not (getf result :whole-word)))
             (is (= (getf result :match-count) 1))
             (is (= (getf result :selected-occurrence) 1))
             (is (string= (getf result :matched-text) "token-42"))
             (is (= (getf result :match-start-column) 8))
             (is (= (getf result :match-end-column) 16))
             (is (string= (getf result :after-preview) "before done after"))
             (is (string= (getf result :diff-preview)
                          (format nil "@@ match 7..15 @@~%-~A~%+~A"
                                  "before token-42 after"
                                  "before done after")))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-expands-regex-capture-groups-in-replacement-text
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-regex-captures.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before token-42 after" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "(token)-([0-9]+)"
                                                           :new-text "$2:$1|\\0"
                                                           :preview t
                                                           :use-regex t))))
             (is (getf result :use-regex))
             (is (not (getf result :whole-word)))
             (is (string= (getf result :matched-text) "token-42"))
             (is (string= (getf result :replacement-text) "42:token|token-42"))
             (is (string= (getf result :after-preview) "before 42:token|token-42 after"))
             (is (string= (getf result :diff-preview)
                          (format nil "@@ match 7..15 @@~%-~A~%+~A"
                                  "before token-42 after"
                                  "before 42:token|token-42 after")))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-expands-regex-capture-groups-for-replace-all
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-regex-captures-replace-all.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "id-1 and id-22" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "id-([0-9]+)"
                                                           :new-text "item-$1"
                                                           :replace-all t
                                                           :use-regex t))))
             (is (= (getf result :match-count) 2))
             (is (not (getf result :whole-word)))
             (is (string= (getf result :replacement-text) "item-1"))
             (is (string= (uiop:read-file-string path) "item-1 and item-22"))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-regex-replace-all
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-regex-replace-all.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha id-1~%beta~%gamma id-22") stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "id-[0-9]+"
                                                           :new-text "item"
                                                           :preview t
                                                           :replace-all t
                                                           :use-regex t
                                                           :line-context 0))))
             (is (getf result :use-regex))
             (is (not (getf result :whole-word)))
             (is (= (getf result :match-count) 2))
             (is (null (getf result :selected-occurrence)))
             (is (search "@@ -1 +1 @@" (getf result :unified-diff-preview)))
             (is (search "@@ -3 +3 @@" (getf result :unified-diff-preview)))
             (is (string= (getf result :matched-text) "id-1"))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-whole-word-matching
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-whole-word.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "target retarget target_1 target." stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "target"
                                                           :new-text "done"
                                                           :preview t
                                                           :replace-all t
                                                           :whole-word t))))
             (is (getf result :whole-word))
             (is (= (getf result :match-count) 2))
             (is (search "全部 2 处命中" (getf result :summary)))
             (is (string= (getf result :matched-text) "target"))
             (is (string= (getf result :after-preview) "done retarget target_1 d"))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-left-word-boundary-matching
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-left-word-boundary.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "target retarget target_1 x-target" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "target"
                                                           :new-text "done"
                                                           :preview t
                                                           :replace-all t
                                                           :left-word-boundary t))))
             (is (not (getf result :whole-word)))
             (is (getf result :left-word-boundary))
             (is (not (getf result :right-word-boundary)))
             (is (= (getf result :match-count) 3))
             (is (string= (getf result :after-preview) "done retarget done_1 x-d"))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-right-word-boundary-matching
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-right-word-boundary.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "retarget target_1 target x-target" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "target"
                                                           :new-text "done"
                                                           :preview t
                                                           :replace-all t
                                                           :right-word-boundary t))))
             (is (not (getf result :whole-word)))
             (is (not (getf result :left-word-boundary)))
             (is (getf result :right-word-boundary))
             (is (= (getf result :match-count) 3))
             (is (string= (getf result :after-preview) "redone target_1 done x-don"))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-regex-whole-word-matching
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-regex-whole-word.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "id-7 mid-22 id-300x id-44" stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "id-[0-9]+"
                                                           :new-text "item"
                                                           :preview t
                                                           :replace-all t
                                                           :use-regex t
                                                           :whole-word t))))
             (is (getf result :use-regex))
             (is (getf result :whole-word))
             (is (= (getf result :match-count) 2))
             (is (string= (getf result :after-preview) "item mid-22 id-300x item"))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-regex-multiline-matching
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-regex-multiline.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%id-42~%omega") stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "^id-[0-9]+$"
                                                           :new-text "item"
                                                           :preview t
                                                           :use-regex t
                                                           :multiline t))))
             (is (getf result :use-regex))
             (is (getf result :multiline))
             (is (not (getf result :dot-all)))
             (is (= (getf result :match-count) 1))
             (is (string= (getf result :matched-text) "id-42"))
             (is (string= (getf result :after-preview) (format nil "alpha~%item~%omega")))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-regex-dot-all-matching
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-regex-dot-all.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "begin~%middle~%end") stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "begin.*end"
                                                           :new-text "block"
                                                           :preview t
                                                           :use-regex t
                                                           :dot-all t))))
             (is (getf result :use-regex))
             (is (not (getf result :multiline)))
             (is (getf result :dot-all))
             (is (= (getf result :match-count) 1))
             (is (string= (getf result :matched-text) (format nil "begin~%middle~%end")))
             (is (string= (getf result :after-preview) "block"))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-signals-stable-error-for-invalid-regex
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-invalid-regex.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string "before token after" stream))
           (handler-case
               (progn
                 (cl-cc.tools:file-edit-tool (list :path path
                                                   :old-text "("
                                                   :new-text "value"
                                                   :use-regex t))
                 (fail "expected invalid regex error"))
             (cl-cc.lib:cl-cc-error (condition)
               (is (eq (cl-cc.lib:error-code condition) :file-edit-failed))
               (is (search "正则表达式无效" (cl-cc.lib:error-message condition))))))
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
             (is (= (getf result :line-context) 1))
             (is (not (getf result :ignore-case)))
             (is (not (getf result :whole-word)))
             (is (= (getf result :match-start-line) 1))
             (is (= (getf result :match-start-column) 9))
             (is (= (getf result :match-end-line) 1))
             (is (= (getf result :match-end-column) 12))
             (is (string= (getf result :before-preview) "dup gap dup tail"))
             (is (string= (getf result :after-preview) "dup gap done tail"))
             (is (string= (getf result :diff-preview)
                  (format nil "@@ match 8..11 @@~%-~A~%+~A"
                    "dup gap dup tail"
                    "dup gap done tail")))
             (is (string= (getf result :line-diff-preview)
                          (format nil "@@ lines 1..1 -> 1..1 @@~%before:~%- 1| dup gap dup tail~%after:~%+ 1| dup gap done tail")))
             (is (string= (getf result :unified-diff-preview)
                    (format nil "--- a/~A~%+++ b/~A~%@@ -1 +1 @@~%-dup gap dup tail~%+dup gap done tail"
                    (substitute #\/ #\\ path)
                    (substitute #\/ #\\ path)))))
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

(test file-edit-tool-computes-multiline-position-metadata
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-multiline.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%beta target~%gamma") stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path :old-text "target" :new-text "done" :preview t))))
             (is (= (getf result :match-start-line) 2))
             (is (= (getf result :match-start-column) 6))
             (is (= (getf result :match-end-line) 2))
             (is (= (getf result :match-end-column) 12))
             (is (string= (getf result :line-diff-preview)
                          (format nil "@@ lines 2..2 -> 2..2 @@~%before:~%  1| alpha~%- 2| beta target~%  3| gamma~%after:~%  1| alpha~%+ 2| beta done~%  3| gamma")))
             (is (string= (getf result :unified-diff-preview)
                 (format nil "--- a/~A~%+++ b/~A~%@@ -1,3 +1,3 @@~% alpha~%-beta target~%+beta done~% gamma"
                    (substitute #\/ #\\ path)
                    (substitute #\/ #\\ path))))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-renders-line-diff-preview-for-multiline-replacement
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-line-diff.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "alpha~%beta target~%gamma") stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "beta target"
                                                           :new-text (format nil "beta~%done")
                                                           :preview t))))
             (is (string= (getf result :line-diff-preview)
                          (format nil "@@ lines 2..2 -> 2..3 @@~%before:~%  1| alpha~%- 2| beta target~%  3| gamma~%after:~%  1| alpha~%+ 2| beta~%+ 3| done~%  4| gamma")))
             (is (string= (getf result :unified-diff-preview)
                 (format nil "--- a/~A~%+++ b/~A~%@@ -1,3 +1,4 @@~% alpha~%-beta target~%+beta~%+done~% gamma"
                    (substitute #\/ #\\ path)
                    (substitute #\/ #\\ path))))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-supports-custom-line-diff-context
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-line-context.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "zero~%alpha~%beta target~%gamma~%omega") stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "target"
                                                           :new-text "done"
                                                           :preview t
                                                           :line-context 2))))
             (is (= (getf result :line-context) 2))
             (is (string= (getf result :line-diff-preview)
                          (format nil "@@ lines 3..3 -> 3..3 @@~%before:~%  1| zero~%  2| alpha~%- 3| beta target~%  4| gamma~%  5| omega~%after:~%  1| zero~%  2| alpha~%+ 3| beta done~%  4| gamma~%  5| omega")))
             (is (string= (getf result :unified-diff-preview)
                 (format nil "--- a/~A~%+++ b/~A~%@@ -1,5 +1,5 @@~% zero~% alpha~%-beta target~%+beta done~% gamma~% omega"
                    (substitute #\/ #\\ path)
                    (substitute #\/ #\\ path))))))
      (when (probe-file path)
        (delete-file path)))))

(test file-edit-tool-line-diff-preview-shows-omission-markers-when-context-is-clipped
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "file-edit-tool-line-context-omitted.txt"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "zero~%alpha~%beta target~%gamma~%omega") stream))
           (let ((result (cl-cc.tools:file-edit-tool (list :path path
                                                           :old-text "target"
                                                           :new-text "done"
                                                           :preview t
                                                           :line-context 0))))
             (is (= (getf result :line-context) 0))
             (is (string= (getf result :line-diff-preview)
                          (format nil "@@ lines 3..3 -> 3..3 @@~%before:~%  ... | 前文省略 2 行~%- 3| beta target~%  ... | 后文省略 2 行~%after:~%  ... | 前文省略 2 行~%+ 3| beta done~%  ... | 后文省略 2 行")))
             (is (string= (getf result :unified-diff-preview)
                  (format nil "--- a/~A~%+++ b/~A~%@@ -3 +3 @@~%-beta target~%+beta done"
                    (substitute #\/ #\\ path)
                    (substitute #\/ #\\ path))))))
      (when (probe-file path)
        (delete-file path)))))
