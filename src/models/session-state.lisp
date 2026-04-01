;;;; src/models/session-state.lisp
(in-package :cl-cc.models)

(defclass session-state ()
  ((session-id :initarg :session-id :accessor session-id :documentation "唯一标识")
   (created-at :initarg :created-at :accessor session-created-at :documentation "创建时间")
   (updated-at :initarg :updated-at :accessor session-updated-at :documentation "最后更新时间")
   (history-index :initarg :history-index :accessor session-history-index :documentation "历史索引")
   (context-summary :initarg :context-summary :accessor session-context-summary :documentation "上下文摘要")
   (permission-snapshot :initarg :permission-snapshot :accessor session-permission-snapshot :documentation "权限快照")
   (status :initarg :status :accessor session-status :documentation "状态")
   (version :initarg :version :accessor session-version :documentation "状态格式版本")))
