;;;; src/tools/registry.lisp - 工具注册表骨架
(in-package :cl-cc.tools)

(defparameter *tool-registry* (make-hash-table :test 'equal))

(defun %register-tool-handler-and-options (tool-id-or-definition arguments)
  (declare (ignore tool-id-or-definition))
  (if (and arguments
           (not (keywordp (first arguments))))
      (values (first arguments) (rest arguments))
      (values nil arguments)))

(defun %make-tool-definition (tool-id handler &key summary input-schema output-schema error-output-schema failure-modes permission-profile)
  (make-instance 'cl-cc.models:tool-definition
                 :tool-id tool-id
                 :summary summary
                 :handler-function handler
                 :input-schema input-schema
                 :output-schema output-schema
                 :error-output-schema error-output-schema
                 :failure-modes failure-modes
                 :permission-profile permission-profile))

(defun register-tool (tool-id-or-definition &rest arguments)
  "注册工具到注册表。"
  (multiple-value-bind (handler option-arguments)
      (%register-tool-handler-and-options tool-id-or-definition arguments)
    (let ((definition (if (typep tool-id-or-definition 'cl-cc.models:tool-definition)
                          tool-id-or-definition
                          (%make-tool-definition tool-id-or-definition
                                                 handler
                                                 :summary (getf option-arguments :summary)
                                                 :input-schema (getf option-arguments :input-schema)
                                                 :output-schema (getf option-arguments :output-schema)
                                                 :error-output-schema (getf option-arguments :error-output-schema)
                                                 :failure-modes (getf option-arguments :failure-modes)
                                                 :permission-profile (getf option-arguments :permission-profile)))))
    (setf (gethash (cl-cc.models:tool-id definition) *tool-registry*) definition)
      definition)))

(defmacro define-tool (tool-id handler &body clauses)
  "使用声明式子句注册工具定义。"
  (let ((options '()))
    (dolist (clause clauses)
      (unless (and (consp clause)
                   (keywordp (first clause))
                   (= (length clause) 2))
        (error "Invalid DEFINE-TOOL clause: ~S" clause))
      (setf options (append options (list (first clause) (second clause)))))
    `(register-tool ,tool-id ,handler ,@options)))

(defun find-tool-definition (tool-id)
  "查找工具定义对象。"
  (gethash tool-id *tool-registry*))

(defun find-tool (tool-id)
  "查找工具处理函数。"
  (let ((definition (find-tool-definition tool-id)))
    (and definition
         (cl-cc.models:tool-handler-function definition))))

(defun list-tool-definitions ()
  "返回按工具 ID 排序的工具定义列表。"
  (let ((definitions '()))
    (maphash (lambda (_ definition)
               (declare (ignore _))
               (push definition definitions))
             *tool-registry*)
    (sort definitions #'string< :key #'cl-cc.models:tool-id)))

;; 初始化注册表，注册 echo-tool 和 failing-tool
(define-tool "echo-tool" #'cl-cc.tools:echo-tool
  (:summary "回显输入字符串")
  (:input-schema `(:text "input string"
                   :closed t
                   :json (,(schema-field "input" "待回显的输入字符串" :type :string))))
  (:output-schema `(:text "echoed string"
                    :closed t
                    :json (,(schema-field "result" "工具返回的回显结果" :source :raw-result :type :string))))
  (:failure-modes '())
  (:permission-profile :default))

(define-tool "failing-tool" #'cl-cc.tools:failing-tool
  (:summary "始终返回失败，用于验证错误传播")
  (:input-schema `(:text "input string"
                   :closed t
                   :json (,(schema-field "input" "触发失败路径的输入字符串" :type :string))))
  (:output-schema '(:text "no successful output"
                    :json ()))
  (:error-output-schema `(:text "failed output"
                          :closed t
                          :json (,(schema-field "error" "失败摘要消息" :source :error-message :type :string)
                                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
  (:failure-modes '(:failed))
  (:permission-profile :default))

(define-tool "file-read-tool" #'cl-cc.tools:file-read-tool
  (:summary "读取指定文件内容，用于最小可用的只读文件检索")
  (:input-schema `(:text "path string with optional line range"
                   :closed t
                   :json (,(schema-field "path" "待读取的文件路径" :type :string)
                          ,(schema-field "startLine" "起始行号，缺省时读取整个文件" :type :integer :minimum 1 :required nil :nullable t)
                          ,(schema-field "endLine" "结束行号，缺省时等于 startLine" :type :integer :minimum 1 :required nil :nullable t))))
  (:output-schema `(:text "file contents"
                    :closed t
                    :json (,(schema-field "result" "文件读取结果内容" :source :raw-result :type :string))))
  (:error-output-schema `(:text "file read failed output"
                          :closed t
                          :json (,(schema-field "error" "文件读取失败摘要消息" :source :error-message :type :string)
                                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
  (:failure-modes '(:failed))
  (:permission-profile :file-read))

(define-tool "grep-tool" #'cl-cc.tools:grep-tool
  (:summary "在指定目录或单个文件内搜索文本，用于最小可用的代码检索")
  (:input-schema `(:text "search query or `query :: root`"
                   :closed t
                   :json (,(schema-field "query" "待搜索的文本关键词" :type :string)
                          ,(schema-field "root" "搜索根路径，缺省为当前工作目录" :type :string :required nil :nullable t))))
  (:output-schema `(:text "matched lines"
                    :closed t
                    :json (,(schema-field "result" "搜索结果文本，每行一条匹配记录" :source :raw-result :type :string))))
  (:error-output-schema `(:text "grep search failed output"
                          :closed t
                          :json (,(schema-field "error" "搜索失败摘要消息" :source :error-message :type :string)
                                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
  (:failure-modes '(:failed))
  (:permission-profile :file-read))

(define-tool "file-write-tool" #'cl-cc.tools:file-write-tool
  (:summary "写入或追加指定文件内容，用于最小可用的文件落盘")
  (:input-schema `(:text "write or append request"
                   :closed t
                   :json (,(schema-field "path" "待写入的文件路径" :type :string)
                          ,(schema-field "content" "待写入的文本内容" :type :string)
                          ,(schema-field "mode" "写入模式，缺省为 overwrite" :type :string :enum '("overwrite" "append") :required nil :nullable t))))
  (:output-schema `(:text "write summary"
                    :closed t
                    :json (,(schema-field "result" "文件写入结果摘要" :source :raw-result :type :string))))
  (:error-output-schema `(:text "file write failed output"
                          :closed t
                          :json (,(schema-field "error" "文件写入失败摘要消息" :source :error-message :type :string)
                                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
  (:failure-modes '(:failed))
  (:permission-profile :file-write))

  (define-tool "file-edit-tool" #'cl-cc.tools:file-edit-tool
    (:summary "精确替换指定文件中的单个文本片段，用于最小可用的原位编辑")
    (:input-schema `(:text "edit request"
           :closed t
           :json (,(schema-field "path" "待编辑的文件路径" :type :string)
             ,(schema-field "oldText" "期望被替换的原始文本，要求恰好匹配一次" :type :string)
             ,(schema-field "newText" "替换后的新文本，可为空字符串" :type :string)
             ,(schema-field "occurrence" "当旧文本出现多次时，指定要替换的第几处命中（1-based）" :type :integer :minimum 1 :required nil :nullable t)
             ,(schema-field "preview" "是否只预览替换摘要而不落盘，缺省为 false" :type :boolean :required nil :nullable t))))
    (:output-schema `(:text "edit summary"
            :closed t
          :json (,(schema-field "result" "文件编辑结果摘要" :source '(:raw-result-field :summary) :type :string)
           ,(schema-field "path" "本次编辑目标文件路径" :source '(:raw-result-field :path) :type :string)
                   ,(schema-field "preview" "是否为预览模式；普通写回路径下为 null" :source '(:raw-result-field :preview) :type :boolean :required nil :nullable t)
           ,(schema-field "matchCount" "本次命中的文本片段数量，当前成功路径固定为 1" :source '(:raw-result-field :match-count) :type :integer :minimum 1)
           ,(schema-field "totalMatches" "旧文本在文件中的总匹配次数；指定 occurrence 时可大于 1" :source '(:raw-result-field :total-matches) :type :integer :minimum 1)
           ,(schema-field "selectedOccurrence" "本次实际替换的命中序号（1-based）" :source '(:raw-result-field :selected-occurrence) :type :integer :minimum 1)
           ,(schema-field "matchStart" "命中文本的起始字符偏移（0-based）" :source '(:raw-result-field :match-start) :type :integer :minimum 0)
           ,(schema-field "matchEnd" "命中文本的结束字符偏移（exclusive）" :source '(:raw-result-field :match-end) :type :integer :minimum 0)
           ,(schema-field "matchStartLine" "命中文本起始位置所在行号（1-based）" :source '(:raw-result-field :match-start-line) :type :integer :minimum 1)
           ,(schema-field "matchStartColumn" "命中文本起始位置所在列号（1-based）" :source '(:raw-result-field :match-start-column) :type :integer :minimum 1)
           ,(schema-field "matchEndLine" "命中文本结束位置所在行号（1-based，exclusive）" :source '(:raw-result-field :match-end-line) :type :integer :minimum 1)
           ,(schema-field "matchEndColumn" "命中文本结束位置所在列号（1-based，exclusive）" :source '(:raw-result-field :match-end-column) :type :integer :minimum 1)
           ,(schema-field "matchedText" "实际命中的原始文本片段" :source '(:raw-result-field :matched-text) :type :string)
           ,(schema-field "replacementText" "用于替换的新文本片段" :source '(:raw-result-field :replacement-text) :type :string)
           ,(schema-field "beforePreview" "替换前的局部预览片段" :source '(:raw-result-field :before-preview) :type :string)
           ,(schema-field "afterPreview" "替换后的局部预览片段" :source '(:raw-result-field :after-preview) :type :string)
           ,(schema-field "diffPreview" "替换前后合并展示的稳定 diff 预览片段" :source '(:raw-result-field :diff-preview) :type :string)
                   ,(schema-field "writeApplied" "是否已实际写回文件；preview 模式下为 null" :source '(:raw-result-field :write-applied) :type :boolean :required nil :nullable t))))
    (:error-output-schema `(:text "file edit failed output"
             :closed t
             :json (,(schema-field "error" "文件编辑失败摘要消息" :source :error-message :type :string)
               ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
    (:failure-modes '(:failed))
    (:permission-profile :file-write))

(define-tool "directory-list-tool" #'cl-cc.tools:directory-list-tool
  (:summary "列出指定目录的子项，用于最小可用的只读目录检索")
  (:input-schema `(:text "path string"
                   :closed t
                   :json (,(schema-field "input" "待列举的目录路径" :type :string))))
  (:output-schema `(:text "directory entries"
                    :closed t
                    :json (,(schema-field "result" "目录列举结果内容" :source :raw-result :type :string))))
  (:error-output-schema `(:text "directory listing failed output"
                          :closed t
                          :json (,(schema-field "error" "目录列举失败摘要消息" :source :error-message :type :string)
                                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
  (:failure-modes '(:failed))
  (:permission-profile :file-read))
