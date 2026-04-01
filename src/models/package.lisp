;;;; src/models/package.lisp
(defpackage :cl-cc.models
  (:use :cl :cl-cc)
  (:export :command-definition :command-name :command-aliases :command-arguments-schema
           :command-output-schema :command-summary :command-handler-symbol :command-permission-profile
           :tool-definition :tool-id :tool-summary :tool-handler-function :tool-input-schema :tool-output-schema :tool-error-output-schema
           :tool-failure-modes :tool-permission-profile
           :session-state :session-id :session-created-at :session-updated-at
           :session-history-index :session-context-summary :session-permission-snapshot
           :session-status :session-version
           :execution-cycle :cycle-id :cycle-command-name :cycle-input-payload
           :cycle-selected-tools :cycle-context-before :cycle-context-after
           :cycle-result-status :cycle-result-summary
           :permission-decision :decision-id :decision-action-kind :decision-decision
           :decision-reason-code :decision-human-summary :decision-audit-payload
           :compatibility-fixture :fixture-id :fixture-reference-source :fixture-scenario-name
           :fixture-input-sample :fixture-expected-output :fixture-deviation-policy
           :fixture-notes))
(in-package :cl-cc.models)
