;;;; src/tools/package.lisp
(defpackage :cl-cc.tools
  (:use :cl :cl-cc)
  (:export :*tool-registry* :register-tool :find-tool :find-tool-definition
           :list-tool-definitions :echo-tool :failing-tool))
(in-package :cl-cc.tools)
