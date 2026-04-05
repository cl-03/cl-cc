;;;; src/tools/file-edit-tool.lisp - 最小可用文件精确编辑工具
(in-package :cl-cc.tools)

(defun %file-edit-tool-message (detail)
  (format nil "文件编辑失败: ~A" detail))

(defun %file-edit-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :file-edit-failed
                              (%file-edit-tool-message detail)))

(defun %file-edit-basic-prefixes (english-prefixes chinese-prefixes)
  (append english-prefixes chinese-prefixes))

(defun %file-edit-mode (&key preview use-regex line-context)
  (append (list :preview preview
                :use-regex use-regex)
          (when line-context
            (list :line-context line-context))))

(defun %copy-file-edit-mode (mode)
  (copy-list mode))

(defun %file-edit-mode-with-line-context (mode line-context)
  (%file-edit-mode :preview (getf mode :preview)
                   :use-regex (getf mode :use-regex)
                   :line-context line-context))

(defparameter +file-edit-basic-mode-specs+
  (list (list :prefixes (%file-edit-basic-prefixes
                         '("preview regex edit file " "dry run regex edit file " "preview regex replace in file ")
                         '("预览正则编辑文件" "试运行正则编辑文件" "预览正则替换文件"))
              :mode (%file-edit-mode :preview t :use-regex t))
        (list :prefixes (%file-edit-basic-prefixes
                         '("regex edit file " "regex replace in file ")
                         '("正则编辑文件" "正则替换文件"))
              :mode (%file-edit-mode :preview nil :use-regex t))
        (list :prefixes (%file-edit-basic-prefixes
                         '("preview edit file " "dry run edit file " "preview replace in file ")
                         '("预览编辑文件" "试运行编辑文件" "预览替换文件"))
              :mode (%file-edit-mode :preview t :use-regex nil))
        (list :prefixes (%file-edit-basic-prefixes
                         '("edit file " "replace in file " "replace text in file " "modify file ")
                         '("编辑文件" "替换文件" "替换文件内容" "修改文件"))
              :mode (%file-edit-mode :preview nil :use-regex nil)))
  "file-edit-tool 基础自然语言入口与模式映射。")

(defparameter +file-edit-preview-radius+ 20
  "生成替换前后预览片段时保留的上下文字符数。")

(defparameter +file-edit-preview-line-radius+ 1
  "生成行级 diff 预览时保留的上下文行数。")

(defparameter +file-edit-trim-characters+
  '(#\Space #\Tab #\Newline #\Return)
  "file-edit-tool 在解析自然语言输入时统一裁剪的空白字符集。")

(defun %file-edit-line-context-prefix-patterns (english-prefixes chinese-prefixes)
  (append (loop for prefix in english-prefixes
        append (list (list :prefix prefix :suffix " edit file ")
             (list :prefix prefix :suffix " replace in file ")))
      (loop for prefix in chinese-prefixes
        append (list (list :prefix prefix :suffix "行编辑文件")
             (list :prefix prefix :suffix "行替换文件")))))

(defparameter +file-edit-line-context-mode-specs+
  (list (list :patterns (%file-edit-line-context-prefix-patterns '("preview regex context " "preview regex line context ")
                      '("预览正则上下文"))
      :mode (%file-edit-mode :preview t :use-regex t))
    (list :patterns (%file-edit-line-context-prefix-patterns '("regex context " "regex line context ")
                      '("正则上下文"))
      :mode (%file-edit-mode :preview nil :use-regex t))
    (list :patterns (%file-edit-line-context-prefix-patterns '("preview context " "preview line context ")
                      '("预览上下文"))
      :mode (%file-edit-mode :preview t :use-regex nil))
    (list :patterns (%file-edit-line-context-prefix-patterns '("context " "line context ")
                      '("上下文"))
      :mode (%file-edit-mode :preview nil :use-regex nil)))
  "file-edit-tool 参数化 lineContext 自然语言模式映射。")

(defun %file-edit-combinable-base-prefixes (english-prefixes chinese-prefixes &key fallback-prefixes use-regex)
  (append (loop for prefix in english-prefixes
                collect (list :prefix prefix :mode (%file-edit-mode :preview t :use-regex use-regex)))
      (loop for prefix in fallback-prefixes
        collect (list :prefix prefix :mode (%file-edit-mode :preview nil :use-regex use-regex)))
          (loop for prefix in chinese-prefixes
                collect (list :prefix prefix :mode (%file-edit-mode :preview t :use-regex use-regex)))
      (unless fallback-prefixes
            (list (list :prefix "" :mode (%file-edit-mode :preview nil :use-regex use-regex))))))

(defparameter +file-edit-standard-action-suffixes+
  '("edit file " "replace in file " "编辑文件" "替换文件")
  "file-edit-tool 组合解析器共享的文件编辑动作后缀。")

(defparameter +file-edit-combinable-replace-all-compatibility-action-suffixes+
  '("in file " "text in file " "matches in file " "文件" "替换文件全部命中" "替换文件所有命中")
  "组合解析器在 replaceAll 已命中时允许的 legacy 动作后缀。")

(defparameter +file-edit-combinable-flag-mode-keys+
  '(:ignore-case :replace-all :multiline :dot-all :whole-word :left-word-boundary :right-word-boundary)
  "组合解析器从命中的 flag spec 同步到 mode plist 的字段列表。")

(defparameter +file-edit-shared-combinable-flag-specs+
  (list (list :prefixes '("ignore case " "case insensitive " "忽略大小写")
      :ignore-case t)
    (list :prefixes '("whole word " "整词")
      :whole-word t)
    (list :prefixes '("left word boundary " "left boundary " "左边界")
      :left-word-boundary t)
    (list :prefixes '("right word boundary " "right boundary " "右边界")
      :right-word-boundary t))
  "plain/regex 组合解析器共享的自然语言标志前缀。")

(defun %file-edit-combinable-flag-specs (replace-all-prefixes &optional extra-specs)
  (append (list (list :prefixes replace-all-prefixes
          :replace-all t))
      extra-specs
      +file-edit-shared-combinable-flag-specs+))

(defparameter +file-edit-combinable-plain-flag-specs+
  (%file-edit-combinable-flag-specs '("replace all " "replace all text " "replace all matches " "全部替换"))
  "组合非 regex flags 解析器支持的标志前缀。")

(defparameter +file-edit-combinable-regex-flag-specs+
  (%file-edit-combinable-flag-specs
   '("replace all " "replace all matches " "全部替换")
   (list (list :prefixes '("multiline " "多行模式" "多行")
       :multiline t)
     (list :prefixes '("dot all " "dotall " "点号跨行" "跨行")
       :dot-all t)))
  "组合 regex flags 解析器支持的标志前缀。")

(defparameter +file-edit-combinable-mode-specs+
  (list (list :base-prefixes (%file-edit-combinable-base-prefixes
                              '("preview regex " "dry run regex ")
                              '("预览正则" "试运行正则")
                              :fallback-prefixes '("regex " "正则")
                              :use-regex t)
              :flag-specs +file-edit-combinable-regex-flag-specs+)
        (list :base-prefixes (%file-edit-combinable-base-prefixes
                              '("preview " "dry run ")
                              '("预览" "试运行")
                              :use-regex nil)
              :flag-specs +file-edit-combinable-plain-flag-specs+))
  "file-edit-tool 组合 natural-language mode 的统一规格。")

(defun %valid-file-edit-occurrence-p (occurrence)
  (or (null occurrence)
      (and (integerp occurrence)
           (>= occurrence 1))))

(defun %valid-file-edit-line-context-p (line-context)
  (or (null line-context)
      (and (integerp line-context)
           (>= line-context 0))))

(defun %valid-file-edit-boolean-option-p (value)
  (or (null value)
      (typep value 'boolean)))

(defun %file-edit-request (path old-text new-text &key preview occurrence line-context replace-all ignore-case use-regex multiline dot-all whole-word left-word-boundary right-word-boundary)
  (append (list :path path
                :old-text old-text
                :new-text new-text
                :preview (not (null preview))
                :occurrence occurrence
                :line-context line-context
                :ignore-case (not (null ignore-case))
                :whole-word (not (null whole-word))
                :left-word-boundary (not (null left-word-boundary))
                :right-word-boundary (not (null right-word-boundary)))
          (when use-regex
            (list :use-regex t))
          (when multiline
            (list :multiline t))
          (when dot-all
            (list :dot-all t))
          (when replace-all
            (list :replace-all t))))

(defun %normalize-file-edit-request (path old-text new-text &key preview occurrence line-context replace-all ignore-case use-regex multiline dot-all whole-word left-word-boundary right-word-boundary)
  (let ((normalized-path (and path (string-trim +file-edit-trim-characters+ (string path)))))
    (when (and normalized-path
               (> (length normalized-path) 0)
               (stringp old-text)
               (stringp new-text)
               (%valid-file-edit-occurrence-p occurrence)
               (%valid-file-edit-line-context-p line-context)
               (%valid-file-edit-boolean-option-p replace-all)
               (%valid-file-edit-boolean-option-p ignore-case)
               (%valid-file-edit-boolean-option-p use-regex)
               (%valid-file-edit-boolean-option-p multiline)
               (%valid-file-edit-boolean-option-p dot-all)
               (%valid-file-edit-boolean-option-p whole-word)
               (%valid-file-edit-boolean-option-p left-word-boundary)
               (%valid-file-edit-boolean-option-p right-word-boundary))
      (%file-edit-request normalized-path old-text new-text
                          :preview preview
                          :occurrence occurrence
                          :line-context line-context
                          :replace-all replace-all
                          :ignore-case ignore-case
                          :use-regex use-regex
                          :multiline multiline
                          :dot-all dot-all
                          :whole-word whole-word
                          :left-word-boundary left-word-boundary
                          :right-word-boundary right-word-boundary))))

(defun %parse-file-edit-occurrence (text)
  (let ((trimmed (and text (string-trim +file-edit-trim-characters+ text))))
    (when (and trimmed
               (> (length trimmed) 0))
      (multiple-value-bind (value position)
          (parse-integer trimmed :junk-allowed t)
        (when (and value
                   position
                   (= position (length trimmed))
                   (>= value 1))
          value)))))

(defun %parse-file-edit-text (text &key preview occurrence line-context replace-all use-regex ignore-case multiline dot-all whole-word left-word-boundary right-word-boundary)
  (multiple-value-bind (path remainder foundp)
      (%split-once text "::")
    (when foundp
      (multiple-value-bind (old-text new-text replacement-found-p)
          (%split-once remainder "::")
        (when replacement-found-p
          (multiple-value-bind (parsed-new-text occurrence-text occurrence-found-p)
              (%split-once new-text "::")
            (%normalize-file-edit-request path
                                          (string-right-trim +file-edit-trim-characters+
                                                             old-text)
                                          (if occurrence-found-p parsed-new-text new-text)
                                          :preview preview
                                             :occurrence (or occurrence
                                                   (and occurrence-found-p
                                                     (%parse-file-edit-occurrence occurrence-text)))
                                           :line-context line-context
                                           :replace-all replace-all
                                             :ignore-case ignore-case
                                           :use-regex use-regex
                                           :multiline multiline
                                           :dot-all dot-all
                                           :whole-word whole-word
                                           :left-word-boundary left-word-boundary
                                           :right-word-boundary right-word-boundary)))))))

(defun %parse-file-edit-parameterized-prefix (text patterns)
  (loop for pattern in patterns
        for prefix = (getf pattern :prefix)
        for suffix = (getf pattern :suffix)
        when (uiop:string-prefix-p prefix text)
          do (let* ((remainder (subseq text (length prefix)))
                    (suffix-position (search suffix remainder :test #'char-equal)))
               (when suffix-position
                 (let* ((number-text (string-trim +file-edit-trim-characters+
                                                  (subseq remainder 0 suffix-position)))
                        (line-context (ignore-errors (parse-integer number-text :junk-allowed nil))))
                   (when (%valid-file-edit-line-context-p line-context)
                     (return (values (concatenate 'string
                                                 (subseq remainder (+ suffix-position (length suffix))))
                                     line-context))))))
        finally (return (values nil nil))))

(defun %parse-parameterized-file-edit-natural-language-mode (text)
  (loop for spec in +file-edit-line-context-mode-specs+
        do (multiple-value-bind (stripped-text line-context)
               (%parse-file-edit-parameterized-prefix text (getf spec :patterns))
             (when stripped-text
               (return (values stripped-text
                               (%file-edit-mode-with-line-context (getf spec :mode)
                                                                  line-context)))))
        finally (return (values nil nil))))

(defun %parse-file-edit-prefixed-spec (text specs)
  (loop for spec in specs
        for stripped-text = (%strip-input-prefix text (getf spec :prefixes))
        unless (string= stripped-text text)
          do (return (values stripped-text spec))
        finally (return (values nil nil))))

(defun %parse-file-edit-combinable-flag (text flag-specs)
  (%parse-file-edit-prefixed-spec text flag-specs))

(defun %apply-file-edit-flag-spec-to-mode (mode flag-spec)
  (dolist (key +file-edit-combinable-flag-mode-keys+ mode)
    (when (getf flag-spec key)
      (setf (getf mode key) t))))

(defun %parse-file-edit-combinable-mode (text base-prefixes flag-specs action-suffixes &key replace-all-compatibility-action-suffixes)
  (loop for base in base-prefixes
        for base-prefix = (getf base :prefix)
        when (uiop:string-prefix-p base-prefix text)
          do (let ((remainder (subseq text (length base-prefix)))
                   (mode (%copy-file-edit-mode (getf base :mode)))
                   (matched-flag-p nil))
               (loop
                 do (multiple-value-bind (stripped-text flag-spec)
                        (%parse-file-edit-combinable-flag remainder flag-specs)
                      (if stripped-text
                          (progn
                            (setf remainder stripped-text
                                  matched-flag-p t)
                            (setf mode (%apply-file-edit-flag-spec-to-mode mode flag-spec)))
                          (return))))
               (when matched-flag-p
                 (let ((action-stripped (%strip-input-prefix remainder action-suffixes)))
                   (cond
                     ((not (string= action-stripped remainder))
                      (return (values action-stripped mode)))
                     ((and replace-all-compatibility-action-suffixes
                           (getf mode :replace-all))
                      (let ((legacy-action-stripped
                              (%strip-input-prefix remainder replace-all-compatibility-action-suffixes)))
                        (unless (string= legacy-action-stripped remainder)
                          (return (values legacy-action-stripped mode)))))))))
        finally (return (values nil nil))))

(defun %parse-file-edit-combinable-natural-language-mode (text)
  (loop for spec in +file-edit-combinable-mode-specs+
        do (multiple-value-bind (stripped-text mode)
               (%parse-file-edit-combinable-mode text
                                                (getf spec :base-prefixes)
                                                (getf spec :flag-specs)
                                                +file-edit-standard-action-suffixes+
                                                :replace-all-compatibility-action-suffixes +file-edit-combinable-replace-all-compatibility-action-suffixes+)
             (when stripped-text
               (return (values stripped-text mode))))
        finally (return (values nil nil))))

(defun %parse-file-edit-basic-mode (text)
  (multiple-value-bind (stripped-text spec)
      (%parse-file-edit-prefixed-spec text +file-edit-basic-mode-specs+)
    (if stripped-text
        (values stripped-text (%copy-file-edit-mode (getf spec :mode)))
        (values text nil))))

(defparameter +file-edit-natural-language-mode-parsers+
  '(%parse-parameterized-file-edit-natural-language-mode
    %parse-file-edit-combinable-natural-language-mode
    %parse-file-edit-basic-mode)
  "file-edit-tool 自然语言模式解析流水线，按优先级顺序执行。")

(defun %parse-file-edit-with-parser-pipeline (text parser-functions)
  (loop for parser in parser-functions
        do (multiple-value-bind (stripped-text mode)
               (funcall parser text)
             (when (and stripped-text mode)
               (return (values stripped-text mode))))
        finally (return (values text nil))))

(defun %parse-file-edit-natural-language-mode (text)
  (%parse-file-edit-with-parser-pipeline text
                                        +file-edit-natural-language-mode-parsers+))

(defun %parse-prefixed-file-edit-text (text)
  (multiple-value-bind (stripped-text mode)
      (%parse-file-edit-natural-language-mode text)
    (%parse-file-edit-text stripped-text
                           :preview (getf mode :preview)
                           :occurrence (getf mode :occurrence)
                           :line-context (getf mode :line-context)
                           :replace-all (getf mode :replace-all)
                           :use-regex (getf mode :use-regex)
                           :ignore-case (getf mode :ignore-case)
                           :multiline (getf mode :multiline)
                           :dot-all (getf mode :dot-all)
                           :whole-word (getf mode :whole-word)
                           :left-word-boundary (getf mode :left-word-boundary)
                           :right-word-boundary (getf mode :right-word-boundary))))

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
                                   :occurrence (getf input :occurrence)
                                   :line-context (getf input :line-context)
                                   :replace-all (getf input :replace-all)
                                   :ignore-case (getf input :ignore-case)
                                   :use-regex (getf input :use-regex)
                                   :multiline (getf input :multiline)
                                   :dot-all (getf input :dot-all)
                                   :whole-word (getf input :whole-word)
                                   :left-word-boundary (getf input :left-word-boundary)
                                   :right-word-boundary (getf input :right-word-boundary)))
    (t
    (let ((text (and input (string-trim +file-edit-trim-characters+ (string input)))))
       (cond
         ((or (null text) (string= text "")) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-file-edit-input (subseq text (length "fixture-input-"))))
         (t (%parse-prefixed-file-edit-text text)))))))

(defun %file-edit-effective-ignore-case (ignore-case)
  (not (null ignore-case)))

(defun %file-edit-effective-use-regex (use-regex)
  (not (null use-regex)))

(defun %file-edit-effective-multiline (multiline)
  (not (null multiline)))

(defun %file-edit-effective-dot-all (dot-all)
  (not (null dot-all)))

(defun %file-edit-effective-whole-word (whole-word)
  (not (null whole-word)))

(defun %file-edit-effective-left-word-boundary (whole-word left-word-boundary)
  (or (%file-edit-effective-whole-word whole-word)
      (not (null left-word-boundary))))

(defun %file-edit-effective-right-word-boundary (whole-word right-word-boundary)
  (or (%file-edit-effective-whole-word whole-word)
      (not (null right-word-boundary))))

(defun %file-edit-match-test (ignore-case)
  (if (%file-edit-effective-ignore-case ignore-case)
      #'char-equal
      #'char=))

(defun %file-edit-word-character-p (character)
  (and character
       (or (alpha-char-p character)
           (digit-char-p character)
           (char= character #\_))))

(defun %file-edit-word-boundary-p (contents start end)
  (let ((before (and (> start 0)
                     (char contents (1- start))))
        (after (and (< end (length contents))
                    (char contents end))))
    (and (not (%file-edit-word-character-p before))
         (not (%file-edit-word-character-p after)))))

(defun %file-edit-match-boundaries-p (contents start end whole-word left-word-boundary right-word-boundary)
  (let ((effective-left (%file-edit-effective-left-word-boundary whole-word left-word-boundary))
        (effective-right (%file-edit-effective-right-word-boundary whole-word right-word-boundary))
        (before (and (> start 0)
                     (char contents (1- start))))
        (after (and (< end (length contents))
                    (char contents end))))
    (and (or (not effective-left)
             (not (%file-edit-word-character-p before)))
         (or (not effective-right)
             (not (%file-edit-word-character-p after))))))

(defun %file-edit-filter-boundary-matches (contents matches &key whole-word left-word-boundary right-word-boundary)
  (if (or (%file-edit-effective-whole-word whole-word)
          left-word-boundary
          right-word-boundary)
      (remove-if-not (lambda (match)
                       (%file-edit-match-boundaries-p contents
                                                      (getf match :start)
                                                      (getf match :end)
                                                      whole-word
                                                      left-word-boundary
                                                      right-word-boundary))
                     matches)
      matches))

(defun %file-edit-match-record (original-position original-end updated-position matched-text replacement-text selected-occurrence)
  (list :original-position original-position
        :original-end original-end
        :updated-position updated-position
  :updated-end (+ updated-position (length replacement-text))
        :matched-text matched-text
  :replacement-text replacement-text
        :selected-occurrence selected-occurrence))

(defun %exact-match-records (needle haystack &key ignore-case)
  (loop with start = 0
        for position = (search needle haystack :start2 start :test (%file-edit-match-test ignore-case))
        while position
        for end = (+ position (length needle))
        collect (list :start position
                      :end end
                      :matched-text (subseq haystack position end))
        do (setf start end)))

(defun %file-edit-regex-scanner (pattern ignore-case multiline dot-all)
  (cl-ppcre:create-scanner pattern
           :case-insensitive-mode (%file-edit-effective-ignore-case ignore-case)
           :multi-line-mode (%file-edit-effective-multiline multiline)
           :single-line-mode (%file-edit-effective-dot-all dot-all)))

(defun %regex-match-records (pattern contents &key ignore-case multiline dot-all)
  (handler-case
  (let ((scanner (%file-edit-regex-scanner pattern ignore-case multiline dot-all))
            (matches '()))
        (cl-ppcre:do-scans (start end reg-starts reg-ends scanner contents)
          (when (= start end)
            (error (%file-edit-tool-error "正则表达式当前不支持零长度匹配")))
          (push (list :start start
                      :end end
                      :matched-text (subseq contents start end)
                      :register-starts (and reg-starts (copy-seq reg-starts))
                      :register-ends (and reg-ends (copy-seq reg-ends)))
                matches))
        (nreverse matches))
    (cl-cc.lib:cl-cc-error (condition)
      (error condition))
    (error (condition)
      (error (%file-edit-tool-error (format nil "正则表达式无效: ~A" condition))))))

(defun %file-edit-match-records (old-text contents &key ignore-case use-regex multiline dot-all whole-word left-word-boundary right-word-boundary)
  (%file-edit-filter-boundary-matches
   contents
   (if (%file-edit-effective-use-regex use-regex)
  (%regex-match-records old-text contents :ignore-case ignore-case :multiline multiline :dot-all dot-all)
       (%exact-match-records old-text contents :ignore-case ignore-case))
   :whole-word whole-word
   :left-word-boundary left-word-boundary
   :right-word-boundary right-word-boundary))

(defun %file-edit-capture-text (contents match capture-index)
  (let ((register-starts (getf match :register-starts))
        (register-ends (getf match :register-ends)))
    (cond
      ((zerop capture-index)
       (getf match :matched-text))
      ((or (null register-starts)
           (null register-ends)
           (>= (1- capture-index) (length register-starts)))
       "")
      (t
       (let ((start (aref register-starts (1- capture-index)))
             (end (aref register-ends (1- capture-index))))
         (if (and start end)
             (subseq contents start end)
             ""))))))

(defun %file-edit-reference-digit-char-p (character)
  (and character
       (digit-char-p character)))

(defun %file-edit-reference-value (template start-index)
  (let ((index start-index))
    (loop while (and (< index (length template))
                     (%file-edit-reference-digit-char-p (char template index))) do
      (incf index))
    (if (= index start-index)
        (values nil start-index)
        (values (parse-integer template :start start-index :end index)
                index))))

(defun %file-edit-expand-regex-replacement (template contents match)
  (with-output-to-string (stream)
    (loop with index = 0
          while (< index (length template)) do
      (let ((character (char template index)))
        (cond
          ((char= character #\\)
           (multiple-value-bind (reference next-index)
               (%file-edit-reference-value template (1+ index))
             (cond
               (reference
                (write-string (%file-edit-capture-text contents match reference) stream)
                (setf index next-index))
               ((< (1+ index) (length template))
                (write-char (char template (1+ index)) stream)
                (incf index 2))
               (t
                (write-char character stream)
                (incf index 1)))))
          ((char= character #\$)
           (multiple-value-bind (reference next-index)
               (%file-edit-reference-value template (1+ index))
             (if reference
                 (progn
                   (write-string (%file-edit-capture-text contents match reference) stream)
                   (setf index next-index))
                 (progn
                   (write-char character stream)
                   (incf index 1)))))
          (t
           (write-char character stream)
           (incf index 1)))))))

(defun %file-edit-effective-replacement-text (contents match new-text use-regex)
  (if (%file-edit-effective-use-regex use-regex)
      (%file-edit-expand-regex-replacement new-text contents match)
      new-text))

(defun %select-file-edit-match-record (matches occurrence)
  (let ((total-matches (length matches)))
    (cond
      ((zerop total-matches)
       (error (%file-edit-tool-error "未找到待替换内容")))
      ((null occurrence)
       (if (> total-matches 1)
           (error (%file-edit-tool-error "待替换内容出现多次，请提供更精确的旧文本或指定 occurrence"))
           (values (first matches) total-matches 1)))
      ((> occurrence total-matches)
       (error (%file-edit-tool-error
               (format nil "指定 occurrence 超出范围: ~D（共 ~D 处匹配）" occurrence total-matches))))
      (t
       (values (nth (1- occurrence) matches) total-matches occurrence)))))

(defun %replace-at-span (contents start end new-text)
  (concatenate 'string
               (subseq contents 0 start)
               new-text
               (subseq contents end)))

(defun %replace-single-occurrence (contents old-text new-text &key occurrence ignore-case use-regex multiline dot-all whole-word left-word-boundary right-word-boundary)
  (let ((matches (%file-edit-match-records old-text contents
                                           :ignore-case ignore-case
                                           :use-regex use-regex
                                           :multiline multiline
                                           :dot-all dot-all
                                           :whole-word whole-word
                                           :left-word-boundary left-word-boundary
                                           :right-word-boundary right-word-boundary)))
    (multiple-value-bind (match total-matches selected-occurrence)
        (%select-file-edit-match-record matches occurrence)
      (let ((start (getf match :start))
            (end (getf match :end))
            (matched-text (getf match :matched-text))
            (replacement-text (%file-edit-effective-replacement-text contents match new-text use-regex)))
        (values (%replace-at-span contents start end replacement-text)
                (%file-edit-match-record start end start matched-text replacement-text selected-occurrence)
                total-matches
                selected-occurrence)))))

(defun %replace-all-occurrences (contents old-text new-text &key ignore-case use-regex multiline dot-all whole-word left-word-boundary right-word-boundary)
  (let ((matches (%file-edit-match-records old-text contents
                                           :ignore-case ignore-case
                                           :use-regex use-regex
                                           :multiline multiline
                                           :dot-all dot-all
                                           :whole-word whole-word
                                           :left-word-boundary left-word-boundary
                                           :right-word-boundary right-word-boundary)))
    (when (null matches)
      (error (%file-edit-tool-error "未找到待替换内容")))
    (let ((cursor 0)
          (delta 0)
          (records '()))
      (values
       (with-output-to-string (stream)
         (loop for match in matches
               for occurrence from 1 do
           (let ((start (getf match :start))
                 (end (getf match :end))
                 (matched-text (getf match :matched-text))
                 (replacement-text (%file-edit-effective-replacement-text contents match new-text use-regex)))
             (write-string (subseq contents cursor start) stream)
             (write-string replacement-text stream)
             (push (%file-edit-match-record start
                                            end
                                            (+ start delta)
                                            matched-text
                                            replacement-text
                                            occurrence)
                   records)
             (setf cursor end)
             (incf delta (- (length replacement-text) (length matched-text)))))
         (write-string (subseq contents cursor) stream))
       (nreverse records)
       (length matches)))))

(defun %replace-file-edit-occurrences (contents old-text new-text &key occurrence replace-all ignore-case use-regex multiline dot-all whole-word left-word-boundary right-word-boundary)
  (if replace-all
      (multiple-value-bind (updated-contents records total-matches)
          (%replace-all-occurrences contents old-text new-text
                                    :ignore-case ignore-case
                                    :use-regex use-regex
                                    :multiline multiline
                                    :dot-all dot-all
                                    :whole-word whole-word
                                    :left-word-boundary left-word-boundary
                                    :right-word-boundary right-word-boundary)
        (values updated-contents records total-matches nil))
      (multiple-value-bind (updated-contents record total-matches selected-occurrence)
          (%replace-single-occurrence contents old-text new-text
                                      :occurrence occurrence
                                      :ignore-case ignore-case
                                      :use-regex use-regex
                                      :multiline multiline
                                      :dot-all dot-all
                                      :whole-word whole-word
                                      :left-word-boundary left-word-boundary
                                      :right-word-boundary right-word-boundary)
        (values updated-contents
                (list record)
                total-matches
                selected-occurrence))))

(defun %file-edit-selected-occurrence-message (occurrence total-matches)
  (if (> total-matches 1)
      (format nil " [第 ~D/~D 处命中]" occurrence total-matches)
      ""))

(defun %file-edit-replace-all-message (match-count)
  (format nil " [全部 ~D 处命中]" match-count))

(defun %file-edit-success-message (path occurrence total-matches match-count replace-all)
  (format nil "编辑文件: ~A~A"
          path
          (if replace-all
              (%file-edit-replace-all-message match-count)
              (%file-edit-selected-occurrence-message occurrence total-matches))))

(defun %file-edit-preview-message (path old-text new-text occurrence total-matches match-count replace-all)
  (format nil "预览编辑文件: ~A [替换 ~D 处: ~S -> ~S]~A"
          path
          match-count
          old-text
          new-text
          (if replace-all
              (%file-edit-replace-all-message match-count)
              (%file-edit-selected-occurrence-message occurrence total-matches))))

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

(defun %file-edit-effective-line-context (line-context)
  (if (null line-context)
      +file-edit-preview-line-radius+
      line-context))

(defun %file-edit-line-window-with-context (line-count start-line end-line line-context)
  (let ((radius (%file-edit-effective-line-context line-context)))
    (values (max 1 (- start-line radius))
            (min line-count (+ end-line radius)))))

(defun %file-edit-omitted-line-marker (direction omitted-count)
  (format nil "  ... | ~A省略 ~D 行"
          (if (eq direction :before) "前文" "后文")
          omitted-count))

(defun %file-edit-line-range-count (start-line end-line)
  (1+ (- end-line start-line)))

(defun %file-edit-unified-range-fragment (start-line end-line)
  (let ((count (%file-edit-line-range-count start-line end-line)))
    (if (= count 1)
        (format nil "~D" start-line)
        (format nil "~D,~D" start-line count))))

(defun %file-edit-unified-hunk-header (old-start old-end new-start new-end)
  (format nil "@@ -~A +~A @@"
          (%file-edit-unified-range-fragment old-start old-end)
          (%file-edit-unified-range-fragment new-start new-end)))

(defun %file-edit-unified-context-before-lines (lines window-start changed-start)
  (loop for line-number from window-start below changed-start
        collect (format nil " ~A" (nth (1- line-number) lines))))

(defun %file-edit-unified-context-after-lines (lines changed-end window-end)
  (loop for line-number from (1+ changed-end) to window-end
        collect (format nil " ~A" (nth (1- line-number) lines))))

(defun %file-edit-unified-changed-lines (lines start-line end-line prefix)
  (loop for line-number from start-line to end-line
        collect (format nil "~A~A" prefix (nth (1- line-number) lines))))

(defun %file-edit-unified-path-label (path prefix)
  (format nil "~A/~A"
    prefix
    (substitute #\/ #\\ path)))

(defun %file-edit-unified-file-header-lines (path)
  (list (format nil "--- ~A" (%file-edit-unified-path-label path "a"))
  (format nil "+++ ~A" (%file-edit-unified-path-label path "b"))))

(defun %file-edit-unified-change-record (contents updated-contents record line-context)
  (let* ((original-position (getf record :original-position))
         (updated-position (getf record :updated-position))
         (old-end (getf record :original-end))
         (new-end (getf record :updated-end)))
    (multiple-value-bind (old-start-line old-end-line)
        (%file-edit-line-span contents original-position old-end)
      (multiple-value-bind (new-start-line new-end-line)
          (%file-edit-line-span updated-contents updated-position new-end)
        (multiple-value-bind (old-window-start old-window-end)
            (%file-edit-line-window-with-context (length (%file-edit-lines contents)) old-start-line old-end-line line-context)
          (multiple-value-bind (new-window-start new-window-end)
              (%file-edit-line-window-with-context (length (%file-edit-lines updated-contents)) new-start-line new-end-line line-context)
            (list :old-start-line old-start-line
                  :old-end-line old-end-line
                  :new-start-line new-start-line
                  :new-end-line new-end-line
                  :old-window-start old-window-start
                  :old-window-end old-window-end
                  :new-window-start new-window-start
                  :new-window-end new-window-end)))))))

(defun %file-edit-merge-unified-hunks (change-records)
  (let ((merged '())
        (current nil))
    (dolist (change change-records)
      (if (null current)
          (setf current (list :old-window-start (getf change :old-window-start)
                              :old-window-end (getf change :old-window-end)
                              :new-window-start (getf change :new-window-start)
                              :new-window-end (getf change :new-window-end)
                              :changes (list change)))
          (if (or (<= (getf change :old-window-start) (1+ (getf current :old-window-end)))
                  (<= (getf change :new-window-start) (1+ (getf current :new-window-end))))
              (progn
                (setf (getf current :old-window-end) (max (getf current :old-window-end)
                                                          (getf change :old-window-end)))
                (setf (getf current :new-window-end) (max (getf current :new-window-end)
                                                          (getf change :new-window-end)))
                (setf (getf current :changes)
                      (append (getf current :changes) (list change))))
              (progn
                (push current merged)
                (setf current (list :old-window-start (getf change :old-window-start)
                                    :old-window-end (getf change :old-window-end)
                                    :new-window-start (getf change :new-window-start)
                                    :new-window-end (getf change :new-window-end)
                                    :changes (list change)))))))
    (when current
      (push current merged))
    (nreverse merged)))

(defun %file-edit-render-unified-hunk-lines (hunk before-lines after-lines)
  (let ((lines nil)
        (cursor (getf hunk :old-window-start)))
    (push (%file-edit-unified-hunk-header (getf hunk :old-window-start)
                                          (getf hunk :old-window-end)
                                          (getf hunk :new-window-start)
                                          (getf hunk :new-window-end))
          lines)
    (dolist (change (getf hunk :changes))
      (loop for line-number from cursor below (getf change :old-start-line) do
        (push (format nil " ~A" (nth (1- line-number) before-lines)) lines))
      (dolist (line (%file-edit-unified-changed-lines before-lines
                                                      (getf change :old-start-line)
                                                      (getf change :old-end-line)
                                                      "-"))
        (push line lines))
      (dolist (line (%file-edit-unified-changed-lines after-lines
                                                      (getf change :new-start-line)
                                                      (getf change :new-end-line)
                                                      "+"))
        (push line lines))
      (setf cursor (1+ (getf change :old-end-line))))
    (loop for line-number from cursor to (getf hunk :old-window-end) do
      (push (format nil " ~A" (nth (1- line-number) before-lines)) lines))
    (nreverse lines)))

(defun %file-edit-format-line-preview-block (label lines changed-start changed-end line-context)
  (multiple-value-bind (window-start window-end)
      (%file-edit-line-window-with-context (length lines) changed-start changed-end line-context)
    (with-output-to-string (stream)
      (format stream "~A" label)
      (when (> window-start 1)
        (format stream "~%~A" (%file-edit-omitted-line-marker :before (1- window-start))))
      (loop for line-number from window-start to window-end do
        (format stream "~%~A ~D| ~A"
                (if (<= changed-start line-number changed-end)
                    (if (string= label "before:") "-" "+")
                    " ")
                line-number
                (nth (1- line-number) lines)))
      (when (< window-end (length lines))
        (format stream "~%~A"
                (%file-edit-omitted-line-marker :after (- (length lines) window-end)))))))

(defun %file-edit-line-diff-preview (contents updated-contents record &key line-context)
  (let* ((position (getf record :original-position))
         (updated-position (getf record :updated-position))
         (old-end (getf record :original-end))
         (new-end (getf record :updated-end))
         (before-lines (%file-edit-lines contents))
         (after-lines (%file-edit-lines updated-contents)))
    (multiple-value-bind (old-start-line old-end-line)
        (%file-edit-line-span contents position old-end)
      (multiple-value-bind (new-start-line new-end-line)
          (%file-edit-line-span updated-contents updated-position new-end)
        (format nil "@@ lines ~D..~D -> ~D..~D @@~%~A~%~A"
                old-start-line old-end-line new-start-line new-end-line
                (%file-edit-format-line-preview-block "before:" before-lines old-start-line old-end-line line-context)
                (%file-edit-format-line-preview-block "after:" after-lines new-start-line new-end-line line-context))))))

(defun %file-edit-unified-diff-preview (path contents updated-contents replacement-records &key line-context)
  (let* ((change-records (%file-edit-merge-unified-hunks
                          (mapcar (lambda (record)
                                    (%file-edit-unified-change-record contents updated-contents record line-context))
                                  replacement-records)))
         (before-lines (%file-edit-lines contents))
         (after-lines (%file-edit-lines updated-contents)))
    (format nil "~{~A~^~%~}"
            (append (%file-edit-unified-file-header-lines path)
                    (loop for hunk in change-records
                          append (%file-edit-render-unified-hunk-lines hunk before-lines after-lines))))))

(defun %file-edit-diff-preview (contents updated-contents record)
  (let* ((position (getf record :original-position))
         (updated-position (getf record :updated-position))
         (old-end (getf record :original-end))
         (new-end (getf record :updated-end))
         (before-snippet (%file-edit-snippet contents position old-end))
         (after-snippet (%file-edit-snippet updated-contents updated-position new-end)))
    (format nil "@@ match ~D..~D @@~%-~A~%+~A"
            position old-end before-snippet after-snippet)))


(defun %file-edit-matched-text (record)
  (getf record :matched-text))

(defun %file-edit-replacement-text (record)
  (getf record :replacement-text))

(defun %file-edit-result-payload (path old-text new-text contents updated-contents replacement-records total-matches selected-occurrence &key preview line-context replace-all ignore-case use-regex multiline dot-all whole-word left-word-boundary right-word-boundary)
  (let* ((primary-record (first replacement-records))
         (position (getf primary-record :original-position))
         (updated-position (getf primary-record :updated-position))
         (old-end (getf primary-record :original-end))
         (new-end (getf primary-record :updated-end))
         (effective-line-context (%file-edit-effective-line-context line-context))
         (effective-ignore-case (%file-edit-effective-ignore-case ignore-case))
         (effective-use-regex (%file-edit-effective-use-regex use-regex))
         (effective-multiline (and effective-use-regex (%file-edit-effective-multiline multiline)))
         (effective-dot-all (and effective-use-regex (%file-edit-effective-dot-all dot-all)))
         (effective-left-word-boundary (%file-edit-effective-left-word-boundary whole-word left-word-boundary))
         (effective-right-word-boundary (%file-edit-effective-right-word-boundary whole-word right-word-boundary))
         (effective-whole-word (and effective-left-word-boundary effective-right-word-boundary))
         (match-count (length replacement-records))
         (matched-text (%file-edit-matched-text primary-record))
         (replacement-text (%file-edit-replacement-text primary-record))
         (summary (if preview
                      (%file-edit-preview-message path old-text new-text selected-occurrence total-matches match-count replace-all)
                      (%file-edit-success-message path selected-occurrence total-matches match-count replace-all))))
    (append (list :summary summary
      :path path
      :preview (not (null preview))
      :match-count match-count
      :total-matches total-matches
      :selected-occurrence (and (not replace-all) selected-occurrence)
      :line-context effective-line-context
      :ignore-case effective-ignore-case
      :use-regex effective-use-regex
      :multiline effective-multiline
      :dot-all effective-dot-all
      :whole-word effective-whole-word
      :left-word-boundary effective-left-word-boundary
      :right-word-boundary effective-right-word-boundary
      :match-start position
      :match-end old-end)
    (%file-edit-position-metadata contents position old-end)
    (list :matched-text matched-text
      :replacement-text replacement-text
      :before-preview (%file-edit-snippet contents position old-end)
      :after-preview (%file-edit-snippet updated-contents updated-position new-end)
      :diff-preview (%file-edit-diff-preview contents updated-contents primary-record)
      :line-diff-preview (%file-edit-line-diff-preview contents updated-contents primary-record :line-context effective-line-context)
      :unified-diff-preview (%file-edit-unified-diff-preview path contents updated-contents replacement-records :line-context effective-line-context)
      :write-applied (not (null (not preview)))))))

(defun file-edit-tool (input)
  "替换指定文件中的文本片段并返回稳定摘要。"
  (let* ((request (%normalized-file-edit-input input))
         (path (and request (getf request :path)))
         (old-text (and request (getf request :old-text)))
         (new-text (and request (getf request :new-text)))
         (preview (not (null (and request (getf request :preview)))))
         (occurrence (and request (getf request :occurrence)))
         (line-context (and request (getf request :line-context)))
         (replace-all (not (null (and request (getf request :replace-all)))))
         (ignore-case (and request (getf request :ignore-case)))
         (use-regex (and request (getf request :use-regex)))
         (multiline (and request (getf request :multiline)))
         (dot-all (and request (getf request :dot-all)))
         (whole-word (and request (getf request :whole-word)))
         (left-word-boundary (and request (getf request :left-word-boundary)))
         (right-word-boundary (and request (getf request :right-word-boundary))))
    (unless request
      (error (%file-edit-tool-error "请求格式无效，期望 `edit file <path> :: <old-text> :: <new-text> [:: <occurrence>]`、`preview edit file <path> :: <old-text> :: <new-text> [:: <occurrence>]`、`regex edit file <path> :: <old-text> :: <new-text> [:: <occurrence>]` 或 `preview regex edit file <path> :: <old-text> :: <new-text> [:: <occurrence>]`")))
    (unless (and path (> (length path) 0))
      (error (%file-edit-tool-error "路径为空")))
    (unless (> (length old-text) 0)
      (error (%file-edit-tool-error "待替换内容为空")))
    (when (and replace-all occurrence)
      (error (%file-edit-tool-error "replaceAll 与 occurrence 不能同时指定")))
    (unless (probe-file path)
      (error (%file-edit-tool-error (format nil "文件不存在: ~A" path))))
    (handler-case
        (let* ((contents (uiop:read-file-string path))
               (updated-contents nil)
               (replacement-records nil)
               (total-matches nil)
               (selected-occurrence nil)
               (result-payload nil))
          (multiple-value-setq (updated-contents replacement-records total-matches selected-occurrence)
            (%replace-file-edit-occurrences contents old-text new-text
                                            :occurrence occurrence
                                            :replace-all replace-all
                                            :ignore-case ignore-case
                                            :use-regex use-regex
                                            :multiline multiline
                                            :dot-all dot-all
                                            :whole-word whole-word
                                            :left-word-boundary left-word-boundary
                                            :right-word-boundary right-word-boundary))
          (setf result-payload (%file-edit-result-payload path
                                                          old-text
                                                          new-text
                                                          contents
                                                          updated-contents
                                                          replacement-records
                                                          total-matches
                                                          selected-occurrence
                                                          :preview preview
                                                          :line-context line-context
                                                          :replace-all replace-all
                                                          :ignore-case ignore-case
                                                          :use-regex use-regex
                                                          :multiline multiline
                                                          :dot-all dot-all
                                                          :whole-word whole-word
                                                          :left-word-boundary left-word-boundary
                                                          :right-word-boundary right-word-boundary))
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
