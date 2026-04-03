;;;; src/core/command-registry.lisp - 命令注册表骨架
(in-package :cl-cc.core)

(defparameter *command-registry* (make-hash-table :test 'equal))

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

(defmacro define-command (name handler-symbol &body clauses)
  "使用声明式子句注册命令定义。"
  (let ((options '()))
    (dolist (clause clauses)
      (unless (and (consp clause)
                   (keywordp (first clause))
                   (= (length clause) 2))
        (error "Invalid DEFINE-COMMAND clause: ~S" clause))
      (setf options (append options (list (first clause) (second clause)))))
    `(register-command ,name ,handler-symbol ,@options)))

(defun find-command (name)
  "查找命令定义。"
  (gethash name *command-registry*))

(defun find-command-handler (name)
  "查找命令处理函数。"
  (let ((definition (find-command name)))
    (and definition (symbol-function (cl-cc.models:command-handler-symbol definition)))))

(defun %help-command-arguments-schema ()
  '(:positionals nil :options nil))

(defun %help-command-output-schema ()
  '(:text "CLI help text"))

(defun %docs-sync-reference-arguments-schema ()
  `(:positionals ((:name "<output-path>" :required nil))
    :options (,(%docs-sync-reference-check-option)
              ,(%output-format-option))))

(defun %docs-sync-reference-output-schema ()
  (%closed-json-output-schema
   "result message"
   (append (list (schema-field "path" "目标文档路径" :type :string)
                 (%docs-sync-status-schema-field)
                 (schema-field "checkOnly" "是否处于只检查模式" :type :boolean)
                 (schema-field "updated" "本次是否实际写回文件" :type :boolean)
                 (schema-field "needsSync" "当前文档是否存在漂移" :type :boolean))
           (%duration-and-exit-code-output-fields "本次 docs sync 执行时长（秒）"))))

(defun %register-help-command ()
  (define-command "help" 'cl-cc::handle-help-command
    (:aliases '(("--help") ("-h") ("help")))
    (:summary "显示 CLI 帮助")
    (:permission-profile :default)
    (:arguments-schema (%help-command-arguments-schema))
    (:output-schema (%help-command-output-schema))))

(defun %register-docs-sync-reference-command ()
  (define-command "docs sync-reference" 'cl-cc::handle-docs-sync-reference-command
    (:aliases '(("docs" "sync")))
    (:summary "将生成的命令参考同步到指定 Markdown 文件，或以 text/json 形式检查漂移")
    (:permission-profile :default)
    (:arguments-schema (%docs-sync-reference-arguments-schema))
    (:output-schema (%docs-sync-reference-output-schema))))

(defun %session-start-arguments-schema ()
  `(:positionals nil
    :options (,(%session-id-option)
              ,(%session-path-option)
              ,(%history-index-option)
              ,(%output-format-option))))

(defun %session-start-output-schema ()
  (%session-output-schema "session start message"
                          "新会话 ID"
                          "初始历史索引，未指定时为 null"
                          "会话状态，当前通常为 active"
                          "本次 session start 执行时长（秒）"
                          :extra-fields (%session-persistence-output-fields)))

(defun %session-resume-arguments-schema ()
  `(:positionals (,(%single-required-positional "<session-id-or-path>"))
    :options (,(%output-format-option))))

(defun %session-resume-output-schema ()
  (%session-output-schema "session resume message"
                          "恢复后的会话 ID"
                          "恢复快照中的历史索引，缺失时为 null"
                          "恢复后的会话状态"
                          "本次 session resume 执行时长（秒）"))

(defun %session-run-arguments-schema ()
  `(:positionals (,(%single-required-positional "<session-id-or-path>")
                  (:name "<user-input>" :required nil))
    :options (,(%session-run-path-option)
              ,(%tool-ids-option)
              ,(%output-format-option))))

(defun %session-run-output-schema ()
  (%session-output-schema "session run message"
                          "执行后的会话 ID"
                          "执行后的历史索引"
                          "执行后的会话状态"
                          "本次 session run 执行时长（秒）"
                          :extra-fields (append (list (%session-input-output-field "本次 session run 实际使用的用户输入，缺失时为 null"))
                                                (list (%session-execution-status-output-field "本次 session run 的执行状态"))
                                                (list (%session-selected-tools-output-field))
                                                (list (%session-execution-plan-output-field))
                                                (list (%session-execution-result-output-field "本次 session run 的稳定文本执行结果"))
                                                (list (%session-execution-tool-results-output-field))
                                                (%session-persistence-output-fields))))

(defun %chat-arguments-schema ()
  `(:positionals ((:name "<session-id-or-path>" :required nil))
    :options (,(%session-path-option)
              ,(%session-id-option)
              ,(%tool-ids-option))))

(defun %chat-output-schema ()
  '(:text "interactive chat transcript"))

(defun %register-session-start-command ()
  (define-command "session start" 'cl-cc::handle-session-start-command
    (:aliases '(("s" "start")))
    (:summary "启动新会话")
    (:permission-profile :default)
    (:arguments-schema (%session-start-arguments-schema))
    (:output-schema (%session-start-output-schema))))

(defun %register-session-resume-command ()
  (define-command "session resume" 'cl-cc::handle-session-resume-command
    (:aliases '(("s" "resume")))
    (:summary "恢复已有会话")
    (:permission-profile :default)
    (:arguments-schema (%session-resume-arguments-schema))
    (:output-schema (%session-resume-output-schema))))

(defun %register-session-run-command ()
  (define-command "session run" 'cl-cc::handle-session-run-command
    (:aliases '(("s" "run")))
    (:summary "恢复会话并执行一步最小 session loop，可携带用户输入")
    (:permission-profile :default)
    (:arguments-schema (%session-run-arguments-schema))
    (:output-schema (%session-run-output-schema))))

(defun %register-chat-command ()
  (define-command "chat" 'cl-cc::handle-chat-command
    (:aliases '(("c")))
    (:summary "启动最小交互式会话 shell")
    (:permission-profile :default)
    (:arguments-schema (%chat-arguments-schema))
    (:output-schema (%chat-output-schema))))

(defun %register-session-commands ()
  (%register-session-start-command)
  (%register-session-resume-command)
  (%register-session-run-command))

(defun %run-fixture-arguments-schema ()
  `(:positionals (,(%repeatable-required-positional "<fixture-id>"))
    :options (,(%output-format-option :default-when (%run-fixture-output-format-defaults))
              ,(%pretty-json-option)
              ,(%compact-json-option)
              ,(%tool-ids-option))))

(defun %run-fixture-output-schema ()
  (%closed-json-output-schema "fixture execution summary"
                              (%run-fixture-output-json-fields)))

(defun %register-run-fixture-command ()
  (define-command "run --fixture" 'cl-cc::handle-run-fixture-command
    (:aliases '(("r" "--fixture")))
    (:summary "执行 fixture 驱动的脚本化请求")
    (:permission-profile :default)
    (:arguments-schema (%run-fixture-arguments-schema))
    (:output-schema (%run-fixture-output-schema))))

(defun ensure-default-commands ()
  "确保默认 CLI 命令已注册。"
  (%register-help-command)
  (%register-docs-sync-reference-command)
  (%register-session-commands)
  (%register-chat-command)
  (%register-run-fixture-command))

(defun dispatch-command (argv)
  "通过命令注册表分发 argv。返回处理结果或 NIL。"
  (multiple-value-bind (definition pattern) (%resolve-command argv)
    (if definition
        (let ((handler (symbol-function (cl-cc.models:command-handler-symbol definition))))
          (funcall handler argv (%validate-command-arguments definition pattern argv)))
        nil)))
