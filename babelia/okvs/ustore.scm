;; This is a two-way mapping between scheme objects and an ulid.  This
;; is meant to save space and speed up queries.  It rely on the sha256
;; as an intermediate internal representation.
;;
;; TODO: use okvs/mapping
;;
(define-module (babelia okvs ustore))

(import (srfi srfi-9))
(import (rnrs bytevectors))

(import (gcrypt hash))
(import (babelia bytevector))
(import (babelia okvs ulid))
(import (babelia okvs engine))


(define %sha256->object '(0))
(define %sha256->ulid '(1))
(define %ulid->sha256 '(2))


(define-record-type <ustore>
  (make-ustore engine prefix)
  ustore?
  (engine ustore-engine)
  (prefix ustore-prefix))

(export make-ustore)

(define-public (object->ulid transaction ustore object)
  (let ((engine (ustore-engine ustore)))
    (let* ((value (engine-pack engine object))
           (hash (sha256 value))
           (key (engine-pack engine
                             (append (ustore-prefix ustore)
                                     %sha256->ulid
                                     (list hash)))))
      ;; try to get ulid from sha256->ulid subspace
      (let ((out (engine-ref engine transaction key)))
        (if out
            out
            ;; otherwise, create a new identifier and store it.
            (let ((out (ulid)))
              (engine-set! engine transaction
                           (engine-pack engine
                                        (append (ustore-prefix ustore)
                                                %sha256->object
                                                (list hash)))
                           value)

              (engine-set! engine transaction
                           (engine-pack engine
                                        (append (ustore-prefix ustore)
                                                %sha256->ulid
                                                (list hash)))
                           out)

              (engine-set! engine transaction
                           (engine-pack engine
                                        (append (ustore-prefix ustore)
                                                %ulid->sha256
                                                (list out)))
                           hash)

              out))))))

(define-public (ulid->object transaction ustore ulid)
  "Retrieve the object with the given ULID. Otherwise return #f"
  (let ((engine (ustore-engine ustore)))
    ;; try to find the hash
    (and=>
     (engine-ref engine
                 transaction
                 (engine-pack engine
                              (append (ustore-prefix ustore)
                                      %ulid->sha256
                                      (list ulid))))
     (lambda (hash)
       ;; there is a hash, there must be a value
       (let ((value (engine-ref engine transaction
                                (engine-pack engine
                                             (append (ustore-prefix ustore)
                                                     %sha256->object
                                                     (list hash))))))
         (car (engine-unpack engine value)))))))
