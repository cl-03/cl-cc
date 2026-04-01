;;;; src/services/fixture-loader.lisp - 夹具加载
(in-package :cl-cc.services)

(defun load-fixture (fixture-id)
  "加载指定夹具，优先读取 fixtures/contracts 下的 lisp 数据。"
  (let ((path (format nil "d:/VSCode/cl-cc/cl-cc/fixtures/contracts/~A.lisp" fixture-id)))
    (if (probe-file path)
        (with-open-file (stream path :direction :input)
          (read stream nil nil))
        (list :fixture-id fixture-id :input fixture-id :expected-output nil))))
