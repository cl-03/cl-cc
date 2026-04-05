;;;; tests/unit/lib-git-context-test.lisp - Git context 快照测试
(in-package :cl-cc/tests)

(def-suite lib-git-context-test :in cl-cc-suite)
(in-suite lib-git-context-test)

(test capture-git-context-returns-nil-outside-git-repo
  (let ((cl-cc.lib::*git-command-runner*
          (lambda (arguments &key directory)
            (declare (ignore arguments directory))
            nil)))
    (is (null (cl-cc.lib:capture-git-context)))))

(test capture-git-context-collects-root-branch-status-and-commits
  (let ((cl-cc.lib::*git-command-runner*
          (lambda (arguments &key directory)
            (declare (ignore directory))
            (cond
              ((equal arguments '("rev-parse" "--show-toplevel")) "D:/VSCode/cl-cc/cl-cc")
              ((equal arguments '("branch" "--show-current")) "main")
              ((equal arguments '("status" "--short"))
               (format nil "M src/core/session-loop.lisp~%?? tests/unit/lib-git-context-test.lisp"))
              ((equal arguments '("log" "--oneline" "-5"))
               (format nil "abc1234 add git context~%def5678 refactor session loop"))
              (t nil)))))
    (is (equal (cl-cc.lib:capture-git-context)
               '(:root "D:/VSCode/cl-cc/cl-cc"
                 :branch "main"
                 :dirty t
                 :status-lines ("M src/core/session-loop.lisp"
                                "?? tests/unit/lib-git-context-test.lisp")
                 :recent-commits ("abc1234 add git context"
                                  "def5678 refactor session loop"))))))

(test capture-git-context-marks-clean-repo-as-not-dirty
  (let ((cl-cc.lib::*git-command-runner*
          (lambda (arguments &key directory)
            (declare (ignore directory))
            (cond
              ((equal arguments '("rev-parse" "--show-toplevel")) "D:/VSCode/cl-cc/cl-cc")
              ((equal arguments '("branch" "--show-current")) "main")
              ((equal arguments '("status" "--short")) nil)
              ((equal arguments '("log" "--oneline" "-5")) "abc1234 add git context")
              (t nil)))))
    (let ((context (cl-cc.lib:capture-git-context)))
      (is (equal (getf context :root) "D:/VSCode/cl-cc/cl-cc"))
      (is (equal (getf context :branch) "main"))
      (is (not (getf context :dirty)))
      (is (null (getf context :status-lines)))
      (is (equal (getf context :recent-commits)
                 '("abc1234 add git context"))))))