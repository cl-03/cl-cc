;;;; src/core/command-argument-parsing.lisp - 命令参数解析与帮助构造
(in-package :cl-cc.core)

(defun %string-starts-with-option-prefix-p (value)
  (and (stringp value)
       (or (uiop:string-prefix-p "--" value)
           (uiop:string-prefix-p "-" value))))

(defun %command-required-tail-count (definition)
  (getf (cl-cc.models:command-arguments-schema definition) :required-tail-count))

(defun %command-usage-tail (definition)
  (getf (cl-cc.models:command-arguments-schema definition) :usage-tail))

(defun %legacy-positional-specs (definition)
  (let ((required-tail-count (%command-required-tail-count definition))
        (usage-tail (%command-usage-tail definition)))
    (cond
      ((or (null required-tail-count) (= required-tail-count 0)) nil)
      ((and (= required-tail-count 1)
            usage-tail
            (> (length usage-tail) 0))
       (list (list :name usage-tail :required t)))
      (t
       (loop for index from 1 to required-tail-count
             collect (list :name (format nil "<arg-~A>" index) :required t))))))

(defun %command-positionals (definition)
  (or (getf (cl-cc.models:command-arguments-schema definition) :positionals)
      (%legacy-positional-specs definition)))

(defun %command-options (definition)
  (getf (cl-cc.models:command-arguments-schema definition) :options))

(defun %required-positional-count (definition)
  (count-if (lambda (spec) (getf spec :required)) (%command-positionals definition)))

(defun %repeatable-positional-spec (definition)
  (let ((positionals (%command-positionals definition)))
    (when positionals
      (let ((last-spec (car (last positionals))))
        (when (getf last-spec :repeatable)
          last-spec)))))

(defun %maximum-positional-count (definition)
  (if (%repeatable-positional-spec definition)
      nil
      (length (%command-positionals definition))))

