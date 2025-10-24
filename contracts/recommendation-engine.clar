;; Recommendation Engine
;; Social graph and discovery capabilities enabling user connections, content evaluation,
;; and curated collections for personalized audio exploration

(define-constant PERM-DENIED (err u401))
(define-constant USR-ABSENT (err u404))
(define-constant MEDIA-ABSENT (err u405))
(define-constant ALREADY-FOLLOWING (err u406))
(define-constant NOT-FOLLOWING-YET (err u407))
(define-constant RATED-ALREADY (err u408))
(define-constant RATING-OUT-OF-BOUNDS (err u409))
(define-constant COLL-MISSING (err u410))
(define-constant ALREADY-IN-COLL (err u411))
(define-constant NOT-IN-COLL (err u412))
(define-constant GEO-BOUNDS-ERROR (err u413))

;; User profiles with optional metadata
(define-map profile-store
  { account: principal }
  {
    display-name: (optional (string-utf8 50)),
    about-text: (optional (string-utf8 500)),
    geo-coord: (optional {latitude: int, longitude: int}),
    follower-qty: uint,
    following-qty: uint,
    published-qty: uint
  }
)

;; Follower relationships
(define-map follow-index
  { publisher: principal, follower: principal }
  { when: uint }
)

;; Content evaluation records
(define-map media-metadata
  { media-id: uint }
  {
    publisher: principal,
    title-text: (string-utf8 100),
    description-text: (optional (string-utf8 500)),
    geo-coord: {latitude: int, longitude: int},
    when: uint,
    cumulative-rating: uint,
    evaluation-count: uint,
    play-count: uint
  }
)

;; User evaluations per content
(define-map user-evaluation
  { account: principal, media-id: uint }
  { score: uint }
)

;; User collections/playlists
(define-map collection-store
  { coll-id: uint, owner: principal }
  {
    title-text: (string-utf8 100),
    description-text: (optional (string-utf8 500)),
    is-public: bool,
    created-when: uint,
    modified-when: uint,
    media-qty: uint
  }
)

;; Collection membership tracking
(define-map collection-member
  { coll-id: uint, media-id: uint }
  { when: uint }
)

;; Collection identifier generator
(define-data-var next-coll-id uint u1)

;; Cache validity window (in blocks)
(define-data-var cache-valid-duration uint u144)

;; Haversine approximation using Manhattan metric for simplicity
;; Note: In production, consider implementing precise geographic formulas
(define-private (spatial-distance 
  (loc-a {latitude: int, longitude: int}) 
  (loc-b {latitude: int, longitude: int}))
  
  (let (
    (lat-variance (if (> (get latitude loc-a) (get latitude loc-b))
      (- (get latitude loc-a) (get latitude loc-b))
      (- (get latitude loc-b) (get latitude loc-a))))
    
    (long-variance (if (> (get longitude loc-a) (get longitude loc-b))
      (- (get longitude loc-a) (get longitude loc-b))
      (- (get longitude loc-b) (get longitude loc-a))))
  )
    (+ lat-variance long-variance)
  )
)

;; Check user existence
(define-private (account-registered (account principal))
  (is-some (map-get? profile-store {account: account}))
)

;; Check media existence
(define-private (media-registered (media-id uint))
  (is-some (map-get? media-metadata {media-id: media-id}))
)

;; Check collection existence
(define-private (collection-registered (coll-id uint) (owner principal))
  (is-some (map-get? collection-store {coll-id: coll-id, owner: owner}))
)

;; Check follow relationship
(define-private (has-follow-rel (publisher principal) (follower principal))
  (is-some (map-get? follow-index {publisher: publisher, follower: follower}))
)

;; Calculate content average rating
(define-private (avg-content-score (media-id uint))
  (let (
    (data (unwrap-panic (map-get? media-metadata {media-id: media-id})))
    (total (get cumulative-rating data))
    (cnt (get evaluation-count data))
  )
    (if (is-eq cnt u0)
      u0
      (/ total cnt)
    )
  )
)

;; Verify rating bounds
(define-private (rating-is-valid (score uint))
  (and (>= score u1) (<= score u5))
)

;; Retrieve user's public profile
(define-read-only (read-profile (account principal))
  (if (account-registered account)
    (ok (unwrap-panic (map-get? profile-store {account: account})))
    PERM-DENIED
  )
)

;; Verify follower status
(define-read-only (is-follower (publisher principal) (follower principal))
  (ok (has-follow-rel publisher follower))
)

