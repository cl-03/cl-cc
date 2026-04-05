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

(defparameter +file-read-multi-range-separators+
  '(#\, #\;)
  "file-read-tool 在文本输入里支持的多段行范围分隔符。")

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
           (normalized-range-list (ranges)
             (when ranges
               (loop for range in ranges
                     for normalized-range = (cond
                                              ((and (listp range)
                                                    (or (getf range :start-line)
                                                        (getf range :startLine)))
                                               (line-range-request (or (getf range :start-line)
                                                                       (getf range :startLine))
                                                                   :end-line (or (getf range :end-line)
                                                                                  (getf range :endLine))))
                                              (t nil))
                     when normalized-range
                       collect normalized-range
                     else
                       do (return nil))))
           (file-read-request (path &key start-line end-line ranges)
             (let ((normalized-path (trim-text path))
                   (single-range (and start-line
                                      (line-range-request start-line :end-line end-line)))
                   (multiple-ranges (normalized-range-list ranges)))
               (when (and normalized-path
                          (> (length normalized-path) 0)
                          (or (null start-line) single-range)
                          (or (null ranges) multiple-ranges))
                 (let ((all-ranges (append (and single-range (list single-range)) multiple-ranges)))
                   (if (and all-ranges (> (length all-ranges) 1))
                       (list :path normalized-path
                             :start-line nil
                             :end-line nil
                             :ranges all-ranges)
                       (let ((range-request (first all-ranges)))
                         (list :path normalized-path
                               :start-line (and range-request (getf range-request :start-line))
                       :end-line (and range-request (getf range-request :end-line)))))))))
           (parse-line-range (text)
             (multiple-value-bind (start end foundp)
                 (cl-cc.tools::%split-once text +file-read-range-separator+)
               (cond
                 (foundp
                  (line-range-request start :end-line end))
                 (t
                  (line-range-request text)))))
           (parse-line-range-spec (text)
             (let* ((segments (remove nil
                                      (mapcar #'trim-text
                                              (uiop:split-string text :separator +file-read-multi-range-separators+))))
                    (ranges (and segments
                                 (loop for segment in segments
                                       for range-request = (parse-line-range segment)
                                       when range-request
                                         collect range-request
                                       else
                                         do (return nil)))))
               (and ranges (> (length ranges) 0) ranges)))
           (merge-path-and-ranges (path range-requests)
             (when range-requests
               (file-read-request path :ranges range-requests)))
           (parse-double-colon-request (text)
             (multiple-value-bind (path range foundp)
                 (cl-cc.tools::%split-once text "::")
               (cond
                 (foundp
                  (let ((trimmed-range (trim-text range)))
                    (if (or (null trimmed-range)
                            (string= trimmed-range ""))
                        (file-read-request path)
                        (merge-path-and-ranges path (parse-line-range-spec trimmed-range)))))
                 (t nil))))
           (parse-inline-range-request (text)
             (let ((last-colon (position #\: text :from-end t)))
               (when last-colon
                 (let ((path (subseq text 0 last-colon))
                       (suffix (subseq text (1+ last-colon))))
                   (or (merge-path-and-ranges path (parse-line-range-spec suffix))
                       (let ((previous-colon (position #\: text :from-end t :end last-colon)))
                         (when previous-colon
                           (let ((grep-path (subseq text 0 previous-colon))
                                 (line-number (subseq text (1+ previous-colon) last-colon)))
                             (merge-path-and-ranges grep-path (parse-line-range-spec line-number))))))))))
           (parse-english-line-request (text)
             (loop for prefix in +file-read-line-prefixes+
                   for position = (search prefix text :test #'char-equal)
                   when position
                     do (return (merge-path-and-ranges (subseq text 0 position)
                                                       (parse-line-range-spec (subseq text (+ position (length prefix))))))))
           (parse-chinese-line-request (text)
             (let ((marker (search "第" text :test #'char-equal))
                   (line-suffix (position #\行 text :from-end t)))
               (when (and marker line-suffix (< marker line-suffix))
                 (merge-path-and-ranges (subseq text 0 marker)
                                        (parse-line-range-spec (subseq text (1+ marker) line-suffix))))))
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
                          :end-line (getf input :end-line)
                          :ranges (or (getf input :ranges)
                                      (getf input :line-ranges)
                                      (getf input :lineRanges))))
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

(defun %file-read-multi-range-contents (contents ranges)
  (let* ((lines (uiop:split-string (%normalized-file-read-lines contents) :separator '(#\Newline)))
         (total-lines (length lines))
         (emitted-lines '())
         (seen-line-numbers (make-hash-table :test #'eql)))
    (when (= total-lines 0)
      (error (%file-read-tool-error "请求的起始行超出文件范围: 1")))
    (dolist (range ranges)
      (let ((start-line (getf range :start-line))
            (end-line (getf range :end-line)))
        (when (> start-line total-lines)
          (error (%file-read-tool-error (format nil "请求的起始行超出文件范围: ~D" start-line))))
        (loop for line-number from start-line to (min end-line total-lines)
              unless (gethash line-number seen-line-numbers)
                do (setf (gethash line-number seen-line-numbers) t)
                   (push (format nil "~D:~A"
                                 line-number
                                 (nth (1- line-number) lines))
                         emitted-lines))))
    (format nil "~{~A~^~%~}" (nreverse emitted-lines))))

(defun file-read-tool (input)
  "读取指定文件并返回其文本内容。"
  (let* ((request (%normalized-file-read-input input))
         (path (and request (if (listp request) (getf request :path) request)))
         (start-line (and (listp request) (getf request :start-line)))
         (end-line (and (listp request) (getf request :end-line)))
         (ranges (and (listp request) (getf request :ranges))))
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
         "请求格式无效，期望 `<path>`、`<path>:<line>`、`<path>:<start>-<end>`、`<path>:<start>-<end>,<line>` 或 `read file <path> :: <ranges>`"))))
    (unless (probe-file path)
      (error (%file-read-tool-error (format nil "文件不存在: ~A" path))))
    (handler-case
        (let ((contents (uiop:read-file-string path)))
          (if ranges
              (%file-read-multi-range-contents contents ranges)
              (if start-line
              (%file-read-line-contents contents start-line end-line)
                  contents)))
      (cl-cc.lib:cl-cc-error (condition)
        (error condition))
      (error ()
        (error (%file-read-tool-error (format nil "无法读取文件: ~A" path)))))))