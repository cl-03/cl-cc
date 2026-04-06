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

;; 初始化注册表，注册当前内置工具定义。
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
  (:input-schema `(:text "path string with optional line range(s)"
                   :closed t
                   :json (,(schema-field "path" "待读取的文件路径" :type :string)
                          ,(schema-field "startLine" "起始行号，缺省时读取整个文件" :type :integer :minimum 1 :required nil :nullable t)
                          ,(schema-field "endLine" "结束行号，缺省时等于 startLine" :type :integer :minimum 1 :required nil :nullable t)
                          ,(schema-field "contextLines" "为所选行范围额外扩展的上下文行数；提供时会对扩展后重叠或相邻的 ranges 做稳定合并" :type :integer :minimum 1 :required nil :nullable t)
                          ,(schema-field "ranges" "多段行范围列表；提供时按给定顺序拼接输出且自动去重重复行" :type :array :required nil :nullable t :collection t :closed t
                                         :fields (list (schema-field "startLine" "行范围起始行号" :type :integer :minimum 1)
                                                       (schema-field "endLine" "行范围结束行号" :type :integer :minimum 1))))))
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
  (:input-schema `(:text "search query, `query-1 || query-2`, or `query :: root`"
                   :closed t
                   :json (,(schema-field "query" "待搜索的单个文本关键词" :type :string)
                          ,(schema-field "queries" "待搜索的多个文本关键词列表，任一命中即返回该行" :type :array :required nil :nullable t :collection t
                                         :fields (list (schema-field "query" "待搜索的文本关键词" :type :string)))
                          ,(schema-field "includePattern" "仅返回路径匹配该 glob 模式的命中记录" :type :string :required nil :nullable t)
                          ,(schema-field "excludePattern" "排除路径匹配该 glob 模式的命中记录" :type :string :required nil :nullable t)
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

(define-tool "glob-tool" #'cl-cc.tools:glob-tool
  (:summary "在指定目录树下按 glob 模式匹配文件，用于最小可用的文件发现")
  (:input-schema `(:text "glob pattern or `pattern :: root`"
                   :closed t
                   :json (,(schema-field "pattern" "待匹配的 glob 模式" :type :string)
                          ,(schema-field "root" "搜索根路径，缺省为当前工作目录" :type :string :required nil :nullable t))))
  (:output-schema `(:text "matched file paths"
                    :closed t
                    :json (,(schema-field "result" "匹配结果文本，每行一条相对路径记录" :source :raw-result :type :string))))
  (:error-output-schema `(:text "glob search failed output"
                          :closed t
                          :json (,(schema-field "error" "glob 匹配失败摘要消息" :source :error-message :type :string)
                                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
  (:failure-modes '(:failed))
  (:permission-profile :file-read))

(define-tool "todo-write-tool" #'cl-cc.tools:todo-write-tool
  (:summary "更新当前会话的结构化待办列表，用于最小可用的进度跟踪")
  (:input-schema `(:text "todo list update request"
                   :closed t
                   :json (,(schema-field "todos" "更新后的待办列表" :type :array :closed t :collection t
                                         :fields (list (schema-field "content" "待办项内容" :type :string)
                                                       (schema-field "status" "待办项状态" :type :string :enum '("pending" "in_progress" "completed"))
                                                       (schema-field "activeForm" "待办项执行中的描述" :type :string))))))
  (:output-schema `(:text "todo write result"
                    :closed t
                    :json (,(schema-field "result" "待办列表更新摘要" :source '(:raw-result-field :summary) :type :string)
                           ,(schema-field "oldTodos" "更新前的待办列表" :source '(:raw-result-field :old-todos) :type :array :required nil :nullable t :closed t :collection t
                                          :fields (list (schema-field "content" "待办项内容" :type :string)
                                                        (schema-field "status" "待办项状态" :type :string)
                                                        (schema-field "activeForm" "待办项执行中的描述" :type :string)))
                           ,(schema-field "newTodos" "更新后的待办列表" :source '(:raw-result-field :new-todos) :type :array :closed t :collection t
                                          :fields (list (schema-field "content" "待办项内容" :type :string)
                                                        (schema-field "status" "待办项状态" :type :string)
                                                        (schema-field "activeForm" "待办项执行中的描述" :type :string))))))
  (:error-output-schema `(:text "todo write failed output"
                          :closed t
                          :json (,(schema-field "error" "待办列表写入失败摘要消息" :source :error-message :type :string)
                                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
  (:failure-modes '(:failed))
  (:permission-profile :default))

(define-tool "shell-tool" #'cl-cc.tools:shell-tool
  (:summary "执行受控 shell 命令，用于最小可用的终端/命令行操作")
  (:input-schema `(:text "shell command request"
                   :closed t
                   :json (,(schema-field "command" "待执行的 shell 命令字符串" :type :string)
                          ,(schema-field "directory" "命令执行目录，缺省为当前工作目录" :type :string :required nil :nullable t)
           ,(schema-field "background" "是否以后台模式启动命令；缺省为 false" :type :boolean :required nil :nullable t)
                          ,(schema-field "timeoutSeconds" "超时时间（秒），缺省为不设超时" :type :number :minimum 0 :required nil :nullable t))))
  (:output-schema `(:text "shell execution result"
                    :closed t
                    :json (,(schema-field "result" "shell 执行摘要" :source '(:raw-result-field :summary) :type :string)
                           ,(schema-field "command" "本次执行的 shell 命令" :source '(:raw-result-field :command) :type :string)
                           ,(schema-field "directory" "本次命令实际执行目录" :source '(:raw-result-field :directory) :type :string)
            ,(schema-field "background" "本次执行是否以后台模式启动" :source '(:raw-result-field :background) :type :boolean)
            ,(schema-field "backgroundTaskId" "后台任务标识；前台模式下为 null" :source '(:raw-result-field :background-task-id) :type :string :required nil :nullable t)
            ,(schema-field "outputPath" "后台输出日志路径；前台模式下为 null" :source '(:raw-result-field :output-path) :type :string :required nil :nullable t)
            ,(schema-field "processId" "底层进程 ID；不可用时为 null" :source '(:raw-result-field :process-id) :type :integer :minimum 0 :required nil :nullable t)
            ,(schema-field "stdout" "shell 标准输出文本；后台模式下为 null" :source '(:raw-result-field :stdout) :type :string :required nil :nullable t)
            ,(schema-field "stderr" "shell 标准错误文本；后台模式下为 null" :source '(:raw-result-field :stderr) :type :string :required nil :nullable t)
                           ,(schema-field "exitCode" "shell 进程退出码；超时终止时为 null" :source '(:raw-result-field :exit-code) :type :integer :minimum 0 :required nil :nullable t)
                           ,(schema-field "timedOut" "本次执行是否因超时被终止" :source '(:raw-result-field :timed-out) :type :boolean))))
  (:error-output-schema `(:text "shell execution failed output"
                          :closed t
                          :json (,(schema-field "error" "shell 执行失败摘要消息" :source :error-message :type :string)
                                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
  (:failure-modes '(:failed))
  (:permission-profile :shell))

  (define-tool "shell-task-list-tool" #'cl-cc.tools:shell-task-list-tool
    (:summary "列出当前后台 shell 任务，用于最小可用的后台任务发现入口")
    (:input-schema `(:text "shell task list request"
           :closed t
           :json (,(schema-field "all" "是否列出全部后台任务，当前缺省且固定为 true" :type :boolean :required nil :nullable t)
             ,(schema-field "status" "按状态过滤后台任务，缺省为 all" :type :string :enum '("all" "running" "stopped" "completed" "failed") :required nil :nullable t)
             ,(schema-field "taskIdPrefix" "按任务 ID 前缀过滤后台任务" :type :string :required nil :nullable t)
             ,(schema-field "directoryContains" "按执行目录包含指定片段过滤后台任务" :type :string :required nil :nullable t)
             ,(schema-field "terminationReason" "按后台任务终止原因过滤，支持 exit、error-exit、stop、interrupt" :type :string :enum '("exit" "error-exit" "stop" "interrupt") :required nil :nullable t))))
    (:output-schema `(:text "shell task list result"
            :closed t
            :json (,(schema-field "result" "后台 shell 任务列表摘要" :source '(:raw-result-field :summary) :type :string)
              ,(schema-field "statusFilter" "本次任务列表实际应用的状态过滤器" :source '(:raw-result-field :status-filter) :type :string)
              ,(schema-field "taskIdPrefixFilter" "本次任务列表实际应用的任务 ID 前缀过滤器；未指定时为 null" :source '(:raw-result-field :task-id-prefix-filter) :type :string :required nil :nullable t)
              ,(schema-field "directoryContainsFilter" "本次任务列表实际应用的目录片段过滤器；未指定时为 null" :source '(:raw-result-field :directory-contains-filter) :type :string :required nil :nullable t)
              ,(schema-field "terminationReasonFilter" "本次任务列表实际应用的终止原因过滤器；未指定时为 null" :source '(:raw-result-field :termination-reason-filter) :type :string :required nil :nullable t)
              ,(schema-field "totalCount" "当前后台任务总数" :source '(:raw-result-field :total-count) :type :integer :minimum 0)
              ,(schema-field "runningCount" "当前运行中的后台任务数量" :source '(:raw-result-field :running-count) :type :integer :minimum 0)
              ,(schema-field "stoppedCount" "当前已停止的后台任务数量" :source '(:raw-result-field :stopped-count) :type :integer :minimum 0)
              ,(schema-field "completedCount" "当前已完成的后台任务数量" :source '(:raw-result-field :completed-count) :type :integer :minimum 0)
              ,(schema-field "failedCount" "当前失败的后台任务数量" :source '(:raw-result-field :failed-count) :type :integer :minimum 0)
              ,(schema-field "tasks" "后台任务列表，每项包含 taskId、status、stallDetected、terminationReason、endedAt、command 等字段" :source '(:raw-result-field :tasks) :type :array :closed t :collection t
                             :fields (list (schema-field "taskId" "后台任务标识" :type :string)
                                           (schema-field "status" "后台任务当前状态" :type :string)
                                           (schema-field "running" "后台任务当前是否仍在运行" :type :boolean)
                                           (schema-field "stopped" "后台任务是否被显式停止" :type :boolean)
                                           (schema-field "command" "后台任务对应的 shell 命令" :type :string)
                                           (schema-field "directory" "后台任务的执行目录" :type :string)
                                           (schema-field "outputPath" "后台任务输出日志路径" :type :string)
                                           (schema-field "processId" "后台任务底层进程 ID；不可用时为 null" :type :integer :minimum 0 :required nil :nullable t)
                                           (schema-field "exitCode" "后台任务退出码；运行中或不可用时为 null" :type :integer :minimum 0 :required nil :nullable t)
                                           (schema-field "stallDetected" "后台任务是否疑似卡在交互提示；未检测到时为 false" :type :boolean)
                                           (schema-field "stallDetectedAt" "后台任务首次检测到疑似卡住的时间，UTC ISO-8601 格式；未检测到时为 null" :type :string :required nil :nullable t)
                                           (schema-field "stallPromptLine" "后台任务触发 stall 检测时的最后一行输出；未检测到时为 null" :type :string :required nil :nullable t)
                                           (schema-field "terminationReason" "后台任务终止原因；运行中时为 null" :type :string :required nil :nullable t)
                                           (schema-field "endedAt" "后台任务终止时间，UTC ISO-8601 格式；运行中时为 null" :type :string :required nil :nullable t))))))
    (:error-output-schema `(:text "shell task list failed output"
             :closed t
             :json (,(schema-field "error" "后台 shell 任务列表失败摘要消息" :source :error-message :type :string)
               ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
    (:failure-modes '(:failed))
    (:permission-profile :shell))

    (define-tool "shell-task-detail-tool" #'cl-cc.tools:shell-task-detail-tool
      (:summary "读取单个后台 shell 任务的详情，用于最小可用的生命周期观察入口")
      (:input-schema `(:text "shell task detail request"
             :closed t
             :json (,(schema-field "taskId" "后台任务标识" :type :string))))
      (:output-schema `(:text "shell task detail result"
              :closed t
              :json (,(schema-field "result" "后台 shell 任务详情摘要" :source '(:raw-result-field :summary) :type :string)
                ,(schema-field "taskId" "后台任务标识" :source '(:raw-result-field :task-id) :type :string)
                ,(schema-field "status" "后台任务当前状态" :source '(:raw-result-field :status) :type :string)
                ,(schema-field "running" "后台任务当前是否仍在运行" :source '(:raw-result-field :running) :type :boolean)
                ,(schema-field "stopped" "后台任务是否被显式停止" :source '(:raw-result-field :stopped) :type :boolean)
                ,(schema-field "command" "后台任务对应的 shell 命令" :source '(:raw-result-field :command) :type :string)
                ,(schema-field "directory" "后台任务的执行目录" :source '(:raw-result-field :directory) :type :string)
                ,(schema-field "outputPath" "后台任务输出日志路径" :source '(:raw-result-field :output-path) :type :string)
                ,(schema-field "processId" "后台任务底层进程 ID；不可用时为 null" :source '(:raw-result-field :process-id) :type :integer :minimum 0 :required nil :nullable t)
                ,(schema-field "exitCode" "后台任务退出码；运行中或不可用时为 null" :source '(:raw-result-field :exit-code) :type :integer :minimum 0 :required nil :nullable t)
                ,(schema-field "stallDetected" "后台任务是否疑似卡在交互提示；未检测到时为 false" :source '(:raw-result-field :stall-detected) :type :boolean)
                ,(schema-field "stallDetectedAt" "后台任务首次检测到疑似卡住的时间，UTC ISO-8601 格式；未检测到时为 null" :source '(:raw-result-field :stall-detected-at) :type :string :required nil :nullable t)
                ,(schema-field "stallPromptLine" "后台任务触发 stall 检测时的最后一行输出；未检测到时为 null" :source '(:raw-result-field :stall-prompt-line) :type :string :required nil :nullable t)
                ,(schema-field "startedAt" "后台任务开始时间，UTC ISO-8601 格式" :source '(:raw-result-field :started-at) :type :string :required nil :nullable t)
                ,(schema-field "stoppedAt" "后台任务被显式停止的时间，未停止时为 null" :source '(:raw-result-field :stopped-at) :type :string :required nil :nullable t)
                ,(schema-field "finishedAt" "后台任务自然结束时间，运行中或显式停止时为 null" :source '(:raw-result-field :finished-at) :type :string :required nil :nullable t)
                ,(schema-field "terminationReason" "后台任务终止原因；运行中时为 null" :source '(:raw-result-field :termination-reason) :type :string :required nil :nullable t)
                ,(schema-field "endedAt" "后台任务终止时间，UTC ISO-8601 格式；运行中时为 null" :source '(:raw-result-field :ended-at) :type :string :required nil :nullable t)
                ,(schema-field "durationSeconds" "后台任务已运行或总运行时长（秒）" :source '(:raw-result-field :duration-seconds) :type :number :minimum 0 :required nil :nullable t)
                ,(schema-field "outputBytes" "后台任务当前输出日志字节数；日志不可用时为 null" :source '(:raw-result-field :output-bytes) :type :integer :minimum 0 :required nil :nullable t)
                ,(schema-field "outputLineCount" "后台任务当前输出日志行数；日志不可用时为 null" :source '(:raw-result-field :output-line-count) :type :integer :minimum 0 :required nil :nullable t)
                ,(schema-field "outputUpdatedAt" "后台任务输出日志最后更新时间，UTC ISO-8601 格式；日志不可用时为 null" :source '(:raw-result-field :output-updated-at) :type :string :required nil :nullable t))))
      (:error-output-schema `(:text "shell task detail failed output"
               :closed t
               :json (,(schema-field "error" "后台 shell 任务详情失败摘要消息" :source :error-message :type :string)
                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
      (:failure-modes '(:failed))
      (:permission-profile :shell))

  (define-tool "shell-task-cleanup-tool" #'cl-cc.tools:shell-task-cleanup-tool
    (:summary "清理后台 shell 任务注册表中的非运行任务，用于最小可用的后台任务回收")
    (:input-schema `(:text "shell task cleanup request"
           :closed t
        :json (,(schema-field "status" "按状态清理后台任务，缺省为 all（即 stopped/completed/failed）" :type :string :enum '("all" "stopped" "completed" "failed") :required nil :nullable t)
          ,(schema-field "terminationReason" "按后台任务终止原因清理，支持 exit、error-exit、stop、interrupt" :type :string :enum '("exit" "error-exit" "stop" "interrupt") :required nil :nullable t))))
    (:output-schema `(:text "shell task cleanup result"
            :closed t
            :json (,(schema-field "result" "后台 shell 任务清理摘要" :source '(:raw-result-field :summary) :type :string)
              ,(schema-field "statusFilter" "本次清理实际应用的状态过滤器" :source '(:raw-result-field :status-filter) :type :string)
      ,(schema-field "terminationReasonFilter" "本次清理实际应用的终止原因过滤器；未指定时为 null" :source '(:raw-result-field :termination-reason-filter) :type :string :required nil :nullable t)
              ,(schema-field "removedCount" "本次清理移除的后台任务数量" :source '(:raw-result-field :removed-count) :type :integer :minimum 0)
              ,(schema-field "remainingCount" "清理完成后注册表中剩余的后台任务数量" :source '(:raw-result-field :remaining-count) :type :integer :minimum 0)
              ,(schema-field "removedTaskIds" "本次清理移除的后台任务 ID 列表" :source '(:raw-result-field :removed-task-ids) :type :array))))
    (:error-output-schema `(:text "shell task cleanup failed output"
             :closed t
             :json (,(schema-field "error" "后台 shell 任务清理失败摘要消息" :source :error-message :type :string)
               ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
    (:failure-modes '(:failed))
    (:permission-profile :shell))

  (define-tool "shell-task-tool" #'cl-cc.tools:shell-task-tool
    (:summary "查询单个后台 shell 任务，或批量中断/停止/等待多个后台 shell 任务，用于最小可用的后台任务观察与控制")
    (:input-schema `(:text "shell task request"
           :closed t
           :json (,(schema-field "taskId" "单个后台任务标识；与 taskIds 二选一" :type :string :required nil :nullable t)
             ,(schema-field "taskIds" "批量 interrupt/stop/wait 的后台任务标识列表；与 taskId 二选一" :type :array :required nil :nullable t)
             ,(schema-field "action" "动作类型，缺省为 status" :type :string :enum '("status" "interrupt" "stop" "wait") :required nil :nullable t)
             ,(schema-field "timeoutSeconds" "wait 动作的最长等待时间（秒），缺省为一直等待直到任务结束" :type :number :minimum 0 :required nil :nullable t))))
    (:output-schema `(:text "shell task result"
            :closed t
            :json (,(schema-field "result" "后台 shell 任务摘要" :source '(:raw-result-field :summary) :type :string)
              ,(schema-field "taskId" "单任务模式下的后台任务标识；批量模式为 null" :source '(:raw-result-field :task-id) :type :string :required nil :nullable t)
              ,(schema-field "taskIds" "批量模式下的后台任务标识列表；单任务模式为 null" :source '(:raw-result-field :task-ids) :type :array :required nil :nullable t)
              ,(schema-field "taskCount" "本次操作覆盖的后台任务数量；单任务模式为 null" :source '(:raw-result-field :task-count) :type :integer :minimum 1 :required nil :nullable t)
              ,(schema-field "action" "本次执行的任务动作" :source '(:raw-result-field :action) :type :string)
              ,(schema-field "status" "后台任务当前状态；批量模式下为聚合状态，相异时为 mixed" :source '(:raw-result-field :status) :type :string)
              ,(schema-field "running" "后台任务当前是否仍在运行；批量模式下表示是否仍有任务在运行" :source '(:raw-result-field :running) :type :boolean)
              ,(schema-field "stopped" "后台任务是否被显式停止；批量模式下表示是否全部已停止" :source '(:raw-result-field :stopped) :type :boolean)
              ,(schema-field "command" "单任务模式下后台任务对应的 shell 命令；批量模式为 null" :source '(:raw-result-field :command) :type :string :required nil :nullable t)
              ,(schema-field "directory" "单任务模式下后台任务的执行目录；批量模式为 null" :source '(:raw-result-field :directory) :type :string :required nil :nullable t)
              ,(schema-field "outputPath" "单任务模式下后台任务输出日志路径；批量模式为 null" :source '(:raw-result-field :output-path) :type :string :required nil :nullable t)
              ,(schema-field "processId" "后台任务底层进程 ID；不可用时为 null" :source '(:raw-result-field :process-id) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "exitCode" "后台任务退出码；运行中或不可用时为 null" :source '(:raw-result-field :exit-code) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "stallDetected" "后台任务是否疑似卡在交互提示；未检测到时为 false" :source '(:raw-result-field :stall-detected) :type :boolean)
              ,(schema-field "stallDetectedAt" "后台任务首次检测到疑似卡住的时间，UTC ISO-8601 格式；未检测到时为 null" :source '(:raw-result-field :stall-detected-at) :type :string :required nil :nullable t)
              ,(schema-field "stallPromptLine" "后台任务触发 stall 检测时的最后一行输出；未检测到时为 null" :source '(:raw-result-field :stall-prompt-line) :type :string :required nil :nullable t)
              ,(schema-field "terminationReason" "后台任务终止原因；运行中时为 null" :source '(:raw-result-field :termination-reason) :type :string :required nil :nullable t)
              ,(schema-field "endedAt" "后台任务终止时间，UTC ISO-8601 格式；运行中时为 null" :source '(:raw-result-field :ended-at) :type :string :required nil :nullable t)
              ,(schema-field "runningCount" "批量模式下仍在运行的后台任务数量；单任务模式为 null" :source '(:raw-result-field :running-count) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "stoppedCount" "批量模式下已停止的后台任务数量；单任务模式为 null" :source '(:raw-result-field :stopped-count) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "completedCount" "批量模式下已完成的后台任务数量；单任务模式为 null" :source '(:raw-result-field :completed-count) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "failedCount" "批量模式下已失败的后台任务数量；单任务模式为 null" :source '(:raw-result-field :failed-count) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "tasks" "批量模式下的逐任务结果数组；单任务模式为 null" :source '(:raw-result-field :tasks) :type :array :required nil :nullable t :closed t :collection t
                             :fields (list (schema-field "taskId" "后台任务标识" :type :string)
                                           (schema-field "action" "本次执行的任务动作" :type :string)
                                           (schema-field "status" "后台任务当前状态" :type :string)
                                           (schema-field "running" "后台任务当前是否仍在运行" :type :boolean)
                                           (schema-field "stopped" "后台任务是否被显式停止" :type :boolean)
                                           (schema-field "command" "后台任务对应的 shell 命令" :type :string)
                                           (schema-field "directory" "后台任务的执行目录" :type :string)
                                           (schema-field "outputPath" "后台任务输出日志路径" :type :string)
                                           (schema-field "processId" "后台任务底层进程 ID；不可用时为 null" :type :integer :minimum 0 :required nil :nullable t)
                                           (schema-field "exitCode" "后台任务退出码；运行中或不可用时为 null" :type :integer :minimum 0 :required nil :nullable t)
                                           (schema-field "stallDetected" "后台任务是否疑似卡在交互提示；未检测到时为 false" :type :boolean)
                                           (schema-field "stallDetectedAt" "后台任务首次检测到疑似卡住的时间，UTC ISO-8601 格式；未检测到时为 null" :type :string :required nil :nullable t)
                                           (schema-field "stallPromptLine" "后台任务触发 stall 检测时的最后一行输出；未检测到时为 null" :type :string :required nil :nullable t)
                                           (schema-field "terminationReason" "后台任务终止原因；运行中时为 null" :type :string :required nil :nullable t)
                                           (schema-field "endedAt" "后台任务终止时间，UTC ISO-8601 格式；运行中时为 null" :type :string :required nil :nullable t)
                                           (schema-field "timedOut" "本次 wait 是否因达到 timeoutSeconds 而提前返回；非 wait 动作为 false" :type :boolean)))
              ,(schema-field "timedOut" "本次 wait 是否因达到 timeoutSeconds 而提前返回；非 wait 动作为 false" :source '(:raw-result-field :timed-out) :type :boolean))))
    (:error-output-schema `(:text "shell task failed output"
             :closed t
             :json (,(schema-field "error" "后台 shell 任务失败摘要消息" :source :error-message :type :string)
               ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
    (:failure-modes '(:failed))
    (:permission-profile :shell))

  (define-tool "shell-task-output-tool" #'cl-cc.tools:shell-task-output-tool
    (:summary "读取单个后台 shell 任务输出窗口，或批量读取多个后台任务输出，并支持共享或按任务定制的窗口参数、短时 follow 与阻塞等待，用于最小可用的后台日志跟进")
    (:input-schema `(:text "shell task output request"
           :closed t
           :json (,(schema-field "taskId" "单任务模式下的后台任务标识；与 taskIds 二选一，批量模式可为 null" :type :string :required nil :nullable t)
             ,(schema-field "taskIds" "批量模式下的后台任务标识数组；单任务模式为 null" :type :array :required nil :nullable t :closed t :collection t
                            :fields (list (schema-field "taskId" "后台任务标识" :type :string)))
             ,(schema-field "tasks" "按任务定制批量输出请求的对象数组；与 taskId/taskIds 互斥，单任务模式为 null" :type :array :required nil :nullable t :closed t :collection t
                            :fields (list (schema-field "taskId" "后台任务标识" :type :string)
                                          (schema-field "lines" "该任务待读取的输出行数；未指定时复用顶层默认值" :type :integer :minimum 1 :required nil :nullable t)
                                          (schema-field "startLine" "该任务区间读取的起始行号；指定后进入 range 模式" :type :integer :minimum 1 :required nil :nullable t)
                                          (schema-field "endLine" "该任务区间读取的结束行号；与 startLine 配套使用" :type :integer :minimum 1 :required nil :nullable t)
                                          (schema-field "followSeconds" "该任务继续跟随日志输出的秒数；未指定时复用顶层默认值" :type :integer :minimum 0 :required nil :nullable t)
                                          (schema-field "waitUntilFinished" "该任务是否阻塞直到后台任务结束；未指定时复用顶层默认值" :type :boolean :required nil :nullable t)))
             ,(schema-field "lines" "待读取的输出行数；tail 模式下缺省为 20" :type :integer :minimum 1 :required nil :nullable t)
             ,(schema-field "startLine" "区间读取的起始行号；指定后进入 range 模式" :type :integer :minimum 1 :required nil :nullable t)
             ,(schema-field "endLine" "区间读取的结束行号；与 startLine 配套使用" :type :integer :minimum 1 :required nil :nullable t)
             ,(schema-field "followSeconds" "继续跟随日志输出的秒数；未指定时不 follow" :type :integer :minimum 0 :required nil :nullable t)
             ,(schema-field "waitUntilFinished" "是否阻塞直到后台任务结束；与 followSeconds 互斥" :type :boolean :required nil :nullable t))))
    (:output-schema `(:text "shell task output result"
            :closed t
            :json (,(schema-field "result" "后台任务输出读取摘要" :source '(:raw-result-field :summary) :type :string)
              ,(schema-field "taskId" "单任务模式下的后台任务标识；批量模式为 null" :source '(:raw-result-field :task-id) :type :string :required nil :nullable t)
              ,(schema-field "taskIds" "批量模式下的后台任务标识数组；单任务模式为 null" :source '(:raw-result-field :task-ids) :type :array :required nil :nullable t :closed t :collection t
                             :fields (list (schema-field "taskId" "后台任务标识" :type :string)))
              ,(schema-field "taskCount" "批量模式下的后台任务数量；单任务模式为 null" :source '(:raw-result-field :task-count) :type :integer :minimum 1 :required nil :nullable t)
              ,(schema-field "mode" "本次输出读取模式：tail、range 或 mixed" :source '(:raw-result-field :mode) :type :string)
              ,(schema-field "status" "后台任务当前状态；批量模式下若存在多种状态则为 mixed" :source '(:raw-result-field :status) :type :string)
              ,(schema-field "running" "后台任务当前是否仍在运行；批量模式下表示是否仍有任一任务运行" :source '(:raw-result-field :running) :type :boolean)
              ,(schema-field "stopped" "后台任务是否被显式停止；批量模式下表示是否全部已停止" :source '(:raw-result-field :stopped) :type :boolean)
              ,(schema-field "outputPath" "单任务模式下后台任务输出日志路径；批量模式为 null" :source '(:raw-result-field :output-path) :type :string :required nil :nullable t)
              ,(schema-field "linesRequested" "共享请求下的输出窗口行数；按任务定制且不一致时为 null" :source '(:raw-result-field :lines-requested) :type :integer :minimum 1 :required nil :nullable t)
              ,(schema-field "requestedStartLine" "本次请求的起始行号；tail 模式下为 null" :source '(:raw-result-field :requested-start-line) :type :integer :minimum 1 :required nil :nullable t)
              ,(schema-field "requestedEndLine" "本次请求的结束行号；tail 模式下为 null" :source '(:raw-result-field :requested-end-line) :type :integer :minimum 1 :required nil :nullable t)
              ,(schema-field "followSeconds" "本次请求的 follow 秒数；未指定时为 null" :source '(:raw-result-field :follow-seconds) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "waitUntilFinished" "共享请求是否阻塞直到后台任务结束；按任务定制且不一致时为 null" :source '(:raw-result-field :wait-until-finished) :type :boolean :required nil :nullable t)
              ,(schema-field "startLine" "单任务模式下本次返回内容的起始行号；无内容或批量模式时为 null" :source '(:raw-result-field :start-line) :type :integer :minimum 1 :required nil :nullable t)
              ,(schema-field "endLine" "单任务模式下本次返回内容的结束行号；无内容或批量模式时为 null" :source '(:raw-result-field :end-line) :type :integer :minimum 1 :required nil :nullable t)
              ,(schema-field "totalLines" "单任务模式下当前后台输出日志总行数；批量模式为 null" :source '(:raw-result-field :total-lines) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "runningCount" "批量模式下仍在运行的后台任务数量；单任务模式为 null" :source '(:raw-result-field :running-count) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "stoppedCount" "批量模式下已停止的后台任务数量；单任务模式为 null" :source '(:raw-result-field :stopped-count) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "completedCount" "批量模式下已完成的后台任务数量；单任务模式为 null" :source '(:raw-result-field :completed-count) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "failedCount" "批量模式下已失败的后台任务数量；单任务模式为 null" :source '(:raw-result-field :failed-count) :type :integer :minimum 0 :required nil :nullable t)
              ,(schema-field "tasks" "批量模式下的逐任务输出结果数组；单任务模式为 null" :source '(:raw-result-field :tasks) :type :array :required nil :nullable t :closed t :collection t
                             :fields (list (schema-field "taskId" "后台任务标识" :type :string)
                                           (schema-field "mode" "本次输出读取模式：tail 或 range" :type :string)
                                           (schema-field "status" "后台任务当前状态" :type :string)
                                           (schema-field "running" "后台任务当前是否仍在运行" :type :boolean)
                                           (schema-field "stopped" "后台任务是否被显式停止" :type :boolean)
                                           (schema-field "outputPath" "后台任务输出日志路径" :type :string)
                                           (schema-field "linesRequested" "本次请求的输出窗口行数" :type :integer :minimum 1)
                                           (schema-field "requestedStartLine" "本次请求的起始行号；tail 模式下为 null" :type :integer :minimum 1 :required nil :nullable t)
                                           (schema-field "requestedEndLine" "本次请求的结束行号；tail 模式下为 null" :type :integer :minimum 1 :required nil :nullable t)
                                           (schema-field "followSeconds" "本次请求的 follow 秒数；未指定时为 null" :type :integer :minimum 0 :required nil :nullable t)
                                           (schema-field "waitUntilFinished" "本次请求是否阻塞直到后台任务结束" :type :boolean)
                                           (schema-field "startLine" "本次返回内容的起始行号；无内容时为 null" :type :integer :minimum 1 :required nil :nullable t)
                                           (schema-field "endLine" "本次返回内容的结束行号；无内容时为 null" :type :integer :minimum 1 :required nil :nullable t)
                                           (schema-field "totalLines" "当前后台输出日志总行数" :type :integer :minimum 0)
                                           (schema-field "content" "按绝对行号编号后的输出内容" :type :string)))
              ,(schema-field "content" "单任务模式下按绝对行号编号后的输出内容；批量模式为 null" :source '(:raw-result-field :content) :type :string :required nil :nullable t))))
    (:error-output-schema `(:text "shell task output failed output"
             :closed t
             :json (,(schema-field "error" "后台 shell 任务输出失败摘要消息" :source :error-message :type :string)
               ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
    (:failure-modes '(:failed))
    (:permission-profile :shell))

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
    (:summary "替换指定文件中的文本片段，用于最小可用的原位编辑")
    (:input-schema `(:text "edit request"
           :closed t
           :json (,(schema-field "path" "待编辑的文件路径" :type :string)
             ,(schema-field "oldText" "期望被替换的原始文本；默认按精确文本匹配，useRegex 为 true 时按正则表达式解释" :type :string)
             ,(schema-field "newText" "替换后的新文本，可为空字符串；useRegex 为 true 时支持 `$1` / `\\1` 形式的捕获组引用" :type :string)
             ,(schema-field "occurrence" "当旧文本出现多次时，指定要替换的第几处命中（1-based）" :type :integer :minimum 1 :required nil :nullable t)
             ,(schema-field "replaceAll" "是否替换全部命中；与 occurrence 互斥，缺省为 false" :type :boolean :required nil :nullable t)
             ,(schema-field "lineContext" "生成 lineDiffPreview 时保留的上下文行数，缺省为 1" :type :integer :minimum 0 :required nil :nullable t)
             ,(schema-field "ignoreCase" "是否忽略大小写；缺省为 false" :type :boolean :required nil :nullable t)
             ,(schema-field "useRegex" "是否将 oldText 作为正则表达式解释；缺省为 false" :type :boolean :required nil :nullable t)
             ,(schema-field "multiline" "是否启用正则多行模式（^/$ 按行匹配）；缺省为 false" :type :boolean :required nil :nullable t)
             ,(schema-field "dotAll" "是否启用正则 dotAll 模式（`.` 可跨换行匹配）；缺省为 false" :type :boolean :required nil :nullable t)
             ,(schema-field "wholeWord" "是否要求左右两侧都为单词边界；缺省为 false" :type :boolean :required nil :nullable t)
             ,(schema-field "leftWordBoundary" "是否要求命中左侧为单词边界；缺省为 false" :type :boolean :required nil :nullable t)
             ,(schema-field "rightWordBoundary" "是否要求命中右侧为单词边界；缺省为 false" :type :boolean :required nil :nullable t)
             ,(schema-field "preview" "是否只预览替换摘要而不落盘，缺省为 false" :type :boolean :required nil :nullable t))))
    (:output-schema `(:text "edit summary"
            :closed t
          :json (,(schema-field "result" "文件编辑结果摘要" :source '(:raw-result-field :summary) :type :string)
           ,(schema-field "path" "本次编辑目标文件路径" :source '(:raw-result-field :path) :type :string)
                   ,(schema-field "preview" "是否为预览模式；普通写回路径下为 null" :source '(:raw-result-field :preview) :type :boolean :required nil :nullable t)
           ,(schema-field "matchCount" "本次实际替换的命中数量" :source '(:raw-result-field :match-count) :type :integer :minimum 1)
           ,(schema-field "totalMatches" "旧文本在文件中的总匹配次数；指定 occurrence 时可大于 1" :source '(:raw-result-field :total-matches) :type :integer :minimum 1)
           ,(schema-field "selectedOccurrence" "本次实际替换的命中序号（1-based）；replaceAll 模式下为 null" :source '(:raw-result-field :selected-occurrence) :type :integer :minimum 1 :required nil :nullable t)
           ,(schema-field "lineContext" "本次生成 lineDiffPreview 时实际采用的上下文行数" :source '(:raw-result-field :line-context) :type :integer :minimum 0)
           ,(schema-field "ignoreCase" "本次匹配是否忽略大小写" :source '(:raw-result-field :ignore-case) :type :boolean)
           ,(schema-field "useRegex" "本次匹配是否使用正则表达式" :source '(:raw-result-field :use-regex) :type :boolean)
           ,(schema-field "multiline" "本次匹配是否启用正则多行模式" :source '(:raw-result-field :multiline) :type :boolean)
           ,(schema-field "dotAll" "本次匹配是否启用正则 dotAll 模式" :source '(:raw-result-field :dot-all) :type :boolean)
           ,(schema-field "wholeWord" "本次匹配是否要求左右两侧都为单词边界" :source '(:raw-result-field :whole-word) :type :boolean)
           ,(schema-field "leftWordBoundary" "本次匹配是否要求左侧为单词边界" :source '(:raw-result-field :left-word-boundary) :type :boolean)
           ,(schema-field "rightWordBoundary" "本次匹配是否要求右侧为单词边界" :source '(:raw-result-field :right-word-boundary) :type :boolean)
           ,(schema-field "matchStart" "命中文本的起始字符偏移（0-based）" :source '(:raw-result-field :match-start) :type :integer :minimum 0)
           ,(schema-field "matchEnd" "命中文本的结束字符偏移（exclusive）" :source '(:raw-result-field :match-end) :type :integer :minimum 0)
           ,(schema-field "matchStartLine" "命中文本起始位置所在行号（1-based）" :source '(:raw-result-field :match-start-line) :type :integer :minimum 1)
           ,(schema-field "matchStartColumn" "命中文本起始位置所在列号（1-based）" :source '(:raw-result-field :match-start-column) :type :integer :minimum 1)
           ,(schema-field "matchEndLine" "命中文本结束位置所在行号（1-based，exclusive）" :source '(:raw-result-field :match-end-line) :type :integer :minimum 1)
           ,(schema-field "matchEndColumn" "命中文本结束位置所在列号（1-based，exclusive）" :source '(:raw-result-field :match-end-column) :type :integer :minimum 1)
           ,(schema-field "matchedText" "实际命中的原始文本片段" :source '(:raw-result-field :matched-text) :type :string)
           ,(schema-field "replacementText" "本次命中实际写入的新文本片段；正则模式下为捕获组展开后的结果" :source '(:raw-result-field :replacement-text) :type :string)
           ,(schema-field "beforePreview" "替换前的局部预览片段" :source '(:raw-result-field :before-preview) :type :string)
           ,(schema-field "afterPreview" "替换后的局部预览片段" :source '(:raw-result-field :after-preview) :type :string)
           ,(schema-field "diffPreview" "替换前后合并展示的稳定 diff 预览片段" :source '(:raw-result-field :diff-preview) :type :string)
           ,(schema-field "lineDiffPreview" "替换前后按行展示并带上下文的稳定 diff 预览片段" :source '(:raw-result-field :line-diff-preview) :type :string)
           ,(schema-field "unifiedDiffPreview" "替换前后按 unified diff 风格展示的稳定预览片段" :source '(:raw-result-field :unified-diff-preview) :type :string)
                   ,(schema-field "writeApplied" "是否已实际写回文件；preview 模式下为 null" :source '(:raw-result-field :write-applied) :type :boolean :required nil :nullable t))))
    (:error-output-schema `(:text "file edit failed output"
             :closed t
             :json (,(schema-field "error" "文件编辑失败摘要消息" :source :error-message :type :string)
               ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
    (:failure-modes '(:failed))
    (:permission-profile :file-write))

(define-tool "directory-list-tool" #'cl-cc.tools:directory-list-tool
  (:summary "列出指定目录的子项，用于最小可用的只读目录检索")
  (:input-schema `(:text "path string with optional recursive/depth/contains modifiers"
                   :closed t
                   :json (,(schema-field "path" "待列举的目录路径" :type :string)
                          ,(schema-field "recursive" "是否递归列举子目录，缺省为 false" :type :boolean :required nil :nullable t)
                          ,(schema-field "depth" "递归列举的最大深度，缺省为不限制" :type :integer :required nil :nullable t :minimum 1)
                          ,(schema-field "contains" "仅返回路径中包含该子串的条目，缺省为不过滤" :type :string :required nil :nullable t))))
  (:output-schema `(:text "directory entries"
                    :closed t
                    :json (,(schema-field "result" "目录列举结果内容" :source :raw-result :type :string))))
  (:error-output-schema `(:text "directory listing failed output"
                          :closed t
                          :json (,(schema-field "error" "目录列举失败摘要消息" :source :error-message :type :string)
                                 ,(schema-field "code" "稳定错误码" :source :error-code :type :string))))
  (:failure-modes '(:failed))
  (:permission-profile :file-read))
