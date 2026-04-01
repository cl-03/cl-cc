;;;; tests/unit/cli-output-test.lisp - CLI 输出单元测试
(in-package :cl-cc/tests)

(def-suite cli-output-test :in cl-cc-suite)

(in-suite cli-output-test)

(test main-help-output
  (let ((output (capture-output (lambda () (cl-cc:main "--help")))))
    (is (search "Usage:" output))
    (is (search "docs sync-reference [<output-path>] [--check] [--output-format <output-format>]" output))
    (is (search "session start [--session-id <session-id>] [--history-index <history-index>]" output))
    (is (search "run --fixture <fixture-id>... [--output-format <output-format>]" output))
    (is (search "aliases: cl-cc r --fixture" output))
    (is (search "options:" output))
    (is (search "--check" output))
    (is (search "--output-format <output-format>" output))
    (is (search "-i, --session-id <session-id>" output))
    (is (search "-o, --output-format <output-format>" output))
    (is (search "--pretty" output))
    (is (search "--compact" output))
    (is (search "-t, --tool <tool-id>" output))))

(test session-start-output
  (let ((output (capture-output (lambda () (cl-cc:handle-session-start)))))
    (is (search "新会话已创建" output))))

(test session-start-json-output
  (let ((output (capture-output (lambda () (cl-cc:handle-session-start "json-session" 2 "json")))))
    (is (search "\"status\":\"success\"" output))
    (is (search "\"sessionId\":\"json-session\"" output))
    (is (search "\"durationSeconds\":" output))
    (is (search "\"historyIndex\":2" output))))

(test session-resume-output
  (let ((output (capture-output (lambda () (cl-cc:handle-session-resume "resume-user")))))
    (is (search "会话已恢复: resume-user" output))))

(test session-resume-json-output
  (let ((output (capture-output (lambda () (cl-cc:handle-session-resume "resume-user" "json")))))
    (is (search "\"status\":\"success\"" output))
    (is (search "\"sessionId\":\"resume-user\"" output))
    (is (search "\"durationSeconds\":" output))
    (is (search "\"historyIndex\":null" output))))