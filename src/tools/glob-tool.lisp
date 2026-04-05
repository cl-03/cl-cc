;;;; src/tools/glob-tool.lisp - 只读文件 glob 匹配工具
(in-package :cl-cc.tools)

(defparameter +glob-tool-input-prefixes+
  '("glob " "find files " "search files " "match files "
    "查找文件 " "搜索文件 " "列出匹配文件 ")
  "允许 glob-tool 直接消费的自然语言前缀。")

(defparameter +glob-tool-max-results+ 100
  "glob-tool 返回的最大匹配条数，避免一次结果过长。")

(defun %glob-tool-message (detail)
  (format nil "文件匹配失败: ~A" detail))

(defun %glob-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :glob-search-failed
                              (%glob-tool-message detail)))

(defun %glob-request (pattern &key root)
  (list :pattern pattern :root root))

(defun %normalize-glob-request (pattern &key root)
  (let ((normalized-pattern (%normalize-grep-string pattern))
        (normalized-root (%normalize-grep-string root)))
    (when normalized-pattern
      (%glob-request normalized-pattern :root normalized-root))))

(defun %parse-glob-text (text)
  (multiple-value-bind (pattern root foundp)
      (%split-once text "::")
    (if foundp
        (%normalize-glob-request pattern :root root)
        (%normalize-glob-request text))))

(defun %parse-prefixed-glob-text (text)
  (%parse-glob-text (%strip-input-prefix text +glob-tool-input-prefixes+)))

(defun %normalized-glob-input (input)
  (cond
    ((and (listp input)
          (getf input :pattern))
     (%normalize-glob-request (getf input :pattern)
                              :root (getf input :root)))
    (t
     (let ((text (%normalize-grep-string input)))
       (cond
         ((null text) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-glob-input (subseq text (length "fixture-input-"))))
         (t (%parse-prefixed-glob-text text)))))))

(defun %glob-pattern-regex (pattern)
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

(defun %glob-pattern-matches-p (pattern relative-path)
  (let ((scanner (cl-ppcre:create-scanner (%glob-pattern-regex pattern))))
    (cl-ppcre:scan scanner (substitute #\/ #\\ relative-path))))

(defun %glob-tool-result-paths (pattern root)
  (let* ((resolved-root (%normalized-search-root root))
         (matches (sort (loop for file in (%search-target-files resolved-root)
                              for relative-path = (%relative-match-path file resolved-root)
                              when (%glob-pattern-matches-p pattern relative-path)
                                collect relative-path)
                        #'string<))
         (match-count (length matches))
         (truncated-p (> match-count +glob-tool-max-results+)))
    (values (if truncated-p
                (subseq matches 0 +glob-tool-max-results+)
                matches)
            truncated-p)))

(defun %glob-tool-render-result (matches truncated-p)
  (cond
    ((null matches) "(no matches)")
    (truncated-p
     (format nil "~{~A~^~%~}~%... (truncated to ~D matches)"
             matches
             +glob-tool-max-results+))
    (t
     (format nil "~{~A~^~%~}" matches))))

(defun glob-tool (input)
  "在目录树或单个文件下按 glob 模式匹配文件，并返回稳定文本结果。"
  (let* ((request (%normalized-glob-input input))
         (pattern (and request (getf request :pattern)))
         (root (and request (getf request :root)))
         (resolved-root (%normalized-search-root root)))
    (unless request
      (error (%glob-tool-error "请求格式无效，期望 `glob <pattern>` 或 `glob <pattern> :: <root>`")))
    (unless pattern
      (error (%glob-tool-error "glob 模式为空")))
    (unless (probe-file resolved-root)
      (error (%glob-tool-error (format nil "搜索根路径不存在: ~A" (%search-root-display root)))))
    (handler-case
        (multiple-value-bind (matches truncated-p)
            (%glob-tool-result-paths pattern root)
          (%glob-tool-render-result matches truncated-p))
      (error ()
        (error (%glob-tool-error (format nil "无法匹配路径: ~A" (%search-root-display root))))))))