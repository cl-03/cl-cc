;;;; src/lib/text.lisp - shared text normalization helpers
(in-package :cl-cc.lib)

(defun string-designator-downcase (value)
  (and value
       (string-downcase (string value))))

(defun string-designator-upcase (value)
  (and value
       (string-upcase (string value))))

(defun string-designator-keyword (value)
  (and value
       (intern (string-designator-upcase value) :keyword)))