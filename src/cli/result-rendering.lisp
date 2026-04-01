;;;; src/cli/result-rendering.lisp - 结构化 CLI 结果渲染
(in-package :cl-cc)

(defun %cli-json-escape-string (value)
  (with-output-to-string (stream)
    (loop for character across value do
      (case character
        (#\\ (write-string "\\\\" stream))
        (#\" (write-string "\\\"" stream))
        (#\Newline (write-string "\\n" stream))
        (#\Return (write-string "\\r" stream))
        (#\Tab (write-string "\\t" stream))
        (t (write-char character stream))))))

(defun %cli-json-boolean (value)
  (if value "true" "false"))

(defun %cli-json-string-or-null (value)
  (if value
      (format nil "\"~A\"" (%cli-json-escape-string value))
      "null"))

(defun %cli-json-number-or-null (value)
  (if value
      (%cli-json-number value)
      "null"))

(defun %cli-json-number (value)
  (cond
    ((integerp value) (format nil "~D" value))
    ((floatp value) (string-downcase (format nil "~F" value)))
    ((rationalp value) (string-downcase (format nil "~F" (coerce value 'double-float))))
    (t (format nil "~A" value))))

(defun %cli-result-status-name (status)
  (string-downcase (string status)))

(defun %cli-render-status-counts-json (status-counts)
  (with-output-to-string (stream)
    (write-char #\{ stream)
    (loop for entry in status-counts
          for first-entry = t then nil do
      (unless first-entry
        (write-char #\, stream))
      (format stream
              "\"~A\":~D"
              (%cli-json-escape-string (car entry))
              (cdr entry)))
    (write-char #\} stream)))

(defun %cli-render-status-counts-pretty-json (status-counts)
  (with-output-to-string (stream)
    (write-string "{" stream)
    (loop with last-entry = (car (last status-counts))
          for entry in status-counts do
      (write-char #\Newline stream)
      (write-string "    " stream)
      (format stream
              "\"~A\": ~D"
              (%cli-json-escape-string (car entry))
              (cdr entry))
      (unless (eq entry last-entry)
        (write-char #\, stream)))
    (write-char #\Newline stream)
    (write-string "  }" stream)))

(defun %cli-plist-key-name (key)
  (string-downcase (string key)))

(defun %cli-json-value (value)
  (cond
    ((null value) "null")
    ((stringp value) (format nil "\"~A\"" (%cli-json-escape-string value)))
    ((symbolp value) (format nil "\"~A\"" (%cli-json-escape-string (%cli-result-status-name value))))
    ((numberp value) (%cli-json-number value))
    ((listp value) (%cli-render-plist-json value))
    (t (format nil "\"~A\"" (%cli-json-escape-string (princ-to-string value))))))

(defun %cli-render-plist-json (plist)
  (with-output-to-string (stream)
    (write-char #\{ stream)
    (loop for (key value) on plist by #'cddr
          for first-entry = t then nil do
      (unless first-entry
        (write-char #\, stream))
      (format stream
              "\"~A\":~A"
              (%cli-json-escape-string (%cli-plist-key-name key))
              (%cli-json-value value)))
    (write-char #\} stream)))

(defun %cli-render-tool-result-json (record)
  (format nil
          "{\"toolId\":\"~A\",\"status\":\"~A\",\"durationSeconds\":~A,\"output\":~A,\"error\":~A,\"errorCode\":~A}"
          (%cli-json-escape-string (getf record :tool))
          (%cli-json-escape-string (%cli-result-status-name (getf record :status)))
          (%cli-json-number (getf record :duration-seconds 0d0))
          (%cli-json-value (getf record :output))
          (%cli-json-string-or-null (getf record :error))
          (%cli-json-string-or-null (and (getf record :error-code)
                                         (string-upcase (string (getf record :error-code)))))))

(defun %cli-render-tool-result-pretty-json (record)
  (format nil
          "{~%  \"toolId\": \"~A\",~%  \"status\": \"~A\",~%  \"durationSeconds\": ~A,~%  \"output\": ~A,~%  \"error\": ~A,~%  \"errorCode\": ~A~%}"
          (%cli-json-escape-string (getf record :tool))
          (%cli-json-escape-string (%cli-result-status-name (getf record :status)))
          (%cli-json-number (getf record :duration-seconds 0d0))
          (%cli-json-value (getf record :output))
          (%cli-json-string-or-null (getf record :error))
          (%cli-json-string-or-null (and (getf record :error-code)
                                         (string-upcase (string (getf record :error-code)))))))

(defun %cli-render-result-record-json (record)
  (format nil
          "{\"fixtureId\":\"~A\",\"status\":\"~A\",\"durationSeconds\":~A,\"result\":\"~A\",\"toolResults\":[~{~A~^,~}]}"
          (%cli-json-escape-string (getf record :fixture-id))
          (%cli-json-escape-string (%cli-result-status-name (getf record :status)))
          (%cli-json-number (getf record :duration-seconds 0d0))
          (%cli-json-escape-string (getf record :result))
          (mapcar #'%cli-render-tool-result-json (getf record :tool-results))))

(defun %cli-render-result-record-pretty-json (record)
  (format nil
          "{~%  \"fixtureId\": \"~A\",~%  \"status\": \"~A\",~%  \"durationSeconds\": ~A,~%  \"result\": \"~A\",~%  \"toolResults\": [~%~{~A~^,~%~}~%  ]~%}"
          (%cli-json-escape-string (getf record :fixture-id))
          (%cli-json-escape-string (%cli-result-status-name (getf record :status)))
          (%cli-json-number (getf record :duration-seconds 0d0))
          (%cli-json-escape-string (getf record :result))
          (mapcar (lambda (tool-record)
                    (%cli-indent-lines (%cli-render-tool-result-pretty-json tool-record) "    "))
                  (getf record :tool-results))))

(defun %cli-indent-lines (text prefix)
  (with-output-to-string (stream)
    (loop with first-line = t
          for line in (uiop:split-string text :separator '(#\Newline)) do
      (unless first-line
        (write-char #\Newline stream))
      (setf first-line nil)
      (write-string prefix stream)
      (write-string line stream))))

(defun render-run-fixture-result (result-object &key pretty-json)
  (let* ((payload (cl-cc.lib:result-payload result-object))
         (status (cl-cc.lib:result-status result-object))
         (status-counts (getf payload :status-counts))
         (results (getf payload :results)))
    (if pretty-json
        (format nil
          "{~%  \"status\": \"~A\",~%  \"fixtureCount\": ~D,~%  \"successfulCount\": ~D,~%  \"failedCount\": ~D,~%  \"durationSeconds\": ~A,~%  \"statusCounts\": ~A,~%  \"ok\": ~A,~%  \"exitCode\": ~D,~%  \"results\": [~%~{~A~^,~%~}~%  ]~%}"
                (%cli-json-escape-string (%cli-result-status-name status))
                (getf payload :fixture-count)
                (getf payload :successful-count)
                (getf payload :failed-count)
          (%cli-json-number (getf payload :duration-seconds 0d0))
                (%cli-render-status-counts-pretty-json status-counts)
                (%cli-json-boolean (getf payload :ok))
                (getf payload :exit-code)
                (mapcar (lambda (record)
                          (%cli-indent-lines (%cli-render-result-record-pretty-json record) "    "))
                        results))
        (format nil
          "{\"status\":\"~A\",\"fixtureCount\":~D,\"successfulCount\":~D,\"failedCount\":~D,\"durationSeconds\":~A,\"statusCounts\":~A,\"ok\":~A,\"exitCode\":~D,\"results\":[~{~A~^,~}]}"
                (%cli-json-escape-string (%cli-result-status-name status))
                (getf payload :fixture-count)
                (getf payload :successful-count)
                (getf payload :failed-count)
          (%cli-json-number (getf payload :duration-seconds 0d0))
                (%cli-render-status-counts-json status-counts)
                (%cli-json-boolean (getf payload :ok))
                (getf payload :exit-code)
                (mapcar #'%cli-render-result-record-json results)))))

(defun render-docs-sync-result (result-object)
  (let* ((payload (cl-cc.lib:result-payload result-object))
         (status (cl-cc.lib:result-status result-object)))
    (format nil
            "{\"path\":\"~A\",\"status\":\"~A\",\"checkOnly\":~A,\"updated\":~A,\"needsSync\":~A,\"durationSeconds\":~A,\"exitCode\":~D}"
            (%cli-json-escape-string (getf payload :path))
            (%cli-json-escape-string (%cli-result-status-name status))
            (%cli-json-boolean (getf payload :check-only))
            (%cli-json-boolean (getf payload :updated))
            (%cli-json-boolean (getf payload :needs-sync))
            (%cli-json-number (getf payload :duration-seconds 0d0))
            (getf payload :exit-code))))

(defun render-session-command-result (result-object &key output-format)
  (if (string= (or output-format "text") "json")
      (let* ((payload (cl-cc.lib:result-payload result-object))
             (status (cl-cc.lib:result-status result-object))
             (session-status (getf payload :session-status)))
        (format nil
          "{\"status\":\"~A\",\"sessionId\":~A,\"historyIndex\":~A,\"sessionStatus\":~A,\"durationSeconds\":~A,\"exitCode\":~D}"
                (%cli-json-escape-string (%cli-result-status-name status))
                (%cli-json-string-or-null (getf payload :session-id))
                (%cli-json-number-or-null (getf payload :history-index))
                (%cli-json-string-or-null (and session-status (%cli-result-status-name session-status)))
          (%cli-json-number (getf payload :duration-seconds 0d0))
                (getf payload :exit-code 0)))
      (cl-cc.lib:result-message result-object)))