;; Discovery Engine - Core audio catalog indexing and retrieval
;; Manages the foundational storage and organization of audio content entries
;; with comprehensive geographic and metadata capabilities

(define-constant INVALID-AUTH (err u100))
(define-constant NOT-PRESENT (err u101))
(define-constant COORD-OUT-OF-RANGE (err u102))
(define-constant BAD-INPUT (err u103))
(define-constant FORBIDDEN-OP (err u104))
(define-constant DUPLICATE-ENTRY (err u105))

;; Entry catalog - stores detailed information indexed by unique identifier
(define-map entry-catalog
  { idx: uint }
  {
    owner: principal,
    heading: (string-utf8 100),
    body: (string-utf8 500),
    stream-source: (string-utf8 256),
    lat: int,
    lng: int,
    block-recorded: uint,
    accessible-public: bool
  }
)

;; Creator's entry registry - maps principals to their entry identifiers
(define-map creator-entry-index
  { owner: principal }
  { indices: (list 100 uint) }
)

;; Entry access control list - tracks authorized principals per entry
(define-map entry-acl
  { idx: uint }
  { permitted-principals: (list 50 principal) }
)

;; Sequential identifier generator
(define-data-var current-entry-index uint u1)

;; Helper: Initialize or retrieve owner's entry list
(define-private (fetch-or-init-creator-entries (owner principal))
  (match (map-get? creator-entry-index { owner: owner })
    existing existing
    { indices: (list) }
  )
)

;; Retrieve all entries belonging to a specific creator
(define-read-only (list-creator-entries (owner principal))
  (match (map-get? creator-entry-index { owner: owner })
    data (ok (get indices data))
    (ok (list))
  )
)

;; Retrieve a specific entry's full details
(define-read-only (fetch-entry-details (entry-id uint))
  (map-get? entry-catalog { idx: entry-id })
)

;; List all access-granted principals for an entry
(define-read-only (query-entry-permissions (entry-id uint))
  (map-get? entry-acl { idx: entry-id })
)

;; Get the next available entry identifier
(define-read-only (next-available-id)
  (var-get current-entry-index)
)

;; Create new audio entry with location metadata
(define-public (store-new-entry
  (heading (string-utf8 100))
  (body (string-utf8 500))
  (stream-source (string-utf8 256))
  (lat int)
  (lng int)
  (accessible-public bool))
  
  (let ((entry-id (var-get current-entry-index)))
    (map-set entry-catalog
      { idx: entry-id }
      {
        owner: tx-sender,
        heading: heading,
        body: body,
        stream-source: stream-source,
        lat: lat,
        lng: lng,
        block-recorded: block-height,
        accessible-public: accessible-public
      }
    )
    
    (let ((creator-data (fetch-or-init-creator-entries tx-sender)))
      (map-set creator-entry-index
        { owner: tx-sender }
        { indices: (unwrap! (as-max-len? (append (get indices creator-data) entry-id) u100) NOT-PRESENT) }
      )
    )
    
    (var-set current-entry-index (+ entry-id u1))
    (ok entry-id)
  )
)

;; Modify an existing entry (owner only)
(define-public (modify-entry
  (entry-id uint)
  (heading (string-utf8 100))
  (body (string-utf8 500))
  (stream-source (string-utf8 256))
  (lat int)
  (lng int)
  (accessible-public bool))
  
  (let ((current-entry (unwrap! (map-get? entry-catalog { idx: entry-id }) NOT-PRESENT)))
    (asserts! (is-eq tx-sender (get owner current-entry)) INVALID-AUTH)
    
    (map-set entry-catalog
      { idx: entry-id }
      {
        owner: (get owner current-entry),
        heading: heading,
        body: body,
        stream-source: stream-source,
        lat: lat,
        lng: lng,
        block-recorded: (get block-recorded current-entry),
        accessible-public: accessible-public
      }
    )
    (ok true)
  )
)

;; Grant access permission to a principal
(define-public (permit-access (entry-id uint) (granted-principal principal))
  (let ((entry (unwrap! (map-get? entry-catalog { idx: entry-id }) NOT-PRESENT)))
    (asserts! (is-eq tx-sender (get owner entry)) INVALID-AUTH)
    
    (let ((acl (match (map-get? entry-acl { idx: entry-id })
                 existing existing
                 { permitted-principals: (list) })))
      
      (asserts! (not (is-some (index-of? (get permitted-principals acl) granted-principal))) DUPLICATE-ENTRY)
      
      (map-set entry-acl
        { idx: entry-id }
        { permitted-principals: (unwrap! (as-max-len? (append (get permitted-principals acl) granted-principal) u50) NOT-PRESENT) }
      )
      (ok true)
    )
  )
)

;; Revoke access permission
(define-public (revoke-permission (entry-id uint) (revoke-principal principal))
  (let ((entry (unwrap! (map-get? entry-catalog { idx: entry-id }) NOT-PRESENT)))
    (asserts! (is-eq tx-sender (get owner entry)) INVALID-AUTH)
    
    (let ((acl (unwrap! (map-get? entry-acl { idx: entry-id }) NOT-PRESENT)))
      (match (index-of? (get permitted-principals acl) revoke-principal)
        idx
        (let ((updated (unwrap! (as-max-len? 
          (concat 
            (unwrap! (as-max-len? (slice (get permitted-principals acl) u0 idx) u50) NOT-PRESENT)
            (unwrap! (as-max-len? (slice (get permitted-principals acl) (+ idx u1)) u50) NOT-PRESENT)
          ) u50) NOT-PRESENT)))
          (map-set entry-acl { idx: entry-id } { permitted-principals: updated })
          (ok true)
        )
        (err false)
      )
    )
  )
)

;; Check if principal has access to entry
(define-read-only (verify-access (entry-id uint) (principal-addr principal))
  (let ((entry (map-get? entry-catalog { idx: entry-id })))
    (match entry
      details
      (ok (or
        (get accessible-public details)
        (is-eq (get owner details) principal-addr)
        (match (map-get? entry-acl { idx: entry-id })
          acl (is-some (index-of? (get permitted-principals acl) principal-addr))
          false
        )
      ))
      (err false)
    )
  )
)