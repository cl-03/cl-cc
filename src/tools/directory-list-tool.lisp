;;;; src/tools/directory-list-tool.lisp - 只读目录列举工具
(in-package :cl-cc.tools)

(defun %directory-list-tool-message (detail)
  (format nil "目录列举失败: ~A" detail))

(defun %directory-list-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :directory-list-failed
                              (%directory-list-tool-message detail)))

(defparameter +directory-list-input-prefixes+
  '("list directory " "list dir " "show directory " "show folder " "ls " "dir "
    "列出目录" "查看目录" "列出文件夹" "查看文件夹")
  "允许 directory-list-tool 直接消费的自然语言前缀。")

(defparameter +directory-list-recursive-options+
  '("recursive" "递归")
  "directory-list-tool 在文本输入中支持的递归列举标记。")

(defparameter +directory-list-contains-option-prefixes+
  '("contains=" "contains " "包含=" "包含 ")
  "directory-list-tool 在文本输入中支持的子串过滤选项前缀。")

(defun %normalized-directory-list-input (input)
  (labels ((trim-text (value)
             (and value
                  (string-trim '(#\Space #\Tab #\Newline #\Return) (string value))))
           (positive-integer-or-nil (value)
             (cond
               ((integerp value)
                (and (> value 0) value))
               (t
                (let ((text (trim-text value)))
                  (when text
                    (let ((number (ignore-errors (parse-integer text :junk-allowed nil))))
                      (and number (> number 0) number)))))))
           (boolean-or-nil (value)
             (cond
               ((null value) nil)
               ((eq value t) t)
               ((stringp value)
                (let ((text (trim-text value)))
                  (when text
                    (cond
                      ((member text '("true" "yes" "1" "recursive" "递归") :test #'string-equal) t)
                      ((member text '("false" "no" "0") :test #'string-equal) nil)
                      (t :invalid)))))
               (t :invalid)))
           (non-empty-string-or-nil (value)
             (let ((text (trim-text value)))
               (and text
                    (> (length text) 0)
                    text)))
           (directory-list-request (path &key recursive depth contains force-plist)
             (let* ((normalized-path (trim-text path))
                    (normalized-depth (and depth (positive-integer-or-nil depth)))
                    (normalized-recursive (boolean-or-nil recursive))
                    (normalized-contains (and contains (non-empty-string-or-nil contains)))
                    (effective-recursive (or (eq normalized-recursive t)
                                             normalized-depth)))
               (when (and normalized-path
                          (> (length normalized-path) 0)
                          (or (null depth) normalized-depth)
                          (or (null contains) normalized-contains)
                          (not (eq normalized-recursive :invalid)))
                 (if (and (not force-plist)
                          (null effective-recursive)
                          (null normalized-depth)
                          (null normalized-contains))
                     normalized-path
                     (append (list :path normalized-path
                           :recursive (not (null effective-recursive))
                           :depth normalized-depth)
                         (and normalized-contains
                          (list :contains normalized-contains)))))))
           (split-double-colon-segments (text)
             (labels ((collect-segments (remaining collected)
                        (multiple-value-bind (head tail foundp)
                            (cl-cc.tools::%split-once remaining "::")
                          (if foundp
                              (collect-segments tail (cons head collected))
                              (nreverse (cons remaining collected))))))
               (mapcar #'trim-text (collect-segments text '()))))
           (depth-option-value (segment)
             (cond
               ((or (uiop:string-prefix-p "depth=" segment)
                    (uiop:string-prefix-p "depth " segment))
                (positive-integer-or-nil (subseq segment 6)))
               ((or (uiop:string-prefix-p "深度=" segment)
                    (uiop:string-prefix-p "深度 " segment))
                (positive-integer-or-nil (subseq segment 3)))
               (t nil)))
           (contains-option-value (segment)
             (loop for prefix in +directory-list-contains-option-prefixes+
                   when (uiop:string-prefix-p prefix segment)
                     do (return (non-empty-string-or-nil (subseq segment (length prefix))))))
           (parse-option-segments (segments)
             (let ((recursive nil)
                   (depth nil)
                   (contains nil))
               (dolist (segment segments)
                 (cond
                   ((or (null segment) (string= segment ""))
                    nil)
                   ((member segment +directory-list-recursive-options+ :test #'string-equal)
                    (setf recursive t))
                   ((or (uiop:string-prefix-p "recursive=" segment)
                        (uiop:string-prefix-p "递归=" segment))
                    (let ((flag (boolean-or-nil (subseq segment (1+ (position #\= segment))))))
                      (when (eq flag :invalid)
                        (return-from parse-option-segments nil))
                      (setf recursive (eq flag t))))
                   (t
                    (let ((parsed-depth (depth-option-value segment))
                          (parsed-contains (contains-option-value segment)))
                      (cond
                        (parsed-depth
                         (setf depth parsed-depth))
                        (parsed-contains
                         (setf contains parsed-contains))
                        (t
                          (return-from parse-option-segments nil)))))))
               (list :recursive recursive :depth depth :contains contains)))
           (parse-text-request (text)
             (let* ((stripped-text (cl-cc.tools::%strip-input-prefix text +directory-list-input-prefixes+))
                    (segments (split-double-colon-segments stripped-text))
                    (path (first segments))
                    (options (rest segments)))
               (cond
                 ((null options)
                  (directory-list-request path))
                 (t
                  (let ((parsed-options (parse-option-segments options)))
                    (when parsed-options
                      (directory-list-request path
                                              :recursive (getf parsed-options :recursive)
                                              :depth (getf parsed-options :depth)
                                              :contains (getf parsed-options :contains)
                                              :force-plist t))))))))
    (cond
      ((and (listp input)
            (or (getf input :path)
                (getf input :input)))
       (directory-list-request (or (getf input :path)
                                   (getf input :input))
                               :recursive (getf input :recursive)
                               :depth (getf input :depth)
                     :contains (or (getf input :contains)
                           (getf input :name-contains)
                           (getf input :nameContains))
                               :force-plist t))
      (t
       (let ((text (trim-text input)))
         (cond
           ((or (null text) (string= text "")) nil)
           (t (parse-text-request text))))))))

(defun %directory-entry-name (path)
  (let* ((pathname (pathname path))
         (directory-path (uiop:directory-pathname-p pathname))
         (name (file-namestring pathname)))
    (cond
      ((and name (> (length name) 0))
       name)
      (directory-path
       (let* ((directory-components (pathname-directory pathname))
              (last-component (car (last directory-components))))
         (if (or (null last-component)
                 (keywordp last-component))
             (namestring pathname)
             (format nil "~A/" last-component))))
      (t (namestring pathname)))))

(defun %directory-entry< (left right)
  (string-lessp (%directory-entry-name left)
                (%directory-entry-name right)))

(defun %directory-list-request-path (input)
  (if (listp input)
      (getf input :path)
      input))

(defun %directory-list-request-recursive-p (input)
  (and (listp input)
       (getf input :recursive)))

(defun %directory-list-request-depth (input)
  (and (listp input)
       (getf input :depth)))

(defun %directory-list-request-contains (input)
  (and (listp input)
       (getf input :contains)))

(defun %directory-entry-matches-contains-p (entry contains)
  (or (null contains)
      (search (cl-cc.lib:string-designator-downcase contains)
              (cl-cc.lib:string-designator-downcase entry)
              :test #'char=)))

(defun %directory-entry-lines (path &key recursive depth contains)
  (labels ((collect-entry-lines (directory prefix level)
             (let* ((files (sort (copy-list (uiop:directory-files directory))
                                 #'%directory-entry<))
                    (directories (sort (copy-list (uiop:subdirectories directory))
                                       #'%directory-entry<)))
               (append (loop for file in files
                             collect (format nil "~A~A" prefix (%directory-entry-name file)))
                       (loop for subdirectory in directories
                             for directory-name = (%directory-entry-name subdirectory)
                             for display-name = (format nil "~A~A" prefix directory-name)
                             append (append (list display-name)
                                            (when (and recursive
                                                       (or (null depth)
                                                           (< level depth)))
                                              (collect-entry-lines subdirectory display-name (1+ level))))))))
           (sorted-entry-lines (lines)
             (sort (copy-list lines) #'string-lessp)))
    (let* ((entries (if recursive
                        (sorted-entry-lines (collect-entry-lines path "" 1))
                        (sorted-entry-lines (collect-entry-lines path "" 0))))
           (filtered-entries (if contains
                                (remove-if-not (lambda (entry)
                                                 (%directory-entry-matches-contains-p entry contains))
                                               entries)
                                entries)))
      (if entries
          (if filtered-entries
              filtered-entries
              (list (if contains
                        "(no matching entries)"
                        "(empty directory)")))
          (list "(empty directory)")))))

(defun directory-list-tool (input)
  "列出指定目录的子项，并在请求时支持递归与深度限制。"
  (let* ((request (%normalized-directory-list-input input))
         (path (%directory-list-request-path request))
         (recursive (%directory-list-request-recursive-p request))
      (depth (%directory-list-request-depth request))
      (contains (%directory-list-request-contains request)))
    (unless (and path (> (length path) 0))
      (error (%directory-list-tool-error "路径为空")))
    (unless (probe-file path)
      (error (%directory-list-tool-error (format nil "目录不存在: ~A" path))))
    (unless (uiop:directory-exists-p path)
      (error (%directory-list-tool-error (format nil "不是目录: ~A" path))))
    (handler-case
        (format nil "~{~A~^~%~}" (%directory-entry-lines path :recursive recursive :depth depth :contains contains))
      (error ()
        (error (%directory-list-tool-error (format nil "无法列举目录: ~A" path)))))))