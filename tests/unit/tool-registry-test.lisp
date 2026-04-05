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
               '(:text "path string with optional line range(s)" :closed t
                 :json ((:name "path" :summary "待读取的文件路径" :type :string)
                        (:name "startLine" :summary "起始行号，缺省时读取整个文件" :type :integer :minimum 1 :required nil :nullable t)
                        (:name "endLine" :summary "结束行号，缺省时等于 startLine" :type :integer :minimum 1 :required nil :nullable t)
                        (:name "ranges" :summary "多段行范围列表；提供时按给定顺序拼接输出且自动去重重复行" :type :array :required nil :nullable t :collection t :closed t
                         :fields ((:name "startLine" :summary "行范围起始行号" :type :integer :minimum 1)
                                  (:name "endLine" :summary "行范围结束行号" :type :integer :minimum 1)))))))
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

(test glob-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "glob-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "glob-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "在指定目录树下按 glob 模式匹配文件，用于最小可用的文件发现"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "glob pattern or `pattern :: root`" :closed t
                 :json ((:name "pattern" :summary "待匹配的 glob 模式" :type :string)
                        (:name "root" :summary "搜索根路径，缺省为当前工作目录" :type :string :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "matched file paths" :closed t
                 :json ((:name "result" :summary "匹配结果文本，每行一条相对路径记录" :source :raw-result :type :string)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "glob search failed output" :closed t
                 :json ((:name "error" :summary "glob 匹配失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :file-read))))

(test todo-write-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "todo-write-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "todo-write-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "更新当前会话的结构化待办列表，用于最小可用的进度跟踪"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "todo list update request" :closed t
                 :json ((:name "todos" :summary "更新后的待办列表" :type :array :closed t :collection t :fields ((:name "content" :summary "待办项内容" :type :string)
                                                                                                                    (:name "status" :summary "待办项状态" :type :string :enum ("pending" "in_progress" "completed"))
                                                                                                                    (:name "activeForm" :summary "待办项执行中的描述" :type :string)))))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "todo write result" :closed t
                 :json ((:name "result" :summary "待办列表更新摘要" :source (:raw-result-field :summary) :type :string)
                        (:name "oldTodos" :summary "更新前的待办列表" :source (:raw-result-field :old-todos) :type :array :required nil :nullable t :closed t :collection t :fields ((:name "content" :summary "待办项内容" :type :string)
                                                                                                                                                                                       (:name "status" :summary "待办项状态" :type :string)
                                                                                                                                                                                       (:name "activeForm" :summary "待办项执行中的描述" :type :string)))
                        (:name "newTodos" :summary "更新后的待办列表" :source (:raw-result-field :new-todos) :type :array :closed t :collection t :fields ((:name "content" :summary "待办项内容" :type :string)
                                                                                                                                                                (:name "status" :summary "待办项状态" :type :string)
                                                                                                                                                                (:name "activeForm" :summary "待办项执行中的描述" :type :string)))))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "todo write failed output" :closed t
                 :json ((:name "error" :summary "待办列表写入失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :default))))

(test shell-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "shell-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "shell-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "执行受控 shell 命令，用于最小可用的终端/命令行操作"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "shell command request" :closed t
                 :json ((:name "command" :summary "待执行的 shell 命令字符串" :type :string)
                        (:name "directory" :summary "命令执行目录，缺省为当前工作目录" :type :string :required nil :nullable t)
                        (:name "background" :summary "是否以后台模式启动命令；缺省为 false" :type :boolean :required nil :nullable t)
                        (:name "timeoutSeconds" :summary "超时时间（秒），缺省为不设超时" :type :number :minimum 0 :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "shell execution result" :closed t
                 :json ((:name "result" :summary "shell 执行摘要" :source (:raw-result-field :summary) :type :string)
                        (:name "command" :summary "本次执行的 shell 命令" :source (:raw-result-field :command) :type :string)
                        (:name "directory" :summary "本次命令实际执行目录" :source (:raw-result-field :directory) :type :string)
                        (:name "background" :summary "本次执行是否以后台模式启动" :source (:raw-result-field :background) :type :boolean)
                        (:name "backgroundTaskId" :summary "后台任务标识；前台模式下为 null" :source (:raw-result-field :background-task-id) :type :string :required nil :nullable t)
                        (:name "outputPath" :summary "后台输出日志路径；前台模式下为 null" :source (:raw-result-field :output-path) :type :string :required nil :nullable t)
                        (:name "processId" :summary "底层进程 ID；不可用时为 null" :source (:raw-result-field :process-id) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "stdout" :summary "shell 标准输出文本；后台模式下为 null" :source (:raw-result-field :stdout) :type :string :required nil :nullable t)
                        (:name "stderr" :summary "shell 标准错误文本；后台模式下为 null" :source (:raw-result-field :stderr) :type :string :required nil :nullable t)
                        (:name "exitCode" :summary "shell 进程退出码；超时终止时为 null" :source (:raw-result-field :exit-code) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "timedOut" :summary "本次执行是否因超时被终止" :source (:raw-result-field :timed-out) :type :boolean)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "shell execution failed output" :closed t
                 :json ((:name "error" :summary "shell 执行失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :shell))))

(test shell-task-list-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "shell-task-list-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "shell-task-list-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "列出当前后台 shell 任务，用于最小可用的后台任务发现入口"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "shell task list request" :closed t
                 :json ((:name "all" :summary "是否列出全部后台任务，当前缺省且固定为 true" :type :boolean :required nil :nullable t)
                        (:name "status" :summary "按状态过滤后台任务，缺省为 all" :type :string :enum ("all" "running" "stopped" "completed" "failed") :required nil :nullable t)
                        (:name "taskIdPrefix" :summary "按任务 ID 前缀过滤后台任务" :type :string :required nil :nullable t)
                        (:name "directoryContains" :summary "按执行目录包含指定片段过滤后台任务" :type :string :required nil :nullable t)
                        (:name "terminationReason" :summary "按后台任务终止原因过滤，支持 exit、error-exit、stop、interrupt" :type :string :enum ("exit" "error-exit" "stop" "interrupt") :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "shell task list result" :closed t
                 :json ((:name "result" :summary "后台 shell 任务列表摘要" :source (:raw-result-field :summary) :type :string)
                        (:name "statusFilter" :summary "本次任务列表实际应用的状态过滤器" :source (:raw-result-field :status-filter) :type :string)
                        (:name "taskIdPrefixFilter" :summary "本次任务列表实际应用的任务 ID 前缀过滤器；未指定时为 null" :source (:raw-result-field :task-id-prefix-filter) :type :string :required nil :nullable t)
                        (:name "directoryContainsFilter" :summary "本次任务列表实际应用的目录片段过滤器；未指定时为 null" :source (:raw-result-field :directory-contains-filter) :type :string :required nil :nullable t)
                        (:name "terminationReasonFilter" :summary "本次任务列表实际应用的终止原因过滤器；未指定时为 null" :source (:raw-result-field :termination-reason-filter) :type :string :required nil :nullable t)
                        (:name "totalCount" :summary "当前后台任务总数" :source (:raw-result-field :total-count) :type :integer :minimum 0)
                        (:name "runningCount" :summary "当前运行中的后台任务数量" :source (:raw-result-field :running-count) :type :integer :minimum 0)
                        (:name "stoppedCount" :summary "当前已停止的后台任务数量" :source (:raw-result-field :stopped-count) :type :integer :minimum 0)
                        (:name "completedCount" :summary "当前已完成的后台任务数量" :source (:raw-result-field :completed-count) :type :integer :minimum 0)
                        (:name "failedCount" :summary "当前失败的后台任务数量" :source (:raw-result-field :failed-count) :type :integer :minimum 0)
                        (:name "tasks" :summary "后台任务列表，每项包含 taskId、status、stallDetected、terminationReason、endedAt、command 等字段" :source (:raw-result-field :tasks) :type :array :closed t :collection t :fields ((:name "taskId" :summary "后台任务标识" :type :string) (:name "status" :summary "后台任务当前状态" :type :string) (:name "running" :summary "后台任务当前是否仍在运行" :type :boolean) (:name "stopped" :summary "后台任务是否被显式停止" :type :boolean) (:name "command" :summary "后台任务对应的 shell 命令" :type :string) (:name "directory" :summary "后台任务的执行目录" :type :string) (:name "outputPath" :summary "后台任务输出日志路径" :type :string) (:name "processId" :summary "后台任务底层进程 ID；不可用时为 null" :type :integer :minimum 0 :required nil :nullable t) (:name "exitCode" :summary "后台任务退出码；运行中或不可用时为 null" :type :integer :minimum 0 :required nil :nullable t) (:name "stallDetected" :summary "后台任务是否疑似卡在交互提示；未检测到时为 false" :type :boolean) (:name "stallDetectedAt" :summary "后台任务首次检测到疑似卡住的时间，UTC ISO-8601 格式；未检测到时为 null" :type :string :required nil :nullable t) (:name "stallPromptLine" :summary "后台任务触发 stall 检测时的最后一行输出；未检测到时为 null" :type :string :required nil :nullable t) (:name "terminationReason" :summary "后台任务终止原因；运行中时为 null" :type :string :required nil :nullable t) (:name "endedAt" :summary "后台任务终止时间，UTC ISO-8601 格式；运行中时为 null" :type :string :required nil :nullable t)))))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "shell task list failed output" :closed t
                 :json ((:name "error" :summary "后台 shell 任务列表失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :shell))))

(test shell-task-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "shell-task-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "shell-task-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "查询单个后台 shell 任务，或批量中断/停止/等待多个后台 shell 任务，用于最小可用的后台任务观察与控制"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "shell task request" :closed t
                 :json ((:name "taskId" :summary "单个后台任务标识；与 taskIds 二选一" :type :string :required nil :nullable t)
                        (:name "taskIds" :summary "批量 interrupt/stop/wait 的后台任务标识列表；与 taskId 二选一" :type :array :required nil :nullable t)
                        (:name "action" :summary "动作类型，缺省为 status" :type :string :enum ("status" "interrupt" "stop" "wait") :required nil :nullable t)
                        (:name "timeoutSeconds" :summary "wait 动作的最长等待时间（秒），缺省为一直等待直到任务结束" :type :number :minimum 0 :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "shell task result" :closed t
                 :json ((:name "result" :summary "后台 shell 任务摘要" :source (:raw-result-field :summary) :type :string)
                        (:name "taskId" :summary "单任务模式下的后台任务标识；批量模式为 null" :source (:raw-result-field :task-id) :type :string :required nil :nullable t)
                        (:name "taskIds" :summary "批量模式下的后台任务标识列表；单任务模式为 null" :source (:raw-result-field :task-ids) :type :array :required nil :nullable t)
                        (:name "taskCount" :summary "本次操作覆盖的后台任务数量；单任务模式为 null" :source (:raw-result-field :task-count) :type :integer :minimum 1 :required nil :nullable t)
                        (:name "action" :summary "本次执行的任务动作" :source (:raw-result-field :action) :type :string)
                        (:name "status" :summary "后台任务当前状态；批量模式下为聚合状态，相异时为 mixed" :source (:raw-result-field :status) :type :string)
                        (:name "running" :summary "后台任务当前是否仍在运行；批量模式下表示是否仍有任务在运行" :source (:raw-result-field :running) :type :boolean)
                        (:name "stopped" :summary "后台任务是否被显式停止；批量模式下表示是否全部已停止" :source (:raw-result-field :stopped) :type :boolean)
                        (:name "command" :summary "单任务模式下后台任务对应的 shell 命令；批量模式为 null" :source (:raw-result-field :command) :type :string :required nil :nullable t)
                        (:name "directory" :summary "单任务模式下后台任务的执行目录；批量模式为 null" :source (:raw-result-field :directory) :type :string :required nil :nullable t)
                        (:name "outputPath" :summary "单任务模式下后台任务输出日志路径；批量模式为 null" :source (:raw-result-field :output-path) :type :string :required nil :nullable t)
                        (:name "processId" :summary "后台任务底层进程 ID；不可用时为 null" :source (:raw-result-field :process-id) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "exitCode" :summary "后台任务退出码；运行中或不可用时为 null" :source (:raw-result-field :exit-code) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "stallDetected" :summary "后台任务是否疑似卡在交互提示；未检测到时为 false" :source (:raw-result-field :stall-detected) :type :boolean)
                        (:name "stallDetectedAt" :summary "后台任务首次检测到疑似卡住的时间，UTC ISO-8601 格式；未检测到时为 null" :source (:raw-result-field :stall-detected-at) :type :string :required nil :nullable t)
                        (:name "stallPromptLine" :summary "后台任务触发 stall 检测时的最后一行输出；未检测到时为 null" :source (:raw-result-field :stall-prompt-line) :type :string :required nil :nullable t)
                        (:name "terminationReason" :summary "后台任务终止原因；运行中时为 null" :source (:raw-result-field :termination-reason) :type :string :required nil :nullable t)
                        (:name "endedAt" :summary "后台任务终止时间，UTC ISO-8601 格式；运行中时为 null" :source (:raw-result-field :ended-at) :type :string :required nil :nullable t)
                        (:name "runningCount" :summary "批量模式下仍在运行的后台任务数量；单任务模式为 null" :source (:raw-result-field :running-count) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "stoppedCount" :summary "批量模式下已停止的后台任务数量；单任务模式为 null" :source (:raw-result-field :stopped-count) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "completedCount" :summary "批量模式下已完成的后台任务数量；单任务模式为 null" :source (:raw-result-field :completed-count) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "failedCount" :summary "批量模式下已失败的后台任务数量；单任务模式为 null" :source (:raw-result-field :failed-count) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "tasks" :summary "批量模式下的逐任务结果数组；单任务模式为 null" :source (:raw-result-field :tasks) :type :array :required nil :nullable t :closed t :collection t :fields ((:name "taskId" :summary "后台任务标识" :type :string) (:name "action" :summary "本次执行的任务动作" :type :string) (:name "status" :summary "后台任务当前状态" :type :string) (:name "running" :summary "后台任务当前是否仍在运行" :type :boolean) (:name "stopped" :summary "后台任务是否被显式停止" :type :boolean) (:name "command" :summary "后台任务对应的 shell 命令" :type :string) (:name "directory" :summary "后台任务的执行目录" :type :string) (:name "outputPath" :summary "后台任务输出日志路径" :type :string) (:name "processId" :summary "后台任务底层进程 ID；不可用时为 null" :type :integer :minimum 0 :required nil :nullable t) (:name "exitCode" :summary "后台任务退出码；运行中或不可用时为 null" :type :integer :minimum 0 :required nil :nullable t) (:name "stallDetected" :summary "后台任务是否疑似卡在交互提示；未检测到时为 false" :type :boolean) (:name "stallDetectedAt" :summary "后台任务首次检测到疑似卡住的时间，UTC ISO-8601 格式；未检测到时为 null" :type :string :required nil :nullable t) (:name "stallPromptLine" :summary "后台任务触发 stall 检测时的最后一行输出；未检测到时为 null" :type :string :required nil :nullable t) (:name "terminationReason" :summary "后台任务终止原因；运行中时为 null" :type :string :required nil :nullable t) (:name "endedAt" :summary "后台任务终止时间，UTC ISO-8601 格式；运行中时为 null" :type :string :required nil :nullable t) (:name "timedOut" :summary "本次 wait 是否因达到 timeoutSeconds 而提前返回；非 wait 动作为 false" :type :boolean)))
                        (:name "timedOut" :summary "本次 wait 是否因达到 timeoutSeconds 而提前返回；非 wait 动作为 false" :source (:raw-result-field :timed-out) :type :boolean)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "shell task failed output" :closed t
                 :json ((:name "error" :summary "后台 shell 任务失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :shell))))

(test shell-task-cleanup-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "shell-task-cleanup-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "shell-task-cleanup-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "清理后台 shell 任务注册表中的非运行任务，用于最小可用的后台任务回收"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "shell task cleanup request" :closed t
                 :json ((:name "status" :summary "按状态清理后台任务，缺省为 all（即 stopped/completed/failed）" :type :string :enum ("all" "stopped" "completed" "failed") :required nil :nullable t)
                        (:name "terminationReason" :summary "按后台任务终止原因清理，支持 exit、error-exit、stop、interrupt" :type :string :enum ("exit" "error-exit" "stop" "interrupt") :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "shell task cleanup result" :closed t
                 :json ((:name "result" :summary "后台 shell 任务清理摘要" :source (:raw-result-field :summary) :type :string)
                        (:name "statusFilter" :summary "本次清理实际应用的状态过滤器" :source (:raw-result-field :status-filter) :type :string)
                        (:name "terminationReasonFilter" :summary "本次清理实际应用的终止原因过滤器；未指定时为 null" :source (:raw-result-field :termination-reason-filter) :type :string :required nil :nullable t)
                        (:name "removedCount" :summary "本次清理移除的后台任务数量" :source (:raw-result-field :removed-count) :type :integer :minimum 0)
                        (:name "remainingCount" :summary "清理完成后注册表中剩余的后台任务数量" :source (:raw-result-field :remaining-count) :type :integer :minimum 0)
                        (:name "removedTaskIds" :summary "本次清理移除的后台任务 ID 列表" :source (:raw-result-field :removed-task-ids) :type :array)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "shell task cleanup failed output" :closed t
                 :json ((:name "error" :summary "后台 shell 任务清理失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :shell))))

(test shell-task-detail-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "shell-task-detail-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "shell-task-detail-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "读取单个后台 shell 任务的详情，用于最小可用的生命周期观察入口"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "shell task detail request" :closed t
                 :json ((:name "taskId" :summary "后台任务标识" :type :string)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "shell task detail result" :closed t
                 :json ((:name "result" :summary "后台 shell 任务详情摘要" :source (:raw-result-field :summary) :type :string)
                        (:name "taskId" :summary "后台任务标识" :source (:raw-result-field :task-id) :type :string)
                        (:name "status" :summary "后台任务当前状态" :source (:raw-result-field :status) :type :string)
                        (:name "running" :summary "后台任务当前是否仍在运行" :source (:raw-result-field :running) :type :boolean)
                        (:name "stopped" :summary "后台任务是否被显式停止" :source (:raw-result-field :stopped) :type :boolean)
                        (:name "command" :summary "后台任务对应的 shell 命令" :source (:raw-result-field :command) :type :string)
                        (:name "directory" :summary "后台任务的执行目录" :source (:raw-result-field :directory) :type :string)
                        (:name "outputPath" :summary "后台任务输出日志路径" :source (:raw-result-field :output-path) :type :string)
                        (:name "processId" :summary "后台任务底层进程 ID；不可用时为 null" :source (:raw-result-field :process-id) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "exitCode" :summary "后台任务退出码；运行中或不可用时为 null" :source (:raw-result-field :exit-code) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "stallDetected" :summary "后台任务是否疑似卡在交互提示；未检测到时为 false" :source (:raw-result-field :stall-detected) :type :boolean)
                        (:name "stallDetectedAt" :summary "后台任务首次检测到疑似卡住的时间，UTC ISO-8601 格式；未检测到时为 null" :source (:raw-result-field :stall-detected-at) :type :string :required nil :nullable t)
                        (:name "stallPromptLine" :summary "后台任务触发 stall 检测时的最后一行输出；未检测到时为 null" :source (:raw-result-field :stall-prompt-line) :type :string :required nil :nullable t)
                        (:name "startedAt" :summary "后台任务开始时间，UTC ISO-8601 格式" :source (:raw-result-field :started-at) :type :string :required nil :nullable t)
                        (:name "stoppedAt" :summary "后台任务被显式停止的时间，未停止时为 null" :source (:raw-result-field :stopped-at) :type :string :required nil :nullable t)
                        (:name "finishedAt" :summary "后台任务自然结束时间，运行中或显式停止时为 null" :source (:raw-result-field :finished-at) :type :string :required nil :nullable t)
                        (:name "terminationReason" :summary "后台任务终止原因；运行中时为 null" :source (:raw-result-field :termination-reason) :type :string :required nil :nullable t)
                        (:name "endedAt" :summary "后台任务终止时间，UTC ISO-8601 格式；运行中时为 null" :source (:raw-result-field :ended-at) :type :string :required nil :nullable t)
                        (:name "durationSeconds" :summary "后台任务已运行或总运行时长（秒）" :source (:raw-result-field :duration-seconds) :type :number :minimum 0 :required nil :nullable t)
                        (:name "outputBytes" :summary "后台任务当前输出日志字节数；日志不可用时为 null" :source (:raw-result-field :output-bytes) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "outputLineCount" :summary "后台任务当前输出日志行数；日志不可用时为 null" :source (:raw-result-field :output-line-count) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "outputUpdatedAt" :summary "后台任务输出日志最后更新时间，UTC ISO-8601 格式；日志不可用时为 null" :source (:raw-result-field :output-updated-at) :type :string :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "shell task detail failed output" :closed t
                 :json ((:name "error" :summary "后台 shell 任务详情失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :shell))))

(test shell-task-output-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "shell-task-output-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "shell-task-output-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "读取单个后台 shell 任务输出窗口，或批量读取多个后台任务输出，并支持共享或按任务定制的窗口参数、短时 follow 与阻塞等待，用于最小可用的后台日志跟进"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "shell task output request" :closed t
                 :json ((:name "taskId" :summary "单任务模式下的后台任务标识；与 taskIds 二选一，批量模式可为 null" :type :string :required nil :nullable t)
                        (:name "taskIds" :summary "批量模式下的后台任务标识数组；单任务模式为 null" :type :array :required nil :nullable t :closed t :collection t
                         :fields ((:name "taskId" :summary "后台任务标识" :type :string)))
                        (:name "tasks" :summary "按任务定制批量输出请求的对象数组；与 taskId/taskIds 互斥，单任务模式为 null" :type :array :required nil :nullable t :closed t :collection t
                         :fields ((:name "taskId" :summary "后台任务标识" :type :string)
                                  (:name "lines" :summary "该任务待读取的输出行数；未指定时复用顶层默认值" :type :integer :minimum 1 :required nil :nullable t)
                                  (:name "startLine" :summary "该任务区间读取的起始行号；指定后进入 range 模式" :type :integer :minimum 1 :required nil :nullable t)
                                  (:name "endLine" :summary "该任务区间读取的结束行号；与 startLine 配套使用" :type :integer :minimum 1 :required nil :nullable t)
                                  (:name "followSeconds" :summary "该任务继续跟随日志输出的秒数；未指定时复用顶层默认值" :type :integer :minimum 0 :required nil :nullable t)
                                  (:name "waitUntilFinished" :summary "该任务是否阻塞直到后台任务结束；未指定时复用顶层默认值" :type :boolean :required nil :nullable t)))
                        (:name "lines" :summary "待读取的输出行数；tail 模式下缺省为 20" :type :integer :minimum 1 :required nil :nullable t)
                        (:name "startLine" :summary "区间读取的起始行号；指定后进入 range 模式" :type :integer :minimum 1 :required nil :nullable t)
                        (:name "endLine" :summary "区间读取的结束行号；与 startLine 配套使用" :type :integer :minimum 1 :required nil :nullable t)
                        (:name "followSeconds" :summary "继续跟随日志输出的秒数；未指定时不 follow" :type :integer :minimum 0 :required nil :nullable t)
                        (:name "waitUntilFinished" :summary "是否阻塞直到后台任务结束；与 followSeconds 互斥" :type :boolean :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "shell task output result" :closed t
                 :json ((:name "result" :summary "后台任务输出读取摘要" :source (:raw-result-field :summary) :type :string)
                        (:name "taskId" :summary "单任务模式下的后台任务标识；批量模式为 null" :source (:raw-result-field :task-id) :type :string :required nil :nullable t)
                        (:name "taskIds" :summary "批量模式下的后台任务标识数组；单任务模式为 null" :source (:raw-result-field :task-ids) :type :array :required nil :nullable t :closed t :collection t
                         :fields ((:name "taskId" :summary "后台任务标识" :type :string)))
                        (:name "taskCount" :summary "批量模式下的后台任务数量；单任务模式为 null" :source (:raw-result-field :task-count) :type :integer :minimum 1 :required nil :nullable t)
                        (:name "mode" :summary "本次输出读取模式：tail、range 或 mixed" :source (:raw-result-field :mode) :type :string)
                        (:name "status" :summary "后台任务当前状态；批量模式下若存在多种状态则为 mixed" :source (:raw-result-field :status) :type :string)
                        (:name "running" :summary "后台任务当前是否仍在运行；批量模式下表示是否仍有任一任务运行" :source (:raw-result-field :running) :type :boolean)
                        (:name "stopped" :summary "后台任务是否被显式停止；批量模式下表示是否全部已停止" :source (:raw-result-field :stopped) :type :boolean)
                        (:name "outputPath" :summary "单任务模式下后台任务输出日志路径；批量模式为 null" :source (:raw-result-field :output-path) :type :string :required nil :nullable t)
                        (:name "linesRequested" :summary "共享请求下的输出窗口行数；按任务定制且不一致时为 null" :source (:raw-result-field :lines-requested) :type :integer :minimum 1 :required nil :nullable t)
                        (:name "requestedStartLine" :summary "本次请求的起始行号；tail 模式下为 null" :source (:raw-result-field :requested-start-line) :type :integer :minimum 1 :required nil :nullable t)
                        (:name "requestedEndLine" :summary "本次请求的结束行号；tail 模式下为 null" :source (:raw-result-field :requested-end-line) :type :integer :minimum 1 :required nil :nullable t)
                        (:name "followSeconds" :summary "本次请求的 follow 秒数；未指定时为 null" :source (:raw-result-field :follow-seconds) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "waitUntilFinished" :summary "共享请求是否阻塞直到后台任务结束；按任务定制且不一致时为 null" :source (:raw-result-field :wait-until-finished) :type :boolean :required nil :nullable t)
                        (:name "startLine" :summary "单任务模式下本次返回内容的起始行号；无内容或批量模式时为 null" :source (:raw-result-field :start-line) :type :integer :minimum 1 :required nil :nullable t)
                        (:name "endLine" :summary "单任务模式下本次返回内容的结束行号；无内容或批量模式时为 null" :source (:raw-result-field :end-line) :type :integer :minimum 1 :required nil :nullable t)
                        (:name "totalLines" :summary "单任务模式下当前后台输出日志总行数；批量模式为 null" :source (:raw-result-field :total-lines) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "runningCount" :summary "批量模式下仍在运行的后台任务数量；单任务模式为 null" :source (:raw-result-field :running-count) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "stoppedCount" :summary "批量模式下已停止的后台任务数量；单任务模式为 null" :source (:raw-result-field :stopped-count) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "completedCount" :summary "批量模式下已完成的后台任务数量；单任务模式为 null" :source (:raw-result-field :completed-count) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "failedCount" :summary "批量模式下已失败的后台任务数量；单任务模式为 null" :source (:raw-result-field :failed-count) :type :integer :minimum 0 :required nil :nullable t)
                        (:name "tasks" :summary "批量模式下的逐任务输出结果数组；单任务模式为 null" :source (:raw-result-field :tasks) :type :array :required nil :nullable t :closed t :collection t
                         :fields ((:name "taskId" :summary "后台任务标识" :type :string)
                                  (:name "mode" :summary "本次输出读取模式：tail 或 range" :type :string)
                                  (:name "status" :summary "后台任务当前状态" :type :string)
                                  (:name "running" :summary "后台任务当前是否仍在运行" :type :boolean)
                                  (:name "stopped" :summary "后台任务是否被显式停止" :type :boolean)
                                  (:name "outputPath" :summary "后台任务输出日志路径" :type :string)
                                  (:name "linesRequested" :summary "本次请求的输出窗口行数" :type :integer :minimum 1)
                                  (:name "requestedStartLine" :summary "本次请求的起始行号；tail 模式下为 null" :type :integer :minimum 1 :required nil :nullable t)
                                  (:name "requestedEndLine" :summary "本次请求的结束行号；tail 模式下为 null" :type :integer :minimum 1 :required nil :nullable t)
                                  (:name "followSeconds" :summary "本次请求的 follow 秒数；未指定时为 null" :type :integer :minimum 0 :required nil :nullable t)
                                  (:name "waitUntilFinished" :summary "本次请求是否阻塞直到后台任务结束" :type :boolean)
                                  (:name "startLine" :summary "本次返回内容的起始行号；无内容时为 null" :type :integer :minimum 1 :required nil :nullable t)
                                  (:name "endLine" :summary "本次返回内容的结束行号；无内容时为 null" :type :integer :minimum 1 :required nil :nullable t)
                                  (:name "totalLines" :summary "当前后台输出日志总行数" :type :integer :minimum 0)
                                  (:name "content" :summary "按绝对行号编号后的输出内容" :type :string)))
                        (:name "content" :summary "单任务模式下按绝对行号编号后的输出内容；批量模式为 null" :source (:raw-result-field :content) :type :string :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-error-output-schema definition)
               '(:text "shell task output failed output" :closed t
                 :json ((:name "error" :summary "后台 shell 任务输出失败摘要消息" :source :error-message :type :string)
                        (:name "code" :summary "稳定错误码" :source :error-code :type :string)))))
    (is (eq (cl-cc.models:tool-permission-profile definition) :shell))))

(test directory-list-tool-metadata
  (let ((definition (cl-cc.tools:find-tool-definition "directory-list-tool")))
    (is (typep definition 'cl-cc.models:tool-definition))
    (is (string= (cl-cc.models:tool-id definition) "directory-list-tool"))
    (is (string= (cl-cc.models:tool-summary definition) "列出指定目录的子项，用于最小可用的只读目录检索"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "path string with optional recursive/depth/contains modifiers" :closed t
                 :json ((:name "path" :summary "待列举的目录路径" :type :string)
                        (:name "recursive" :summary "是否递归列举子目录，缺省为 false" :type :boolean :required nil :nullable t)
                        (:name "depth" :summary "递归列举的最大深度，缺省为不限制" :type :integer :required nil :nullable t :minimum 1)
                        (:name "contains" :summary "仅返回路径中包含该子串的条目，缺省为不过滤" :type :string :required nil :nullable t)))))
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
    (is (string= (cl-cc.models:tool-summary definition) "替换指定文件中的文本片段，用于最小可用的原位编辑"))
    (is (equal (cl-cc.models:tool-input-schema definition)
               '(:text "edit request" :closed t
                 :json ((:name "path" :summary "待编辑的文件路径" :type :string)
                        (:name "oldText" :summary "期望被替换的原始文本；默认按精确文本匹配，useRegex 为 true 时按正则表达式解释" :type :string)
                        (:name "newText" :summary "替换后的新文本，可为空字符串；useRegex 为 true 时支持 `$1` / `\\1` 形式的捕获组引用" :type :string)
                        (:name "occurrence" :summary "当旧文本出现多次时，指定要替换的第几处命中（1-based）" :type :integer :minimum 1 :required nil :nullable t)
                      (:name "replaceAll" :summary "是否替换全部命中；与 occurrence 互斥，缺省为 false" :type :boolean :required nil :nullable t)
                      (:name "lineContext" :summary "生成 lineDiffPreview 时保留的上下文行数，缺省为 1" :type :integer :minimum 0 :required nil :nullable t)
                      (:name "ignoreCase" :summary "是否忽略大小写；缺省为 false" :type :boolean :required nil :nullable t)
                      (:name "useRegex" :summary "是否将 oldText 作为正则表达式解释；缺省为 false" :type :boolean :required nil :nullable t)
                      (:name "multiline" :summary "是否启用正则多行模式（^/$ 按行匹配）；缺省为 false" :type :boolean :required nil :nullable t)
                      (:name "dotAll" :summary "是否启用正则 dotAll 模式（`.` 可跨换行匹配）；缺省为 false" :type :boolean :required nil :nullable t)
                      (:name "wholeWord" :summary "是否要求左右两侧都为单词边界；缺省为 false" :type :boolean :required nil :nullable t)
                      (:name "leftWordBoundary" :summary "是否要求命中左侧为单词边界；缺省为 false" :type :boolean :required nil :nullable t)
                      (:name "rightWordBoundary" :summary "是否要求命中右侧为单词边界；缺省为 false" :type :boolean :required nil :nullable t)
                        (:name "preview" :summary "是否只预览替换摘要而不落盘，缺省为 false" :type :boolean :required nil :nullable t)))))
    (is (equal (cl-cc.models:tool-output-schema definition)
               '(:text "edit summary" :closed t
                 :json ((:name "result" :summary "文件编辑结果摘要" :source (:raw-result-field :summary) :type :string)
                        (:name "path" :summary "本次编辑目标文件路径" :source (:raw-result-field :path) :type :string)
                        (:name "preview" :summary "是否为预览模式；普通写回路径下为 null" :source (:raw-result-field :preview) :type :boolean :required nil :nullable t)
                        (:name "matchCount" :summary "本次实际替换的命中数量" :source (:raw-result-field :match-count) :type :integer :minimum 1)
                        (:name "totalMatches" :summary "旧文本在文件中的总匹配次数；指定 occurrence 时可大于 1" :source (:raw-result-field :total-matches) :type :integer :minimum 1)
                        (:name "selectedOccurrence" :summary "本次实际替换的命中序号（1-based）；replaceAll 模式下为 null" :source (:raw-result-field :selected-occurrence) :type :integer :minimum 1 :required nil :nullable t)
                        (:name "lineContext" :summary "本次生成 lineDiffPreview 时实际采用的上下文行数" :source (:raw-result-field :line-context) :type :integer :minimum 0)
                        (:name "ignoreCase" :summary "本次匹配是否忽略大小写" :source (:raw-result-field :ignore-case) :type :boolean)
                        (:name "useRegex" :summary "本次匹配是否使用正则表达式" :source (:raw-result-field :use-regex) :type :boolean)
                        (:name "multiline" :summary "本次匹配是否启用正则多行模式" :source (:raw-result-field :multiline) :type :boolean)
                        (:name "dotAll" :summary "本次匹配是否启用正则 dotAll 模式" :source (:raw-result-field :dot-all) :type :boolean)
                        (:name "wholeWord" :summary "本次匹配是否要求左右两侧都为单词边界" :source (:raw-result-field :whole-word) :type :boolean)
                        (:name "leftWordBoundary" :summary "本次匹配是否要求左侧为单词边界" :source (:raw-result-field :left-word-boundary) :type :boolean)
                        (:name "rightWordBoundary" :summary "本次匹配是否要求右侧为单词边界" :source (:raw-result-field :right-word-boundary) :type :boolean)
                        (:name "matchStart" :summary "命中文本的起始字符偏移（0-based）" :source (:raw-result-field :match-start) :type :integer :minimum 0)
                        (:name "matchEnd" :summary "命中文本的结束字符偏移（exclusive）" :source (:raw-result-field :match-end) :type :integer :minimum 0)
                        (:name "matchStartLine" :summary "命中文本起始位置所在行号（1-based）" :source (:raw-result-field :match-start-line) :type :integer :minimum 1)
                        (:name "matchStartColumn" :summary "命中文本起始位置所在列号（1-based）" :source (:raw-result-field :match-start-column) :type :integer :minimum 1)
                        (:name "matchEndLine" :summary "命中文本结束位置所在行号（1-based，exclusive）" :source (:raw-result-field :match-end-line) :type :integer :minimum 1)
                        (:name "matchEndColumn" :summary "命中文本结束位置所在列号（1-based，exclusive）" :source (:raw-result-field :match-end-column) :type :integer :minimum 1)
                        (:name "matchedText" :summary "实际命中的原始文本片段" :source (:raw-result-field :matched-text) :type :string)
                        (:name "replacementText" :summary "本次命中实际写入的新文本片段；正则模式下为捕获组展开后的结果" :source (:raw-result-field :replacement-text) :type :string)
                        (:name "beforePreview" :summary "替换前的局部预览片段" :source (:raw-result-field :before-preview) :type :string)
                        (:name "afterPreview" :summary "替换后的局部预览片段" :source (:raw-result-field :after-preview) :type :string)
                        (:name "diffPreview" :summary "替换前后合并展示的稳定 diff 预览片段" :source (:raw-result-field :diff-preview) :type :string)
                        (:name "lineDiffPreview" :summary "替换前后按行展示并带上下文的稳定 diff 预览片段" :source (:raw-result-field :line-diff-preview) :type :string)
                        (:name "unifiedDiffPreview" :summary "替换前后按 unified diff 风格展示的稳定预览片段" :source (:raw-result-field :unified-diff-preview) :type :string)
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