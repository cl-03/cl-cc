
;;;; src/services/session-service.lisp - 会话服务骨架
(in-package :cl-cc.services)

(defun start-session (&rest arguments)
  "启动新会话，返回会话对象。"
  (let* ((requested-id (and arguments
                            (not (keywordp (first arguments)))
                            (first arguments)))
         (option-arguments (if requested-id (rest arguments) arguments))
         (history-index (getf option-arguments :history-index))
         (session-id (or requested-id (format nil "session-~A" (get-universal-time)))))
    (make-instance 'cl-cc.models:session-state
                   :session-id session-id
                   :created-at "now"
                   :updated-at "now"
                   :history-index history-index
                   :context-summary nil
                   :permission-snapshot nil
                   :status :active
                   :version "0.1")))

(defun %elapsed-seconds (start-time end-time)
  (/ (- end-time start-time)
     (float internal-time-units-per-second 1d0)))

(defun %make-session-start-result (session duration-seconds)
  (let ((history-index (cl-cc.models:session-history-index session)))
    (cl-cc.lib:make-result
     :status :success
     :payload (list :session-id (cl-cc.models:session-id session)
                    :history-index history-index
                    :session-status (cl-cc.models:session-status session)
                    :duration-seconds duration-seconds
                    :exit-code 0)
     :message (with-output-to-string (stream)
                (format stream "新会话已创建: ~A" (cl-cc.models:session-id session))
                (when history-index
                  (format stream "~%历史索引: ~A" history-index))))))

