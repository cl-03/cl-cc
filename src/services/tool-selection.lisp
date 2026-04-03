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
  '("edit file" "replace in file" "replace text in file" "modify file"
    "编辑文件" "替换文件" "替换文件内容" "修改文件")
  "触发 file-edit-tool 优先级的输入关键词。")

(defparameter +directory-list-tool-keywords+
  '("list directory" "list dir" "show directory" "show folder" "ls " "dir "
    "列出目录" "查看目录" "列出文件夹" "查看文件夹")
  "触发 directory-list-tool 优先级的输入关键词。")

(defparameter +grep-tool-keywords+
  '("grep " "search code" "search text" "search for" "find text" "find in files"
    "搜索代码" "搜索文本" "查找文本" "在代码中搜索")
  "触发 grep-tool 优先级的输入关键词。")

(defun %normalized-selection-context (context)
  (or (cl-cc.lib:string-designator-downcase context) ""))

(defun %context-contains-keyword-p (context keywords)
  (loop for keyword in keywords
        thereis (search keyword context :test #'char-equal)))

(defun %planned-tool-input (tool-id context)
  (cond
    ((string= tool-id "grep-tool")
     (or (cl-cc.tools::%normalized-grep-input context)
         context))
    ((string= tool-id "file-read-tool")
     (or (cl-cc.tools::%normalized-file-read-input context)
         context))
    ((string= tool-id "directory-list-tool")
     (or (cl-cc.tools::%normalized-directory-list-input context)
         context))
    ((string= tool-id "file-write-tool")
     (or (cl-cc.tools::%normalized-file-write-input context)
         context))
    ((string= tool-id "file-edit-tool")
     (or (cl-cc.tools::%normalized-file-edit-input context)
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
