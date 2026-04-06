;;;; src/tools/repository-metadata-guard.lisp - repository metadata path guard helpers
(in-package :cl-cc.tools)


(defparameter +protected-repository-metadata-directories+
  '(".git" ".hg" ".svn")
  "禁止写入的受保护仓库元数据目录段。默认包含 .git、.hg、.svn。")

(defun %protected-repository-metadata-path-p (path)
  (let ((components (cl-ppcre:split "[/\\\\]+" (or path ""))))
    (loop for component in components
          thereis (and (> (length component) 0)
                       (not (string= component "."))
                       (member component +protected-repository-metadata-directories+
                               :test #'string-equal)))))