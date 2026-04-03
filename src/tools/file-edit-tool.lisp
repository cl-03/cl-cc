;;;; src/tools/file-edit-tool.lisp - 最小可用文件精确编辑工具
(in-package :cl-cc.tools)

(defun %file-edit-tool-message (detail)
  (format nil "文件编辑失败: ~A" detail))

(defun %file-edit-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :file-edit-failed
                              (%file-edit-tool-message detail)))

(defparameter +file-edit-input-prefixes+
  '("edit file " "replace in file " "replace text in file " "modify file "
    "编辑文件" "替换文件" "替换文件内容" "修改文件")
  "允许 file-edit-tool 直接消费的自然语言前缀。")

(defparameter +file-edit-preview-input-prefixes+
  '("preview edit file " "dry run edit file " "preview replace in file "
    "预览编辑文件" "试运行编辑文件" "预览替换文件")
  "允许 file-edit-tool 以预览模式消费的自然语言前缀。")

(defparameter +file-edit-preview-radius+ 20
  "生成替换前后预览片段时保留的上下文字符数。")

(defparameter +file-edit-preview-line-radius+ 1
  "生成行级 diff 预览时保留的上下文行数。")

(defun %valid-file-edit-occurrence-p (occurrence)
  (or (null occurrence)
      (and (integerp occurrence)
           (>= occurrence 1))))

(defun %file-edit-request (path old-text new-text &key preview occurrence)
  (list :path path
        :old-text old-text
        :new-text new-text
        :preview (not (null preview))
        :occurrence occurrence))

