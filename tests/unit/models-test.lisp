;;;; tests/unit/models-test.lisp - 数据模型单元测试
(in-package :cl-cc/tests)

(def-suite models-test :in cl-cc-suite)

(in-suite models-test)


(test command-definition-init
  (let ((cmd (make-instance 'cl-cc.models:command-definition
                            :name "test"
                            :aliases '("t")
                            :arguments-schema nil
                            :output-schema '(:text "message" :json ("status"))
                            :summary "test"
                            :handler-symbol 'test-fn
                            :permission-profile :default
                            :group :test
                            :source :builtin
                            :hidden-p t
                            :beta-p t
                            :requires-auth-p t)))
    (is (string= (cl-cc.models:command-name cmd) "test"))
    (is (equal (cl-cc.models:command-aliases cmd) '("t")))
    (is (equal (cl-cc.models:command-output-schema cmd) '(:text "message" :json ("status"))))
    (is (eq (cl-cc.models:command-permission-profile cmd) :default))
    (is (eq (cl-cc.models:command-group cmd) :test))
    (is (eq (cl-cc.models:command-source cmd) :builtin))
    (is (eq (cl-cc.models:command-hidden-p cmd) t))
    (is (eq (cl-cc.models:command-beta-p cmd) t))
    (is (eq (cl-cc.models:command-requires-auth-p cmd) t))))

(test tool-definition-init
  (let ((tool (make-instance 'cl-cc.models:tool-definition :tool-id "echo" :summary "echo" :handler-function #'identity :input-schema '(:text "input" :json ((:name "input" :summary "输入"))) :output-schema '(:text "output" :json ((:name "result" :summary "输出" :source :raw-result))) :error-output-schema '(:text "failed output" :json ((:name "error" :summary "失败" :source :error-message))) :failure-modes '(:failed) :permission-profile :default)))
    (is (string= (cl-cc.models:tool-id tool) "echo"))
    (is (functionp (cl-cc.models:tool-handler-function tool)))
    (is (equal (cl-cc.models:tool-output-schema tool) '(:text "output" :json ((:name "result" :summary "输出" :source :raw-result)))))
    (is (equal (cl-cc.models:tool-error-output-schema tool) '(:text "failed output" :json ((:name "error" :summary "失败" :source :error-message)))))
    (is (equal (cl-cc.models:tool-failure-modes tool) '(:failed)))
    (is (eq (cl-cc.models:tool-permission-profile tool) :default))))
