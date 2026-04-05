;;;; src/session/store.lisp - 会话快照存储抽象
(in-package :cl-cc.session)

(defun %session-snapshot-not-found-message (path)
  (format nil "session snapshot not found: ~A" path))

(defun %session-snapshot-not-found-error (path)
  (cl-cc.lib:make-cl-cc-error :session-not-found
                              (%session-snapshot-not-found-message path)))

(defun %session-directory-file-message (path)
  (format nil "session directory path is a file: ~A" path))

(defun %session-directory-file-error (path)
  (cl-cc.lib:make-cl-cc-error :invalid-session-path
                              (%session-directory-file-message path)))

(defun %native-directory-pathname (path)
  (uiop:ensure-directory-pathname (uiop:parse-native-namestring path)))

(defun %default-session-directory-pathname ()
  (flet ((base-directory (value)
           (and value
                (> (length value) 0)
                (%native-directory-pathname value))))
    (or (let ((local-appdata (base-directory (uiop:getenv "LOCALAPPDATA"))))
          (and local-appdata
               (merge-pathnames #P"cl-cc/sessions/" local-appdata)))
        (let ((xdg-state-home (base-directory (uiop:getenv "XDG_STATE_HOME"))))
          (and xdg-state-home
               (merge-pathnames #P"cl-cc/sessions/" xdg-state-home)))
        (merge-pathnames #P".cl-cc/sessions/"
                         (uiop:ensure-directory-pathname (user-homedir-pathname))))))

(defun default-session-directory ()
  "返回 CL-CC 默认会话目录的本地路径字符串。"
  (uiop:native-namestring (%default-session-directory-pathname)))

(defun %session-metadata-summary-value (session key)
  (let ((summary (cl-cc.models:session-context-summary session)))
    (and (listp summary)
         (getf summary key))))

(defun %file-size-bytes (path)
  (ignore-errors
    (with-open-file (stream path :direction :input :element-type '(unsigned-byte 8))
      (file-length stream))))

(defun %utc-iso-8601-string (universal-time)
  (when universal-time
    (multiple-value-bind (second minute hour day month year)
        (decode-universal-time universal-time 0)
      (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
              year month day hour minute second))))

(defun %session-snapshot-metadata (path)
  (handler-case
      (let* ((native-path (uiop:native-namestring path))
             (session (load-session native-path))
             (tasks (cl-cc.models:session-tasks session))
             (write-date (ignore-errors (file-write-date path))))
        (list :session-id (cl-cc.models:session-id session)
              :session-path native-path
              :created-at (cl-cc.models:session-created-at session)
              :updated-at (cl-cc.models:session-updated-at session)
              :history-index (cl-cc.models:session-history-index session)
              :session-status (cl-cc.models:session-status session)
              :task-count (length tasks)
              :last-input (%session-metadata-summary-value session :input)
              :last-result (%session-metadata-summary-value session :result)
              :file-size-bytes (%file-size-bytes native-path)
              :file-updated-at (%utc-iso-8601-string write-date)
              :version (cl-cc.models:session-version session)))
    (error () nil)))

(defun list-session-snapshots (&optional directory)
  "列出目录下可识别的 session snapshot 元数据。
返回三个值: metadata 列表、实际目录字符串、是否使用默认目录。"
  (let* ((used-default-directory (null directory))
         (directory-pathname (if directory
                                 (%native-directory-pathname directory)
                                 (%default-session-directory-pathname)))
         (directory-string (uiop:native-namestring directory-pathname)))
    (when (and directory
               (probe-file directory-string)
               (not (uiop:directory-exists-p directory-string)))
      (error (%session-directory-file-error directory-string)))
    (let ((metadata
            (if (uiop:directory-exists-p directory-string)
                (remove nil
                        (mapcar #'%session-snapshot-metadata
                                (sort (copy-list (uiop:directory-files directory-pathname))
                                      #'string<
                                      :key #'uiop:native-namestring)))
                nil)))
      (values metadata directory-string used-default-directory))))

(defun save-session (session path)
  "保存 session-state 到指定路径。"
  (ensure-directories-exist path)
  (with-open-file (stream path
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (write-string (serialize-session session) stream))
  t)

(defun load-session (path)
  "从指定路径加载 session-state。"
  (if (probe-file path)
      (with-open-file (stream path :direction :input)
        (let ((contents (make-string (file-length stream))))
          (read-sequence contents stream)
          (deserialize-session contents)))
      (error (%session-snapshot-not-found-error path))))
