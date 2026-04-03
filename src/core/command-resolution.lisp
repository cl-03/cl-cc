;;;; src/core/command-resolution.lisp - 命令匹配与解析
(in-package :cl-cc.core)

(defvar *command-registry*)

(defun %normalize-command-pattern (pattern)
  (cond
    ((null pattern) nil)
    ((and (listp pattern) (every #'stringp pattern)) pattern)
    ((stringp pattern) (list pattern))
    (t nil)))

(defun %primary-command-pattern (definition)
  (uiop:split-string (cl-cc.models:command-name definition) :separator '(#\Space)))

(defun %command-patterns (definition)
  (let ((patterns (list (%primary-command-pattern definition))))
    (dolist (alias (cl-cc.models:command-aliases definition) patterns)
      (let ((normalized (%normalize-command-pattern alias)))
        (when normalized
          (push normalized patterns))))))

(defun %pattern-matches-argv-p (pattern argv)
  (and (<= (length pattern) (length argv))
       (loop for expected in pattern
             for actual in argv
             always (string= expected actual))))

(defun %all-command-definitions ()
  (let ((definitions '()))
    (maphash (lambda (_ definition)
               (declare (ignore _))
               (push definition definitions))
             *command-registry*)
    definitions))

(defun list-command-definitions ()
  "返回按命令名排序的命令定义列表。"
  (sort (copy-list (%all-command-definitions)) #'string< :key #'cl-cc.models:command-name))

(defun %find-matching-command (argv)
  (dolist (definition (%all-command-definitions) (values nil nil))
    (dolist (pattern (%command-patterns definition))
      (when (%pattern-matches-argv-p pattern argv)
        (return-from %find-matching-command (values definition pattern))))))

(defun %resolve-command (argv)
  (ensure-default-commands)
  (when (or (null argv)
            (member "--help" argv :test #'string=))
    (let ((definition (find-command "help")))
      (return-from %resolve-command (values definition '("--help")))))
  (%find-matching-command argv))

(defun command-key-from-argv (argv)
  "从 argv 推导注册表命令键。"
  (multiple-value-bind (definition pattern) (%resolve-command argv)
    (declare (ignore pattern))
    (and definition (cl-cc.models:command-name definition))))