;;;; src/tools/grep-tool.lisp - 最小可用代码检索工具
(in-package :cl-cc.tools)

(defparameter +grep-tool-input-prefixes+
  '("grep " "search code for " "search text for " "search for " "find text " "find in files "
    "搜索代码 " "搜索文本 " "查找文本 " "在代码中搜索 ")
  "允许 grep-tool 直接消费的自然语言前缀。")

(defparameter +grep-tool-max-results+ 50
  "grep-tool 返回的最大匹配条数，避免一次结果过长。")

(defun %grep-tool-message (detail)
  (format nil "代码搜索失败: ~A" detail))

(defun %grep-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :grep-search-failed
                              (%grep-tool-message detail)))

(defun %grep-request (query &key root)
  (list :query query :root root))

(defun %normalize-grep-string (value)
  (let ((text (and value (string-trim '(#\Space #\Tab #\Newline #\Return) (string value)))))
    (and text
         (> (length text) 0)
         text)))

(defun %normalize-grep-request (query &key root)
  (let ((normalized-query (%normalize-grep-string query))
        (normalized-root (%normalize-grep-string root)))
    (when normalized-query
      (%grep-request normalized-query :root normalized-root))))

(defun %parse-grep-text (text)
  (multiple-value-bind (query root foundp)
      (%split-once text "::")
    (if foundp
        (%normalize-grep-request query :root root)
        (%normalize-grep-request text))))

(defun %parse-prefixed-grep-text (text)
  (%parse-grep-text (%strip-input-prefix text +grep-tool-input-prefixes+)))

(defun %normalized-grep-input (input)
  (cond
    ((and (listp input)
          (getf input :query))
     (%normalize-grep-request (getf input :query)
                              :root (getf input :root)))
    (t
     (let ((text (%normalize-grep-string input)))
       (cond
         ((null text) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-grep-input (subseq text (length "fixture-input-"))))
         (t (%parse-prefixed-grep-text text)))))))

(defun %portable-path-string (path)
  (substitute #\/ #\\ (namestring path)))

(defun %canonical-path-string (path)
  (%portable-path-string (or (ignore-errors (truename path))
                             (pathname path))))

(defun %normalized-search-root (root)
  (let* ((base (uiop:ensure-directory-pathname (uiop:getcwd)))
         (resolved (if root
                       (uiop:merge-pathnames* root base)
                       base)))
    (if (uiop:directory-exists-p resolved)
        (uiop:ensure-directory-pathname resolved)
        resolved)))

(defun %search-target-files (root)
  (labels ((walk (directory)
             (append (sort (copy-list (uiop:directory-files directory))
                           #'string<
                           :key #'%portable-path-string)
                     (loop for subdirectory in (sort (copy-list (uiop:subdirectories directory))
                                                    #'string<
                                                    :key #'%portable-path-string)
                           append (walk subdirectory)))))
    (cond
      ((uiop:directory-exists-p root)
       (walk (uiop:ensure-directory-pathname root)))
      ((probe-file root)
       (list root))
      (t nil))))

(defun %search-root-display (root)
  (let ((path (%normalized-search-root root)))
    (if (uiop:directory-exists-p path)
        (%portable-path-string (uiop:ensure-directory-pathname path))
        (%portable-path-string path))))

(defun %relative-match-path (path root)
  (let* ((root-path (%normalized-search-root root))
         (root-string (%canonical-path-string root-path))
         (directory-root-string (if (and (> (length root-string) 0)
                                         (char/= (char root-string (1- (length root-string))) #\/))
                                    (format nil "~A/" root-string)
                                    root-string))
         (file-string (%canonical-path-string path)))
    (cond
      ((string-equal file-string root-string)
       (file-namestring path))
      ((uiop:string-prefix-p directory-root-string file-string)
       (subseq file-string (length directory-root-string)))
      (t file-string))))

(defun %normalized-file-lines (contents)
  (labels ((normalize-line-endings (text)
             (with-output-to-string (stream)
               (loop for index from 0 below (length text)
                     for character = (char text index)
                     do (cond
                          ((char= character #\Return)
                           (write-char #\Newline stream)
                           (when (and (< (1+ index) (length text))
                                      (char= (char text (1+ index)) #\Newline))
                             (incf index)))
                          (t
                           (write-char character stream)))))))
    (uiop:split-string (normalize-line-endings contents) :separator '(#\Newline))))

(defun %file-match-lines (file query root)
  (handler-case
      (loop with contents = (uiop:read-file-string file)
            for line in (%normalized-file-lines contents)
            for line-number from 1
            when (search query line :test #'char-equal)
              collect (format nil "~A:~D:~A"
                              (%relative-match-path file root)
                              line-number
                              line))
    (error ()
      nil)))

(defun %grep-tool-result-lines (query root)
  (let ((matches '())
        (truncated-p nil)
        (resolved-root (%normalized-search-root root)))
    (dolist (file (%search-target-files resolved-root))
      (dolist (line (%file-match-lines file query resolved-root))
        (if (< (length matches) +grep-tool-max-results+)
            (push line matches)
            (setf truncated-p t))))
    (values (nreverse matches) truncated-p)))

(defun %grep-tool-render-result (matches truncated-p)
  (cond
    ((null matches) "(no matches)")
    (truncated-p
     (format nil "~{~A~^~%~}~%... (truncated to ~D matches)"
             matches
             +grep-tool-max-results+))
    (t
     (format nil "~{~A~^~%~}" matches))))

(defun grep-tool (input)
  "在目录树或单个文件中搜索文本，并返回稳定的逐行结果。"
  (let* ((request (%normalized-grep-input input))
         (query (and request (getf request :query)))
         (root (and request (getf request :root)))
         (resolved-root (%normalized-search-root root)))
    (unless request
      (error (%grep-tool-error "请求格式无效，期望 `grep <query>`、`search code for <query>` 或 `grep <query> :: <root>`")))
    (unless query
      (error (%grep-tool-error "搜索词为空")))
    (unless (probe-file resolved-root)
      (error (%grep-tool-error (format nil "搜索根路径不存在: ~A" (%search-root-display root)))))
    (handler-case
        (multiple-value-bind (matches truncated-p)
            (%grep-tool-result-lines query root)
          (%grep-tool-render-result matches truncated-p))
      (error ()
        (error (%grep-tool-error (format nil "无法搜索路径: ~A" (%search-root-display root))))))))