#lang racket/base

(require waxeye/ast
         "action.rkt"
         "expand.rkt"
         "gen.rkt"
         "util.rkt")

(provide (all-defined-out))


;; The hash table for the names of the non-terminals
(define nt-names (make-hash))


;; Transforms the grammar and performs sanity checks
(define (transform-grammar g)
  (and (check-not-empty g)
       (collect-actions g)
       (collect-nt-names g)
       (check-refs g)
       (expand-grammar g)))


(define (check-not-empty g)
  (when (null? (ast-c g))
        (error 'check-not-empty "grammar is empty")))


(define (collect-nt-names g)
  (let ((ok #t))
    (for-each (lambda (a)
                (let* ((name (get-non-term a)) (found (hash-ref nt-names name #f)))
                  (if found
                      (begin
                        (set! ok #f)
                        (error 'check-duplicate "duplicate definition of non-terminal: ~a" name))
                      (hash-set! nt-names name name))))
              (ast-c g))
    ok))


;; Checks that referenced non-terminals have been defined
(define (check-refs grammar)
  (define (visit-nt exp)
    (let ((name (list->string (ast-c exp))))
      (unless (hash-ref nt-names name #f)
              (error 'waxeye "undefined reference to non-terminal: ~a" name))))

  (define (visit-alternation exp)
    (for-each visit-sequence (ast-c exp)))

  (define (visit-sequence exp)
    (for-each visit-unit (ast-c exp)))

  (define (visit-unit exp)
    (let* ((el (ast-c exp)) (el-len (length el)))
      (visit-exp (list-ref el (- el-len 1)))))

  (define (visit-exp exp)
    (let ((type (ast-t exp)))
      (case type
       ((alternation) (visit-alternation exp))
       ((identifier) (visit-nt exp))
       ((sequence) (visit-sequence exp))
       ((unit) (visit-unit exp)))))

  (define (check-nt-refs def)
    (visit-alternation (caddr (ast-c def))))

  (for-each check-nt-refs (get-defs grammar)))