;; Read media with rating calculation
(define-read-only (read-media (media-id uint))
  (if (media-registered media-id)
    (let (
      (data (unwrap-panic (map-get? media-metadata {media-id: media-id})))
      (avg-score (avg-content-score media-id))
    )
      (ok (merge data {avg-rating: avg-score}))
    )
    MEDIA-ABSENT
  )
)

;; Fetch user's rating for content
(define-read-only (read-user-eval (account principal) (media-id uint))
  (match (map-get? user-evaluation {account: account, media-id: media-id})
    eval-data (ok (get score eval-data))
    (ok u0)
  )
)

;; Retrieve collection details
(define-read-only (read-collection (coll-id uint) (owner principal))
  (if (collection-registered coll-id owner)
    (ok (unwrap-panic (map-get? collection-store {coll-id: coll-id, owner: owner})))
    COLL-MISSING
  )
)

;; Find nearby content by geographic proximity
;; Placeholder implementation - full functionality requires indexer
(define-read-only (search-by-location 
  (location {latitude: int, longitude: int}) 
  (radius int))
  
  (ok location)
)

;; Create/update user profile
(define-public (upsert-profile
  (display-name (optional (string-utf8 50)))
  (about-text (optional (string-utf8 500)))
  (geo-coord (optional {latitude: int, longitude: int})))
  
  (let (
    (account tx-sender)
    (existing (map-get? profile-store {account: account}))
  )
    (if (is-some existing)
      ;; Merge with existing
      (map-set profile-store
        {account: account}
        (merge (unwrap-panic existing)
          {
            display-name: display-name,
            about-text: about-text,
            geo-coord: geo-coord
          })
      )
      ;; Create new
      (map-set profile-store
        {account: account}
        {
          display-name: display-name,
          about-text: about-text,
          geo-coord: geo-coord,
          follower-qty: u0,
          following-qty: u0,
          published-qty: u0
        }
      )
    )
    (ok true)
  )
)

;; Establish follow relationship
(define-public (initiate-follow (publisher principal))
  (let (
    (follower tx-sender)
  )
    (asserts! (not (is-eq publisher follower)) PERM-DENIED)
    (asserts! (account-registered publisher) USR-ABSENT)
    
    (if (has-follow-rel publisher follower)
      ALREADY-FOLLOWING
      (begin
        ;; Create follow edge
        (map-set follow-index 
          {publisher: publisher, follower: follower}
          {when: block-height}
        )
        
        ;; Update counters
        (let (
          (pub-prof (unwrap-panic (map-get? profile-store {account: publisher})))
          (foll-prof (default-to 
            {
              display-name: none, 
              about-text: none, 
              geo-coord: none,
              follower-qty: u0,
              following-qty: u0,
              published-qty: u0
            }
            (map-get? profile-store {account: follower})))
        )
          (map-set profile-store
            {account: publisher}
            (merge pub-prof {follower-qty: (+ (get follower-qty pub-prof) u1)})
          )
          
          (map-set profile-store
            {account: follower}
            (merge foll-prof {following-qty: (+ (get following-qty foll-prof) u1)})
          )
          
          (ok true)
        )
      )
    )
  )
)

;; Discontinue follow relationship
(define-public (terminate-follow (publisher principal))
  (let (
    (follower tx-sender)
  )
    (asserts! (not (is-eq publisher follower)) PERM-DENIED)
    
    (if (has-follow-rel publisher follower)
      (begin
        ;; Remove follow edge
        (map-delete follow-index {publisher: publisher, follower: follower})
        
        ;; Update counters
        (let (
          (pub-prof (unwrap-panic (map-get? profile-store {account: publisher})))
          (foll-prof (unwrap-panic (map-get? profile-store {account: follower})))
        )
          (map-set profile-store
            {account: publisher}
            (merge pub-prof {follower-qty: (- (get follower-qty pub-prof) u1)})
          )
          
          (map-set profile-store
            {account: follower}
            (merge foll-prof {following-qty: (- (get following-qty foll-prof) u1)})
          )
          
          (ok true)
        )
      )
      NOT-FOLLOWING-YET
    )
  )
)