(defun start-session-result (&rest arguments)
  "启动新会话并返回结构化结果对象。"
  (let ((started-at (get-internal-real-time)))
    (%make-session-start-result (apply #'start-session arguments)
                                (%elapsed-seconds started-at (get-internal-real-time)))))

(defun resume-session (session-id)
  "恢复会话。"
  (if (probe-file session-id)
      (cl-cc.session:load-session session-id)
      (make-instance 'cl-cc.models:session-state
                     :session-id session-id
                     :created-at "restored"
                     :updated-at "restored"
                     :history-index nil
                     :context-summary nil
                     :permission-snapshot nil
                     :status :active
                     :version "0.1")))

(defun %make-session-resume-result (session duration-seconds)
  (cl-cc.lib:make-result
   :status :success
   :payload (list :session-id (cl-cc.models:session-id session)
                  :history-index (cl-cc.models:session-history-index session)
                  :session-status (cl-cc.models:session-status session)
                  :duration-seconds duration-seconds
                  :exit-code 0)
   :message (format nil "会话已恢复: ~A" (cl-cc.models:session-id session))))

(defun resume-session-result (session-id)
  "恢复会话并返回结构化结果对象。"
  (let ((started-at (get-internal-real-time)))
    (%make-session-resume-result (resume-session session-id)
                                 (%elapsed-seconds started-at (get-internal-real-time)))))

(defun last-execution-results (context)
  "返回最近一次执行的所有工具结果归档。"
  (cl-cc.core:execution-context-results context))

(defun %json-escape-string (value)
  (with-output-to-string (stream)
    (loop for character across value do
      (case character
        (#\\ (write-string "\\\\" stream))
        (#\" (write-string "\\\"" stream))
        (#\Newline (write-string "\\n" stream))
        (#\Return (write-string "\\r" stream))
        (#\Tab (write-string "\\t" stream))
        (t (write-char character stream))))))

(defun %fixture-status-name (status)
  (string-downcase (string status)))

(defun %json-boolean (value)
  (if value "true" "false"))

(defun %successful-fixture-record-p (record)
  (eq (getf record :status) :success))

(defun %denied-fixture-record-p (record)
  (eq (getf record :status) :denied))

(defun %not-found-fixture-record-p (record)
  (eq (getf record :status) :not-found))

(defun %failed-fixture-record-p (record)
  (eq (getf record :status) :failed))

(defun %count-fixture-records (predicate records)
  (count-if predicate records))

(defparameter +fixture-status-count-order+
  '("success" "failed" "partial" "denied" "not-found" "unknown"))

(defun %fixture-status-counts (records)
  (mapcar (lambda (status-name)
            (cons status-name
                  (count status-name records
                         :test #'string=
                         :key (lambda (record)
                                (%fixture-status-name (getf record :status))))))
          +fixture-status-count-order+))

(defun %status-count (status-counts status-name)
  (or (cdr (assoc status-name status-counts :test #'string=)) 0))

(defun %non-zero-status-counts (status-counts)
  (remove-if-not (lambda (entry) (> (cdr entry) 0)) status-counts))

(defun %render-status-counts-json (status-counts)
  (with-output-to-string (stream)
    (write-char #\{ stream)
    (loop for entry in status-counts
          for first-entry = t then nil do
      (unless first-entry
        (write-char #\, stream))
      (format stream
              "\"~A\":~D"
              (%json-escape-string (car entry))
              (cdr entry)))
    (write-char #\} stream)))

(defun %render-status-counts-pretty-json (status-counts)
  (with-output-to-string (stream)
    (write-string "{" stream)
    (loop with last-entry = (car (last status-counts))
          for entry in status-counts
          for first-entry = t then nil do
      (write-char #\Newline stream)
      (write-string "    " stream)
      (format stream
              "\"~A\": ~D"
              (%json-escape-string (car entry))
              (cdr entry))
      (unless (eq entry last-entry)
        (write-char #\, stream)))
    (write-char #\Newline stream)
    (write-string "  }" stream)))

(defun %aggregate-fixture-status (records)
  (let* ((status-counts (%fixture-status-counts records))
         (non-zero-statuses (%non-zero-status-counts status-counts))
         (fixture-count (length records))
         (success-count (%status-count status-counts "success"))
         (denied-count (%status-count status-counts "denied"))
         (not-found-count (%status-count status-counts "not-found"))
         (failed-count (%status-count status-counts "failed"))
         (partial-count (%status-count status-counts "partial")))
    (cond
      ((= success-count fixture-count) "success")
      ((and (= (length non-zero-statuses) 1) (= denied-count fixture-count)) "denied")
      ((and (= (length non-zero-statuses) 1) (= not-found-count fixture-count)) "not-found")
      ((and (= (length non-zero-statuses) 1) (= failed-count fixture-count)) "failed")
      ((and (= (length non-zero-statuses) 1) (= partial-count fixture-count)) "partial")
      ((> (length non-zero-statuses) 1) "partial")
      (t "failed"))))

(defun %fixture-exit-code (status)
  (if (string= status "success") 0 1))

(defun %status-keyword (status)
  (intern (string-upcase status) :keyword))

(defun %fixture-status-tag (status)
  (string-upcase (%fixture-status-name status)))

(defun %fixture-payload-record (record)
  (list :fixture-id (getf record :fixture-id)
        :status (getf record :status)
    :duration-seconds (getf record :duration-seconds)
    :result (getf record :result)
    :tool-results (getf record :tool-results)))

(defun %fixture-text-record (record)
  (format nil "[~A] ~A"
          (%fixture-status-tag (getf record :status))
          (getf record :result)))

(defun %fixture-text-message (records)
  (if (= (length records) 1)
      (%fixture-text-record (first records))
      (with-output-to-string (stream)
        (loop for record in records
              for first-record = t then nil do
          (unless first-record
            (write-char #\Newline stream))
          (format stream "~A: ~A"
                  (getf record :fixture-id)
                  (%fixture-text-record record))))))

(defun %fixture-result-payload (records)
  (let* ((status (%aggregate-fixture-status records))
         (status-counts (%fixture-status-counts records))
         (fixture-count (length records))
         (successful-count (%count-fixture-records #'%successful-fixture-record-p records))
         (failed-count (%count-fixture-records #'%failed-fixture-record-p records))
         (duration-seconds (reduce #'+ records
                                   :key (lambda (record) (getf record :duration-seconds 0d0))
                                   :initial-value 0d0))
         (exit-code (%fixture-exit-code status)))
    (list :fixture-count fixture-count
          :successful-count successful-count
          :failed-count failed-count
          :duration-seconds duration-seconds
          :status-counts status-counts
          :ok (string= status "success")
          :exit-code exit-code
          :results (mapcar #'%fixture-payload-record records))))

(defun %make-fixture-result (records)
  (let ((status (%aggregate-fixture-status records)))
    (cl-cc.lib:make-result :status (%status-keyword status)
                           :payload (%fixture-result-payload records)
                           :message (%fixture-text-message records))))

(defun %derived-fixture-record-status (context)
  (let ((results (cl-cc.core:execution-context-results context)))
    (cond
      ((eq (cl-cc.core:execution-context-status context) :success) :success)
      ((and results (every (lambda (entry) (eq (getf entry :status) :denied)) results))
       :denied)
      ((and results (every (lambda (entry) (eq (getf entry :status) :not-found)) results))
       :not-found)
      (t :failed))))


(defun %run-fixture-record (fixture-id tool-ids-override)
  (let* ((started-at (get-internal-real-time))
         (fixture (load-fixture fixture-id))
         (tool-ids (or tool-ids-override (select-tools fixture-id)))
         (context (cl-cc.core:make-execution-context :command "run" :input (getf fixture :input fixture-id) :output nil :status nil))
         (result (apply #'cl-cc.core:run-execution-cycle context tool-ids))
         (duration-seconds (/ (- (get-internal-real-time) started-at)
                              (float internal-time-units-per-second 1d0))))
    (list :fixture-id fixture-id
          :status (%derived-fixture-record-status context)
          :duration-seconds duration-seconds
          :result result
          :tool-results (cl-cc.core:execution-context-results context))))

(defun run-fixtures (&rest arguments)
  "运行多个夹具并返回结构化结果对象。"
  (let* ((fixture-ids (first arguments))
         (tool-ids-override (getf (rest arguments) :tool-ids))
         (records (mapcar (lambda (fixture-id)
                            (%run-fixture-record fixture-id tool-ids-override))
                          fixture-ids))
         (result-object (%make-fixture-result records)))
    (values result-object
            (getf (cl-cc.lib:result-payload result-object) :exit-code))))

(defun run-fixture (&rest arguments)
  "运行指定夹具并返回结构化结果对象。"
  (let* ((fixture-id (first arguments))
         (tool-ids-override (getf (rest arguments) :tool-ids))
         (record (%run-fixture-record fixture-id tool-ids-override))
         (result-object (%make-fixture-result (list record))))
    (values
     result-object
     (getf (cl-cc.lib:result-payload result-object) :exit-code))))
