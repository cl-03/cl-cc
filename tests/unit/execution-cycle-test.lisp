;;;; tests/unit/execution-cycle-test.lisp - 执行循环状态迁移单元测试
(in-package :cl-cc/tests)

(def-suite execution-cycle-test :in cl-cc-suite)

(in-suite execution-cycle-test)

(test execution-cycle-init
  (let ((cycle (make-instance 'cl-cc.models:execution-cycle :cycle-id "cid" :command-name "run" :input-payload "foo" :selected-tools '("echo-tool") :context-before nil :context-after nil :result-status :success :result-summary "ok")))
    (is (string= (cl-cc.models:cycle-command-name cycle) "run"))
    (is (string= (cl-cc.models:cycle-input-payload cycle) "foo"))
    (is (equal (cl-cc.models:cycle-selected-tools cycle) '("echo-tool")))
    (is (eq (cl-cc.models:cycle-result-status cycle) :success))))