;; Submit content evaluation
(define-public (submit-rating (media-id uint) (score uint))
  (let (
    (account tx-sender)
    (prev-eval (map-get? user-evaluation {account: account, media-id: media-id}))
  )
    ;; Validate content and rating
    (asserts! (media-registered media-id) MEDIA-ABSENT)
    (asserts! (rating-is-valid score) RATING-OUT-OF-BOUNDS)
    
    ;; Ensure one evaluation per user per content
    (if (is-some prev-eval)
      RATED-ALREADY
      (begin
        ;; Record evaluation
        (map-set user-evaluation
          {account: account, media-id: media-id}
          {score: score}
        )
        
        ;; Update aggregates
        (let (
          (data (unwrap-panic (map-get? media-metadata {media-id: media-id})))
        )
          (map-set media-metadata
            {media-id: media-id}
            (merge data 
              {
                cumulative-rating: (+ (get cumulative-rating data) score),
                evaluation-count: (+ (get evaluation-count data) u1)
              }
            )
          )
          
          (ok true)
        )
      )
    )
  )
)

;; Record playback event
(define-public (register-listen (media-id uint))
  (let (
    (account tx-sender)
  )
    (asserts! (media-registered media-id) MEDIA-ABSENT)
    
    (let (
      (data (unwrap-panic (map-get? media-metadata {media-id: media-id})))
    )
      (map-set media-metadata
        {media-id: media-id}
        (merge data {play-count: (+ (get play-count data) u1)})
      )
      
      (ok true)
    )
  )
)

;; Create new playlist
(define-public (assemble-collection 
  (title-text (string-utf8 100))
  (description-text (optional (string-utf8 500)))
  (is-public bool))
  
  (let (
    (owner tx-sender)
    (coll-id (var-get next-coll-id))
    (now block-height)
  )
    ;; Create collection record
    (map-set collection-store
      {coll-id: coll-id, owner: owner}
      {
        title-text: title-text,
        description-text: description-text,
        is-public: is-public,
        created-when: now,
        modified-when: now,
        media-qty: u0
      }
    )
    
    ;; Increment ID counter
    (var-set next-coll-id (+ coll-id u1))
    
    (ok coll-id)
  )
)

;; Add content to playlist
(define-public (append-to-collection (coll-id uint) (media-id uint))
  (let (
    (owner tx-sender)
  )
    (asserts! (collection-registered coll-id owner) COLL-MISSING)
    (asserts! (media-registered media-id) MEDIA-ABSENT)
    
    ;; Prevent duplicates
    (if (is-some (map-get? collection-member {coll-id: coll-id, media-id: media-id}))
      ALREADY-IN-COLL
      (begin
        ;; Add to collection
        (map-set collection-member
          {coll-id: coll-id, media-id: media-id}
          {when: block-height}
        )
        
        ;; Update metadata
        (let (
          (coll (unwrap-panic (map-get? collection-store {coll-id: coll-id, owner: owner})))
        )
          (map-set collection-store
            {coll-id: coll-id, owner: owner}
            (merge coll 
              {
                modified-when: block-height,
                media-qty: (+ (get media-qty coll) u1)
              }
            )
          )
          
          (ok true)
        )
      )
    )
  )
)

;; Remove content from playlist
(define-public (excise-from-collection (coll-id uint) (media-id uint))
  (let (
    (owner tx-sender)
  )
    (asserts! (collection-registered coll-id owner) COLL-MISSING)
    
    ;; Check membership
    (if (is-some (map-get? collection-member {coll-id: coll-id, media-id: media-id}))
      (begin
        ;; Remove from collection
        (map-delete collection-member {coll-id: coll-id, media-id: media-id})
        
        ;; Update metadata
        (let (
          (coll (unwrap-panic (map-get? collection-store {coll-id: coll-id, owner: owner})))
        )
          (map-set collection-store
            {coll-id: coll-id, owner: owner}
            (merge coll 
              {
                modified-when: block-height,
                media-qty: (- (get media-qty coll) u1)
              }
            )
          )
          
          (ok true)
        )
      )
      NOT-IN-COLL
    )
  )
)

;; Modify playlist visibility
(define-public (adjust-collection-access (coll-id uint) (is-public bool))
  (let (
    (owner tx-sender)
  )
    (asserts! (collection-registered coll-id owner) COLL-MISSING)
    
    (let (
      (coll (unwrap-panic (map-get? collection-store {coll-id: coll-id, owner: owner})))
    )
      (map-set collection-store
        {coll-id: coll-id, owner: owner}
        (merge coll 
          {
            is-public: is-public,
            modified-when: block-height
          }
        )
      )
      
      (ok true)
    )
  )
)