;;;; src/models/compatibility-fixture.lisp
(in-package :cl-cc.models)

(defclass compatibility-fixture ()
  ((fixture-id :initarg :fixture-id :accessor fixture-id :documentation "唯一标识")
   (reference-source :initarg :reference-source :accessor fixture-reference-source :documentation "参考来源")
   (scenario-name :initarg :scenario-name :accessor fixture-scenario-name :documentation "场景名")
   (input-sample :initarg :input-sample :accessor fixture-input-sample :documentation "测试输入")
   (expected-output :initarg :expected-output :accessor fixture-expected-output :documentation "目标输出")
   (deviation-policy :initarg :deviation-policy :accessor fixture-deviation-policy :documentation "strict | explainable-deviation | deferred")
   (notes :initarg :notes :accessor fixture-notes :documentation "偏差说明")))
