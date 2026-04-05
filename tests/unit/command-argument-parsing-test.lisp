;;;; tests/unit/command-argument-parsing-test.lisp
(in-package :cl-cc/tests)

(def-suite command-argument-parsing-test :in cl-cc-suite)
(in-suite command-argument-parsing-test)

(test parses-inline-and-repeatable-options
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command "run --fixture"))
         (parsed (cl-cc.core::%validate-command-arguments definition
                                                          '("run" "--fixture")
                                                          '("run" "--fixture" "test" "--output-format=json" "-t" "echo-tool" "-t" "failing-tool"))))
    (is (equal (cl-cc.core:command-positional-arguments parsed) '("test")))
    (is (string= (cl-cc.core:command-option-value parsed :output-format) "json"))
    (is (equal (cl-cc.core:command-option-values parsed :tool-ids)
               '("echo-tool" "failing-tool")))))

(test applies-conditional-output-format-defaults
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command "run --fixture"))
         (parsed (cl-cc.core::%validate-command-arguments definition
                                                          '("run" "--fixture")
                                                          '("run" "--fixture" "test" "--pretty"))))
    (is (string= (cl-cc.core:command-option-value parsed :output-format) "json"))
    (is (cl-cc.core:command-option-value parsed :pretty-json))))

(test explicit-option-value-wins-over-conditional-default
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command "run --fixture"))
         (parsed (cl-cc.core::%validate-command-arguments definition
                                                          '("run" "--fixture")
                                                          '("run" "--fixture" "test" "--output-format" "json" "--pretty"))))
    (is (string= (cl-cc.core:command-option-value parsed :output-format) "json"))
    (is (cl-cc.core:command-option-value parsed :pretty-json))))

(test renders-option-help-lines-with-constraints
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command "run --fixture"))
         (help-lines (cl-cc.core::command-option-help-lines definition)))
    (is (find "      -o, --output-format <output-format>  指定输出格式: text 或 json [default: text]"
              help-lines
              :test #'string=))
    (is (find "      --pretty  以多行缩进格式输出 JSON [requires: --output-format=json] [conflicts: --compact]"
              help-lines
              :test #'string=))
    (is (find "      --compact  以紧凑单行格式输出 JSON [requires: --output-format=json] [conflicts: --pretty]"
              help-lines
              :test #'string=))
    (is (find "      -t, --tool <tool-id>  覆盖自动工具选择并按给定顺序执行 [repeatable]"
              help-lines
              :test #'string=))))

(test invalid-arguments-helper-rendering
  (cl-cc.core:ensure-default-commands)
  (let ((definition (cl-cc.core:find-command "run --fixture")))
    (is (string= (cl-cc.core::%invalid-arguments-message definition)
                 "Invalid arguments for command run --fixture"))
    (let ((condition (cl-cc.core::%invalid-arguments-error definition)))
      (is (string= (string (cl-cc.lib:error-code condition)) "INVALID-ARGUMENTS"))
      (is (string= (cl-cc.lib:error-message condition)
                   "Invalid arguments for command run --fixture")))))

(test rejects-missing-and-unknown-options
  (cl-cc.core:ensure-default-commands)
  (let ((definition (cl-cc.core:find-command "run --fixture")))
    (handler-case
        (progn
          (cl-cc.core::%validate-command-arguments definition
                                                   '("run" "--fixture")
                                                   '("run" "--fixture" "test" "-t"))
          (fail "expected invalid arguments for missing option value"))
      (cl-cc.lib:cl-cc-error (condition)
        (is (string= (string (cl-cc.lib:error-code condition)) "INVALID-ARGUMENTS"))))
    (handler-case
        (progn
          (cl-cc.core::%validate-command-arguments definition
                                                   '("run" "--fixture")
                                                   '("run" "--fixture" "test" "--unknown"))
          (fail "expected invalid arguments for unknown option"))
      (cl-cc.lib:cl-cc-error (condition)
        (is (string= (string (cl-cc.lib:error-code condition)) "INVALID-ARGUMENTS"))))))

(test preserves-repeatable-positionals-with-mixed-options
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command "run --fixture"))
         (parsed (cl-cc.core::%validate-command-arguments definition
                                                          '("run" "--fixture")
                                                          '("run" "--fixture"
                                                            "alpha"
                                                            "--output-format=json"
                                                            "beta"
                                                            "-t" "echo-tool"
                                                            "gamma"))))
    (is (equal (cl-cc.core:command-positional-arguments parsed)
               '("alpha" "beta" "gamma")))
    (is (string= (cl-cc.core:command-option-value parsed :output-format) "json"))
    (is (equal (cl-cc.core:command-option-values parsed :tool-ids)
               '("echo-tool")))))

(test parses-optional-positional-before-options
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command "docs sync-reference"))
         (parsed (cl-cc.core::%validate-command-arguments definition
                                                          '("docs" "sync-reference")
                                                          '("docs" "sync-reference"
                                                            "README.md"
                                                            "--auth-scope" "public"
                                                            "--group-scope" "docs"
                                                            "--output-format" "json"))))
    (is (equal (cl-cc.core:command-positional-arguments parsed)
               '("README.md")))
    (is (string= (cl-cc.core:command-option-value parsed :auth-scope) "public"))
    (is (string= (cl-cc.core:command-option-value parsed :group-scope) "docs"))
    (is (string= (cl-cc.core:command-option-value parsed :output-format) "json"))))

(test session-run-parses-repeatable-tool-overrides
  (cl-cc.core:ensure-default-commands)
  (let* ((definition (cl-cc.core:find-command "session run"))
         (parsed (cl-cc.core::%validate-command-arguments definition
                                                          '("session" "run")
                                                          '("session" "run" "resume-user" "hello" "-t" "file-write-tool" "-t" "echo-tool"))))
    (is (equal (cl-cc.core:command-positional-arguments parsed)
               '("resume-user" "hello")))
    (is (equal (cl-cc.core:command-option-values parsed :tool-ids)
               '("file-write-tool" "echo-tool")))))

(test rejects-inline-values-for-flag-options
  (cl-cc.core:ensure-default-commands)
  (let ((definition (cl-cc.core:find-command "run --fixture")))
    (handler-case
        (progn
          (cl-cc.core::%validate-command-arguments definition
                                                   '("run" "--fixture")
                                                   '("run" "--fixture" "test" "--pretty=true"))
          (fail "expected invalid arguments for inline flag assignment"))
      (cl-cc.lib:cl-cc-error (condition)
        (is (string= (string (cl-cc.lib:error-code condition)) "INVALID-ARGUMENTS"))))))

(test conditional-defaults-still-flow-through-constraint-validation
  (cl-cc.core:ensure-default-commands)
  (let ((definition (cl-cc.core:find-command "run --fixture")))
    (handler-case
        (progn
          (cl-cc.core::%validate-command-arguments definition
                                                   '("run" "--fixture")
                                                   '("run" "--fixture" "test" "--pretty" "--compact"))
          (fail "expected invalid arguments for conflicting flags after default application"))
      (cl-cc.lib:cl-cc-error (condition)
        (is (string= (string (cl-cc.lib:error-code condition)) "INVALID-ARGUMENTS"))))))