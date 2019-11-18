(define-module (babelia okvs ustore))

(import (srfi srfi-9))
(import (rnrs bytevectors))

(import (gcrypt hash))
(import (babelia bytevector))
(import (babelia okvs ulid))
(import (babelia okvs engine))


(define %sha256->value #vu8(0))
(define %sha256->ulid #vu8(1))
(define %ulid->sha256 #vu8(2))


(define-record-type <ustore>
  (%ustore engine prefix)
  ustore?
  (engine ustore-engine)
  (prefix ustore-prefix))

(define-public (ustore engine prefix)
  (%ustore engine prefix))

(define-public (object->ulid transaction ustore value)
  (let ((engine (ustore-engine ustore)))
    (let* ((value (engine-pack engine value))
           (hash (sha256 value))
           (key (bytevector-append (ustore-prefix ustore)
                                    %sha256->ulid
                                    hash)))
      ;; try to get ulid from sha256->ulid subspace
      (let ((out (engine-ref engine transaction key)))
        (if out
            out
            ;; otherwise, create a new identifier and store it.
            (let ((out (ulid)))
              (engine-set! engine transaction
                           (bytevector-append (ustore-prefix ustore)
                                               %sha256->value
                                               hash)
                           value)

              (engine-set! engine transaction
                           (bytevector-append (ustore-prefix ustore)
                                               %sha256->ulid
                                               hash)
                           out)

              (engine-set! engine transaction
                           (bytevector-append (ustore-prefix ustore)
                                               %ulid->sha256
                                               out)
                           hash)

              out))))))

(define-public (ulid->object transaction ustore ulid)
  "Retrieve the object with the given ULID. Otherwise return #f"
  (let ((engine (ustore-engine ustore)))
    ;; try to find the hash
    (and=>
     (engine-ref engine
                 transaction
                 (bytevector-append (ustore-prefix ustore)
                                     %ulid->sha256
                                     ulid))
     (lambda (hash)
       ;; there is a hash, there must be a value
       (let ((value (engine-ref engine transaction
                                (bytevector-append (ustore-prefix ustore)
                                                    %sha256->value
                                                    hash))))
         (car (engine-unpack engine value)))))))