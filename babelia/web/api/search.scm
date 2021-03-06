(define-module (babelia web api search))

(import (scheme base))

(import (babelia app))
(import (babelia log))
(import (babelia pool))
(import (babelia okvs engine))
(import (babelia okvs fts))
(import (babelia okvs rstore))
(import (babelia web helpers))
(import (babelia web decode))

(import (ice-9 threads))
(import (babelia okvs wiredtiger))


(define-public (route/api/search app query)
  (let ((query (cadr (assoc "query" (decode query)))))
    (log-debug "search" query)
    (scheme->response
     (pool-apply
      (lambda ()
        (engine-in-transaction (app-engine app) (app-okvs app)
          (lambda (tx)
            (map (lambda (x) (document-url (rstore-ref tx (app-rstore app) (car x))))
                 (fts-query (app-okvs app) (app-fts app) query)))))))))
