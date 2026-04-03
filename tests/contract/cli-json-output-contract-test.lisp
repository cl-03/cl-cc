;;;; tests/contract/cli-json-output-contract-test.lisp - CLI JSON 输出契约测试
(in-package :cl-cc/tests)

(def-suite cli-json-output-contract-test :in cl-cc-suite)

(in-suite cli-json-output-contract-test)

(test session-command-json-output-contract
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "session-command-json-output-contract.session"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (expect-command-json-output-valid
          "session start"
          (capture-output (lambda () (cl-cc:handle-session-start "json-session" 2 "json" path))))
      (when (probe-file path)
        (delete-file path))))
  (expect-command-json-output-valid
   "session start"
   (capture-output (lambda () (cl-cc:handle-session-start "json-session" 2 "json"))))
  (expect-command-json-output-valid
   "session resume"
    (capture-output (lambda () (cl-cc:handle-session-resume "resume-user" "json"))))
    (expect-command-json-output-valid
    "session run"
    (capture-output (lambda () (cl-cc::handle-session-run "resume-user" "hello contract" "json"))))
  (expect-command-json-output-valid
   "session run"
    (capture-output (lambda () (cl-cc:main "session" "run" "resume-user" "read file README.md" "-t" "echo-tool" "--output-format" "json")))))

(test docs-sync-json-output-contract
  (let ((path (uiop:native-namestring
               (uiop:merge-pathnames* "generated-reference-json-contract-test.md"
                                      (uiop:temporary-directory)))))
    (unwind-protect
         (progn
           (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
             (write-string (format nil "before~%<!-- BEGIN GENERATED COMMAND REFERENCE -->~%old~%<!-- END GENERATED COMMAND REFERENCE -->~%after~%")
                           stream))
           (expect-command-json-output-valid
            "docs sync-reference"
            (capture-output (lambda () (cl-cc:main "docs" "sync" path "--check" "--output-format" "json"))))
           (expect-command-json-output-valid
            "docs sync-reference"
            (capture-output (lambda () (cl-cc:main "docs" "sync" path "--output-format" "json")))))
      (when (probe-file path)
        (delete-file path)))))

(test run-fixture-json-output-contract
  (expect-command-json-output-valid
   "run --fixture"
   (capture-output (lambda () (cl-cc:main "run" "--fixture" "test" "--output-format" "json"))))
  (expect-command-json-output-valid
   "run --fixture"
   (capture-output (lambda () (cl-cc:main "run" "--fixture" "test" "--output-format" "json" "--pretty"))))
  (expect-command-json-output-valid
   "run --fixture"
   (capture-output (lambda () (cl-cc:main "run" "--fixture" "test" "-o" "json" "-t" "failing-tool"))))
  (expect-command-json-output-valid
   "run --fixture"
   (capture-output (lambda () (cl-cc:main "run" "--fixture" "restricted" "-o" "json" "-t" "echo-tool")))))

(test command-json-output-schema-parse-error
  (expect-command-json-output-error-containing
   "session start"
   "{\"status\":\"success\""
   "JSON parse error"))

(test command-json-output-schema-extra-field-error
  (expect-command-json-output-error-containing
   "session start"
   "{\"status\":\"success\",\"sessionId\":\"json-session\",\"durationSeconds\":0.01,\"exitCode\":0,\"extraField\":true}"
   "payload.extra-field: unexpected field"))