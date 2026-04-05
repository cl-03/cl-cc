;;;; src/lib/git-context.lisp - Git 上下文快照
(in-package :cl-cc.lib)

(defparameter +git-context-trim-characters+
  '(#\Space #\Tab #\Newline #\Return)
  "Git 命令输出统一裁剪的空白字符集。")

(defun %trim-git-output (output)
  (let ((text (and output (string-trim +git-context-trim-characters+ output))))
    (and text
         (> (length text) 0)
         text)))

(defun %git-output-lines (output)
  (let ((trimmed (%trim-git-output output)))
    (if trimmed
        (cl-ppcre:split "\\r?\\n" trimmed)
        nil)))

(defun %default-git-command-runner (arguments &key directory)
  (handler-case
      (%trim-git-output
       (uiop:run-program (append (list "git") arguments)
                         :directory directory
                         :ignore-error-status t
                         :output :string
                         :error-output :output))
    (error () nil)))

(defparameter *git-command-runner* #'%default-git-command-runner
  "用于执行 Git 命令的可替换函数，签名为 (arguments &key directory)。")

(defun %git-command-output (arguments &key directory)
  (let ((output (funcall *git-command-runner* arguments :directory directory)))
    (when (and output
               (not (uiop:string-prefix-p "fatal:" output))
               (not (uiop:string-prefix-p "git: " output)))
      output)))

(defun %git-root (&key directory)
  (let ((root (%git-command-output '("rev-parse" "--show-toplevel") :directory directory)))
    (when (and root
               (probe-file root))
      root)))

(defun %git-branch (root)
  (%git-command-output '("branch" "--show-current") :directory root))

(defun %git-status-lines (root)
  (%git-output-lines (%git-command-output '("status" "--short") :directory root)))

(defun %git-recent-commits (root)
  (%git-output-lines (%git-command-output '("log" "--oneline" "-5") :directory root)))

(defun capture-git-context (&key directory)
  "捕获当前工作目录对应的 Git 快照；若不在 Git 仓库中则返回 NIL。"
  (let ((root (%git-root :directory directory)))
    (when root
      (let ((status-lines (%git-status-lines root)))
        (list :root root
              :branch (%git-branch root)
              :dirty (not (null status-lines))
              :status-lines status-lines
              :recent-commits (%git-recent-commits root))))))