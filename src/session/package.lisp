;;;; src/session/package.lisp
(defpackage :cl-cc.session
  (:use :cl :cl-cc)
  (:export :serialize-session :deserialize-session :save-session :load-session))
(in-package :cl-cc.session)
