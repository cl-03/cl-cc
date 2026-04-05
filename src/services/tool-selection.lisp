;;;; src/services/tool-selection.lisp - 工具选择逻辑
(in-package :cl-cc.services)

(defparameter +failing-tool-keywords+
  '("fail" "error" "exception" "broken" "失败" "报错" "异常")
  "触发 failing-tool 优先级的输入关键词。")

(defparameter +echo-tool-keywords+
  '("echo" "repeat" "print" "say" "回显" "重复" "输出")
  "触发 echo-tool 优先级的输入关键词。")

(defparameter +file-read-tool-keywords+
  '("read file" "open file" "show file" "cat " "读取文件" "打开文件" "查看文件" "显示文件"
    ".lisp" ".md" ".txt" ".json" ".asd")
  "触发 file-read-tool 优先级的输入关键词。")

(defparameter +file-write-tool-keywords+
  '("write file" "save file" "create file" "update file" "append file" "append to file"
    "写入文件" "保存文件" "创建文件" "更新文件" "追加写入文件" "追加文件")
  "触发 file-write-tool 优先级的输入关键词。")

(defparameter +file-edit-tool-keywords+
  '("edit file" "replace in file" "replace text in file" "modify file" "patch file"
    "replace all in file" "replace all text in file" "replace all matches in file"
    "编辑文件" "替换文件" "替换文件内容" "修改文件" "全部替换文件" "替换文件全部命中" "替换文件所有命中")
  "触发 file-edit-tool 优先级的输入关键词。")

(defparameter +directory-list-tool-keywords+
  '("list directory" "list dir" "show directory" "show folder" "ls " "dir "
    "列出目录" "查看目录" "列出文件夹" "查看文件夹")
  "触发 directory-list-tool 优先级的输入关键词。")

(defparameter +grep-tool-keywords+
  '("grep " "search code" "search text" "search for" "find text" "find in files"
    "搜索代码" "搜索文本" "查找文本" "在代码中搜索")
  "触发 grep-tool 优先级的输入关键词。")

(defparameter +glob-tool-keywords+
  '("glob " "find files" "search files" "match files"
    "查找文件" "搜索文件" "列出匹配文件")
  "触发 glob-tool 优先级的输入关键词。")

(defparameter +todo-write-tool-keywords+
  '("todo write" "update todo list" "todo list " "track progress"
    "待办列表" "更新待办列表" "任务清单")
  "触发 todo-write-tool 优先级的输入关键词。")

(defparameter +shell-tool-keywords+
  '("run shell " "shell " "bash " "execute command " "run command "
    "执行命令" "运行命令" "执行shell" "运行shell")
  "触发 shell-tool 优先级的输入关键词。")

(defparameter +shell-task-list-tool-keywords+
  '("shell task list" "list shell tasks" "list background tasks" "show shell tasks"
    "running shell task list" "failed shell task list" "completed shell task list" "stopped shell task list"
    "background task list" "后台任务列表" "列出后台任务" "查看后台任务列表"
    "列出运行中的后台任务" "列出失败后台任务" "列出已完成后台任务" "列出已停止后台任务")
  "触发 shell-task-list-tool 优先级的输入关键词。")

(defparameter +shell-task-detail-tool-keywords+
  '("shell task detail " "background task detail " "show shell task detail "
    "后台任务详情" "查看后台任务详情" "显示后台任务详情")
  "触发 shell-task-detail-tool 优先级的输入关键词。")

(defparameter +shell-task-cleanup-tool-keywords+
  '("cleanup shell tasks" "cleanup background tasks" "prune shell tasks"
    "cleanup completed shell tasks" "cleanup failed shell tasks" "cleanup stopped shell tasks"
    "清理后台任务" "清理已完成后台任务" "清理失败后台任务" "清理已停止后台任务")
  "触发 shell-task-cleanup-tool 优先级的输入关键词。")

(defparameter +shell-task-tool-keywords+
  '("shell task " "background task "
    "status shell task " "status background task "
    "inspect shell task " "inspect background task "
    "show shell task " "show background task "
    "interrupt shell task " "interrupt background task "
    "interrupt shell tasks " "interrupt background tasks "
    "interrupt task " "interrupt tasks "
    "sigint shell task " "sigint background task "
    "sigint shell tasks " "sigint background tasks "
    "sigint task " "sigint tasks "
    "ctrl-c shell task " "ctrl-c background task "
    "ctrl-c shell tasks " "ctrl-c background tasks "
    "ctrl-c task " "ctrl-c tasks "
    "ctrl+c shell task " "ctrl+c background task "
    "ctrl+c shell tasks " "ctrl+c background tasks "
    "ctrl+c task " "ctrl+c tasks "
    "stop shell task " "stop background task "
    "stop shell tasks " "stop background tasks "
    "kill shell task " "kill background task "
    "kill shell tasks " "kill background tasks "
    "terminate shell task " "terminate background task "
    "terminate shell tasks " "terminate background tasks "
    "cancel shell task " "cancel background task "
    "cancel shell tasks " "cancel background tasks "
    "stop task " "kill task " "terminate task " "cancel task "
    "stop tasks " "kill tasks " "terminate tasks " "cancel tasks "
    "wait shell task " "wait background task " "wait task "
    "wait shell tasks " "wait background tasks " "wait tasks "
    "join shell task " "join background task " "join task "
    "join shell tasks " "join background tasks " "join tasks "
    "await shell task " "await background task " "await task "
    "await shell tasks " "await background tasks " "await tasks "
    "后台任务" "停止后台任务" "终止后台任务" "取消后台任务"
    "中断后台任务" "中断任务" "停止任务" "终止任务" "取消任务" "查询后台任务" "等待后台任务" "等待任务")
  "触发 shell-task-tool 优先级的输入关键词。")

