;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; utils.lisp --- Various utilities.
;;;
;;; Copyright (C) 2005-2006, Luis Oliveira  <loliveira(@)common-lisp.net>
;;;
;;; Permission is hereby granted, free of charge, to any person
;;; obtaining a copy of this software and associated documentation
;;; files (the "Software"), to deal in the Software without
;;; restriction, including without limitation the rights to use, copy,
;;; modify, merge, publish, distribute, sublicense, and/or sell copies
;;; of the Software, and to permit persons to whom the Software is
;;; furnished to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be
;;; included in all copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;;; NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;;; HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;;; WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;;; DEALINGS IN THE SOFTWARE.
;;;

(in-package #:cl-user)

;;; This package is for CFFI's internal use.  No effort is made to
;;; maintain backwards compatibility.  Use at your own risk.
(defpackage #:cffi-utils
  (:use #:common-lisp #:alexandria)
  (:export #:discard-docstring
           #:symbolicate
           #:post-incf
           #:single-bit-p
           #:warn-if-kw-or-belongs-to-cl))

(in-package #:cffi-utils)

;;;# General Utilities

;;; frodef's, see: http://paste.lisp.org/display/2771#1
(defmacro post-incf (place &optional (delta 1) &environment env)
  "Increment PLACE by DELTA and return its previous value."
  (multiple-value-bind (dummies vals new setter getter)
      (get-setf-expansion place env)
    `(let* (,@(mapcar #'list dummies vals) (,(car new) ,getter))
       (prog1 ,(car new)
         (setq ,(car new) (+ ,(car new) ,delta))
         ,setter))))

(defmacro discard-docstring (body-var &optional force)
  "Discards the first element of the list in body-var if it's a
string and the only element (or if FORCE is T)."
  `(when (and (stringp (car ,body-var)) (or ,force (cdr ,body-var)))
     (pop ,body-var)))

(defun side-effect-free? (exp)
  "Is exp a constant, variable, or function,
  or of the form (THE type x) where x is side-effect-free?"
  (or (atom exp) (constantp exp)
      (starts-with exp 'function)
      (and (starts-with exp 'the)
           (side-effect-free? (third exp)))))

;;;; The following utils were taken from SBCL's
;;;; src/code/*-extensions.lisp

(defun symbolicate (&rest things)
  "Concatenate together the names of some strings and symbols,
producing a symbol in the current package."
  (let* ((length (reduce #'+ things
                         :key (lambda (x) (length (string x)))))
         (name (make-array length :element-type 'character)))
    (let ((index 0))
      (dolist (thing things (values (intern name)))
        (let* ((x (string thing))
               (len (length x)))
          (replace name x :start1 index)
          (incf index len))))))

(defun single-bit-p (integer)
  "Answer whether INTEGER, which must be an integer, is a single
set twos-complement bit."
  (if (<= integer 0)
    nil                       ;infinite set bits for negatives
    (loop until (logbitp 0 integer)
         do (setf integer (ash integer -1))
         finally (return (zerop (ash integer -1))))))

;;; This function is here because it needs to be defined early.
;;;
;;; This function is used by DEFINE-PARSE-METHOD and DEFCTYPE to warn
;;; users when they're defining types whose names belongs to the
;;; KEYWORD or CL packages.  CFFI itself gets to use keywords without
;;; a warning though.
(defun warn-if-kw-or-belongs-to-cl (name)
  (let ((package (symbol-package name)))
    (when (or (eq package (find-package '#:cl))
              (and (not (eq *package* (find-package '#:cffi)))
                   (eq package (find-package '#:keyword))))
      (warn "Defining a foreign type named ~S.  This symbol belongs to the ~A ~
             package and that may interfere with other code using CFFI."
            name (package-name package)))))

;(defun deprecation-warning (bad-name &optional good-name)
;  (warn "using deprecated ~S~@[, should use ~S instead~]"
;        bad-name
;        good-name))

;;; Anaphoric macros
;(defmacro awhen (test &body body)
;  `(let ((it ,test))
;     (when it ,@body)))

;(defmacro acond (&rest clauses)
;  (if (null clauses)
;      `()
;      (destructuring-bind ((test &body body) &rest rest) clauses
;        (once-only (test)
;          `(if ,test
;               (let ((it ,test)) (declare (ignorable it)),@body)
;               (acond ,@rest))))))
