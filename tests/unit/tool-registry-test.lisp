;;;; tests/unit/tool-registry-test.lisp - 工具注册表单元测试
(in-package :cl-cc/tests)

(def-suite tool-registry-test :in cl-cc-suite)

(in-suite tool-registry-test)

(test default-tool-definition-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "echo-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "echo-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "回显输入字符串"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "input string" :closed t :json ((:name "input" :summary "待回显的输入字符串" :type :string)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "echoed string" :closed t :json ((:name "result" :summary "工具返回的回显结果" :source :raw-result :type :string)))))
    (is (null (cl-cc.models:tool-error-output-schema definition)))
    (is (null (cl-cc.models:tool-failure-modes definition)))
    (is (functionp (cl-cc.models:tool-handler-function definition)))))

(test failing-tool-error-output-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "failing-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "no successful output" :json ())))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "failed output" :closed t
           :json ((:name "error" :summary "失败摘要消息" :source :error-message :type :string)
             (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))))

(test file-read-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "file-read-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "file-read-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "读取指定文件内容，用于最小可用的只读文件检索"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "path string with optional line range" :closed t
                 :json ((:name "path" :summary "待读取的文件路径" :type :string)
                        (:name "startLine" :summary "起始行号，缺省时读取整个文件" :type :integer :minimum 1 :required nil :nullable t)
                        (:name "endLine" :summary "结束行号，缺省时等于 startLine" :type :integer :minimum 1 :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "file contents" :closed t :json ((:name "result" :summary "文件读取结果内容" :source :raw-result :type :string)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "file read failed output" :closed t
                 :json ((:name "error" :summary "文件读取失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :file-read))))

(test grep-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "grep-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "grep-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "在指定目录或单个文件内搜索文本，用于最小可用的代码检索"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "search query or `query :: root`" :closed t
                 :json ((:name "query" :summary "待搜索的文本关键词" :type :string)
                        (:name "root" :summary "搜索根路径，缺省为当前工作目录" :type :string :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "matched lines" :closed t
                 :json ((:name "result" :summary "搜索结果文本，每行一条匹配记录" :source :raw-result :type :string)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "grep search failed output" :closed t
                 :json ((:name "error" :summary "搜索失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :file-read))))

(test directory-list-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "directory-list-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "directory-list-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "列出指定目录的子项，用于最小可用的只读目录检索"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "path string" :closed t :json ((:name "input" :summary "待列举的目录路径" :type :string)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "directory entries" :closed t :json ((:name "result" :summary "目录列举结果内容" :source :raw-result :type :string)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "directory listing failed output" :closed t
                 :json ((:name "error" :summary "目录列举失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :file-read))))

(test file-write-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "file-write-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "file-write-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "写入或追加指定文件内容，用于最小可用的文件落盘"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "write or append request" :closed t
                 :json ((:name "path" :summary "待写入的文件路径" :type :string)
                        (:name "content" :summary "待写入的文本内容" :type :string)
                        (:name "mode" :summary "写入模式，缺省为 overwrite" :type :string
                         :enum ("overwrite" "append") :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "write summary" :closed t
                 :json ((:name "result" :summary "文件写入结果摘要" :source :raw-result :type :string)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "file write failed output" :closed t
                 :json ((:name "error" :summary "文件写入失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :file-write))))

(test file-edit-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "file-edit-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "file-edit-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "精确替换指定文件中的单个文本片段，用于最小可用的原位编辑"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "edit request" :closed t
                 :json ((:name "path" :summary "待编辑的文件路径" :type :string)
                        (:name "oldText" :summary "期望被替换的原始文本，要求恰好匹配一次" :type :string)
                        (:name "newText" :summary "替换后的新文本，可为空字符串" :type :string)
                        (:name "occurrence" :summary "当旧文本出现多次时，指定要替换的第几处命中（1-based）" :type :integer :minimum 1 :required nil :nullable t)
                        (:name "preview" :summary "是否只预览替换摘要而不落盘，缺省为 false" :type :boolean :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "edit summary" :closed t
                 :json ((:name "result" :summary "文件编辑结果摘要" :source (:raw-result-field :summary) :type :string)
                        (:name "path" :summary "本次编辑目标文件路径" :source (:raw-result-field :path) :type :string)
                        (:name "preview" :summary "是否为预览模式；普通写回路径下为 null" :source (:raw-result-field :preview) :type :boolean :required nil :nullable t)
                        (:name "matchCount" :summary "本次命中的文本片段数量，当前成功路径固定为 1" :source (:raw-result-field :match-count) :type :integer :minimum 1)
                        (:name "totalMatches" :summary "旧文本在文件中的总匹配次数；指定 occurrence 时可大于 1" :source (:raw-result-field :total-matches) :type :integer :minimum 1)
                        (:name "selectedOccurrence" :summary "本次实际替换的命中序号（1-based）" :source (:raw-result-field :selected-occurrence) :type :integer :minimum 1)
                        (:name "matchStart" :summary "命中文本的起始字符偏移（0-based）" :source (:raw-result-field :match-start) :type :integer :minimum 0)
                        (:name "matchEnd" :summary "命中文本的结束字符偏移（exclusive）" :source (:raw-result-field :match-end) :type :integer :minimum 0)
                        (:name "matchedText" :summary "实际命中的原始文本片段" :source (:raw-result-field :matched-text) :type :string)
                        (:name "replacementText" :summary "用于替换的新文本片段" :source (:raw-result-field :replacement-text) :type :string)
                        (:name "beforePreview" :summary "替换前的局部预览片段" :source (:raw-result-field :before-preview) :type :string)
                        (:name "afterPreview" :summary "替换后的局部预览片段" :source (:raw-result-field :after-preview) :type :string)
                        (:name "diffPreview" :summary "替换前后合并展示的稳定 diff 预览片段" :source (:raw-result-field :diff-preview) :type :string)
                        (:name "writeApplied" :summary "是否已实际写回文件；preview 模式下为 null" :source (:raw-result-field :write-applied) :type :boolean :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "file edit failed output" :closed t
                 :json ((:name "error" :summary "文件编辑失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :file-write))))

(test find-tool-preserves-call-site-behavior
  (let ((tool-fn (cl-cc.tools:find-tool "echo-tool")))
    (is (functionp tool-fn))
    (is (equal (funcall tool-fn "registry-ok") "registry-ok"))))

(test register-tool-accepts-definition-object
  (unwind-protect
    (let* ((definition (make-instance 'cl-cc.models:tool-definition
                 :tool-id "test-tool"
                 :summary "test"
                 :handler-function #'identity
                 :input-schema '(:text "input")
                 :output-schema '(:text "output")
                :error-output-schema nil
                 :failure-modes '()
                 :permission-profile :default))
        (registered (cl-cc.tools:register-tool definition)))
      (is (eq registered definition))
      (is (eq (cl-cc.tools:find-tool-definition "test-tool") definition))
      (is (equal (funcall (cl-cc.tools:find-tool "test-tool") "value") "value")))
    (remhash "test-tool" cl-cc.tools:*tool-registry*)))

(test register-tool-parses-positional-handler-and-keywords
  (unwind-protect
      (let ((definition (cl-cc.tools:register-tool "test-tool-2"
                                                   #'identity
                                                   :summary "test-2"
                                                   :input-schema '(:text "input")
                                                   :output-schema '(:text "output")
                                                   :error-output-schema nil
                                                   :failure-modes '(:failed)
                                                   :permission-profile :default)))
        (is (typep definition 'cl-cc.models:tool-definition))
        (is (string= (cl-cc.models:tool-id definition) "test-tool-2"))
        (is (equal (funcall (cl-cc.tools:find-tool "test-tool-2") "value") "value"))
        (is (equal (cl-cc.models:tool-failure-modes definition) '(:failed))))
    (remhash "test-tool-2" cl-cc.tools:*tool-registry*)))

    (test define-tool-registers-declaratively
      (unwind-protect
        (let ((definition (cl-cc.tools:define-tool "test-tool-3" #'identity
                  (:summary "test-3")
                  (:input-schema '(:text "input"))
                  (:output-schema '(:text "output"))
                  (:error-output-schema nil)
                  (:failure-modes '())
                  (:permission-profile :default))))
        (is (typep definition 'cl-cc.models:tool-definition))
        (is (string= (cl-cc.models:tool-id definition) "test-tool-3"))
        (is (string= (cl-cc.models:tool-summary definition) "test-3"))
        (is (equal (funcall (cl-cc.tools:find-tool "test-tool-3") "value") "value")))
      (remhash "test-tool-3" cl-cc.tools:*tool-registry*)))