(defparameter +shell-task-output-tool-keywords+
  '("shell task output " "background task output " "read shell task output " "tail shell task "
    "shell task outputs " "background task outputs " "read shell task outputs " "tail shell tasks "
    "follow shell task output " "follow background task output "
    "follow shell task outputs " "follow background task outputs "
    "wait shell task output " "wait background task output "
    "wait shell task outputs " "wait background task outputs "
    "wait until finished shell task output " "wait until finished background task output "
    "wait until finished shell task outputs " "wait until finished background task outputs "
    "后台任务输出" "查看后台任务输出" "读取后台任务输出"
    "跟随后台任务输出" "持续查看后台任务输出" "持续读取后台任务输出"
    "等待后台任务输出" "等待后台任务输出完成" "等待后台任务结束输出")
  "触发 shell-task-output-tool 优先级的输入关键词。")

(defun %normalized-selection-context (context)
  (or (cl-cc.lib:string-designator-downcase context) ""))

(defun %context-contains-keyword-p (context keywords)
  (loop for keyword in keywords
        thereis (search keyword context :test #'char-equal)))

(defun %planned-tool-input-or-context (thunk context)
  (handler-case
      (or (funcall thunk) context)
    (cl-cc.lib:cl-cc-error () context)))

(defun %planned-tool-input (tool-id context)
  (cond
    ((string= tool-id "todo-write-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-todo-write-input context))
      context))
    ((string= tool-id "glob-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-glob-input context))
      context))
    ((string= tool-id "grep-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-grep-input context))
      context))
    ((string= tool-id "file-read-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-file-read-input context))
      context))
    ((string= tool-id "directory-list-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-directory-list-input context))
      context))
    ((string= tool-id "file-write-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-file-write-input context))
      context))
    ((string= tool-id "file-edit-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-file-edit-input context))
      context))
    ((string= tool-id "shell-task-list-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-shell-task-list-input context))
      context))
    ((string= tool-id "shell-task-detail-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-shell-task-detail-input context))
      context))
    ((string= tool-id "shell-task-cleanup-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-shell-task-cleanup-input context))
      context))
    ((string= tool-id "shell-task-output-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-shell-task-output-input context))
      context))
    ((string= tool-id "shell-task-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-shell-task-input context))
      context))
    ((string= tool-id "shell-tool")
     (%planned-tool-input-or-context
      (lambda () (cl-cc.tools::%normalized-shell-input context))
      context))
    (t context)))

(defun %session-execution-steps (tool-ids context)
  (loop for tool-id in tool-ids
        for tool-input = (%planned-tool-input tool-id context)
        collect (list :tool tool-id :input tool-input)))

(defun %session-execution-tool-inputs (steps)
  (mapcar (lambda (step)
            (cons (getf step :tool)
                  (getf step :input)))
          steps))

(defun select-tools (context)
  "根据 context 选择工具，优先返回最可能成功的工具。"
  (let ((normalized-context (%normalized-selection-context context)))
    (cond
      ((%context-contains-keyword-p normalized-context +shell-task-list-tool-keywords+)
       (list "shell-task-list-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +shell-task-cleanup-tool-keywords+)
       (list "shell-task-cleanup-tool" "shell-task-list-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +shell-task-output-tool-keywords+)
       (list "shell-task-output-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +shell-task-detail-tool-keywords+)
       (list "shell-task-detail-tool" "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +shell-task-tool-keywords+)
       (list "shell-task-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +shell-tool-keywords+)
       (list "shell-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +todo-write-tool-keywords+)
       (list "todo-write-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +glob-tool-keywords+)
       (list "glob-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +grep-tool-keywords+)
       (list "grep-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +file-edit-tool-keywords+)
       (list "file-edit-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +file-write-tool-keywords+)
       (list "file-write-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +directory-list-tool-keywords+)
       (list "directory-list-tool" "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +file-read-tool-keywords+)
       (list "file-read-tool" "echo-tool" "failing-tool"))
      ((%context-contains-keyword-p normalized-context +failing-tool-keywords+)
       (list "failing-tool" "echo-tool"))
      ((%context-contains-keyword-p normalized-context +echo-tool-keywords+)
       (list "echo-tool" "failing-tool"))
      (t (list "echo-tool" "failing-tool")))))

(defun plan-session-execution (context &key tool-ids-override)
  "为 session-loop 生成最小执行计划，包含工具顺序与按工具归一化后的输入。"
  (let* ((resolved-context (or context ""))
         (tool-ids (or tool-ids-override
                       (select-tools resolved-context)))
         (steps (%session-execution-steps tool-ids resolved-context)))
    (list :tool-ids tool-ids
          :tool-inputs (%session-execution-tool-inputs steps)
          :steps steps)))
