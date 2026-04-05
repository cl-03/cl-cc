;;;; src/core/command-schema-builders.lisp - 命令 schema/option 构造器
(in-package :cl-cc.core)

(defun %closed-json-output-schema (text-summary json-fields)
  `(:text ,text-summary
    :closed t
    :json ,json-fields))

(defun %duration-and-exit-code-output-fields (duration-summary)
  (list (%duration-seconds-schema-field "durationSeconds" duration-summary)
        (%exit-code-schema-field "命令退出码")))

(defun %duration-seconds-schema-field (name summary)
  (schema-field name summary :type :number :minimum 0))

(defun %enum-string-schema-field (name summary enum-values &rest properties)
  (append (schema-field name summary :type :string :enum enum-values)
          properties))

(defun %nullable-nonnegative-integer-schema-field (name summary)
  (schema-field name summary :type :integer :minimum 0 :required nil :nullable t))

(defun %exit-code-schema-field (summary)
  (schema-field "exitCode" summary :type :integer :minimum 0 :maximum 255))

(defun %success-status-schema-field (summary)
  (%enum-string-schema-field "status" summary '("success")))

(defun %session-status-schema-field (summary)
  (%enum-string-schema-field "sessionStatus" summary '("active") :required nil :nullable t))

(defun %docs-sync-status-schema-field ()
  (%enum-string-schema-field "status" "同步状态: synced、in-sync 或 drift" '("synced" "in-sync" "drift")))

(defun %docs-sync-reference-check-option ()
  '(:flags ("--check")
    :key :check-only
    :flag t
    :summary "仅检查命令参考是否需要同步，不写回文件"))

(defun %docs-sync-reference-auth-scope-option ()
  '(:flags ("--auth-scope")
    :key :auth-scope
    :type (:enum "all" "public" "requires-auth")
    :default "all"
    :value-name "<auth-scope>"
    :summary "生成或检查指定 auth 视图的命令参考: all、public 或 requires-auth"))

(defun %command-group-scope-values ()
  '("all" "meta" "chat" "session" "automation" "docs"))

(defun %docs-sync-reference-group-scope-option ()
  `(:flags ("--group-scope")
    :key :group-scope
    :type (:enum ,@(%command-group-scope-values))
    :default "all"
    :value-name "<group-scope>"
    :summary "生成或检查指定命令分组视图: all、meta、chat、session、automation 或 docs"))

(defun %session-persistence-output-fields ()
  (list (schema-field "sessionPath" "若请求持久化，则为写入的快照路径" :type :string :required nil :nullable t)
        (schema-field "saved" "是否已将新会话快照写入 sessionPath" :type :boolean :required nil :nullable t)))

(defun %session-input-output-field (summary)
  (schema-field "input" summary :type :string :required nil :nullable t))

