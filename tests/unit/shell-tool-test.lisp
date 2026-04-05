;;;; tests/unit/shell-tool-test.lisp - shell-tool 单元测试
(in-package :cl-cc/tests)

(def-suite shell-tool-test :in cl-cc-suite)

(in-suite shell-tool-test)

(test normalized-shell-input-parses-natural-language-and-structured-input
  (let ((directory (uiop:native-namestring (uiop:temporary-directory))))
    (is (equal (cl-cc.tools::%normalized-shell-input "run shell git status")
               '(:command "git status" :background nil)))
    (is (equal (cl-cc.tools::%normalized-shell-input "background shell git status")
               '(:command "git status" :background t)))
    (is (equal (cl-cc.tools::%normalized-shell-input (format nil "run shell dir :: ~A" directory))
               (list :command "dir" :directory directory :background nil)))
    (is (equal (cl-cc.tools::%normalized-shell-input (list :command "git status" :directory directory :timeout-seconds 5))
               (list :command "git status" :directory directory :background nil :timeout-seconds 5)))
    (is (equal (cl-cc.tools::%normalized-shell-input (list :command "git status" :directory directory :background t :timeout-seconds 5))
               (list :command "git status" :directory directory :background t :timeout-seconds 5)))))

(test shell-tool-captures-stdout-and-nonzero-exit-code
  (let ((directory (uiop:native-namestring (uiop:temporary-directory))))
    (let ((success (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('shell-unit-ok')"
                                                 :directory directory)))
          (failure (cl-cc.tools:shell-tool (list :command "[Console]::Error.Write('shell-unit-err'); exit 7"
                                                 :directory directory))))
      (is (string= (getf success :stdout) "shell-unit-ok"))
      (is (string= (getf success :stderr) ""))
      (is (= (getf success :exit-code) 0))
      (is (not (getf success :timed-out)))
      (is (string= (getf failure :stderr) "shell-unit-err"))
      (is (= (getf failure :exit-code) 7))
      (is (not (getf failure :timed-out))))))

(test shell-tool-signals-stable-error-for-invalid-directory
  (handler-case
      (progn
        (cl-cc.tools:shell-tool (list :command "dir" :directory "D:/this/path/should/not/exist/"))
        (fail "expected shell-tool error"))
    (cl-cc.lib:cl-cc-error (condition)
      (is (eq (cl-cc.lib:error-code condition) :shell-execution-failed))
      (is (search "目录不存在" (cl-cc.lib:error-message condition))))))

(test shell-tool-can-start-background-task
  (let* ((directory (uiop:native-namestring (uiop:temporary-directory)))
         (result (cl-cc.tools:shell-tool (list :command "[Console]::Out.Write('shell-bg-ok')"
                                               :directory directory
                                               :background t)))
         (task-id (getf result :background-task-id))
         (output-path (getf result :output-path)))
    (unwind-protect
         (progn
           (is (getf result :background))
           (is (stringp task-id))
           (is (> (length task-id) 0))
           (is (stringp output-path))
           (is (probe-file output-path))
           (is (null (getf result :stdout)))
           (is (null (getf result :stderr)))
           (is (null (getf result :exit-code)))
           (is (not (getf result :timed-out)))
           (is (gethash task-id cl-cc.tools::*shell-background-task-registry*)))
      (when task-id
        (remhash task-id cl-cc.tools::*shell-background-task-registry*))
      (sleep 0.1)
      (when (and output-path (probe-file output-path))
        (ignore-errors (delete-file output-path))))))