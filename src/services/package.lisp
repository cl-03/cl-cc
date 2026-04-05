;;;; src/services/package.lisp
(defpackage :cl-cc.services
  (:use :cl :cl-cc)
  (:export :check-permission :audit-permission :load-fixture :select-tools :plan-session-execution
           :run-tool :compare-golden
           :start-session :start-session-result
           :list-sessions :list-sessions-result
           :resume-session :resume-session-result
           :run-session :run-session-result
           :run-fixture :run-fixtures :last-execution-results
           :command-result-schema-errors :command-result-conforms-p
           :command-json-output-schema-errors :command-json-output-conforms-p
           :run-fixture-result-schema-errors :run-fixture-result-conforms-p
           :docs-sync-result-schema-errors :docs-sync-result-conforms-p
           :session-start-result-schema-errors :session-start-result-conforms-p
           :session-resume-result-schema-errors :session-resume-result-conforms-p
           :session-run-result-schema-errors :session-run-result-conforms-p
           :session-list-result-schema-errors :session-list-result-conforms-p))
(in-package :cl-cc.services)
