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