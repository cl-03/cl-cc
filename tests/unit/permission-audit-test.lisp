;;;; tests/unit/permission-audit-test.lisp - permission-audit 单元测试
(in-package :cl-cc/tests)

(def-suite permission-audit-test :in cl-cc-suite)

(in-suite permission-audit-test)

(test permission-audit-helper-rendering-remains-stable
  (is (eq (cl-cc.services::%permission-audit-action '(:action echo-tool)) 'echo-tool))
  (is (eq (cl-cc.services::%permission-audit-action '(:tool "echo-tool")) :unknown))
  (is (eq (cl-cc.services::%permission-audit-reason :allow) :allowed))
  (is (eq (cl-cc.services::%permission-audit-reason :deny) :denied-by-policy))
  (is (eq (cl-cc.services::%permission-audit-reason :allow '(:decision-source :user-prompt)) :approved-by-user))
  (is (eq (cl-cc.services::%permission-audit-reason :deny '(:decision-source :user-prompt)) :denied-by-user))
  (is (string= (cl-cc.services::%permission-audit-summary :allow 'echo-tool)
               "action ECHO-TOOL allowed"))
  (is (string= (cl-cc.services::%permission-audit-summary :deny 'delete-file)
               "action DELETE-FILE denied"))
  (is (string= (cl-cc.services::%permission-audit-summary :allow 'file-write '(:decision-source :user-prompt))
               "action FILE-WRITE approved by user"))
  (is (string= (cl-cc.services::%permission-audit-summary :deny 'file-write '(:decision-source :user-prompt))
               "action FILE-WRITE denied by user")))

(test audit-permission-populates-allowed-decision-fields
  (let* ((context '(:action echo-tool :tool "echo-tool" :input "fixture-input-test"))
         (audit (cl-cc.services:audit-permission :allow context)))
    (is (typep audit 'cl-cc.models:permission-decision))
    (is (search "perm-" (cl-cc.models:decision-id audit)))
    (is (eq (cl-cc.models:decision-action-kind audit) 'echo-tool))
    (is (eq (cl-cc.models:decision-decision audit) :allow))
    (is (eq (cl-cc.models:decision-reason-code audit) :allowed))
    (is (string= (cl-cc.models:decision-human-summary audit)
                 "action ECHO-TOOL allowed"))
    (is (equal (cl-cc.models:decision-audit-payload audit) context))))

(test audit-permission-populates-denied-decision-fields
  (let* ((context '(:action delete-file :tool "echo-tool" :input "restricted"))
         (audit (cl-cc.services:audit-permission :deny context)))
    (is (typep audit 'cl-cc.models:permission-decision))
    (is (eq (cl-cc.models:decision-action-kind audit) 'delete-file))
    (is (eq (cl-cc.models:decision-decision audit) :deny))
    (is (eq (cl-cc.models:decision-reason-code audit) :denied-by-policy))
    (is (string= (cl-cc.models:decision-human-summary audit)
                 "action DELETE-FILE denied"))
    (is (equal (cl-cc.models:decision-audit-payload audit) context))))

(test audit-permission-populates-user-prompt-decision-fields
  (let* ((context '(:action file-write
                   :tool "file-write-tool"
                   :input (:path "tmp/demo.txt" :content "hello")
                   :decision-source :user-prompt))
         (allowed-audit (cl-cc.services:audit-permission :allow context))
         (denied-audit (cl-cc.services:audit-permission :deny context)))
    (is (eq (cl-cc.models:decision-reason-code allowed-audit) :approved-by-user))
    (is (string= (cl-cc.models:decision-human-summary allowed-audit)
                 "action FILE-WRITE approved by user"))
    (is (eq (cl-cc.models:decision-reason-code denied-audit) :denied-by-user))
    (is (string= (cl-cc.models:decision-human-summary denied-audit)
                 "action FILE-WRITE denied by user"))))