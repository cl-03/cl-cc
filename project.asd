;;;; project.asd - compatibility shim for the canonical CL-CC ASDF entrypoint

(eval-when (:compile-toplevel :load-toplevel :execute)
  (let* ((current-file (or *load-truename* *compile-file-truename*))
         (canonical-asd (and current-file
                             (merge-pathnames "cl-cc.asd" current-file))))
    (unless (and canonical-asd (probe-file canonical-asd))
      (error "Canonical ASDF definition not found: ~A" canonical-asd))
    (load canonical-asd :verbose nil :print nil)))