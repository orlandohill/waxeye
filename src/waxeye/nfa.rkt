#lang racket/base

(require waxeye/ast
         waxeye/fa
         "util.rkt")

(provide make-nfa
         reset-nfa-builder
         unwinds)


(define is-void #f)
(define unwinds '())

(define (reset-nfa-builder)
  (set! is-void #f)
  (set! unwinds '()))

(define (build-unwind-nfa type exp)
  (let ((nfa (build-states exp (state '() #t))))
    (set! unwinds (append unwinds (list (cons type (nfa->vector nfa)))))
    (- (length unwinds) 1)))


(define (make-nfa def)
  (nfa->vector (build-states (caddr (ast-c def)) (state '() #t))))


;; Converts an NFA into a vector of it's states
;; References between states are changed to indexes into the vector
(define (nfa->vector nfa)
  (let ((visited-table (make-hash)) (state-list '()) (state-count 0))

    (define (add-edge e)
      (set-edge-s! e (add-state (edge-s e))))

    (define (add-state to-add)
      (let ((h-index (hash-ref visited-table to-add #f)))
        (if h-index
            h-index
            (let ((new-index state-count))
              (hash-set! visited-table to-add state-count)

              (set! state-count (+ state-count 1))

              ;; Create a deep copy of the nfa state since, we are about to destroy the
              ;; original edges but still need to hash against them
              (let ((state-copy (state (map
                                         (lambda (a)
                                           (edge (edge-t a) (edge-s a) (edge-v a)))
                                         (state-edges to-add))
                                       (state-match to-add))))
                (set! state-list (cons state-copy state-list))

                ;; Add the states of the edges
                (for-each add-edge (state-edges state-copy)))

              new-index))))

    (add-state nfa)
    (list->vector (reverse state-list))))


(define (build-states exp end)
  (let ((type (ast-t exp)))
    ((case type
      ((action) build-action)
      ((alternation) build-alternation)
      ((and) build-and)
      ((charClass) build-char-class)
      ((closure) build-closure)
      ((identifier) build-identifier)
      ((label) build-label)
      ((literal) build-literal)
      ((not) build-not)
      ((optional) build-optional)
      ((plus) build-plus)
      ((sequence) build-sequence)
      ((void) build-void)
      ((wildCard) build-wildCard)
      (else (error 'build-states "unknown expression type: ~s" type)))
     exp end)))


(define (build-action exp end)
  (error 'build-action "actions not done yet"))


(define (build-alternation exp end)
  (state
    (list-concat
      (map
        (lambda (a)
          (state-edges (build-states a end)))
        (ast-c exp)))
    #f))


(define (build-and exp end)
  (state (list (edge (build-unwind-nfa '& (car (ast-c exp))) end is-void))
         #f))


(define (build-char-class exp end)
  (state (list (edge (ast-c exp) end is-void))
         #f))


(define (build-closure exp end)
  (let* ((s (state #f #f))
         (e (build-states (car (ast-c exp)) s)))
    (set-state-edges! s (append (state-edges e) (list (edge 'e end is-void))))
    s))


(define (build-identifier exp end)
  (state (list (edge (list->string (ast-c exp)) end is-void)) #f))


(define (build-label exp end)
  (error 'build-label "labels not done yet"))


(define (build-literal exp end)
  (define (build-char c end)
    (state (list (edge c end is-void)) #f))
  (define (build-iter es end)
    (let ((c (car es)) (n (cdr es)))
      (build-char c (if (null? n)
                        end
                        (build-iter n end)))))
  (build-iter (ast-c exp) end))


(define (build-not exp end)
  (state (list (edge (build-unwind-nfa '! (car (ast-c exp))) end is-void)) #f))


(define (build-optional exp end)
  (let ((s (build-states (car (ast-c exp)) end)))
    (set-state-edges! s (append (state-edges s) (list (edge 'e end is-void))))
    s))


(define (build-plus exp end)
  (build-states (car (ast-c exp)) (build-closure exp end)))


(define (build-sequence exp end)
  (define (build-iter es end)
    (let ((c (car es)) (n (cdr es)))
      (build-states c (if (null? n)
                          end
                          (build-iter n end)))))
  (build-iter (ast-c exp) end))


(define (build-void exp end)
  (let ((old-void is-void))
    (set! is-void #t)
    (let ((res (build-states (car (ast-c exp)) end)))
      (set! is-void old-void)
      res)))


(define (build-wildCard exp end)
  (state (list (edge 'wild end is-void)) #f))
