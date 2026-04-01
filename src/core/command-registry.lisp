;;;; src/core/command-registry.lisp - 命令注册表骨架
(in-package :cl-cc.core)

(defparameter *command-registry* (make-hash-table :test 'equal))

(defun %string-starts-with-option-prefix-p (value)
  (and (stringp value)
       (or (uiop:string-prefix-p "--" value)
           (uiop:string-prefix-p "-" value))))

(defun %normalize-command-pattern (pattern)
  (cond
    ((null pattern) nil)
    ((and (listp pattern) (every #'stringp pattern)) pattern)
    ((stringp pattern) (list pattern))
    (t nil)))

(defun %command-patterns (definition)
  (let ((patterns (list (uiop:split-string (cl-cc.models:command-name definition) :separator '(#\Space)))))
    (dolist (alias (cl-cc.models:command-aliases definition) patterns)
      (let ((normalized (%normalize-command-pattern alias)))
        (when normalized
          (push normalized patterns))))))

(defun %pattern-matches-argv-p (pattern argv)
  (and (<= (length pattern) (length argv))
       (loop for expected in pattern
             for actual in argv
             always (string= expected actual))))

(defun %command-required-tail-count (definition)
  (getf (cl-cc.models:command-arguments-schema definition) :required-tail-count))

(defun %command-usage-tail (definition)
  (getf (cl-cc.models:command-arguments-schema definition) :usage-tail))

(defun %legacy-positional-specs (definition)
  (let ((required-tail-count (%command-required-tail-count definition))
        (usage-tail (%command-usage-tail definition)))
    (cond
      ((or (null required-tail-count) (= required-tail-count 0)) nil)
      ((and (= required-tail-count 1)
            usage-tail
            (> (length usage-tail) 0))
       (list (list :name usage-tail :required t)))
      (t
       (loop for index from 1 to required-tail-count
             collect (list :name (format nil "<arg-~A>" index) :required t))))))

(defun %command-positionals (definition)
  (or (getf (cl-cc.models:command-arguments-schema definition) :positionals)
      (%legacy-positional-specs definition)))

(defun %command-options (definition)
  (getf (cl-cc.models:command-arguments-schema definition) :options))

(defun %required-positional-count (definition)
  (count-if (lambda (spec) (getf spec :required)) (%command-positionals definition)))

(defun %repeatable-positional-spec (definition)
  (let ((positionals (%command-positionals definition)))
    (when positionals
      (let ((last-spec (car (last positionals))))
        (when (getf last-spec :repeatable)
          last-spec)))))

(defun %maximum-positional-count (definition)
  (if (%repeatable-positional-spec definition)
      nil
      (length (%command-positionals definition))))

(defun %find-option-spec (definition token)
  (find-if (lambda (spec)
             (member token (getf spec :flags) :test #'string=))
           (%command-options definition)))

(defun %find-inline-option-spec (definition token)
  (dolist (spec (%command-options definition) nil)
    (dolist (flag (getf spec :flags))
      (let ((prefix (format nil "~A=" flag)))
        (when (uiop:string-prefix-p prefix token)
          (return-from %find-inline-option-spec
            (values spec (subseq token (length prefix)))))))))

(defun %option-expects-value-p (option-spec)
  (not (getf option-spec :flag)))

(defun %preferred-option-flag (option-spec)
  (or (find-if (lambda (flag) (uiop:string-prefix-p "--" flag))
               (getf option-spec :flags))
      (first (getf option-spec :flags))))

(defun %option-help-label (option-spec)
  (format nil "~{~A~^, ~}" (getf option-spec :flags)))

(defun %find-option-spec-by-key (definition option-key)
  (find option-key (%command-options definition) :key (lambda (spec) (getf spec :key))))

(defun %option-present-p (options option-key)
  (not (eq (getf options option-key :missing) :missing)))

(defun %requirement-satisfied-p (options requirement)
  (let* ((required-key (getf requirement :key))
         (expected-value (getf requirement :value :missing))
         (actual-value (getf options required-key :missing)))
    (and (not (eq actual-value :missing))
         (or (eq expected-value :missing)
             (equal actual-value expected-value)))))

(defun %requirement-help-label (definition requirement)
  (let* ((option-spec (%find-option-spec-by-key definition (getf requirement :key)))
         (label (if option-spec
                    (%preferred-option-flag option-spec)
                    (string-downcase (string (getf requirement :key)))))
         (expected-value (getf requirement :value :missing)))
    (if (eq expected-value :missing)
        label
        (format nil "~A=~A" label expected-value))))

(defun %conflict-help-label (definition option-key)
  (let ((option-spec (%find-option-spec-by-key definition option-key)))
    (if option-spec
        (%preferred-option-flag option-spec)
        (string-downcase (string option-key)))))

(defun %coerce-argument-value (value spec)
  (let ((type (getf spec :type :string)))
    (cond
      ((or (null type) (eq type :string)) value)
      ((eq type :integer)
       (handler-case
           (parse-integer value :junk-allowed nil)
         (error () :invalid)))
      ((and (consp type) (eq (first type) :enum))
       (if (member value (rest type) :test #'string=)
           value
           :invalid))
      (t value))))

(defun %option-storage-value (options option-spec option-key coerced-value)
  (if (getf option-spec :repeatable)
      (let ((existing (getf options option-key)))
        (setf (getf options option-key) (append existing (list coerced-value)))
        options)
      (progn
        (setf (getf options option-key) coerced-value)
        options)))

(defun %copy-default-value (option-spec value)
  (if (and (getf option-spec :repeatable)
           (listp value))
      (copy-list value)
      value))

(defun %conditional-default-value (options option-spec)
  (dolist (clause (getf option-spec :default-when) nil)
    (when (every (lambda (requirement)
                   (%requirement-satisfied-p options requirement))
                 (getf clause :when))
      (return (%copy-default-value option-spec (getf clause :value))))))

(defun %apply-option-defaults (definition options)
  (dolist (option-spec (%command-options definition) options)
    (let ((option-key (getf option-spec :key)))
      (when (and (null (getf options option-key))
                 (or (not (null (getf option-spec :default)))
                     (not (null (getf option-spec :default-when)))))
        (let ((default-value (or (%conditional-default-value options option-spec)
                                 (%copy-default-value option-spec (getf option-spec :default)))))
          (when (not (null default-value))
            (setf (getf options option-key) default-value)))))))

(defun %validate-option-constraints (definition options)
  (dolist (option-spec (%command-options definition))
    (let ((option-key (getf option-spec :key)))
      (when (%option-present-p options option-key)
        (dolist (conflict-key (getf option-spec :conflicts-with))
          (when (%option-present-p options conflict-key)
            (%signal-invalid-arguments definition)))
        (dolist (requirement (getf option-spec :requires))
          (unless (%requirement-satisfied-p options requirement)
            (%signal-invalid-arguments definition))))))
  options)

(defun %signal-invalid-arguments (definition)
  (error 'cl-cc.lib:cl-cc-error
         :code :invalid-arguments
         :message (format nil "invalid arguments for command ~A" (cl-cc.models:command-name definition))))

(defun %parse-command-arguments (definition matched-pattern argv)
  (let ((tail (nthcdr (length matched-pattern) argv))
        (positionals '())
        (options '()))
    (loop while tail do
      (let* ((token (first tail))
             (direct-option-spec (%find-option-spec definition token)))
        (multiple-value-bind (inline-option-spec inline-value)
            (%find-inline-option-spec definition token)
          (let ((option-spec (or direct-option-spec inline-option-spec)))
        (cond
          (option-spec
           (let ((option-key (getf option-spec :key)))
             (cond
               (inline-option-spec
                (when (or (not (%option-expects-value-p option-spec))
                          (string= inline-value ""))
                  (%signal-invalid-arguments definition))
                (let ((coerced-value (%coerce-argument-value inline-value option-spec)))
                  (when (eq coerced-value :invalid)
                    (%signal-invalid-arguments definition))
                  (setf options (%option-storage-value options option-spec option-key coerced-value))
                  (setf tail (rest tail))))
               ((%option-expects-value-p option-spec)
                (let ((value (second tail)))
                  (when (or (null value)
                            (and (%string-starts-with-option-prefix-p value)
                                 (null (%find-option-spec definition value))))
                    (%signal-invalid-arguments definition))
                  (let ((coerced-value (%coerce-argument-value value option-spec)))
                    (when (eq coerced-value :invalid)
                      (%signal-invalid-arguments definition))
                    (setf options (%option-storage-value options option-spec option-key coerced-value)))
                  (setf tail (cddr tail))))
               (t
                (setf options (%option-storage-value options option-spec option-key t))
                (setf tail (rest tail))))))
          ((%string-starts-with-option-prefix-p token)
           (%signal-invalid-arguments definition))
          (t
           (push token positionals)
           (setf tail (rest tail))))))))
    (let ((required-positionals (%required-positional-count definition))
          (maximum-positionals (%maximum-positional-count definition)))
      (when (< (length positionals) required-positionals)
        (%signal-invalid-arguments definition))
      (when (and maximum-positionals
                 (> (length positionals) maximum-positionals))
        (%signal-invalid-arguments definition)))
    (dolist (option-spec (%command-options definition))
      (when (and (getf option-spec :required)
                 (null (getf options (getf option-spec :key))))
        (%signal-invalid-arguments definition)))
    (setf options (%apply-option-defaults definition options))
    (setf options (%validate-option-constraints definition options))
    (list :positionals (nreverse positionals)
          :options options)))

(defun %render-positional-usage (spec)
  (let* ((name (getf spec :name "<arg>"))
         (base-name (if (getf spec :repeatable)
                        (format nil "~A..." name)
                        name)))
    (if (getf spec :required)
        base-name
        (format nil "[~A]" base-name))))

(defun %render-option-usage (spec)
  (let ((flag (%preferred-option-flag spec))
        (value-name (getf spec :value-name "<value>")))
    (if (getf spec :flag)
        (if (getf spec :required)
            flag
            (format nil "[~A]" flag))
        (if (getf spec :required)
            (format nil "~A ~A" flag value-name)
            (format nil "[~A ~A]" flag value-name)))))

(defun %join-usage-parts (parts)
  (format nil "~{~A~^ ~}" (remove-if (lambda (part) (or (null part) (string= part ""))) parts)))

(defun command-usage-tail (definition)
  (let* ((positionals (mapcar #'%render-positional-usage (%command-positionals definition)))
         (options (mapcar #'%render-option-usage (%command-options definition))))
    (%join-usage-parts (append positionals options))))

(defun command-option-help-lines (definition)
  (mapcar (lambda (spec)
            (let ((usage (if (getf spec :flag)
                             (%option-help-label spec)
                             (format nil "~A ~A"
                                     (%option-help-label spec)
             (getf spec :value-name "<value>")))))
              (format nil "      ~A~@[  ~A~]"
                      usage
                      (%join-usage-parts
                       (remove nil
                               (list (getf spec :summary)
                                     (when (getf spec :repeatable)
                                       "[repeatable]")
                                     (when (not (null (getf spec :default)))
                                       (format nil "[default: ~A]" (getf spec :default)))
                                      (when (getf spec :requires)
                                        (format nil "[requires: ~{~A~^, ~}]"
                                                (mapcar (lambda (requirement)
                                                          (%requirement-help-label definition requirement))
                                                        (getf spec :requires))))
                                      (when (getf spec :conflicts-with)
                                        (format nil "[conflicts: ~{~A~^, ~}]"
                                                (mapcar (lambda (option-key)
                                                          (%conflict-help-label definition option-key))
                                                        (getf spec :conflicts-with))))))))))
          (%command-options definition)))

(defun command-positional-argument (parsed-arguments index)
  (nth index (getf parsed-arguments :positionals)))

(defun command-positional-arguments (parsed-arguments &optional (start-index 0))
  (nthcdr start-index (getf parsed-arguments :positionals)))

(defun command-option-value (parsed-arguments option-key &optional default)
  (let* ((options (getf parsed-arguments :options))
         (value (getf options option-key :missing)))
    (if (eq value :missing)
        default
        value)))

(defun command-option-values (parsed-arguments option-key)
  (let ((value (command-option-value parsed-arguments option-key nil)))
    (cond
      ((null value) nil)
      ((listp value) value)
      (t (list value)))))

(defun %validate-command-arguments (definition matched-pattern argv)
  (%parse-command-arguments definition matched-pattern argv))

(defun %make-command-definition (name handler-symbol &key aliases summary permission-profile arguments-schema output-schema)
  (make-instance 'cl-cc.models:command-definition
                 :name name
                 :aliases aliases
                 :arguments-schema arguments-schema
                 :output-schema output-schema
                 :summary summary
                 :handler-symbol handler-symbol
                 :permission-profile permission-profile))

(defun reset-command-registry ()
  "清空命令注册表。"
  (clrhash *command-registry*))

(defun register-command (name-or-definition handler-symbol &key aliases summary permission-profile arguments-schema output-schema)
  "注册命令定义到注册表。"
  (let ((definition (if (typep name-or-definition 'cl-cc.models:command-definition)
                        name-or-definition
                        (%make-command-definition name-or-definition
                                                  handler-symbol
                                                  :aliases aliases
                                                  :summary summary
                                                  :permission-profile permission-profile
                                                  :arguments-schema arguments-schema
                                                  :output-schema output-schema))))
    (setf (gethash (cl-cc.models:command-name definition) *command-registry*) definition)
    definition))

(defun find-command (name)
  "查找命令定义。"
  (gethash name *command-registry*))

(defun find-command-handler (name)
  "查找命令处理函数。"
  (let ((definition (find-command name)))
    (and definition (symbol-function (cl-cc.models:command-handler-symbol definition)))))

(defun %all-command-definitions ()
  (let ((definitions '()))
    (maphash (lambda (_ definition)
               (declare (ignore _))
               (push definition definitions))
             *command-registry*)
    definitions))

(defun list-command-definitions ()
  "返回按命令名排序的命令定义列表。"
  (sort (copy-list (%all-command-definitions)) #'string< :key #'cl-cc.models:command-name))

(defun %resolve-command (argv)
  (ensure-default-commands)
  (when (or (null argv)
            (member "--help" argv :test #'string=))
    (let ((definition (find-command "help")))
      (return-from %resolve-command (values definition '("--help")))))
  (dolist (definition (%all-command-definitions))
    (dolist (pattern (%command-patterns definition))
      (when (%pattern-matches-argv-p pattern argv)
        (return-from %resolve-command (values definition pattern)))))
  (values nil nil))

(defun command-key-from-argv (argv)
  "从 argv 推导注册表命令键。"
  (multiple-value-bind (definition pattern) (%resolve-command argv)
    (declare (ignore pattern))
    (and definition (cl-cc.models:command-name definition))))

(defun ensure-default-commands ()
  "确保默认 CLI 命令已注册。"
  (unless (find-command "help")
    (register-command "help" 'cl-cc::handle-help-command
                      :aliases '(("--help") ("-h") ("help"))
                      :summary "显示 CLI 帮助"
                      :permission-profile :default
                      :arguments-schema '(:positionals nil :options nil)
                      :output-schema '(:text "CLI help text")))
  (unless (find-command "docs sync-reference")
    (register-command "docs sync-reference" 'cl-cc::handle-docs-sync-reference-command
                      :aliases '(("docs" "sync"))
                      :summary "将生成的命令参考同步到指定 Markdown 文件，或以 text/json 形式检查漂移"
                      :permission-profile :default
                      :arguments-schema '(:positionals ((:name "<output-path>" :required nil))
                                          :options ((:flags ("--check")
                                                     :key :check-only
                                                     :flag t
                                                     :summary "仅检查命令参考是否需要同步，不写回文件")
                                                    (:flags ("-o" "--output-format")
                                                     :key :output-format
                                                     :type (:enum "text" "json")
                                                     :default "text"
                                                     :value-name "<output-format>"
                                                     :summary "指定输出格式: text 或 json")))
                      :output-schema '(:text "result message"
                                       :closed t
                                                     :json ((:name "path" :summary "目标文档路径" :type :string)
                                                      (:name "status"
                                                       :summary "同步状态: synced、in-sync 或 drift"
                                                       :type :string
                                                       :enum ("synced" "in-sync" "drift"))
                                                      (:name "checkOnly" :summary "是否处于只检查模式" :type :boolean)
                                                      (:name "updated" :summary "本次是否实际写回文件" :type :boolean)
                                                      (:name "needsSync" :summary "当前文档是否存在漂移" :type :boolean)
                                                      (:name "durationSeconds" :summary "本次 docs sync 执行时长（秒）" :type :number :minimum 0)
                                                      (:name "exitCode" :summary "命令退出码" :type :integer :minimum 0 :maximum 255)))))
  (unless (find-command "session start")
    (register-command "session start" 'cl-cc::handle-session-start-command
                      :aliases '(("s" "start"))
                      :summary "启动新会话"
                      :permission-profile :default
                      :arguments-schema '(:positionals nil
                                          :options ((:flags ("-i" "--session-id")
                                                     :key :session-id
                                                     :type :string
                                                     :value-name "<session-id>"
                                                     :summary "显式指定新会话 ID")
                                                    (:flags ("--history-index")
                                                     :key :history-index
                                                     :type :integer
                                                     :value-name "<history-index>"
                                                     :summary "设置初始历史索引")
                                                    (:flags ("-o" "--output-format")
                                                     :key :output-format
                                                     :type (:enum "text" "json")
                                                     :default "text"
                                                     :value-name "<output-format>"
                                                     :summary "指定输出格式: text 或 json")))
                      :output-schema '(:text "session start message"
                                       :closed t
                                                     :json ((:name "status"
                                                              :summary "结果状态，当前固定为 success"
                                                            :type :string
                                                              :enum ("success"))
                                                          (:name "sessionId" :summary "新会话 ID" :type :string)
                                                              (:name "historyIndex" :summary "初始历史索引，未指定时为 null" :type :integer :minimum 0 :required nil :nullable t)
                                                      (:name "sessionStatus"
                                                       :summary "会话状态，当前通常为 active"
                                                           :type :string
                                                       :enum ("active")
                                                       :required nil
                                                       :nullable t)
                                                              (:name "durationSeconds" :summary "本次 session start 执行时长（秒）" :type :number :minimum 0)
                                                              (:name "exitCode" :summary "命令退出码" :type :integer :minimum 0 :maximum 255)))))
  (unless (find-command "session resume")
    (register-command "session resume" 'cl-cc::handle-session-resume-command
                      :aliases '(("s" "resume"))
                      :summary "恢复已有会话"
                      :permission-profile :default
                      :arguments-schema '(:positionals ((:name "<session-id-or-path>" :required t))
                                          :options ((:flags ("-o" "--output-format")
                                                     :key :output-format
                                                     :type (:enum "text" "json")
                                                     :default "text"
                                                     :value-name "<output-format>"
                                                     :summary "指定输出格式: text 或 json")))
                            :output-schema '(:text "session resume message"
                                 :closed t
                              :json ((:name "status"
                                       :summary "结果状态，当前固定为 success"
                                    :type :string
                                       :enum ("success"))
                                  (:name "sessionId" :summary "恢复后的会话 ID" :type :string)
                                  (:name "historyIndex" :summary "恢复快照中的历史索引，缺失时为 null" :type :integer :minimum 0 :required nil :nullable t)
                                (:name "sessionStatus"
                                 :summary "恢复后的会话状态"
                                   :type :string
                                 :enum ("active")
                                 :required nil
                                 :nullable t)
                                  (:name "durationSeconds" :summary "本次 session resume 执行时长（秒）" :type :number :minimum 0)
                                  (:name "exitCode" :summary "命令退出码" :type :integer :minimum 0 :maximum 255)))))
  (unless (find-command "run --fixture")
    (register-command "run --fixture" 'cl-cc::handle-run-fixture-command
                      :aliases '(("r" "--fixture"))
                      :summary "执行 fixture 驱动的脚本化请求"
                      :permission-profile :default
                      :arguments-schema '(:positionals ((:name "<fixture-id>" :required t :repeatable t))
                                          :options ((:flags ("-o" "--output-format")
                                                     :key :output-format
                                                     :type (:enum "text" "json")
                                                     :default "text"
                                                     :default-when ((:when ((:key :pretty-json)) :value "json")
                                                                    (:when ((:key :compact-json)) :value "json"))
                                                     :value-name "<output-format>"
                                                     :summary "指定输出格式: text 或 json")
                                                    (:flags ("--pretty")
                                                     :key :pretty-json
                                                     :flag t
                                                     :summary "以多行缩进格式输出 JSON"
                                                     :requires ((:key :output-format :value "json"))
                                                     :conflicts-with (:compact-json))
                                                    (:flags ("--compact")
                                                     :key :compact-json
                                                     :flag t
                                                     :summary "以紧凑单行格式输出 JSON"
                                                     :requires ((:key :output-format :value "json"))
                                                     :conflicts-with (:pretty-json))
                                                    (:flags ("-t" "--tool")
                                                     :key :tool-ids
                                                     :type :string
                                                     :repeatable t
                                                     :value-name "<tool-id>"
                                                         :summary "覆盖自动工具选择并按给定顺序执行")))
                      :output-schema '(:text "fixture execution summary"
                                       :closed t
                                             :json ((:name "status"
                                               :summary "聚合结果状态"
                                               :type :string
                                               :enum ("success" "partial" "failed" "denied" "not-found")
                                               :enum-when-zero-field (:field "exitCode" :values ("success"))
                                               :enum-when-nonzero-field (:field "exitCode" :values ("partial" "failed" "denied" "not-found")))
                                              (:name "fixtureCount"
                                               :summary "本次执行的 fixture 数量"
                                               :type :integer
                                               :minimum 0
                                               :equals-collection-size-of "results"
                                               :equals-sum-of-fields (:fields ("statusCounts.success"
                                                                               "statusCounts.failed"
                                                                               "statusCounts.partial"
                                                                               "statusCounts.denied"
                                                                               "statusCounts.not-found"
                                                                               "statusCounts.unknown")))
                                              (:name "successfulCount" :summary "成功 fixture 数量" :type :integer :minimum 0 :equals-field "statusCounts.success")
                                              (:name "failedCount" :summary "失败 fixture 数量" :type :integer :minimum 0 :equals-field "statusCounts.failed")
                                              (:name "durationSeconds" :summary "本次 run 聚合执行时长（秒）" :type :number :minimum 0)
                                              (:name "statusCounts"
                                               :summary "各状态计数映射"
                                               :type :object
                                               :closed t
                                               :fields ((:name "success"
                                                        :summary "成功 fixture 数量"
                                                        :type :integer
                                                        :minimum 0
                                                        :equals-field-when-value (:when-field "status" :value "success" :field "fixtureCount"))
                                                        (:name "failed"
                                                         :summary "失败 fixture 数量"
                                                         :type :integer
                                                         :minimum 0
                                                         :equals-field-when-value (:when-field "status" :value "failed" :field "fixtureCount"))
                                                        (:name "partial" :summary "混合结果 fixture 数量" :type :integer :minimum 0)
                                                        (:name "denied"
                                                         :summary "权限拒绝 fixture 数量"
                                                         :type :integer
                                                         :minimum 0
                                                         :equals-field-when-value (:when-field "status" :value "denied" :field "fixtureCount"))
                                                        (:name "not-found"
                                                         :summary "工具未找到 fixture 数量"
                                                         :type :integer
                                                         :minimum 0
                                                         :equals-field-when-value (:when-field "status" :value "not-found" :field "fixtureCount"))
                                                        (:name "unknown" :summary "未归类 fixture 数量" :type :integer :minimum 0)))
                                              (:name "ok" :summary "是否全部成功" :type :boolean :true-when-zero-field "exitCode")
                                              (:name "exitCode" :summary "命令退出码" :type :integer :minimum 0 :maximum 255)
                                              (:name "results"
                                               :summary "逐 fixture 的结果记录，包含稳定文本摘要与 toolResults"
                                               :type :array
                                               :min-items 1
                                               :closed t
                                               :collection t
                                               :fields ((:name "fixtureId" :summary "fixture 标识" :type :string)
                                                        (:name "status"
                                                         :summary "该 fixture 的聚合状态"
                                                         :type :string
                                                         :enum ("success" "partial" "failed" "denied" "not-found"))
                                                        (:name "durationSeconds" :summary "该 fixture 执行时长（秒）" :type :number :minimum 0)
                                                        (:name "result" :summary "兼容既有 golden 的稳定文本摘要" :type :string)
                                                        (:name "toolResults"
                                                         :summary "逐工具尝试记录"
                                                         :type :array
                                                         :min-items 1
                                                         :closed t
                                                         :collection t
                                                         :fields ((:name "toolId" :summary "工具标识" :type :string)
                                                                  (:name "status"
                                                                   :summary "该次工具尝试状态"
                                                                   :type :string
                                                                   :enum ("success" "failed" "denied" "not-found"))
                                                                  (:name "durationSeconds" :summary "该次工具尝试执行时长（秒）" :type :number :minimum 0)
                                                                  (:name "output"
                                                                   :summary "按工具 output-schema 或 error-output-schema 派生的结构化输出，字段集合由工具定义直接提供"
                                                                   :type :object
                                                                   :closed t
                                                                  :required nil
                                                                   :nullable t
                                                                   :tool-schema-refs ((:tool-id "echo-tool" :kind :output)
                                                                                      (:tool-id "failing-tool" :kind :error-output)))
                                                                  (:name "error" :summary "失败时的人类可读摘要，成功时为 null" :type :string :required nil :nullable t)
                                                                  (:name "errorCode"
                                                                   :summary "稳定错误码，成功时为 null"
                                                                   :type :string
                                                                   :required nil
                                                                   :nullable t
                                                                   :enum ("FAIL" "PERMISSION-DENIED" "TOOL-NOT-FOUND"))))))))))
    )

(defun dispatch-command (argv)
  "通过命令注册表分发 argv。返回处理结果或 NIL。"
  (multiple-value-bind (definition pattern) (%resolve-command argv)
    (if definition
        (let ((handler (symbol-function (cl-cc.models:command-handler-symbol definition))))
          (funcall handler argv (%validate-command-arguments definition pattern argv)))
        nil)))
