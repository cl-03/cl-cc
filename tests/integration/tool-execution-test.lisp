;;;; tests/integration/tool-execution-test.lisp - 工具执行集成测试
(in-package :cl-cc/tests)

(def-suite tool-execution-test :in cl-cc-suite)

(in-suite tool-execution-test)


(test tool-execution-success
  (is (equal (cl-cc.tools:echo-tool "hi") "hi"))
  (is (equal (funcall (cl-cc.tools:find-tool "echo-tool") "ok") "ok")))

(test tool-execution-failure
  (signals cl-cc.lib:cl-cc-error (cl-cc.tools:failing-tool nil))
  (signals cl-cc.lib:cl-cc-error (funcall (cl-cc.tools:find-tool "failing-tool") nil)))
