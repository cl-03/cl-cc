;;;; tests/unit/command-resolution-test.lisp
(in-package :cl-cc/tests)

(def-suite command-resolution-test :in cl-cc-suite)
(in-suite command-resolution-test)

(test normalizes-command-patterns
  (is (equal (cl-cc.core::%normalize-command-pattern '("docs" "sync")) '("docs" "sync")))
  (is (equal (cl-cc.core::%normalize-command-pattern "help") '("help")))
  (is (null (cl-cc.core::%normalize-command-pattern '(:invalid)))))

(test resolves-help-and-alias-patterns
  (cl-cc.core:ensure-default-commands)
  (multiple-value-bind (help-definition help-pattern)
      (cl-cc.core::%resolve-command '("run" "--help"))
    (is (string= (cl-cc.models:command-name help-definition) "help"))
    (is (equal help-pattern '("--help"))))
  (multiple-value-bind (resume-definition resume-pattern)
      (cl-cc.core::%resolve-command '("s" "resume" "abc"))
    (is (string= (cl-cc.models:command-name resume-definition) "session resume"))
    (is (equal resume-pattern '("s" "resume")))))

(test command-patterns-include-primary-and-normalized-aliases
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command "session resume"))
         (patterns (cl-cc.core::%command-patterns definition)))
    (is (find '("session" "resume") patterns :test #'equal))
    (is (find '("s" "resume") patterns :test #'equal))))

(test pattern-matching-allows-extra-argv-tail
  (is (cl-cc.core::%pattern-matches-argv-p '("run" "--fixture")
                                           '("run" "--fixture" "test" "extra")))
  (is (not (cl-cc.core::%pattern-matches-argv-p '("run" "--fixture")
                                                '("run")))))

(test lists-command-definitions-sorted
  (cl-cc.core:ensure-default-commands)
  (let ((names (mapcar #'cl-cc.models:command-name
                       (cl-cc.core:list-command-definitions))))
    (is (equal names (sort (copy-list names) #'string<)))
    (is (find "help" names :test #'string=))
    (is (find "run --fixture" names :test #'string=))))