(defun %session-execution-status-output-field (summary)
  (%enum-string-schema-field "executionStatus" summary '("success" "failed")))

(defun %session-execution-result-output-field (summary)
  (schema-field "result" summary :type :string))

(defun %session-execution-tool-results-output-field ()
  (schema-field "toolResults"
                "本次 session run 的逐工具尝试记录"
                :type :array
                :min-items 1
                :closed t
                :collection t
                :fields (%run-tool-result-schema-fields)))

(defun %session-selected-tools-output-field ()
  (schema-field "selectedTools"
                "本次 session run 最终采用的工具顺序"
                :type :array
                :required nil
                :nullable t
                :min-items 1))

(defun %session-execution-plan-output-field ()
  (schema-field "executionPlan"
                "本次 session run 的归一化执行计划，包含每步工具与输入"
                :type :array
                :required nil
                :nullable t
                :min-items 1
                :closed t
                :collection t
                :fields (list (schema-field "tool" "计划步骤对应的工具标识" :type :string)
                              (schema-field "input" "计划步骤归一化后的工具输入" :required nil :nullable t))))

(defun %session-list-entry-output-fields ()
  (list (schema-field "sessionId" "会话 ID" :type :string)
        (schema-field "sessionPath" "会话快照路径" :type :string)
        (schema-field "createdAt" "会话创建时间快照字段" :type :string :required nil :nullable t)
        (schema-field "updatedAt" "会话最近更新时间快照字段" :type :string :required nil :nullable t)
        (%nullable-nonnegative-integer-schema-field "historyIndex" "会话当前历史索引；缺失时为 null")
        (schema-field "sessionStatus" "会话状态" :type :string)
        (schema-field "taskCount" "该会话已知后台任务快照数量" :type :integer :minimum 0)
        (schema-field "lastInput" "最近一次 session run 输入；缺失时为 null" :type :string :required nil :nullable t)
        (schema-field "lastResult" "最近一次稳定执行结果；缺失时为 null" :type :string :required nil :nullable t)
        (schema-field "fileSizeBytes" "快照文件大小（字节）；不可用时为 null" :type :integer :minimum 0 :required nil :nullable t)
        (schema-field "fileUpdatedAt" "快照文件最后修改时间，UTC ISO-8601 格式；不可用时为 null" :type :string :required nil :nullable t)
        (schema-field "version" "快照格式版本" :type :string :required nil :nullable t)))

(defun %session-list-command-output-schema ()
  (%closed-json-output-schema
   "session list message"
   (append (list (%success-status-schema-field "结果状态，当前固定为 success")
                 (schema-field "sessionDirectory" "本次扫描的会话目录" :type :string)
                 (schema-field "usedDefaultDirectory" "是否使用了默认会话目录" :type :boolean)
                 (schema-field "sessionCount" "扫描到的有效会话数量" :type :integer :minimum 0)
                 (schema-field "sessions"
                               "会话快照元数据列表"
                               :type :array
                               :collection t
                               :closed t
                               :fields (%session-list-entry-output-fields)))
           (%duration-and-exit-code-output-fields "本次 session list 执行时长（秒）"))))

(defun %session-task-output-fields ()
  (list (schema-field "taskId" "后台任务标识" :type :string)
        (schema-field "type" "后台任务类型；当前固定为 shell" :type :string)
        (schema-field "status" "后台任务当前状态" :type :string)
        (schema-field "running" "后台任务当前是否仍在运行" :type :boolean)
        (schema-field "stopped" "后台任务是否已被显式停止" :type :boolean)
        (schema-field "command" "后台任务对应的 shell 命令" :type :string)
        (schema-field "directory" "后台任务执行目录" :type :string)
        (schema-field "outputPath" "后台任务输出日志路径" :type :string)
        (%nullable-nonnegative-integer-schema-field "processId" "后台任务底层进程 ID；不可用时为 null")
        (%nullable-nonnegative-integer-schema-field "exitCode" "后台任务退出码；运行中或不可用时为 null")
        (schema-field "startedAt" "后台任务开始时间，UTC ISO-8601 格式" :type :string :required nil :nullable t)
        (schema-field "stoppedAt" "后台任务显式停止时间；未停止时为 null" :type :string :required nil :nullable t)
        (schema-field "finishedAt" "后台任务自然结束时间；运行中或显式停止时为 null" :type :string :required nil :nullable t)
        (schema-field "stallDetected" "后台任务是否检测到疑似交互 stall；未检测到时为 false" :type :boolean)
        (schema-field "stallDetectedAt" "后台任务首次检测到疑似 stall 的时间；未检测到时为 null" :type :string :required nil :nullable t)
        (schema-field "stallPromptLine" "后台任务触发 stall 检测时的最后一行输出；未检测到时为 null" :type :string :required nil :nullable t)
        (schema-field "terminationReason" "后台任务终止原因；运行中时为 null" :type :string :required nil :nullable t)
        (schema-field "endedAt" "后台任务终止时间；运行中时为 null" :type :string :required nil :nullable t)))

(defun %session-tasks-output-field ()
  (schema-field "tasks"
                "当前会话已知的后台任务快照列表；无任务时该字段可省略"
                :type :array
                :required nil
                :collection t
                :closed t
                :fields (%session-task-output-fields)))

(defun %session-git-context-output-fields ()
  (list (schema-field "gitRoot" "本次 session run 检测到的 Git 根目录；未处于 Git 仓库时为 null" :type :string :required nil :nullable t)
        (schema-field "gitBranch" "本次 session run 检测到的 Git 当前分支；无法识别时为 null" :type :string :required nil :nullable t)
        (schema-field "gitDirty" "当前 Git 工作树是否存在未提交改动；未处于 Git 仓库时为 null" :type :boolean :required nil :nullable t)
        (schema-field "gitStatusLines" "`git status --short` 的逐行快照；仓库干净时为空数组，未处于 Git 仓库时为 null" :type :array :required nil :nullable t)
        (schema-field "gitRecentCommits" "最近的 Git commit 摘要列表；未处于 Git 仓库时为 null" :type :array :required nil :nullable t)))

(defun %session-output-json-fields (session-id-summary history-index-summary session-status-summary duration-summary
                                      &key extra-fields)
  (append (list (%success-status-schema-field "结果状态，当前固定为 success")
                (schema-field "sessionId" session-id-summary :type :string)
                (%nullable-nonnegative-integer-schema-field "historyIndex" history-index-summary)
          (%session-status-schema-field session-status-summary)
          (%session-tasks-output-field))
          extra-fields
          (%duration-and-exit-code-output-fields duration-summary)))

(defun %session-output-schema (text-summary session-id-summary history-index-summary session-status-summary duration-summary
                                &key extra-fields)
  (%closed-json-output-schema
   text-summary
   (%session-output-json-fields session-id-summary
                                history-index-summary
                                session-status-summary
                                duration-summary
                                :extra-fields extra-fields)))

(defun %single-required-positional (name)
  (list :name name :required t))

(defun %repeatable-required-positional (name)
  (append (%single-required-positional name)
          '(:repeatable t)))

(defun %run-fixture-status-values ()
  '("success" "partial" "failed" "denied" "not-found"))

(defun %run-tool-status-values ()
  '("success" "failed" "denied" "not-found"))

(defun %run-error-code-values ()
  '("FAIL" "PERMISSION-DENIED" "TOOL-NOT-FOUND" "FILE-READ-FAILED" "DIRECTORY-LIST-FAILED"
    "FILE-WRITE-FAILED" "FILE-EDIT-FAILED" "GREP-SEARCH-FAILED" "SHELL-EXECUTION-FAILED"))

(defun %output-format-option (&key default-when)
  (append '(:flags ("-o" "--output-format")
            :key :output-format
            :type (:enum "text" "json")
            :default "text"
            :value-name "<output-format>"
            :summary "指定输出格式: text 或 json")
          (when default-when
            (list :default-when default-when))))

(defun %string-value-option (flags key value-name summary &key repeatable)
  (append (list :flags flags
                :key key
                :type :string
                :value-name value-name
                :summary summary)
          (when repeatable
            (list :repeatable t))))

(defun %integer-value-option (flags key value-name summary)
  (list :flags flags
        :key key
        :type :integer
        :value-name value-name
        :summary summary))

(defun %session-id-option ()
  (%string-value-option '("-i" "--session-id")
                        :session-id
                        "<session-id>"
                        "显式指定新会话 ID"))

(defun %session-path-option ()
  (%string-value-option '("--session-path")
                        :session-path
                        "<session-path>"
                        "创建会话后立即将快照写入指定路径"))

(defun %session-run-path-option ()
  (%string-value-option '("--session-path")
                        :session-path
                        "<session-path>"
                        "执行后将更新后的快照写入指定路径"))

(defun %session-dir-option ()
  (%string-value-option '("--session-dir")
                        :session-dir
                        "<session-dir>"
                        "指定 session list 扫描的目录；未提供时使用默认会话目录"))

(defun %help-auth-scope-option ()
  '(:flags ("--auth-scope")
    :key :auth-scope
    :type (:enum "all" "public" "requires-auth")
    :default "all"
    :value-name "<auth-scope>"
    :summary "过滤帮助视图: all、public 或 requires-auth"))

(defun %help-group-scope-option ()
  `(:flags ("--group-scope")
    :key :group-scope
    :type (:enum ,@(%command-group-scope-values))
    :default "all"
    :value-name "<group-scope>"
    :summary "过滤帮助分组视图: all、meta、chat、session、automation 或 docs"))

(defun %history-index-option ()
  (%integer-value-option '("--history-index")
                         :history-index
                         "<history-index>"
                         "设置初始历史索引"))

(defun %tool-ids-option ()
  (%string-value-option '("-t" "--tool")
                        :tool-ids
                        "<tool-id>"
                        "覆盖自动工具选择并按给定顺序执行"
                        :repeatable t))

(defun %pretty-json-option ()
  '(:flags ("--pretty")
    :key :pretty-json
    :flag t
    :summary "以多行缩进格式输出 JSON"
    :requires ((:key :output-format :value "json"))
    :conflicts-with (:compact-json)))

(defun %compact-json-option ()
  '(:flags ("--compact")
    :key :compact-json
    :flag t
    :summary "以紧凑单行格式输出 JSON"
    :requires ((:key :output-format :value "json"))
    :conflicts-with (:pretty-json)))

(defun %run-fixture-output-format-defaults ()
  '((:when ((:key :pretty-json)) :value "json")
    (:when ((:key :compact-json)) :value "json")))

(defun %run-top-level-status-schema-field ()
  (schema-field "status"
                "聚合结果状态"
                :type :string
                :enum (%run-fixture-status-values)
                :enum-when-zero-field '(:field "exitCode" :values ("success"))
                :enum-when-nonzero-field '(:field "exitCode" :values ("partial" "failed" "denied" "not-found"))))

(defun %run-result-status-schema-field ()
  (%enum-string-schema-field "status" "该 fixture 的聚合状态" (%run-fixture-status-values)))

(defun %run-tool-status-schema-field ()
  (%enum-string-schema-field "status" "该次工具尝试状态" (%run-tool-status-values)))

(defun %run-error-code-schema-field ()
  (schema-field "errorCode"
                "稳定错误码，成功时为 null"
                :type :string
                :required nil
                :nullable t
                :enum (%run-error-code-values)))

(defun %run-status-count-field (name summary &optional matches-status)
  (append (schema-field name summary :type :integer :minimum 0)
          (when matches-status
            (list :equals-field-when-value
                  (list :when-field "status" :value matches-status :field "fixtureCount")))))

(defun %run-status-counts-schema-fields ()
  (list (%run-status-count-field "success" "成功 fixture 数量" "success")
        (%run-status-count-field "failed" "失败 fixture 数量" "failed")
        (%run-status-count-field "partial" "混合结果 fixture 数量")
        (%run-status-count-field "denied" "权限拒绝 fixture 数量" "denied")
        (%run-status-count-field "not-found" "工具未找到 fixture 数量" "not-found")
        (%run-status-count-field "unknown" "未归类 fixture 数量")))

(defun %run-tool-result-schema-fields ()
  (list (schema-field "toolId" "工具标识" :type :string)
  (%run-tool-status-schema-field)
        (%duration-seconds-schema-field "durationSeconds" "该次工具尝试执行时长（秒）")
        (schema-field "output"
                      "按工具 output-schema 或 error-output-schema 派生的结构化输出，字段集合由工具定义直接提供"
                      :type :object
                      :closed t
                      :required nil
                      :nullable t
                      :tool-schema-refs '((:tool-id "echo-tool" :kind :output)
                                          (:tool-id "failing-tool" :kind :error-output)
                                          (:tool-id "file-read-tool" :kind :output)
                                          (:tool-id "file-read-tool" :kind :error-output)
                                          (:tool-id "directory-list-tool" :kind :output)
                                          (:tool-id "directory-list-tool" :kind :error-output)
                                          (:tool-id "grep-tool" :kind :output)
                                          (:tool-id "grep-tool" :kind :error-output)
                                          (:tool-id "file-write-tool" :kind :output)
                                          (:tool-id "file-write-tool" :kind :error-output)
                                          (:tool-id "file-edit-tool" :kind :output)
                                          (:tool-id "file-edit-tool" :kind :error-output)
                                          (:tool-id "shell-tool" :kind :output)
                                          (:tool-id "shell-tool" :kind :error-output)
                                          (:tool-id "shell-task-list-tool" :kind :output)
                                          (:tool-id "shell-task-list-tool" :kind :error-output)
                                          (:tool-id "shell-task-detail-tool" :kind :output)
                                          (:tool-id "shell-task-detail-tool" :kind :error-output)
                                          (:tool-id "shell-task-cleanup-tool" :kind :output)
                                          (:tool-id "shell-task-cleanup-tool" :kind :error-output)
                                          (:tool-id "shell-task-tool" :kind :output)
                                          (:tool-id "shell-task-tool" :kind :error-output)
                                          (:tool-id "shell-task-output-tool" :kind :output)
                                          (:tool-id "shell-task-output-tool" :kind :error-output)))
        (schema-field "error" "失败时的人类可读摘要，成功时为 null" :type :string :required nil :nullable t)
        (%run-error-code-schema-field)))

(defun %run-result-schema-fields ()
  (list (schema-field "fixtureId" "fixture 标识" :type :string)
        (%run-result-status-schema-field)
        (%duration-seconds-schema-field "durationSeconds" "该 fixture 执行时长（秒）")
        (schema-field "result" "兼容既有 golden 的稳定文本摘要" :type :string)
        (schema-field "toolResults"
                      "逐工具尝试记录"
                      :type :array
                      :min-items 1
                      :closed t
                      :collection t
                      :fields (%run-tool-result-schema-fields))))

(defun %run-fixture-output-json-fields ()
  (list (%run-top-level-status-schema-field)
        (schema-field "fixtureCount"
                      "本次执行的 fixture 数量"
                      :type :integer
                      :minimum 0
                      :equals-collection-size-of "results"
                      :equals-sum-of-fields '(:fields ("statusCounts.success"
                                                      "statusCounts.failed"
                                                      "statusCounts.partial"
                                                      "statusCounts.denied"
                                                      "statusCounts.not-found"
                                                      "statusCounts.unknown")))
        (schema-field "successfulCount" "成功 fixture 数量" :type :integer :minimum 0 :equals-field "statusCounts.success")
        (schema-field "failedCount" "失败 fixture 数量" :type :integer :minimum 0 :equals-field "statusCounts.failed")
        (%duration-seconds-schema-field "durationSeconds" "本次 run 聚合执行时长（秒）")
        (schema-field "statusCounts"
                      "各状态计数映射"
                      :type :object
                      :closed t
                      :fields (%run-status-counts-schema-fields))
        (schema-field "ok" "是否全部成功" :type :boolean :true-when-zero-field "exitCode")
        (%exit-code-schema-field "命令退出码")
        (schema-field "results"
                      "逐 fixture 的结果记录，包含稳定文本摘要与 toolResults"
                      :type :array
                      :min-items 1
                      :closed t
                      :collection t
                      :fields (%run-result-schema-fields))))