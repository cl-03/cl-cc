;;;; src/tools/todo-write-tool.lisp - 会话待办列表写入工具
(in-package :cl-cc.tools)

(defparameter +todo-write-tool-input-prefixes+
  '("todo write " "update todo list " "todo list "
    "写入待办 " "更新待办列表 " "待办列表 ")
  "允许 todo-write-tool 直接消费的自然语言前缀。")

(defun %todo-write-tool-message (detail)
  (format nil "待办列表写入失败: ~A" detail))

(defun %todo-write-tool-error (detail)
  (cl-cc.lib:make-cl-cc-error :todo-write-failed
                              (%todo-write-tool-message detail)))

(defun %normalized-todo-write-string (value)
  (let ((text (and value (string-trim '(#\Space #\Tab #\Newline #\Return) (string value)))))
    (and text
         (> (length text) 0)
         text)))

(defun %normalized-todo-status (value)
  (let ((text (cl-cc.lib:string-designator-downcase value)))
    (cond
      ((null text) nil)
      ((member text '("pending" "todo" "not-started" "待处理" "未开始") :test #'string=)
       :pending)
      ((member text '("in_progress" "in-progress" "in progress" "doing" "进行中") :test #'string=)
       :in-progress)
      ((member text '("completed" "done" "finished" "已完成" "完成") :test #'string=)
       :completed)
      (t nil))))

(defun %todo-status-name (status)
  (ecase status
    (:pending "pending")
    (:in-progress "in_progress")
    (:completed "completed")))

(defun %todo-item (content status active-form)
  (list :content content
        :status (%todo-status-name status)
        :active-form active-form))

(defun %normalize-todo-item (item)
  (let* ((content (%normalized-todo-write-string (getf item :content)))
         (status (or (%normalized-todo-status (getf item :status))
                     (error (%todo-write-tool-error "status 仅支持 pending、in_progress 或 completed"))))
         (active-form (%normalized-todo-write-string (or (getf item :active-form)
                                                         (getf item :activeForm)
                                                         content))))
    (unless content
      (error (%todo-write-tool-error "todo content 不能为空")))
    (unless active-form
      (error (%todo-write-tool-error "todo activeForm 不能为空")))
    (%todo-item content status active-form)))

(defun %split-todo-write-segments (text separator)
  (let ((segments '())
        (start 0)
        (separator-length (length separator)))
    (loop for position = (search separator text :start2 start :test #'char-equal)
          do (if position
                 (progn
                   (push (subseq text start position) segments)
                   (setf start (+ position separator-length)))
                 (progn
                   (push (subseq text start) segments)
                   (return))))
    (nreverse segments)))

(defun %parse-todo-write-item-text (text)
  (let* ((segments (remove nil
                           (mapcar #'%normalized-todo-write-string
                                   (%split-todo-write-segments text "|"))))
         (content (first segments))
         (status (second segments))
         (active-form (third segments)))
    (unless (and content status)
      (error (%todo-write-tool-error
              "文本格式无效，期望 `todo write <content> | <status> | <active-form> ;; ...`")))
    (%normalize-todo-item (list :content content
                                :status status
                                :active-form (or active-form content)))))

(defun %parse-todo-write-text (text)
  (let* ((body (%strip-input-prefix text +todo-write-tool-input-prefixes+))
         (segments (remove nil
                           (mapcar #'%normalized-todo-write-string
                                   (%split-todo-write-segments body ";;")))))
    (when segments
      (list :todos (mapcar #'%parse-todo-write-item-text segments)))))

(defun %normalize-todo-write-request (todos)
  (let ((normalized-todos (mapcar #'%normalize-todo-item todos)))
    (let ((in-progress-count (count "in_progress" normalized-todos
                                    :key (lambda (item) (getf item :status))
                                    :test #'string=)))
      (unless (= in-progress-count 1)
        (error (%todo-write-tool-error "必须且只能有一个 in_progress 状态的待办项"))))
    (list :todos normalized-todos)))

(defun %normalized-todo-write-input (input)
  (cond
    ((and (listp input)
          (getf input :todos))
     (%normalize-todo-write-request (getf input :todos)))
    (t
     (let ((text (%normalized-todo-write-string input)))
       (cond
         ((null text) nil)
         ((search "fixture-input-" text :test #'char-equal)
          (%normalized-todo-write-input (subseq text (length "fixture-input-"))))
         (t
          (let ((request (%parse-todo-write-text text)))
            (and request
                 (%normalize-todo-write-request (getf request :todos))))))))))

(defun %todo-write-count (todos status)
  (count status todos :key (lambda (item) (getf item :status)) :test #'string=))

(defun %todo-write-summary (todos)
  (format nil "更新待办列表: ~D 项（进行中 ~D，待处理 ~D，已完成 ~D）"
          (length todos)
          (%todo-write-count todos "in_progress")
          (%todo-write-count todos "pending")
          (%todo-write-count todos "completed")))

(defun todo-write-tool (input)
  "更新当前会话的结构化待办列表，并返回变更前后的稳定结果。"
  (let* ((request (%normalized-todo-write-input input))
         (session cl-cc.models:*active-session*))
    (unless request
      (error (%todo-write-tool-error
              "请求格式无效，期望结构化 todos 或 `todo write <content> | <status> | <active-form> ;; ...`")))
    (unless session
      (error (%todo-write-tool-error "当前没有可写回的活动 session")))
    (let* ((old-todos (copy-tree (or (cl-cc.models:session-todo-list session) nil)))
           (new-todos (copy-tree (getf request :todos))))
      (setf (cl-cc.models:session-todo-list session) new-todos)
      (list :summary (%todo-write-summary new-todos)
            :old-todos old-todos
            :new-todos new-todos))))