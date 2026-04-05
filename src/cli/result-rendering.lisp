;;;; src/cli/result-rendering.lisp - 结构化 CLI 结果渲染
(in-package :cl-cc)

(defun %cli-error-log-message (condition)
  (format nil "[ERROR] ~A: ~A"
          (cl-cc.lib:error-code condition)
          (cl-cc.lib:error-message condition)))

(defun %cli-unhandled-error-log-message (condition)
  (format nil "[UNHANDLED ERROR] ~A" condition))

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

(defun %cli-json-null ()
  "null")

(defun %cli-json-string (value)
  (format nil "\"~A\"" (%cli-json-escape-string value)))

(defun %cli-json-boolean (value)
  (if value "true" "false"))

(defun %cli-json-string-or-null (value)
  (if value
      (%cli-json-string value)
      (%cli-json-null)))

(defun %cli-json-number-or-null (value)
  (if value
      (%cli-json-number value)
      (%cli-json-null)))

(defun %cli-json-number (value)
  (cond
    ((integerp value) (format nil "~D" value))
    ((floatp value) (string-downcase (format nil "~F" value)))
    ((rationalp value) (string-downcase (format nil "~F" (coerce value 'double-float))))
    (t (format nil "~A" value))))

(defun %cli-result-status-name (status)
  (cl-cc.lib:string-designator-downcase status))

(defun %cli-render-status-count-entry (entry &key spaced)
  (format nil
          (if spaced
              "\"~A\": ~D"
              "\"~A\":~D")
          (%cli-json-escape-string (car entry))
          (cdr entry)))

(defun %cli-render-status-counts (status-counts &key pretty)
  (with-output-to-string (stream)
    (if pretty
        (progn
          (write-string "{" stream)
          (loop with last-entry = (car (last status-counts))
                for entry in status-counts do
            (write-char #\Newline stream)
            (write-string "    " stream)
            (write-string (%cli-render-status-count-entry entry :spaced t) stream)
            (unless (eq entry last-entry)
              (write-char #\, stream)))
          (write-char #\Newline stream)
          (write-string "  }" stream))
        (progn
          (write-char #\{ stream)
          (loop for entry in status-counts
                for first-entry = t then nil do
            (unless first-entry
              (write-char #\, stream))
            (write-string (%cli-render-status-count-entry entry) stream))
          (write-char #\} stream)))))

(defun %cli-render-status-counts-json (status-counts)
  (%cli-render-status-counts status-counts))

(defun %cli-render-status-counts-pretty-json (status-counts)
  (%cli-render-status-counts status-counts :pretty t))

(defun %cli-plist-key-name (key)
  (let* ((text (cl-cc.lib:string-designator-downcase key))
         (segments (uiop:split-string text :separator '(#\-))))
    (if (null segments)
        ""
        (with-output-to-string (stream)
          (write-string (first segments) stream)
          (dolist (segment (rest segments))
            (when (> (length segment) 0)
              (write-char (char-upcase (char segment 0)) stream)
              (when (> (length segment) 1)
                (write-string (subseq segment 1) stream))))))))

(defun %cli-key-default-false-p (key)
  (member key '(:ignore-case :use-regex :multiline :dot-all :whole-word :left-word-boundary :right-word-boundary :timed-out :background :running :stopped :stall-detected :wait-until-finished) :test #'eq))

(defun %cli-json-plist-field-value (key value)
  (if (and (null value)
           (%cli-key-default-false-p key))
      (%cli-json-boolean nil)
      (%cli-json-value value)))

(defun %cli-plist-json-fields (plist)
  (loop for (key value) on plist by #'cddr
        collect (%cli-json-field (%cli-json-escape-string (%cli-plist-key-name key))
                                 (%cli-json-plist-field-value key value))))

(defun %cli-json-value (value)
  (cond
    ((null value) (%cli-json-null))
    ((eq value t) (%cli-json-boolean t))
    ((stringp value) (%cli-json-string value))
    ((symbolp value) (%cli-json-string (%cli-result-status-name value)))
    ((numberp value) (%cli-json-number value))
    ((and (listp value) (or (null value)
                            (not (and (evenp (length value))
                                      (loop for key in value by #'cddr
                                            always (keywordp key))))))
     (%cli-render-json-array (mapcar #'%cli-json-value value)))
    ((listp value) (%cli-render-plist-json value))
    (t (%cli-json-string (princ-to-string value)))))

(defun %cli-render-plist-json (plist)
  (%cli-render-json-object (%cli-plist-json-fields plist)))

(defun %cli-json-field (name rendered-value)
  (format nil "\"~A\":~A" name rendered-value))

(defun %cli-json-field-spaced (name rendered-value)
  (format nil "\"~A\": ~A" name rendered-value))

(defun %cli-json-field-renderer (spaced)
  (if spaced #'%cli-json-field-spaced #'%cli-json-field))

(defun %cli-render-json-fields (field-specs &key spaced)
  (let ((field-renderer (%cli-json-field-renderer spaced)))
    (mapcar (lambda (field-spec)
              (funcall field-renderer
                       (first field-spec)
                       (second field-spec)))
            field-specs)))

(defun %cli-render-json-object (fields)
  (format nil "{~{~A~^,~}}" fields))

(defun %cli-render-json-object-pretty (fields)
  (format nil "{~%  ~{~A~^,~%  ~}~%}" fields))

(defun %cli-render-json-array (items)
  (format nil "[~{~A~^,~}]" items))

(defun %cli-render-json-array-pretty (items &key (closing-indent "  "))
  (format nil "[~%~{~A~^,~%~}~%~A]" items closing-indent))

(defun %cli-tool-result-error-code (record)
  (%cli-json-string-or-null (and (getf record :error-code)
                                 (cl-cc.lib:string-designator-upcase (getf record :error-code)))))

(defun %cli-tool-result-json-fields (record &key spaced)
  (%cli-render-json-fields
   (list (list "toolId"
       (%cli-json-string-or-null (getf record :tool)))
     (list "status"
       (%cli-json-string-or-null (%cli-result-status-name (getf record :status))))
     (list "durationSeconds"
       (%cli-json-number (getf record :duration-seconds 0d0)))
     (list "output"
       (%cli-json-value (getf record :output)))
     (list "error"
       (%cli-json-string-or-null (getf record :error)))
     (list "errorCode"
       (%cli-tool-result-error-code record)))
   :spaced spaced))

(defun %cli-result-record-json-fields (record &key spaced)
  (%cli-render-json-fields
   (list (list "fixtureId"
       (%cli-json-string-or-null (getf record :fixture-id)))
     (list "status"
       (%cli-json-string-or-null (%cli-result-status-name (getf record :status))))
     (list "durationSeconds"
       (%cli-json-number (getf record :duration-seconds 0d0)))
     (list "result"
       (%cli-json-string-or-null (getf record :result)))
     (list "toolResults"
       (%cli-render-json-array
        (mapcar #'%cli-render-tool-result-json (getf record :tool-results)))))
   :spaced spaced))

(defun %cli-render-tool-result-json (record)
  (%cli-render-json-object (%cli-tool-result-json-fields record)))

(defun %cli-render-tool-result-pretty-json (record)
  (%cli-render-json-object-pretty (%cli-tool-result-json-fields record :spaced t)))

(defun %cli-render-result-record-json (record)
  (%cli-render-json-object (%cli-result-record-json-fields record)))

(defun %cli-render-result-record-pretty-json (record)
  (let* ((fields (%cli-result-record-json-fields record :spaced t))
         (tool-records (mapcar (lambda (tool-record)
                                 (%cli-indent-lines (%cli-render-tool-result-pretty-json tool-record) "    "))
                               (getf record :tool-results))))
    (setf (car (last fields))
          (format nil "\"toolResults\": ~A"
                  (%cli-render-json-array-pretty tool-records)))
    (%cli-render-json-object-pretty fields)))

(defun %cli-indent-lines (text prefix)
  (with-output-to-string (stream)
    (loop with first-line = t
          for line in (uiop:split-string text :separator '(#\Newline)) do
      (unless first-line
        (write-char #\Newline stream))
      (setf first-line nil)
      (write-string prefix stream)
      (write-string line stream))))

(defun %cli-run-fixture-json-fields (result-object &key spaced status-counts-value results-value)
  (let* ((payload (cl-cc.lib:result-payload result-object))
     (status (cl-cc.lib:result-status result-object)))
    (%cli-render-json-fields
     (list (list "status"
         (%cli-json-string-or-null (%cli-result-status-name status)))
       (list "fixtureCount"
         (format nil "~D" (getf payload :fixture-count)))
       (list "successfulCount"
         (format nil "~D" (getf payload :successful-count)))
       (list "failedCount"
         (format nil "~D" (getf payload :failed-count)))
       (list "durationSeconds"
         (%cli-json-number (getf payload :duration-seconds 0d0)))
       (list "statusCounts" status-counts-value)
       (list "ok"
         (%cli-json-boolean (getf payload :ok)))
       (list "exitCode"
         (format nil "~D" (getf payload :exit-code)))
       (list "results" results-value))
     :spaced spaced)))

(defun %cli-docs-sync-json-fields (result-object)
  (let* ((payload (cl-cc.lib:result-payload result-object))
         (status (cl-cc.lib:result-status result-object)))
    (list (%cli-json-field "path"
                           (%cli-json-string-or-null (getf payload :path)))
          (%cli-json-field "status"
                           (%cli-json-string-or-null (%cli-result-status-name status)))
          (%cli-json-field "checkOnly"
                           (%cli-json-boolean (getf payload :check-only)))
          (%cli-json-field "updated"
                           (%cli-json-boolean (getf payload :updated)))
          (%cli-json-field "needsSync"
                           (%cli-json-boolean (getf payload :needs-sync)))
          (%cli-json-field "durationSeconds"
                           (%cli-json-number (getf payload :duration-seconds 0d0)))
          (%cli-json-field "exitCode"
                           (format nil "~D" (getf payload :exit-code))))))

(defun %cli-session-command-json-fields (result-object)
  (let* ((payload (cl-cc.lib:result-payload result-object))
         (status (cl-cc.lib:result-status result-object))
         (session-status (getf payload :session-status))
         (input (getf payload :input :missing))
         (execution-status (getf payload :execution-status :missing))
         (selected-tools (getf payload :selected-tools :missing))
         (execution-plan (getf payload :execution-plan :missing))
      (git-root (getf payload :git-root :missing))
      (git-branch (getf payload :git-branch :missing))
      (git-dirty (getf payload :git-dirty :missing))
      (git-status-lines (getf payload :git-status-lines :missing))
      (git-recent-commits (getf payload :git-recent-commits :missing))
         (result (getf payload :result :missing))
         (tool-results (getf payload :tool-results :missing))
         (session-path (getf payload :session-path :missing))
         (saved (getf payload :saved :missing))
         (fields (list (%cli-json-field "status"
                                        (%cli-json-string-or-null (%cli-result-status-name status)))
                       (%cli-json-field "sessionId"
                                        (%cli-json-string-or-null (getf payload :session-id)))
                       (%cli-json-field "historyIndex"
                                        (%cli-json-number-or-null (getf payload :history-index)))
                       (%cli-json-field "sessionStatus"
                                        (%cli-json-string-or-null (and session-status (%cli-result-status-name session-status)))))))
    (when (not (eq input :missing))
      (setf fields (append fields
                           (list (%cli-json-field "input"
                                                  (%cli-json-string-or-null input))))))
    (when (not (eq execution-status :missing))
      (setf fields (append fields
                           (list (%cli-json-field "executionStatus"
                                                  (%cli-json-string-or-null (%cli-result-status-name execution-status)))))))
    (when (not (eq selected-tools :missing))
      (setf fields (append fields
                           (list (%cli-json-field "selectedTools"
                                                  (%cli-render-json-array
                                                   (mapcar #'%cli-json-string selected-tools)))))))
    (when (not (eq execution-plan :missing))
      (setf fields (append fields
                           (list (%cli-json-field "executionPlan"
                                                  (%cli-json-value execution-plan))))))
    (when (not (eq git-root :missing))
      (setf fields (append fields
                           (list (%cli-json-field "gitRoot"
                                                  (%cli-json-string-or-null git-root))))))
    (when (not (eq git-branch :missing))
      (setf fields (append fields
                           (list (%cli-json-field "gitBranch"
                                                  (%cli-json-string-or-null git-branch))))))
    (when (not (eq git-dirty :missing))
      (setf fields (append fields
                           (list (%cli-json-field "gitDirty"
                                                  (%cli-json-boolean git-dirty))))))
    (when (not (eq git-status-lines :missing))
      (setf fields (append fields
                           (list (%cli-json-field "gitStatusLines"
                                                  (%cli-json-value git-status-lines))))))
    (when (not (eq git-recent-commits :missing))
      (setf fields (append fields
                           (list (%cli-json-field "gitRecentCommits"
                                                  (%cli-json-value git-recent-commits))))))
    (when (not (eq result :missing))
      (setf fields (append fields
                           (list (%cli-json-field "result"
                                                  (%cli-json-string-or-null result))))))
    (when (not (eq tool-results :missing))
      (setf fields (append fields
                           (list (%cli-json-field "toolResults"
                                                  (%cli-render-json-array
                                                   (mapcar #'%cli-render-tool-result-json tool-results)))))))
    (when (not (eq session-path :missing))
      (setf fields (append fields
                           (list (%cli-json-field "sessionPath"
                                                  (%cli-json-string-or-null session-path))))))
    (when (not (eq saved :missing))
      (setf fields (append fields
                           (list (%cli-json-field "saved"
                                                  (%cli-json-boolean saved))))))
    (setf fields (append fields
                         (list (%cli-json-field "durationSeconds"
                                                (%cli-json-number (getf payload :duration-seconds 0d0)))
                               (%cli-json-field "exitCode"
                                                (format nil "~D" (getf payload :exit-code 0))))))
    fields))

(defun render-run-fixture-result (result-object &key pretty-json)
  (let* ((payload (cl-cc.lib:result-payload result-object))
         (status-counts (getf payload :status-counts))
         (results (getf payload :results)))
    (if pretty-json
        (%cli-render-json-object-pretty
         (%cli-run-fixture-json-fields result-object
                                       :spaced t
                                       :status-counts-value (%cli-render-status-counts-pretty-json status-counts)
                                       :results-value (%cli-render-json-array-pretty
                                                       (mapcar (lambda (record)
                                                                 (%cli-indent-lines (%cli-render-result-record-pretty-json record) "    "))
                                                               results))))
        (%cli-render-json-object
         (%cli-run-fixture-json-fields result-object
                                       :status-counts-value (%cli-render-status-counts-json status-counts)
                                       :results-value (%cli-render-json-array
                                                       (mapcar #'%cli-render-result-record-json results)))))))

(defun render-docs-sync-result (result-object)
  (%cli-render-json-object (%cli-docs-sync-json-fields result-object)))

(defun render-session-command-result (result-object &key output-format)
  (if (string= (or output-format "text") "json")
      (%cli-render-json-object (%cli-session-command-json-fields result-object))
      (cl-cc.lib:result-message result-object)))