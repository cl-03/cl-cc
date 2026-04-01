;;;; tests/unit/session-store-test.lisp - 会话存储单元测试
(in-package :cl-cc/tests)

(def-suite session-store-test :in cl-cc-suite)

(in-suite session-store-test)

(test save-load-session
  (let* ((session (make-instance 'cl-cc.models:session-state :session-id "sid" :created-at "now" :updated-at "now" :history-index nil :context-summary nil :permission-snapshot nil :status :active :version "0.1"))
         (save-ok (cl-cc.session:save-session session "tmp.session"))
         (loaded (cl-cc.session:load-session "tmp.session")))
    (is (not (null save-ok)))
    (is (typep loaded 'cl-cc.models:session-state))
    (is (string= (cl-cc.models:session-id loaded) "sid"))))
