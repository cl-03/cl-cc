;;;; src/lib/json.lisp - shared JSON parsing helpers
(in-package :cl-cc.lib)

(defparameter +json-null+ (gensym "JSON-NULL"))

(defun json-null-p (value)
  (eq value +json-null+))

(defun %json-name-to-keyword (name)
  (intern (with-output-to-string (stream)
            (loop for character across name
                  for first-character = t then nil do
              (when (and (upper-case-p character)
                         (not first-character))
                (write-char #\- stream))
              (write-char (char-upcase character) stream)))
          :keyword))

(defun %json-whitespace-p (character)
  (member character '(#\Space #\Tab #\Newline #\Return) :test #'char=))

(defun %skip-json-whitespace (text index)
  (loop with length = (length text)
        while (and (< index length)
                   (%json-whitespace-p (char text index))) do
    (incf index)
        finally (return index)))

(defun %json-parser-error (text index message)
  (declare (ignore text))
  (error "JSON parse error at character ~D: ~A" index message))

(defun %ensure-json-cursor-before-end (text cursor message)
  (when (>= cursor (length text))
    (%json-parser-error text cursor message))
  cursor)

(defun %json-expected-error (text index expected)
  (%json-parser-error text index (format nil "expected ~A" expected)))

(defun %json-expected-literal-error (text index literal)
  (%json-expected-error text index literal))

(defun %json-expected-parser-entry-error (text index expected)
  (%json-expected-error text index expected))

(defun %json-string-escape-error (text index message)
  (%json-parser-error text index message))

(defun %json-unsupported-escape-error (text index escaped)
  (%json-parser-error text index (format nil "unsupported escape ~C" escaped)))

(defun %parse-json-literal (text index literal value)
  (let ((end-index (+ index (length literal))))
    (when (> end-index (length text))
      (%json-expected-literal-error text index literal))
    (unless (string= text literal :start1 index :end1 end-index)
      (%json-expected-literal-error text index literal))
    (values value end-index)))

(defun %parse-json-string (text index)
  (unless (char= (char text index) #\")
    (%json-expected-parser-entry-error text index "string"))
  (let ((stream (make-string-output-stream))
        (cursor (1+ index))
        (length (length text)))
    (loop while (< cursor length) do
      (let ((character (char text cursor)))
        (cond
          ((char= character #\")
           (return-from %parse-json-string
             (values (get-output-stream-string stream) (1+ cursor))))
          ((char= character #\\)
           (incf cursor)
           (%ensure-json-cursor-before-end text cursor "unterminated escape sequence")
           (let ((escaped (char text cursor)))
             (case escaped
               (#\" (write-char #\" stream))
               (#\\ (write-char #\\ stream))
               (#\/ (write-char #\/ stream))
               (#\b (write-char #\Backspace stream))
               (#\f (write-char #\Page stream))
               (#\n (write-char #\Newline stream))
               (#\r (write-char #\Return stream))
               (#\t (write-char #\Tab stream))
               (#\u
                (let ((hex-end (+ cursor 5)))
                  (when (> hex-end length)
                    (%json-string-escape-error text cursor "incomplete unicode escape"))
                  (let* ((hex-digits (subseq text (1+ cursor) hex-end))
                         (code-point (parse-integer hex-digits :radix 16 :junk-allowed nil)))
                    (write-char (or (code-char code-point)
                                    (%json-string-escape-error text cursor "invalid unicode code point"))
                                stream)
                    (setf cursor (1- hex-end)))))
               (t
                  (%json-unsupported-escape-error text cursor escaped)))))
          (t
           (write-char character stream))))
      (incf cursor))
    (%json-parser-error text cursor "unterminated string")))

(defun %json-number-character-p (character)
  (or (digit-char-p character)
      (member character '(#\- #\+ #\. #\e #\E) :test #'char=)))

(defun %json-invalid-number-error (text index)
  (%json-parser-error text index "invalid number"))

(defun %json-object-key-separator-error (text index)
  (%json-parser-error text index "expected ':' after object key"))

(defun %json-unexpected-token-error (text index)
  (%json-parser-error text index "unexpected token"))

(defun %advance-json-delimited-sequence-cursor (text cursor close-char unterminated-message invalid-message)
  (%ensure-json-cursor-before-end text cursor unterminated-message)
  (cond
    ((char= (char text cursor) close-char)
     (values t (1+ cursor)))
    ((char= (char text cursor) #\,)
     (values nil (%skip-json-whitespace text (1+ cursor))))
    (t
     (%json-parser-error text cursor invalid-message))))

(defun %parse-json-number (text index)
  (let* ((length (length text))
         (end-index index))
    (loop while (and (< end-index length)
                     (%json-number-character-p (char text end-index))) do
      (incf end-index))
    (let ((token (subseq text index end-index)))
      (handler-case
          (multiple-value-bind (value position)
              (let ((*read-eval* nil))
                (read-from-string token nil nil))
            (unless (and value
                         (numberp value)
                         (= position (length token)))
              (%json-invalid-number-error text index))
            (values value end-index))
        (error ()
          (%json-invalid-number-error text index))))))

(defun %parse-json-array (text index)
  (unless (char= (char text index) #\[)
    (%json-expected-parser-entry-error text index "array"))
  (let ((cursor (%skip-json-whitespace text (1+ index)))
        (items '()))
    (%ensure-json-cursor-before-end text cursor "unterminated array")
    (if (char= (char text cursor) #\])
        (values '() (1+ cursor))
        (loop
          (multiple-value-bind (item next-index)
              (%parse-json-value text cursor)
            (push item items)
            (setf cursor (%skip-json-whitespace text next-index))
            (multiple-value-bind (done-p next-cursor)
                (%advance-json-delimited-sequence-cursor text
                                                        cursor
                                                        #\]
                                                        "unterminated array"
                                                        "expected ',' or ']' in array")
              (if done-p
                  (return (values (nreverse items) next-cursor))
                  (setf cursor next-cursor))))))))

(defun %parse-json-object (text index)
  (unless (char= (char text index) #\{)
    (%json-expected-parser-entry-error text index "object"))
  (let ((cursor (%skip-json-whitespace text (1+ index)))
        (plist '()))
    (%ensure-json-cursor-before-end text cursor "unterminated object")
    (if (char= (char text cursor) #\})
        (values '() (1+ cursor))
        (loop
          (multiple-value-bind (key after-key)
              (%parse-json-string text cursor)
            (setf cursor (%skip-json-whitespace text after-key))
            (when (or (>= cursor (length text))
                      (not (char= (char text cursor) #\:)))
              (%json-object-key-separator-error text cursor))
            (setf cursor (%skip-json-whitespace text (1+ cursor)))
            (multiple-value-bind (value next-index)
                (%parse-json-value text cursor)
              (setf plist (append plist (list (%json-name-to-keyword key) value)))
              (setf cursor (%skip-json-whitespace text next-index))
              (multiple-value-bind (done-p next-cursor)
                  (%advance-json-delimited-sequence-cursor text
                                                          cursor
                                                          #\}
                                                          "unterminated object"
                                                          "expected ',' or '}' in object")
                (if done-p
                    (return (values plist next-cursor))
                    (setf cursor next-cursor)))))))))

(defun %parse-json-value (text index)
  (let ((cursor (%skip-json-whitespace text index)))
    (%ensure-json-cursor-before-end text cursor "unexpected end of input")
    (case (char text cursor)
      (#\{ (%parse-json-object text cursor))
      (#\[ (%parse-json-array text cursor))
      (#\" (%parse-json-string text cursor))
      (#\t (%parse-json-literal text cursor "true" t))
      (#\f (%parse-json-literal text cursor "false" nil))
      (#\n (%parse-json-literal text cursor "null" +json-null+))
      (t
       (if (or (char= (char text cursor) #\-)
               (digit-char-p (char text cursor)))
           (%parse-json-number text cursor)
           (%json-unexpected-token-error text cursor))))))

(defun parse-json-document (text)
  (multiple-value-bind (value next-index)
      (%parse-json-value text 0)
    (let ((cursor (%skip-json-whitespace text next-index)))
      (when (< cursor (length text))
        (%json-parser-error text cursor "trailing content after JSON value"))
      value)))