(defun %find-option-spec (definition token)
  (find-if (lambda (spec)
             (member token (getf spec :flags) :test #'string=))
           (%command-options definition)))

(defun %find-inline-option-spec (definition token)
  (dolist (spec (%command-options definition) nil)
    (dolist (flag (getf spec :flags))
      (let ((prefix (format nil "~A=" flag)))
        (when (uiop:string-prefix-p prefix token)
          (return-from %find-inline-option-spec
            (values spec (subseq token (length prefix)))))))))

(defun %option-expects-value-p (option-spec)
  (not (getf option-spec :flag)))

(defun %preferred-option-flag (option-spec)
  (or (find-if (lambda (flag) (uiop:string-prefix-p "--" flag))
               (getf option-spec :flags))
      (first (getf option-spec :flags))))

(defun %option-help-label (option-spec)
  (format nil "~{~A~^, ~}" (getf option-spec :flags)))

(defun %coerce-argument-value (value spec)
  (let ((type (getf spec :type :string)))
    (cond
      ((or (null type) (eq type :string)) value)
      ((eq type :integer)
       (handler-case
           (parse-integer value :junk-allowed nil)
         (error () :invalid)))
      ((and (consp type) (eq (first type) :enum))
       (if (member value (rest type) :test #'string=)
           value
           :invalid))
      (t value))))

(defun %option-storage-value (options option-spec option-key coerced-value)
  (if (getf option-spec :repeatable)
      (let ((existing (getf options option-key)))
        (setf (getf options option-key) (append existing (list coerced-value)))
        options)
      (progn
        (setf (getf options option-key) coerced-value)
        options)))

(defun %copy-default-value (option-spec value)
  (if (and (getf option-spec :repeatable)
           (listp value))
      (copy-list value)
      value))

(defun %find-option-spec-by-key (definition option-key)
  (find option-key (%command-options definition) :key (lambda (spec) (getf spec :key))))

(defun %option-present-p (options option-key)
  (not (eq (getf options option-key :missing) :missing)))

(defun %requirement-satisfied-p (options requirement)
  (let* ((required-key (getf requirement :key))
         (expected-value (getf requirement :value :missing))
         (actual-value (getf options required-key :missing)))
    (and (not (eq actual-value :missing))
         (or (eq expected-value :missing)
             (equal actual-value expected-value)))))

(defun %conditional-default-value (options option-spec)
  (dolist (clause (getf option-spec :default-when) nil)
    (when (every (lambda (requirement)
                   (%requirement-satisfied-p options requirement))
                 (getf clause :when))
      (return (%copy-default-value option-spec (getf clause :value))))))

(defun %option-has-default-p (option-spec)
  (or (not (null (getf option-spec :default)))
      (not (null (getf option-spec :default-when)))))

(defun %option-default-value (options option-spec)
  (or (%conditional-default-value options option-spec)
      (%copy-default-value option-spec (getf option-spec :default))))

(defun %apply-option-default (options option-spec)
  (let ((option-key (getf option-spec :key)))
    (if (or (not (null (getf options option-key)))
            (not (%option-has-default-p option-spec)))
        options
        (let ((default-value (%option-default-value options option-spec)))
          (if (null default-value)
              options
              (progn
                (setf (getf options option-key) default-value)
                options))))))

(defun %apply-option-defaults (definition options)
  (dolist (option-spec (%command-options definition) options)
    (setf options (%apply-option-default options option-spec))))

(defun %invalid-arguments-message (definition)
  (format nil "Invalid arguments for command ~A"
          (cl-cc.models:command-name definition)))

(defun %invalid-arguments-error (definition)
  (cl-cc.lib:make-cl-cc-error "INVALID-ARGUMENTS"
                              (%invalid-arguments-message definition)))

(defun %signal-invalid-arguments (definition)
  (error (%invalid-arguments-error definition)))

(defun %coerce-option-argument-or-signal (definition raw-value option-spec)
  (let ((coerced-value (%coerce-argument-value raw-value option-spec)))
    (when (eq coerced-value :invalid)
      (%signal-invalid-arguments definition))
    coerced-value))

(defun %parse-inline-option-token (definition token remaining options)
  (multiple-value-bind (option-spec inline-value)
      (%find-inline-option-spec definition token)
    (if (null option-spec)
        (values nil remaining options)
        (progn
          (unless (%option-expects-value-p option-spec)
            (%signal-invalid-arguments definition))
          (let* ((option-key (getf option-spec :key))
                 (coerced-value (%coerce-option-argument-or-signal definition inline-value option-spec)))
            (values t
                    (rest remaining)
                    (%option-storage-value options option-spec option-key coerced-value)))))))

(defun %parse-direct-option-token (definition token remaining options)
  (let ((option-spec (%find-option-spec definition token)))
    (if (null option-spec)
        (values nil remaining options)
        (let ((option-key (getf option-spec :key)))
          (if (%option-expects-value-p option-spec)
              (progn
                (when (or (null (rest remaining))
                          (%string-starts-with-option-prefix-p (second remaining)))
                  (%signal-invalid-arguments definition))
                (let ((coerced-value (%coerce-option-argument-or-signal definition (second remaining) option-spec)))
                  (values t
                          (cddr remaining)
                          (%option-storage-value options option-spec option-key coerced-value))))
              (values t
                      (rest remaining)
                      (%option-storage-value options option-spec option-key t)))))))

(defun %parse-next-command-token (definition remaining positionals options)
  (let ((token (first remaining)))
    (multiple-value-bind (handled-p next-remaining next-options)
        (%parse-inline-option-token definition token remaining options)
      (if handled-p
          (values next-remaining positionals next-options)
          (multiple-value-bind (direct-handled-p direct-remaining direct-options)
              (%parse-direct-option-token definition token remaining options)
            (cond
              (direct-handled-p
               (values direct-remaining positionals direct-options))
              ((%string-starts-with-option-prefix-p token)
               (%signal-invalid-arguments definition))
              (t
               (values (rest remaining)
                       (cons token positionals)
                       options))))))))

(defun %validate-positional-arity (definition positionals)
  (let ((required-positionals (%required-positional-count definition))
        (maximum-positionals (%maximum-positional-count definition)))
    (when (< (length positionals) required-positionals)
      (%signal-invalid-arguments definition))
    (when (and maximum-positionals
               (> (length positionals) maximum-positionals))
      (%signal-invalid-arguments definition))))

(defun %validate-required-options (definition options)
  (dolist (option-spec (%command-options definition))
    (when (and (getf option-spec :required)
               (null (getf options (getf option-spec :key))))
      (%signal-invalid-arguments definition)))
  options)

(defun %validate-option-constraints (definition options)
  (dolist (option-spec (%command-options definition))
    (let ((option-key (getf option-spec :key)))
      (when (%option-present-p options option-key)
        (dolist (conflict-key (getf option-spec :conflicts-with))
          (when (%option-present-p options conflict-key)
            (%signal-invalid-arguments definition)))
        (dolist (requirement (getf option-spec :requires))
          (unless (%requirement-satisfied-p options requirement)
            (%signal-invalid-arguments definition))))))
  options)

(defun %finalize-parsed-options (definition options)
  (setf options (%validate-required-options definition options))
  (setf options (%apply-option-defaults definition options))
  (setf options (%validate-option-constraints definition options))
  options)

(defun %requirement-help-label (definition requirement)
  (let* ((option-spec (%find-option-spec-by-key definition (getf requirement :key)))
         (label (if option-spec
                    (%preferred-option-flag option-spec)
            (cl-cc.lib:string-designator-downcase (getf requirement :key))))
         (expected-value (getf requirement :value :missing)))
    (if (eq expected-value :missing)
        label
        (format nil "~A=~A" label expected-value))))

(defun %conflict-help-label (definition option-key)
  (let ((option-spec (%find-option-spec-by-key definition option-key)))
    (if option-spec
        (%preferred-option-flag option-spec)
        (cl-cc.lib:string-designator-downcase option-key))))

(defun %parse-command-arguments (definition matched-pattern argv)
  (let ((remaining (nthcdr (length matched-pattern) argv))
        (positionals '())
        (options '()))
    (loop while remaining do
      (multiple-value-setq (remaining positionals options)
        (%parse-next-command-token definition remaining positionals options)))
    (%validate-positional-arity definition positionals)
    (setf options (%finalize-parsed-options definition options))
    (list :positionals (nreverse positionals)
          :options options)))

(defun %render-positional-usage (spec)
  (let* ((name (getf spec :name "<arg>"))
         (base-name (if (getf spec :repeatable)
                        (format nil "~A..." name)
                        name)))
    (if (getf spec :required)
        base-name
        (format nil "[~A]" base-name))))

(defun %render-option-usage (spec)
  (let ((flag (%preferred-option-flag spec))
        (value-name (getf spec :value-name "<value>")))
    (if (getf spec :flag)
        (if (getf spec :required)
            flag
            (format nil "[~A]" flag))
        (if (getf spec :required)
            (format nil "~A ~A" flag value-name)
            (format nil "[~A ~A]" flag value-name)))))

(defun %join-usage-parts (parts)
  (format nil "~{~A~^ ~}" (remove-if (lambda (part) (or (null part) (string= part ""))) parts)))

(defun command-usage-tail (definition)
  (let* ((positionals (mapcar #'%render-positional-usage (%command-positionals definition)))
         (options (mapcar #'%render-option-usage (%command-options definition))))
    (%join-usage-parts (append positionals options))))

(defun %option-help-usage (spec)
  (if (getf spec :flag)
      (%option-help-label spec)
      (format nil "~A ~A"
              (%option-help-label spec)
              (getf spec :value-name "<value>"))))

(defun %option-help-annotations (definition spec)
  (remove nil
          (list (getf spec :summary)
                (when (getf spec :repeatable)
                  "[repeatable]")
                (when (not (null (getf spec :default)))
                  (format nil "[default: ~A]" (getf spec :default)))
                (when (getf spec :requires)
                  (format nil "[requires: ~{~A~^, ~}]"
                          (mapcar (lambda (requirement)
                                    (%requirement-help-label definition requirement))
                                  (getf spec :requires))))
                (when (getf spec :conflicts-with)
                  (format nil "[conflicts: ~{~A~^, ~}]"
                          (mapcar (lambda (option-key)
                                    (%conflict-help-label definition option-key))
                                  (getf spec :conflicts-with)))))))

(defun command-option-help-lines (definition)
  (mapcar (lambda (spec)
            (format nil "      ~A~@[  ~A~]"
                    (%option-help-usage spec)
                    (%join-usage-parts (%option-help-annotations definition spec))))
          (%command-options definition)))

(defun command-positional-argument (parsed-arguments index)
  (nth index (getf parsed-arguments :positionals)))

(defun command-positional-arguments (parsed-arguments &optional (start-index 0))
  (nthcdr start-index (getf parsed-arguments :positionals)))

(defun command-option-value (parsed-arguments option-key &optional default)
  (let* ((options (getf parsed-arguments :options))
         (value (getf options option-key :missing)))
    (if (eq value :missing)
        default
        value)))

(defun command-option-values (parsed-arguments option-key)
  (let ((value (command-option-value parsed-arguments option-key nil)))
    (cond
      ((null value) nil)
      ((listp value) value)
      (t (list value)))))

(defun %validate-command-arguments (definition matched-pattern argv)
  (%parse-command-arguments definition matched-pattern argv))