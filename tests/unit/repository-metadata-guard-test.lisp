;;;; tests/unit/repository-metadata-guard-test.lisp - repository metadata guard 单元测试
(in-package :cl-cc/tests)

(def-suite repository-metadata-guard-test :in cl-cc-suite)

(in-suite repository-metadata-guard-test)

(test protected-repository-metadata-path-p-matches-repository-metadata-directories-only
  ;; .git
  (is (cl-cc.tools::%protected-repository-metadata-path-p ".git/config"))
  (is (cl-cc.tools::%protected-repository-metadata-path-p "repo/.git/hooks/pre-commit"))
  (is (cl-cc.tools::%protected-repository-metadata-path-p "repo\\.git\\config"))
  (is (cl-cc.tools::%protected-repository-metadata-path-p "./.git/config"))
  ;; .hg
  (is (cl-cc.tools::%protected-repository-metadata-path-p ".hg/store/data"))
  (is (cl-cc.tools::%protected-repository-metadata-path-p "repo/.hg/00changelog.i"))
  (is (cl-cc.tools::%protected-repository-metadata-path-p "repo\\.hg\\store"))
  (is (cl-cc.tools::%protected-repository-metadata-path-p "./.hg/requires"))
  ;; .svn
  (is (cl-cc.tools::%protected-repository-metadata-path-p ".svn/wc.db"))
  (is (cl-cc.tools::%protected-repository-metadata-path-p "repo/.svn/pristine/"))
  (is (cl-cc.tools::%protected-repository-metadata-path-p "repo\\.svn\\entries"))
  (is (cl-cc.tools::%protected-repository-metadata-path-p "./.svn/format"))
  ;; 非元数据
  (is (not (cl-cc.tools::%protected-repository-metadata-path-p ".gitignore")))
  (is (not (cl-cc.tools::%protected-repository-metadata-path-p ".github/workflows/ci.yml")))
  (is (not (cl-cc.tools::%protected-repository-metadata-path-p "docs/about.git.txt")))
  (is (not (cl-cc.tools::%protected-repository-metadata-path-p ".hgignore")))
  (is (not (cl-cc.tools::%protected-repository-metadata-path-p ".svnignore"))))