;;;; src/lib/time.lisp - shared time helpers
(in-package :cl-cc.lib)

(defun elapsed-seconds (start-time end-time)
  (/ (- end-time start-time)
     (float internal-time-units-per-second 1d0)))