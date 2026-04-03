;;;; src/tools/file-write-tool.lisp - 最小可用文件写入工具
(in-package :cl-cc.tools)

(defun %file-write-tool-message (detail)
  (format nil "文件写入失败: ~A" detail))

(defun %file-write-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :file-write-failed
                              (%file-write-tool-message detail)))

(defparameter +file-write-input-prefixes+
  '("write file " "save file " "create file " "update file "
    "写入文件" "保存文件" "创建文件" "更新文件")
  "允许 file-write-tool 直接消费的自然语言前缀。")

(defparameter +file-append-input-prefixes+
  '("append file " "append to file " "追加写入文件" "追加文件")
  "允许 file-write-tool 以追加模式消费的自然语言前缀。")

(defun %split-once (text delimiter)
  (let ((position (search delimiter text :test #'char-equal)))
    (when position
      (values (subseq text 0 position)
              (subseq text (+ position (length delimiter)))
              t))))

(defun %file-write-request (path content &key (mode :overwrite))
  (list :path path :content content :mode mode))

(defun %normalize-file-write-request (path content &key (mode :overwrite))
  (let ((normalized-path (and path (string-trim '(#\Space #\Tab #\Newline #\Return) (string path)))))
    (when (and normalized-path
               (> (length normalized-path) 0)
               (stringp content))
      (%file-write-request normalized-path content :mode mode))))

(defun %parse-file-write-text (text &key (mode :overwrite))
  (multiple-value-bind (path content foundp)
      (%split-once text "::")
    (cond
      (foundp
       (%normalize-file-write-request path content :mode mode))
      ((search (string #\Newline) text)
       (multiple-value-bind (line-path line-content line-found-p)
           (%split-once text (string #\Newline))
         (and line-found-p
              (%normalize-file-write-request line-path line-content :mode mode))))
      (t nil))))

(defun %parse-prefixed-file-write-text (text)
  (let ((append-text (%strip-input-prefix text +file-append-input-prefixes+))
        (write-text (%strip-input-prefix text +file-write-input-prefixes+)))
    (cond
      ((not (string= append-text text))
       (%parse-file-write-text append-text :mode :append))
      ((not (string= write-text text))
       (%parse-file-write-text write-text :mode :overwrite))
      (t
       (%parse-file-write-text text :mode :overwrite)))))

(defun %normalized-file-write-input (input)
  (cond
    ((and (listp input)
          (getf input :path)
          (stringp (getf input :content)))
     (%normalize-file-write-request (getf input :path)
                                    (getf input :content)
                                    :mode (or (getf input :mode) :overwrite)))
    (t
     (let ((text (and input (string-trim '(#\Space #\Tab #\Newline #\Return) (string input)))))
       (cond
         ((or (null text) (string= text "")) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-file-write-input (subseq text (length "fixture-input-"))))
         (t (%parse-prefixed-file-write-text text)))))))

(defun %file-write-success-message (path mode)
  (if (eq mode :append)
      (format nil "追加写入文件: ~A" path)
      (format nil "写入文件: ~A" path)))

(defun file-write-tool (input)
  "写入指定文件并返回稳定摘要。"
  (let* ((request (%normalized-file-write-input input))
         (path (and request (getf request :path)))
         (content (and request (getf request :content)))
         (mode (or (and request (getf request :mode)) :overwrite)))
    (unless request
      (error (%file-write-tool-error "请求格式无效，期望 `write file <path> :: <content>` 或 `append file <path> :: <content>`")))
    (unless (and path (> (length path) 0))
      (error (%file-write-tool-error "路径为空")))
    (unless content
      (error (%file-write-tool-error "内容为空")))
    (handler-case
        (progn
          (ensure-directories-exist path)
          (with-open-file (stream path
                                  :direction :output
                                  :if-exists (if (eq mode :append) :append :supersede)
                                  :if-does-not-exist :create)
            (write-string content stream))
          (%file-write-success-message path mode))
      (error ()
        (error (%file-write-tool-error (format nil "无法写入文件: ~A" path)))))))