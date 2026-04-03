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

(defun %normalized-directory-list-input (input)
  (let ((text (and input (string-trim '(#\Space #\Tab #\Newline #\Return) (string input)))))
    (cond
      ((or (null text) (string= text "")) nil)
      (t (cl-cc.tools::%strip-input-prefix text +directory-list-input-prefixes+)))))

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

(defun %directory-entry-lines (path)
  (let* ((files (uiop:directory-files path))
         (directories (uiop:subdirectories path))
         (entries (sort (append files directories) #'%directory-entry<)))
    (if entries
        (mapcar #'%directory-entry-name entries)
        (list "(empty directory)"))))

(defun directory-list-tool (input)
  "列出指定目录的直接子项，并返回稳定文本结果。"
  (let ((path (%normalized-directory-list-input input)))
    (unless (and path (> (length path) 0))
      (error (%directory-list-tool-error "路径为空")))
    (unless (probe-file path)
      (error (%directory-list-tool-error (format nil "目录不存在: ~A" path))))
    (unless (uiop:directory-exists-p path)
      (error (%directory-list-tool-error (format nil "不是目录: ~A" path))))
    (handler-case
        (format nil "~{~A~^~%~}" (%directory-entry-lines path))
      (error ()
        (error (%directory-list-tool-error (format nil "无法列举目录: ~A" path)))))))