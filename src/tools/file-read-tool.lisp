;;;; src/tools/file-read-tool.lisp - 只读文件读取工具
(in-package :cl-cc.tools)

(defun %file-read-tool-message (detail)
  (format nil "文件读取失败: ~A" detail))

(defun %file-read-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :file-read-failed
                              (%file-read-tool-message detail)))

(defparameter +file-read-input-prefixes+
  '("read file " "open file " "show file " "cat " "读取文件" "打开文件" "查看文件" "显示文件")
  "允许 file-read-tool 直接消费的自然语言前缀。")

(defparameter +file-read-line-prefixes+
  '(" line " " lines ")
  "允许 file-read-tool 识别英文按行读取后缀。")

(defparameter +file-read-range-separator+ "-"
  "file-read-tool 在文本输入里使用的行范围分隔符。")

(defun %strip-input-prefix (text prefixes)
  (loop for prefix in prefixes
        when (uiop:string-prefix-p prefix text)
          do (return (string-trim '(#\Space #\Tab #\Newline #\Return)
                                  (subseq text (length prefix))))
        finally (return text)))

(defun %normalized-file-read-input (input)
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
           (line-range-request (start-line &key end-line)
             (let ((normalized-start (and start-line (positive-integer-or-nil start-line)))
                   (normalized-end (and end-line (positive-integer-or-nil end-line))))
               (when (and normalized-start
                          (or (null end-line) normalized-end)
                          (or (null normalized-end)
                              (<= normalized-start normalized-end)))
                 (list :start-line normalized-start
                       :end-line (or normalized-end normalized-start)))))
           (file-read-request (path &key start-line end-line)
             (let ((normalized-path (trim-text path))
                   (range-request (and start-line
                                       (line-range-request start-line :end-line end-line))))
               (when (and normalized-path
                          (> (length normalized-path) 0)
                          (or (null start-line) range-request))
                 (list :path normalized-path
                       :start-line (and range-request (getf range-request :start-line))
                       :end-line (and range-request (getf range-request :end-line))))))
           (parse-line-range (text)
             (multiple-value-bind (start end foundp)
                 (cl-cc.tools::%split-once text +file-read-range-separator+)
               (cond
                 (foundp
                  (line-range-request start :end-line end))
                 (t
                  (line-range-request text)))))
           (merge-path-and-range (path range-request)
             (when range-request
               (file-read-request path
                                  :start-line (getf range-request :start-line)
                                  :end-line (getf range-request :end-line))))
           (parse-double-colon-request (text)
             (multiple-value-bind (path range foundp)
                 (cl-cc.tools::%split-once text "::")
               (cond
                 (foundp
                  (let ((trimmed-range (trim-text range)))
                    (if (or (null trimmed-range)
                            (string= trimmed-range ""))
                        (file-read-request path)
                        (merge-path-and-range path (parse-line-range trimmed-range)))))
                 (t nil))))
           (parse-inline-range-request (text)
             (let ((last-colon (position #\: text :from-end t)))
               (when last-colon
                 (let ((path (subseq text 0 last-colon))
                       (suffix (subseq text (1+ last-colon))))
                   (or (merge-path-and-range path (parse-line-range suffix))
                       (let ((previous-colon (position #\: text :from-end t :end last-colon)))
                         (when previous-colon
                           (let ((grep-path (subseq text 0 previous-colon))
                                 (line-number (subseq text (1+ previous-colon) last-colon)))
                             (merge-path-and-range grep-path (parse-line-range line-number))))))))))
           (parse-english-line-request (text)
             (loop for prefix in +file-read-line-prefixes+
                   for position = (search prefix text :test #'char-equal)
                   when position
                     do (return (merge-path-and-range (subseq text 0 position)
                                                      (parse-line-range (subseq text (+ position (length prefix))))))))
           (parse-chinese-line-request (text)
             (let ((marker (search "第" text :test #'char-equal))
                   (line-suffix (position #\行 text :from-end t)))
               (when (and marker line-suffix (< marker line-suffix))
                 (merge-path-and-range (subseq text 0 marker)
                                       (parse-line-range (subseq text (1+ marker) line-suffix))))))
           (parse-text-request (text)
             (let ((stripped-text (%strip-input-prefix text +file-read-input-prefixes+)))
               (cond
                 ((search "::" stripped-text :test #'char-equal)
                  (parse-double-colon-request stripped-text))
                 (t
                  (or (parse-english-line-request stripped-text)
                      (parse-chinese-line-request stripped-text)
                      (parse-inline-range-request stripped-text)
                      (file-read-request stripped-text)))))))
    (cond
      ((and (listp input)
            (getf input :path))
       (file-read-request (getf input :path)
                          :start-line (getf input :start-line)
                          :end-line (getf input :end-line)))
      (t
       (let ((text (trim-text input)))
         (cond
           ((or (null text) (string= text "")) nil)
           ((search "fixture-input-" text :test #'char-equal)
            (%normalized-file-read-input (subseq text (length "fixture-input-"))))
           (t (parse-text-request text))))))))

(defun %normalized-file-read-lines (contents)
  (with-output-to-string (stream)
    (loop for index from 0 below (length contents)
          for character = (char contents index)
          do (cond
               ((char= character #\Return)
                (write-char #\Newline stream)
                (when (and (< (1+ index) (length contents))
                           (char= (char contents (1+ index)) #\Newline))
                  (incf index)))
               (t
                 (write-char character stream))))))

(defun %file-read-line-contents (contents start-line end-line)
  (let* ((lines (uiop:split-string (%normalized-file-read-lines contents) :separator '(#\Newline)))
         (total-lines (length lines))
         (resolved-start (or start-line 1))
         (resolved-end (min (or end-line resolved-start) total-lines)))
    (when (or (= total-lines 0)
              (> resolved-start total-lines))
      (error (%file-read-tool-error (format nil "请求的起始行超出文件范围: ~D" resolved-start))))
    (format nil "~{~A~^~%~}"
            (loop for line-number from resolved-start to resolved-end
                  collect (format nil "~D:~A"
                                  line-number
                                  (nth (1- line-number) lines))))))

(defun file-read-tool (input)
  "读取指定文件并返回其文本内容。"
  (let* ((request (%normalized-file-read-input input))
         (path (and request (if (listp request) (getf request :path) request)))
         (start-line (and (listp request) (getf request :start-line)))
         (end-line (and (listp request) (getf request :end-line))))
    (unless request
   (error (%file-read-tool-error
        (if (or (null input)
          (and (stringp input)
            (string= (string-trim '(#\Space #\Tab #\Newline #\Return) input) ""))
          (and (listp input)
            (getf input :path)
            (stringp (getf input :path))
            (string= (string-trim '(#\Space #\Tab #\Newline #\Return) (getf input :path)) "")))
         "路径为空"
         "请求格式无效，期望 `<path>`、`<path>:<line>`、`<path>:<start>-<end>` 或 `read file <path> :: <start>-<end>`"))))
    (unless (probe-file path)
      (error (%file-read-tool-error (format nil "文件不存在: ~A" path))))
    (handler-case
        (let ((contents (uiop:read-file-string path)))
          (if start-line
              (%file-read-line-contents contents start-line end-line)
              contents))
      (cl-cc.lib:cl-cc-error (condition)
        (error condition))
      (error ()
        (error (%file-read-tool-error (format nil "无法读取文件: ~A" path)))))))