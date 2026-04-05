
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

(defun %session-option-arguments (arguments)
  (if (and arguments
           (not (keywordp (first arguments))))
      (rest arguments)
      arguments))

(defun %session-start-message (session)
  (let ((history-index (cl-cc.models:session-history-index session))
        (session-path (cl-cc.models:session-permission-snapshot session)))
    (with-output-to-string (stream)
      (format stream "新会话已创建: ~A" (cl-cc.models:session-id session))
      (when history-index
        (format stream "~%历史索引: ~A" history-index))
      (when session-path
        (format stream "~%快照已保存: ~A" session-path)))))

(defun %make-session-start-result (session duration-seconds)
  (let ((history-index (cl-cc.models:session-history-index session))
        (session-path (cl-cc.models:session-permission-snapshot session)))
    (cl-cc.lib:make-result
     :status :success
     :payload (list :session-id (cl-cc.models:session-id session)
                    :history-index history-index
                    :session-status (cl-cc.models:session-status session)
                    :session-path session-path
                    :saved (not (null session-path))
                    :duration-seconds duration-seconds
                    :exit-code 0)
     :message (%session-start-message session))))

(defun start-session-result (&rest arguments)
  "启动新会话并返回结构化结果对象。"
  (let* ((started-at (get-internal-real-time))
         (session-path (getf (%session-option-arguments arguments) :session-path))
         (session (apply #'start-session arguments)))
    (when session-path
      (setf (cl-cc.models:session-permission-snapshot session) session-path)
      (cl-cc.session:save-session session session-path))
    (%make-session-start-result session
                                (cl-cc.lib:elapsed-seconds started-at (get-internal-real-time)))))

(defun %session-snapshot-directory-message (path)
  (format nil "session snapshot path is a directory: ~A" path))

(defun %session-snapshot-directory-error (path)
  (cl-cc.lib:make-cl-cc-error :invalid-session-path
                              (%session-snapshot-directory-message path)))

(defun %session-snapshot-directory-p (path)
  (and path
       (uiop:directory-exists-p path)))

(defun %session-snapshot-file-p (path)
  (and path
       (probe-file path)
       (not (%session-snapshot-directory-p path))))

(defun resume-session (session-id)
  "恢复会话。"
  (cond
    ((%session-snapshot-directory-p session-id)
     (error (%session-snapshot-directory-error session-id)))
    ((%session-snapshot-file-p session-id)
     (cl-cc.session:load-session session-id))
    (t
     (make-instance 'cl-cc.models:session-state
                    :session-id session-id
                    :created-at "restored"
                    :updated-at "restored"
                    :history-index nil
                    :context-summary nil
                    :permission-snapshot nil
                    :status :active
                    :version "0.1"))))

(defun %session-resume-message (session)
  (format nil "会话已恢复: ~A" (cl-cc.models:session-id session)))

(defun %make-session-resume-result (session duration-seconds)
  (cl-cc.lib:make-result
   :status :success
   :payload (list :session-id (cl-cc.models:session-id session)
                  :history-index (cl-cc.models:session-history-index session)
                  :session-status (cl-cc.models:session-status session)
                  :duration-seconds duration-seconds
                  :exit-code 0)
   :message (%session-resume-message session)))

(defun resume-session-result (session-id)
  "恢复会话并返回结构化结果对象。"
  (let ((started-at (get-internal-real-time)))
    (%make-session-resume-result (resume-session session-id)
                                 (cl-cc.lib:elapsed-seconds started-at (get-internal-real-time)))))

(defun %session-run-failed-error (session-id-or-path)
  (cl-cc.lib:make-cl-cc-error :session-run-failed
                              (format nil "session loop failed for session: ~A" session-id-or-path)))

(defun %session-run-save-path (session-id-or-path session explicit-path)
  (or explicit-path
  (and (cl-cc.services::%session-snapshot-file-p session-id-or-path)
           session-id-or-path)
      (cl-cc.models:session-permission-snapshot session)))

(defun %session-run-input (session)
  (let ((summary (cl-cc.models:session-context-summary session)))
    (and (listp summary)
         (getf summary :input))))

(defun %session-run-execution-status (session)
  (let ((summary (cl-cc.models:session-context-summary session)))
    (and (listp summary)
         (getf summary :execution-status))))

(defun %session-run-result-summary (session)
  (let ((summary (cl-cc.models:session-context-summary session)))
    (and (listp summary)
         (getf summary :result))))

(defun %session-run-tool-results (session)
  (let ((summary (cl-cc.models:session-context-summary session)))
    (and (listp summary)
         (getf summary :tool-results))))

(defun %session-run-selected-tools (session)
  (let ((summary (cl-cc.models:session-context-summary session)))
    (and (listp summary)
         (getf summary :selected-tools))))

(defun %session-run-execution-plan (session)
  (let ((summary (cl-cc.models:session-context-summary session)))
    (and (listp summary)
         (getf summary :execution-plan))))

(defun %session-run-git-context (session)
  (let ((summary (cl-cc.models:session-context-summary session)))
    (and (listp summary)
         (getf summary :git-context))))

(defun %session-run-git-root (session)
  (getf (%session-run-git-context session) :root))

(defun %session-run-git-branch (session)
  (getf (%session-run-git-context session) :branch))

(defun %session-run-git-dirty (session)
  (getf (%session-run-git-context session) :dirty))

(defun %session-run-git-status-lines (session)
  (getf (%session-run-git-context session) :status-lines))

(defun %session-run-git-recent-commits (session)
  (getf (%session-run-git-context session) :recent-commits))

(defun %session-run-exit-code (session)
  (if (eq (%session-run-execution-status session) :success)
      0
      1))

(defun %session-run-message (session)
  (let ((history-index (cl-cc.models:session-history-index session))
        (input (%session-run-input session))
        (execution-status (%session-run-execution-status session))
        (result (%session-run-result-summary session))
        (session-path (cl-cc.models:session-permission-snapshot session)))
    (with-output-to-string (stream)
      (format stream "会话已执行: ~A" (cl-cc.models:session-id session))
      (when history-index
        (format stream "~%历史索引: ~A" history-index))
      (when input
        (format stream "~%输入: ~A" input))
      (when execution-status
        (format stream "~%执行状态: ~A" (cl-cc.lib:string-designator-downcase execution-status)))
      (when result
        (format stream "~%执行结果: ~A" result))
      (when session-path
        (format stream "~%快照已保存: ~A" session-path)))))

(defun %make-session-run-result (session duration-seconds)
  (let ((session-path (cl-cc.models:session-permission-snapshot session))
        (input (%session-run-input session))
        (execution-status (%session-run-execution-status session))
  (git-root (%session-run-git-root session))
  (git-branch (%session-run-git-branch session))
  (git-dirty (%session-run-git-dirty session))
  (git-status-lines (%session-run-git-status-lines session))
  (git-recent-commits (%session-run-git-recent-commits session))
        (result (%session-run-result-summary session))
        (tool-results (%session-run-tool-results session))
        (selected-tools (%session-run-selected-tools session))
        (execution-plan (%session-run-execution-plan session)))
    (cl-cc.lib:make-result
     :status :success
     :payload (list :session-id (cl-cc.models:session-id session)
                    :history-index (cl-cc.models:session-history-index session)
                    :session-status (cl-cc.models:session-status session)
                    :input input
                    :execution-status execution-status
                    :selected-tools selected-tools
                    :execution-plan execution-plan
                    :git-root git-root
                    :git-branch git-branch
                    :git-dirty git-dirty
                    :git-status-lines git-status-lines
                    :git-recent-commits git-recent-commits
                    :result result
                    :tool-results tool-results
                    :session-path session-path
                    :saved (not (null session-path))
                    :duration-seconds duration-seconds
                    :exit-code (%session-run-exit-code session))
     :message (%session-run-message session))))

(defun run-session (session-id-or-path &key session-path input tool-ids)
  "恢复会话，执行一步 loop，并在需要时保存更新后的快照。"
  (let* ((session (resume-session session-id-or-path))
         (summary (cl-cc.core:session-loop session :input input :tool-ids-override tool-ids))
         (save-path (%session-run-save-path session-id-or-path session session-path)))
    (unless summary
      (error (%session-run-failed-error session-id-or-path)))
    (when save-path
      (setf (cl-cc.models:session-permission-snapshot session) save-path)
      (cl-cc.session:save-session session save-path))
    session))

(defun run-session-result (session-id-or-path &key session-path input tool-ids)
  "恢复会话并执行一步 loop，返回结构化结果对象。"
  (let ((started-at (get-internal-real-time)))
    (%make-session-run-result (run-session session-id-or-path :session-path session-path :input input :tool-ids tool-ids)
                              (cl-cc.lib:elapsed-seconds started-at (get-internal-real-time)))))

(defun last-execution-results (context)
  "返回最近一次执行的所有工具结果归档。"
  (cl-cc.core:execution-context-results context))

(defun %fixture-status-name (status)
  (cl-cc.lib:string-designator-downcase status))

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

(defun %single-non-zero-status-p (status-counts)
  (= (length (%non-zero-status-counts status-counts)) 1))

(defun %uniform-status-count-p (status-counts fixture-count status-name)
  (and (%single-non-zero-status-p status-counts)
       (= (%status-count status-counts status-name) fixture-count)))

(defun %records-all-have-status-p (records status)
  (and records
       (every (lambda (record)
                (eq (getf record :status) status))
              records)))

(defun %aggregate-fixture-status (records)
  (let* ((status-counts (%fixture-status-counts records))
         (fixture-count (length records))
         (success-count (%status-count status-counts "success")))
    (cond
      ((= success-count fixture-count) "success")
      ((%uniform-status-count-p status-counts fixture-count "denied") "denied")
      ((%uniform-status-count-p status-counts fixture-count "not-found") "not-found")
      ((%uniform-status-count-p status-counts fixture-count "failed") "failed")
      ((%uniform-status-count-p status-counts fixture-count "partial") "partial")
      ((not (%single-non-zero-status-p status-counts)) "partial")
      (t "failed"))))

(defun %fixture-exit-code (status)
  (if (string= status "success") 0 1))

(defun %status-keyword (status)
  (cl-cc.lib:string-designator-keyword status))

(defun %fixture-status-tag (status)
  (cl-cc.lib:string-designator-upcase status))

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

(defun %fixture-result-summary (records)
  (let* ((status (%aggregate-fixture-status records))
         (status-counts (%fixture-status-counts records))
         (fixture-count (length records))
         (successful-count (%count-fixture-records #'%successful-fixture-record-p records))
         (failed-count (%count-fixture-records #'%failed-fixture-record-p records))
         (duration-seconds (reduce #'+ records
                                   :key (lambda (record) (getf record :duration-seconds 0d0))
                                   :initial-value 0d0))
         (exit-code (%fixture-exit-code status)))
    (list :status status
          :status-counts status-counts
          :fixture-count fixture-count
          :successful-count successful-count
          :failed-count failed-count
          :duration-seconds duration-seconds
          :exit-code exit-code
          :ok (string= status "success"))))

(defun %fixture-result-payload (records &optional summary)
  (let ((summary (or summary
                     (%fixture-result-summary records))))
    (list :fixture-count (getf summary :fixture-count)
          :successful-count (getf summary :successful-count)
          :failed-count (getf summary :failed-count)
          :duration-seconds (getf summary :duration-seconds)
          :status-counts (getf summary :status-counts)
          :ok (getf summary :ok)
          :exit-code (getf summary :exit-code)
          :results (mapcar #'%fixture-payload-record records))))

(defun %make-fixture-result (records)
  (let ((summary (%fixture-result-summary records)))
    (cl-cc.lib:make-result :status (%status-keyword (getf summary :status))
                           :payload (%fixture-result-payload records summary)
                           :message (%fixture-text-message records))))

(defun %derived-fixture-record-status (context)
  (let ((results (cl-cc.core:execution-context-results context)))
    (cond
      ((eq (cl-cc.core:execution-context-status context) :success) :success)
      ((%records-all-have-status-p results :denied) :denied)
      ((%records-all-have-status-p results :not-found) :not-found)
      (t :failed))))


(defun %run-fixture-record (fixture-id tool-ids-override)
  (let* ((started-at (get-internal-real-time))
         (fixture (load-fixture fixture-id))
         (tool-ids (or tool-ids-override (select-tools fixture-id)))
         (context (cl-cc.core:make-execution-context :command "run" :input (getf fixture :input fixture-id) :output nil :status nil))
         (result (apply #'cl-cc.core:run-execution-cycle context tool-ids))
         (duration-seconds (cl-cc.lib:elapsed-seconds started-at (get-internal-real-time))))
    (list :fixture-id fixture-id
          :status (%derived-fixture-record-status context)
          :duration-seconds duration-seconds
          :result result
          :tool-results (cl-cc.core:execution-context-results context))))

(defun %collect-fixture-records (fixture-ids tool-ids-override)
  (mapcar (lambda (fixture-id)
            (%run-fixture-record fixture-id tool-ids-override))
          fixture-ids))

(defun %fixture-result-values (result-object)
  (values result-object
          (getf (cl-cc.lib:result-payload result-object) :exit-code)))

(defun run-fixtures (&rest arguments)
  "运行多个夹具并返回结构化结果对象。"
  (let* ((fixture-ids (first arguments))
         (tool-ids-override (getf (rest arguments) :tool-ids))
         (records (%collect-fixture-records fixture-ids tool-ids-override)))
    (%fixture-result-values (%make-fixture-result records))))

(defun run-fixture (&rest arguments)
  "运行指定夹具并返回结构化结果对象。"
  (let* ((fixture-id (first arguments))
         (tool-ids-override (getf (rest arguments) :tool-ids))
         (records (%collect-fixture-records (list fixture-id) tool-ids-override)))
    (%fixture-result-values (%make-fixture-result records))))
