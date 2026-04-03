;;;; tests/unit/json-parser-test.lisp
(in-package :cl-cc/tests)

(def-suite json-parser-test :in cl-cc-suite)
(in-suite json-parser-test)

(test parse-json-document-preserves-objects-arrays-and-null
  (let ((parsed (cl-cc.lib:parse-json-document
                 "{\"status\":\"success\",\"items\":[1,2],\"sessionPath\":null}")))
    (is (string= (getf parsed :STATUS) "success"))
    (is (equal (getf parsed :ITEMS) '(1 2)))
    (is (cl-cc.lib:json-null-p (getf parsed :SESSION-PATH)))))

(test ensure-json-cursor-before-end-preserves-stable-errors
  (is (= 1 (cl-cc.lib::%ensure-json-cursor-before-end "[]" 1 "unused")))
  (handler-case
      (progn
        (cl-cc.lib::%ensure-json-cursor-before-end "[]" 2 "unterminated array")
        (fail "expected JSON parse error for exhausted cursor"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 2: unterminated array")))))

(test json-expected-literal-error-preserves-stable-text
  (handler-case
      (progn
        (cl-cc.lib::%json-expected-literal-error "tru" 0 "true")
        (fail "expected literal parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: expected true")))))

(test json-parser-entry-and-unexpected-token-errors-preserve-stable-text
  (handler-case
      (progn
        (cl-cc.lib::%json-expected-parser-entry-error "{" 0 "object")
        (fail "expected parser entry helper error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: expected object"))))
  (handler-case
      (progn
        (cl-cc.lib::%json-unexpected-token-error "@" 0)
        (fail "expected unexpected-token helper error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: unexpected token")))))

(test json-string-escape-errors-preserve-stable-text
  (handler-case
      (progn
        (cl-cc.lib::%json-string-escape-error "\\u12" 1 "incomplete unicode escape")
        (fail "expected string escape helper error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 1: incomplete unicode escape"))))
  (handler-case
      (progn
        (cl-cc.lib::%json-unsupported-escape-error "\\x" 1 #\x)
        (fail "expected unsupported escape helper error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 1: unsupported escape x")))))

(test parse-json-document-preserves-unterminated-structure-errors
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "[")
        (fail "expected unterminated array parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 1: unterminated array"))))
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "{")
        (fail "expected unterminated object parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 1: unterminated object")))))

(test json-invalid-number-error-preserves-stable-text
  (handler-case
      (progn
        (cl-cc.lib::%json-invalid-number-error "1e" 0)
        (fail "expected invalid number helper error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: invalid number")))))

(test json-object-key-separator-error-preserves-stable-text
  (handler-case
      (progn
        (cl-cc.lib::%json-object-key-separator-error "{\"a\" 1}" 5)
        (fail "expected object key separator helper error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 5: expected ':' after object key")))))

(test advance-json-delimited-sequence-cursor-preserves-stable-branching
  (multiple-value-bind (done-p next-cursor)
      (cl-cc.lib::%advance-json-delimited-sequence-cursor "]" 0 #\] "unterminated array" "expected ',' or ']' in array")
    (is (not (null done-p)))
    (is (= 1 next-cursor)))
  (multiple-value-bind (done-p next-cursor)
      (cl-cc.lib::%advance-json-delimited-sequence-cursor ",  " 0 #\] "unterminated array" "expected ',' or ']' in array")
    (is (null done-p))
    (is (= 3 next-cursor)))
  (handler-case
      (progn
        (cl-cc.lib::%advance-json-delimited-sequence-cursor "x" 0 #\] "unterminated array" "expected ',' or ']' in array")
        (fail "expected invalid delimiter parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: expected ',' or ']' in array")))))

(test parse-json-document-reports-invalid-number
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "1e")
        (fail "expected invalid number parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: invalid number")))))

(test parse-json-document-reports-invalid-literals
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "tru")
        (fail "expected truncated true parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: expected true"))))
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "falsx")
        (fail "expected mismatched false parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: expected false"))))
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "nul")
        (fail "expected truncated null parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: expected null")))))

(test parse-json-document-reports-invalid-string-escapes
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "\"\\x\"")
        (fail "expected unsupported escape parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 2: unsupported escape x"))))
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "\"\\u12\"")
        (fail "expected incomplete unicode escape parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 2: incomplete unicode escape")))))

(test parse-json-document-reports-missing-separators
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "[1 2]")
        (fail "expected missing array separator parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 3: expected ',' or ']' in array"))))
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "{\"a\":1 \"b\":2}")
        (fail "expected missing object separator parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 7: expected ',' or '}' in object")))))

(test parse-json-document-reports-missing-object-key-separator
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "{\"a\" 1}")
        (fail "expected missing object key separator parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 5: expected ':' after object key")))))

(test parse-json-document-reports-trailing-content
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "{} trailing")
        (fail "expected JSON parse error for trailing content"))
    (error (condition)
      (is (search "JSON parse error at character" (princ-to-string condition)))
      (is (search "trailing content after JSON value" (princ-to-string condition))))))

(test parse-json-document-reports-unexpected-token
  (handler-case
      (progn
        (cl-cc.lib:parse-json-document "@")
        (fail "expected unexpected token parse error"))
    (error (condition)
      (is (string= (princ-to-string condition)
                   "JSON parse error at character 0: unexpected token")))))