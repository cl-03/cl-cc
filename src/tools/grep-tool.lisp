;;;; src/tools/grep-tool.lisp - 最小可用代码检索工具
(in-package :cl-cc.tools)

(defparameter +grep-tool-input-prefixes+
  '("grep " "search code for " "search text for " "search for " "find text " "find in files "
    "搜索代码 " "搜索文本 " "查找文本 " "在代码中搜索 ")
  "允许 grep-tool 直接消费的自然语言前缀。")

(defparameter +grep-tool-max-results+ 50
  "grep-tool 返回的最大匹配条数，避免一次结果过长。")

(defparameter *grep-command-runner* nil
  "可替换的外部 grep 执行器，签名为 (queries root max-results)。")

(defun %grep-tool-message (detail)
  (format nil "代码搜索失败: ~A" detail))

(defun %grep-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :grep-search-failed
                              (%grep-tool-message detail)))

(defun %grep-request (queries &key root include-pattern exclude-pattern)
  (append (list :queries queries
                :query (first queries))
          (when root
            (list :root root))
          (when include-pattern
            (list :include-pattern include-pattern))
          (when exclude-pattern
            (list :exclude-pattern exclude-pattern))))

(defun %normalize-grep-string (value)
  (let ((text (and value (string-trim '(#\Space #\Tab #\Newline #\Return) (string value)))))
    (and text
         (> (length text) 0)
         text)))

(defun %split-grep-queries (query)
  (let ((normalized-query (%normalize-grep-string query)))
    (when normalized-query
      (let ((segments (uiop:split-string normalized-query :separator "||")))
        (loop for segment in segments
              for normalized-segment = (%normalize-grep-string segment)
              when normalized-segment
                collect normalized-segment)))))

(defun %normalize-grep-request (query &key root include-pattern exclude-pattern)
  (let ((normalized-queries (%split-grep-queries query))
        (normalized-root (%normalize-grep-string root))
        (normalized-include-pattern (%normalize-grep-string include-pattern))
        (normalized-exclude-pattern (%normalize-grep-string exclude-pattern)))
    (when normalized-queries
      (%grep-request normalized-queries
                     :root normalized-root
                     :include-pattern normalized-include-pattern
                     :exclude-pattern normalized-exclude-pattern))))

(defun %normalize-grep-queries-request (queries &key root include-pattern exclude-pattern)
  (let ((normalized-root (%normalize-grep-string root))
        (normalized-include-pattern (%normalize-grep-string include-pattern))
        (normalized-exclude-pattern (%normalize-grep-string exclude-pattern)))
    (when (and (listp queries)
               (> (length queries) 0))
      (let ((normalized-queries (loop for query in queries
                                      for normalized-query = (%normalize-grep-string query)
                                      when normalized-query
                                        collect normalized-query
                                      else
                                        do (return nil))))
        (when normalized-queries
          (%grep-request normalized-queries
                         :root normalized-root
                         :include-pattern normalized-include-pattern
                         :exclude-pattern normalized-exclude-pattern))))))

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
          (getf input :queries)
          (listp (getf input :queries)))
     (%normalize-grep-queries-request (getf input :queries)
                  :root (getf input :root)
                  :include-pattern (or (getf input :include-pattern)
                           (getf input :includePattern))
                  :exclude-pattern (or (getf input :exclude-pattern)
                           (getf input :excludePattern))))
    ((and (listp input)
          (getf input :query))
     (%normalize-grep-request (getf input :query)
              :root (getf input :root)
              :include-pattern (or (getf input :include-pattern)
                       (getf input :includePattern))
              :exclude-pattern (or (getf input :exclude-pattern)
                       (getf input :excludePattern))))
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

(defun %parent-directory-pathname (path)
  (uiop:ensure-directory-pathname
   (make-pathname :name nil :type nil :defaults path)))

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

(defun %grep-command-context (root)
  (let ((resolved-root (%normalized-search-root root)))
    (if (uiop:directory-exists-p resolved-root)
        (values resolved-root ".")
        (values (%parent-directory-pathname resolved-root)
                (file-namestring resolved-root)))))

(defun %grep-command-arguments (queries target max-results)
  (append (list "--color" "never"
        "--no-heading"
        "--with-filename"
        "--line-number"
        "--fixed-strings"
        "--max-count" (write-to-string max-results)
        "--no-messages")
      (loop for query in queries
        append (list "-e" query))
      (list "--" target)))

(defun %trim-grep-command-output (text)
  (let ((trimmed (and text (string-trim '(#\Space #\Tab #\Newline #\Return) text))))
    (and trimmed
         (> (length trimmed) 0)
         trimmed)))

(defun %normalize-grep-command-path (path)
  (let ((portable (%portable-path-string path)))
    (cond
      ((uiop:string-prefix-p "./" portable)
       (subseq portable 2))
      ((uiop:string-prefix-p ".\\" portable)
       (subseq portable 2))
      (t portable))))

(defun %grep-pattern-regex (pattern)
  (let ((portable-pattern (substitute #\/ #\\ pattern)))
    (with-output-to-string (stream)
      (write-char #\^ stream)
      (loop with length = (length portable-pattern)
            for index = 0 then next-index
            while (< index length)
            for character = (char portable-pattern index)
            for next-index = (1+ index)
            do (cond
                 ((char= character #\*)
                  (cond
                    ((and (< next-index length)
                          (char= (char portable-pattern next-index) #\*))
                     (let ((after-next (1+ next-index)))
                       (cond
                         ((and (< after-next length)
                               (char= (char portable-pattern after-next) #\/))
                          (write-string "(?:.*/)?" stream)
                          (setf next-index (+ index 3)))
                         (t
                          (write-string ".*" stream)
                          (setf next-index (+ index 2))))))
                    (t
                     (write-string "[^/]*" stream))))
                 ((char= character #\?)
                  (write-string "[^/]" stream))
                 ((find character ".+()[]{}^$|\\" :test #'char=)
                  (write-char #\\ stream)
                  (write-char character stream))
                 (t
                  (write-char character stream))))
      (write-char #\$ stream))))

(defun %grep-pattern-matches-p (pattern relative-path)
  (let ((scanner (cl-ppcre:create-scanner (%grep-pattern-regex pattern))))
    (cl-ppcre:scan scanner (substitute #\/ #\\ relative-path))))

(defun %grep-path-allowed-p (relative-path include-pattern exclude-pattern)
  (and (or (null include-pattern)
           (%grep-pattern-matches-p include-pattern relative-path))
       (or (null exclude-pattern)
           (not (%grep-pattern-matches-p exclude-pattern relative-path)))))

(defun %grep-command-match-line (line root &key include-pattern exclude-pattern)
  (multiple-value-bind (path remainder path-found-p)
      (%split-once line ":")
    (when (and path-found-p remainder)
      (multiple-value-bind (line-number text line-found-p)
          (%split-once remainder ":")
        (when (and line-found-p
                   line-number
                   (> (length line-number) 0))
          (let ((relative-path (%normalize-grep-command-path path)))
            (when (%grep-path-allowed-p relative-path include-pattern exclude-pattern)
              (let ((absolute-path (merge-pathnames relative-path (%normalized-search-root root))))
                (format nil "~A:~A:~A"
                        (%relative-match-path absolute-path root)
                        line-number
                        text)))))))))

(defun %grep-command-result-lines (stdout root &key include-pattern exclude-pattern)
  (sort (remove nil
                (mapcar (lambda (line)
                          (%grep-command-match-line line root
                                                    :include-pattern include-pattern
                                                    :exclude-pattern exclude-pattern))
                        (%normalized-file-lines (or stdout ""))))
        #'string<))

#+sbcl
(defun %default-grep-command-runner (queries root max-results)
  (multiple-value-bind (directory target)
      (%grep-command-context root)
    (handler-case
        (let* ((process (sb-ext:run-program "rg"
                                            (%grep-command-arguments queries target max-results)
                                            :search t
                                            :directory directory
                                            :output :stream
                                            :error :stream
                                            :input nil
                                            :wait nil)))
          (sb-ext:process-wait process)
          (list :stdout (%trim-grep-command-output
                         (uiop:slurp-stream-string (sb-ext:process-output process)))
                :stderr (%trim-grep-command-output
                         (uiop:slurp-stream-string (sb-ext:process-error process)))
                :exit-code (sb-ext:process-exit-code process)))
      (error ()
        nil))))

#-sbcl
(defun %default-grep-command-runner (queries root max-results)
  (declare (ignore queries root max-results))
  nil)

(setf *grep-command-runner* #'%default-grep-command-runner)

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

(defun %line-matches-any-grep-query-p (line queries)
  (loop for query in queries
        thereis (search query line :test #'char-equal)))

(defun %file-match-lines (file queries root)
  (handler-case
      (loop with contents = (uiop:read-file-string file)
            for line in (%normalized-file-lines contents)
            for line-number from 1
            when (%line-matches-any-grep-query-p line queries)
              collect (format nil "~A:~D:~A"
                              (%relative-match-path file root)
                              line-number
                              line))
    (error ()
      nil)))

(defun %grep-tool-result-lines (queries root &key include-pattern exclude-pattern)
  (let* ((command-result (and *grep-command-runner*
                              (funcall *grep-command-runner* queries root +grep-tool-max-results+)))
         (command-exit-code (and command-result (getf command-result :exit-code))))
    (when (member command-exit-code '(0 1))
      (let* ((command-matches (%grep-command-result-lines (getf command-result :stdout)
                                                          root
                                                          :include-pattern include-pattern
                                                          :exclude-pattern exclude-pattern))
             (truncated-p (> (length command-matches) +grep-tool-max-results+)))
        (return-from %grep-tool-result-lines
          (values (if truncated-p
                      (subseq command-matches 0 +grep-tool-max-results+)
                      command-matches)
                  truncated-p))))
    (let ((matches '())
          (truncated-p nil)
          (resolved-root (%normalized-search-root root)))
      (dolist (file (%search-target-files resolved-root))
        (let ((relative-path (%relative-match-path file resolved-root)))
          (when (%grep-path-allowed-p relative-path include-pattern exclude-pattern)
            (dolist (line (%file-match-lines file queries resolved-root))
              (if (< (length matches) +grep-tool-max-results+)
                  (push line matches)
                  (setf truncated-p t))))))
      (values (nreverse matches) truncated-p))))

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
         (queries (and request (getf request :queries)))
      (include-pattern (and request (getf request :include-pattern)))
      (exclude-pattern (and request (getf request :exclude-pattern)))
         (root (and request (getf request :root)))
         (resolved-root (%normalized-search-root root)))
    (unless request
      (error (%grep-tool-error "请求格式无效，期望 `grep <query>`、`grep <query-1> || <query-2>`、`search code for <query>` 或 `grep <query> :: <root>`")))
    (unless queries
      (error (%grep-tool-error "搜索词为空")))
    (unless (probe-file resolved-root)
      (error (%grep-tool-error (format nil "搜索根路径不存在: ~A" (%search-root-display root)))))
    (handler-case
        (multiple-value-bind (matches truncated-p)
            (%grep-tool-result-lines queries root
                                     :include-pattern include-pattern
                                     :exclude-pattern exclude-pattern)
          (%grep-tool-render-result matches truncated-p))
      (error ()
        (error (%grep-tool-error (format nil "无法搜索路径: ~A" (%search-root-display root))))))))