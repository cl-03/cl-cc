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
(register-tool "echo-tool" #'cl-cc.tools:echo-tool
               :summary "回显输入字符串"
     :input-schema '(:text "input string"
       :closed t
           :json ((:name "input" :summary "待回显的输入字符串" :type :string)))
     :output-schema '(:text "echoed string"
   :closed t
       :json ((:name "result" :summary "工具返回的回显结果" :source :raw-result :type :string)))
               :failure-modes '()
               :permission-profile :default)
(register-tool "failing-tool" #'cl-cc.tools:failing-tool
               :summary "始终返回失败，用于验证错误传播"
     :input-schema '(:text "input string"
       :closed t
           :json ((:name "input" :summary "触发失败路径的输入字符串" :type :string)))
     :output-schema '(:text "no successful output"
       :json ())
         :error-output-schema '(:text "failed output"
           :closed t
             :json ((:name "error" :summary "失败摘要消息" :source :error-message :type :string)
               (:name "code" :summary "稳定错误码" :source :error-code :type :string)))
               :failure-modes '(:failed)
               :permission-profile :default)
