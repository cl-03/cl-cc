;;;; src/session/package.lisp
(defpackage :cl-cc.session
  (:use :cl :cl-cc)
  (:export :serialize-session :deserialize-session :save-session :load-session
           :default-session-directory :list-session-snapshots))
(in-package :cl-cc.session)