(defun %normalize-file-edit-request (path old-text new-text &key preview occurrence)
  (let ((normalized-path (and path (string-trim '(#\Space #\Tab #\Newline #\Return) (string path)))))
    (when (and normalized-path
               (> (length normalized-path) 0)
               (stringp old-text)
               (stringp new-text)
               (%valid-file-edit-occurrence-p occurrence))
      (%file-edit-request normalized-path old-text new-text :preview preview :occurrence occurrence))))

(defun %parse-file-edit-occurrence (text)
  (let ((trimmed (and text (string-trim '(#\Space #\Tab #\Newline #\Return) text))))
    (when (and trimmed
               (> (length trimmed) 0))
      (multiple-value-bind (value position)
          (parse-integer trimmed :junk-allowed t)
        (when (and value
                   position
                   (= position (length trimmed))
                   (>= value 1))
          value)))))

(defun %parse-file-edit-text (text &key preview)
  (multiple-value-bind (path remainder foundp)
      (%split-once text "::")
    (when foundp
      (multiple-value-bind (old-text new-text replacement-found-p)
          (%split-once remainder "::")
        (when replacement-found-p
          (multiple-value-bind (parsed-new-text occurrence-text occurrence-found-p)
              (%split-once new-text "::")
            (%normalize-file-edit-request path
                                          (string-right-trim '(#\Space #\Tab #\Newline #\Return)
                                                             old-text)
                                          (if occurrence-found-p parsed-new-text new-text)
                                          :preview preview
                                          :occurrence (and occurrence-found-p
                                                           (%parse-file-edit-occurrence occurrence-text)))))))))

(defun %parse-prefixed-file-edit-text (text)
  (let ((preview-text (%strip-input-prefix text +file-edit-preview-input-prefixes+))
        (edit-text (%strip-input-prefix text +file-edit-input-prefixes+)))
    (cond
      ((not (string= preview-text text))
       (%parse-file-edit-text preview-text :preview t))
      (t
       (%parse-file-edit-text edit-text :preview nil)))))

(defun %normalized-file-edit-input (input)
  (cond
    ((and (listp input)
          (getf input :path)
          (stringp (getf input :old-text))
          (stringp (getf input :new-text)))
     (%normalize-file-edit-request (getf input :path)
                                   (getf input :old-text)
                   (getf input :new-text)
                   :preview (getf input :preview)
                   :occurrence (getf input :occurrence)))
    (t
     (let ((text (and input (string-trim '(#\Space #\Tab #\Newline #\Return) (string input)))))
       (cond
         ((or (null text) (string= text "")) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-file-edit-input (subseq text (length "fixture-input-"))))
         (t (%parse-prefixed-file-edit-text text)))))))

(defun %exact-match-positions (needle haystack)
  (loop with start = 0
        for position = (search needle haystack :start2 start)
        while position
        collect position
        do (setf start (+ position (length needle)))))

(defun %select-file-edit-position (positions occurrence)
  (let ((total-matches (length positions)))
    (cond
      ((zerop total-matches)
       (error (%file-edit-tool-error "未找到待替换内容")))
      ((null occurrence)
       (if (> total-matches 1)
           (error (%file-edit-tool-error "待替换内容出现多次，请提供更精确的旧文本或指定 occurrence"))
           (values (first positions) total-matches 1)))
      ((> occurrence total-matches)
       (error (%file-edit-tool-error
               (format nil "指定 occurrence 超出范围: ~D（共 ~D 处匹配）" occurrence total-matches))))
      (t
       (values (nth (1- occurrence) positions) total-matches occurrence)))))

(defun %replace-at-position (contents position old-text new-text)
  (concatenate 'string
               (subseq contents 0 position)
               new-text
               (subseq contents (+ position (length old-text)))))

(defun %replace-single-occurrence (contents old-text new-text &key occurrence)
  (let ((positions (%exact-match-positions old-text contents)))
    (multiple-value-bind (position total-matches selected-occurrence)
        (%select-file-edit-position positions occurrence)
      (values (%replace-at-position contents position old-text new-text)
              position
              total-matches
              selected-occurrence))))

(defun %file-edit-selected-occurrence-message (occurrence total-matches)
  (if (> total-matches 1)
      (format nil " [第 ~D/~D 处命中]" occurrence total-matches)
      ""))

(defun %file-edit-success-message (path occurrence total-matches)
  (format nil "编辑文件: ~A~A"
          path
          (%file-edit-selected-occurrence-message occurrence total-matches)))

(defun %file-edit-preview-message (path old-text new-text occurrence total-matches)
  (format nil "预览编辑文件: ~A [替换 1 处: ~S -> ~S]~A"
          path old-text new-text
          (%file-edit-selected-occurrence-message occurrence total-matches)))

(defun %file-edit-snippet (contents start end)
  (let* ((snippet-start (max 0 (- start +file-edit-preview-radius+)))
         (snippet-end (min (length contents) (+ end +file-edit-preview-radius+))))
    (subseq contents snippet-start snippet-end)))

(defun %file-edit-line-and-column (contents position)
  (loop with line = 1
        with column = 1
        with index = 0
        while (< index position) do
          (let ((character (char contents index)))
            (cond
              ((char= character #\Return)
               (incf line)
               (setf column 1)
               (when (and (< (1+ index) position)
                          (< (1+ index) (length contents))
                          (char= (char contents (1+ index)) #\Newline))
                 (incf index)))
              ((char= character #\Newline)
               (incf line)
               (setf column 1))
              (t
               (incf column))))
          (incf index)
        finally (return (values line column))))

(defun %file-edit-position-metadata (contents start end)
  (multiple-value-bind (start-line start-column)
      (%file-edit-line-and-column contents start)
    (multiple-value-bind (end-line end-column)
        (%file-edit-line-and-column contents end)
      (list :match-start-line start-line
            :match-start-column start-column
            :match-end-line end-line
            :match-end-column end-column))))

(defun %file-edit-lines (contents)
  (loop with lines = '()
        with current = (make-string-output-stream)
        with index = 0
        while (< index (length contents)) do
          (let ((character (char contents index)))
            (cond
              ((char= character #\Return)
               (push (get-output-stream-string current) lines)
               (when (and (< (1+ index) (length contents))
                          (char= (char contents (1+ index)) #\Newline))
                 (incf index))
               (setf current (make-string-output-stream)))
              ((char= character #\Newline)
               (push (get-output-stream-string current) lines)
               (setf current (make-string-output-stream)))
              (t
               (write-char character current))))
          (incf index)
        finally
           (push (get-output-stream-string current) lines)
           (return (nreverse lines))))

(defun %file-edit-line-number-at-position (contents position)
  (nth-value 0 (%file-edit-line-and-column contents position)))

(defun %file-edit-line-span (contents start end)
  (let* ((safe-end (if (> end start) (1- end) start))
         (start-line (%file-edit-line-number-at-position contents start))
         (end-line (%file-edit-line-number-at-position contents safe-end)))
    (values start-line end-line)))

(defun %file-edit-line-window (line-count start-line end-line)
  (values (max 1 (- start-line +file-edit-preview-line-radius+))
          (min line-count (+ end-line +file-edit-preview-line-radius+))))

(defun %file-edit-format-line-preview-block (label lines changed-start changed-end)
  (multiple-value-bind (window-start window-end)
      (%file-edit-line-window (length lines) changed-start changed-end)
    (with-output-to-string (stream)
      (format stream "~A" label)
      (loop for line-number from window-start to window-end do
        (format stream "~%~A ~D| ~A"
                (if (<= changed-start line-number changed-end)
                    (if (string= label "before:") "-" "+")
                    " ")
                line-number
                (nth (1- line-number) lines))))))

(defun %file-edit-line-diff-preview (contents updated-contents position old-text new-text)
  (let* ((old-end (+ position (length old-text)))
         (new-end (+ position (length new-text)))
         (before-lines (%file-edit-lines contents))
         (after-lines (%file-edit-lines updated-contents)))
    (multiple-value-bind (old-start-line old-end-line)
        (%file-edit-line-span contents position old-end)
      (multiple-value-bind (new-start-line new-end-line)
          (%file-edit-line-span updated-contents position new-end)
        (format nil "@@ lines ~D..~D -> ~D..~D @@~%~A~%~A"
                old-start-line old-end-line new-start-line new-end-line
                (%file-edit-format-line-preview-block "before:" before-lines old-start-line old-end-line)
                (%file-edit-format-line-preview-block "after:" after-lines new-start-line new-end-line))))))

(defun %file-edit-diff-preview (contents updated-contents position old-text new-text)
  (let* ((old-end (+ position (length old-text)))
         (new-end (+ position (length new-text)))
         (before-snippet (%file-edit-snippet contents position old-end))
         (after-snippet (%file-edit-snippet updated-contents position new-end)))
    (format nil "@@ match ~D..~D @@~%-~A~%+~A"
            position old-end before-snippet after-snippet)))

(defun %file-edit-result-payload (path old-text new-text contents updated-contents position total-matches selected-occurrence &key preview)
  (let* ((old-end (+ position (length old-text)))
         (new-end (+ position (length new-text)))
         (summary (if preview
                      (%file-edit-preview-message path old-text new-text selected-occurrence total-matches)
                      (%file-edit-success-message path selected-occurrence total-matches))))
    (append (list :summary summary
      :path path
      :preview (not (null preview))
      :match-count 1
      :total-matches total-matches
      :selected-occurrence selected-occurrence
      :match-start position
      :match-end old-end)
    (%file-edit-position-metadata contents position old-end)
    (list :matched-text old-text
      :replacement-text new-text
      :before-preview (%file-edit-snippet contents position old-end)
      :after-preview (%file-edit-snippet updated-contents position new-end)
      :diff-preview (%file-edit-diff-preview contents updated-contents position old-text new-text)
      :line-diff-preview (%file-edit-line-diff-preview contents updated-contents position old-text new-text)
      :write-applied (not (null (not preview)))))))

(defun file-edit-tool (input)
  "精确替换指定文件中的单个文本片段并返回稳定摘要。"
  (let* ((request (%normalized-file-edit-input input))
         (path (and request (getf request :path)))
         (old-text (and request (getf request :old-text)))
         (new-text (and request (getf request :new-text)))
         (preview (not (null (and request (getf request :preview)))))
         (occurrence (and request (getf request :occurrence))))
    (unless request
      (error (%file-edit-tool-error "请求格式无效，期望 `edit file <path> :: <old-text> :: <new-text> [:: <occurrence>]` 或 `preview edit file <path> :: <old-text> :: <new-text> [:: <occurrence>]`")))
    (unless (and path (> (length path) 0))
      (error (%file-edit-tool-error "路径为空")))
    (unless (> (length old-text) 0)
      (error (%file-edit-tool-error "待替换内容为空")))
    (unless (probe-file path)
      (error (%file-edit-tool-error (format nil "文件不存在: ~A" path))))
    (handler-case
        (let* ((contents (uiop:read-file-string path))
               (updated-contents nil)
               (position nil)
               (total-matches nil)
               (selected-occurrence nil)
               (result-payload nil))
          (multiple-value-setq (updated-contents position total-matches selected-occurrence)
            (%replace-single-occurrence contents old-text new-text :occurrence occurrence))
          (setf result-payload (%file-edit-result-payload path
                                                          old-text
                                                          new-text
                                                          contents
                                                          updated-contents
                                                          position
                                                          total-matches
                                                          selected-occurrence
                                                          :preview preview))
          (unless preview
            (with-open-file (stream path
                                    :direction :output
                                    :if-exists :supersede
                                    :if-does-not-exist :create)
              (write-string updated-contents stream)))
          result-payload)
      (cl-cc.lib:cl-cc-error (condition)
        (error condition))
      (error ()
        (error (%file-edit-tool-error (format nil "无法编辑文件: ~A" path)))))))
