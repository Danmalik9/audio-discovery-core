;; Monetization Layer
;; Premium content distribution with flexible payment models including one-time purchases
;; and recurring subscriptions with automatic renewal capabilities

(define-constant AUTH-FAILED (err u100))
(define-constant MEDIA-MISSING (err u101))
(define-constant ALREADY-BOUGHT (err u102))
(define-constant LOW-BALANCE (err u103))
(define-constant EXPIRED-SUB (err u104))
(define-constant NO-ACTIVE-SUB (err u105))
(define-constant INVALID-MODEL (err u106))
(define-constant REFUND-WINDOW-BAD (err u107))
(define-constant REFUND-TIMEOUT (err u108))
(define-constant PREVIOUSLY-REFUNDED (err u109))
(define-constant PRICE-INVALID (err u110))
(define-constant SUB-PERIOD-BAD (err u111))

(define-constant MODEL-UNRESTRICTED u1)
(define-constant MODEL-PURCHASE u2)
(define-constant MODEL-RECURRING u3)

;; Premium content registry - tracks all monetized entries
(define-map media-registry
  { media-id: uint }
  {
    uploader: principal,
    name: (string-ascii 100),
    model: uint,
    amount: uint,
    renewal-interval: uint,
    return-window: uint,
    deployment-block: uint
  }
)

;; Transaction records - captures individual purchase events
(define-map txn-log
  { media-id: uint, purchaser: principal }
  {
    settlement-amount: uint,
    acquired-block: uint,
    claimed-back: bool
  }
)

;; Recurring contracts - manages active subscription agreements
(define-map recurring-contracts
  { media-id: uint, subscriber: principal }
  {
    settlement-amount: uint,
    start-block: uint,
    term-end: uint,
    renew-auto: bool,
    refresh-block: uint
  }
)

;; Fee configuration in basis points (10000 = 100%)
(define-data-var fee-amount-bps uint u250)

;; Authority principal
(define-data-var authority principal tx-sender)

;; Authority check
(define-private (is-authority)
  (is-eq tx-sender (var-get authority))
)

;; Verify media uploader
(define-private (verify-uploader (media-id uint))
  (match (map-get? media-registry { media-id: media-id })
    data (is-eq tx-sender (get uploader data))
    false
  )
)

;; Fee calculation in integer arithmetic
(define-private (compute-fee-amount (total uint))
  (/ (* total (var-get fee-amount-bps)) u10000)
)

;; Creator net settlement after fees
(define-private (net-settlement (total uint))
  (- total (compute-fee-amount total))
)

;; Subscription validity check
(define-private (is-sub-valid (media-id uint) (subscriber principal))
  (match (map-get? recurring-contracts { media-id: media-id, subscriber: subscriber })
    contract (< block-height (get term-end contract))
    false
  )
)

;; Purchase history check
(define-private (has-active-purchase (media-id uint) (subscriber principal))
  (match (map-get? txn-log { media-id: media-id, purchaser: subscriber })
    tx (not (get claimed-back tx))
    false
  )
)

;; Comprehensive authorization check
(define-private (is-authorized (media-id uint) (subscriber principal))
  (match (map-get? media-registry { media-id: media-id })
    data 
      (or 
        (is-eq (get model data) MODEL-UNRESTRICTED)
        (and 
          (is-eq (get model data) MODEL-PURCHASE)
          (has-active-purchase media-id subscriber)
        )
        (and 
          (is-eq (get model data) MODEL-RECURRING)
          (is-sub-valid media-id subscriber)
        )
      )
    false
  )
)

;; Fetch media information
(define-read-only (retrieve-media (media-id uint))
  (map-get? media-registry { media-id: media-id })
)

;; Verify subscriber access
(define-read-only (may-access (media-id uint) (subscriber principal))
  (if (is-authorized media-id subscriber)
    (ok true)
    (err false)
  )
)

;; Get purchase record
(define-read-only (fetch-txn (media-id uint) (subscriber principal))
  (map-get? txn-log { media-id: media-id, purchaser: subscriber })
)

;; Get subscription record
(define-read-only (fetch-sub (media-id uint) (subscriber principal))
  (map-get? recurring-contracts { media-id: media-id, subscriber: subscriber })
)

;; Retrieve fee rate
(define-read-only (get-fee-rate)
  (var-get fee-amount-bps)
)

;; Create new media entry with pricing
(define-public (register-media 
  (media-id uint)
  (name (string-ascii 100))
  (model uint)
  (amount uint)
  (renewal-interval uint)
  (return-window uint))
  
  (let ((valid-model (or 
    (is-eq model MODEL-UNRESTRICTED)
    (is-eq model MODEL-PURCHASE)
    (is-eq model MODEL-RECURRING))))
    
    (asserts! valid-model INVALID-MODEL)
    (asserts! (or (is-eq model MODEL-UNRESTRICTED) (> amount u0)) PRICE-INVALID)
    (asserts! (or (not (is-eq model MODEL-RECURRING)) (> renewal-interval u0)) SUB-PERIOD-BAD)
    
    (map-set media-registry
      { media-id: media-id }
      {
        uploader: tx-sender,
        name: name,
        model: model,
        amount: amount,
        renewal-interval: renewal-interval,
        return-window: return-window,
        deployment-block: block-height
      }
    )
    
    (ok true)
  )
)

;; Update media configuration
(define-public (reconfigure-media
  (media-id uint)
  (name (string-ascii 100))
  (model uint)
  (amount uint)
  (renewal-interval uint)
  (return-window uint))
  
  (let ((data (unwrap! (map-get? media-registry { media-id: media-id }) MEDIA-MISSING)))
    
    (asserts! (is-eq tx-sender (get uploader data)) AUTH-FAILED)
    
    (asserts! (or 
      (is-eq model MODEL-UNRESTRICTED)
      (is-eq model MODEL-PURCHASE)
      (is-eq model MODEL-RECURRING)) 
      INVALID-MODEL)
    
    (asserts! (or (is-eq model MODEL-UNRESTRICTED) (> amount u0)) PRICE-INVALID)
    (asserts! (or (not (is-eq model MODEL-RECURRING)) (> renewal-interval u0)) SUB-PERIOD-BAD)
    
    (map-set media-registry
      { media-id: media-id }
      {
        uploader: (get uploader data),
        name: name,
        model: model,
        amount: amount,
        renewal-interval: renewal-interval,
        return-window: return-window,
        deployment-block: (get deployment-block data)
      }
    )
    
    (ok true)
  )
)

;; Execute one-time purchase
(define-public (acquire-media (media-id uint))
  (let (
    (data (unwrap! (map-get? media-registry { media-id: media-id }) MEDIA-MISSING))
    (existing-txn (map-get? txn-log { media-id: media-id, purchaser: tx-sender }))
  )
    
    (asserts! (is-eq (get model data) MODEL-PURCHASE) INVALID-MODEL)
    
    (asserts! (or 
      (is-none existing-txn) 
      (get claimed-back (default-to { claimed-back: false } existing-txn))
    ) 
    ALREADY-BOUGHT)
    
    (let (
      (price (get amount data))
      (creator (get uploader data))
      (platform-fee (compute-fee-amount price))
      (creator-net (net-settlement price))
    )
      (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
      (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get authority))))
      (try! (as-contract (stx-transfer? creator-net tx-sender creator)))
      
      (map-set txn-log
        { media-id: media-id, purchaser: tx-sender }
        {
          settlement-amount: price,
          acquired-block: block-height,
          claimed-back: false
        }
      )
      
      (ok true)
    )
  )
)

;; Establish subscription
(define-public (begin-subscription (media-id uint) (renew-auto bool))
  (let (
    (data (unwrap! (map-get? media-registry { media-id: media-id }) MEDIA-MISSING))
    (existing-sub (map-get? recurring-contracts { media-id: media-id, subscriber: tx-sender }))
  )
    
    (asserts! (is-eq (get model data) MODEL-RECURRING) INVALID-MODEL)
    
    (let (
      (price (get amount data))
      (creator (get uploader data))
      (platform-fee (compute-fee-amount price))
      (creator-net (net-settlement price))
      (blocks-per-period (* (get renewal-interval data) u144))
      (period-end (+ block-height blocks-per-period))
    )
      
      (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
      (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get authority))))
      (try! (as-contract (stx-transfer? creator-net tx-sender creator)))
      
      (map-set recurring-contracts
        { media-id: media-id, subscriber: tx-sender }
        {
          settlement-amount: price,
          start-block: block-height,
          term-end: period-end,
          renew-auto: renew-auto,
          refresh-block: block-height
        }
      )
      
      (ok true)
    )
  )
)

;; Renew existing subscription
(define-public (extend-subscription (media-id uint))
  (let (
    (data (unwrap! (map-get? media-registry { media-id: media-id }) MEDIA-MISSING))
    (sub (unwrap! (map-get? recurring-contracts { media-id: media-id, subscriber: tx-sender }) NO-ACTIVE-SUB))
  )
    
    (asserts! (is-eq (get model data) MODEL-RECURRING) INVALID-MODEL)
    
    (let (
      (price (get amount data))
      (creator (get uploader data))
      (platform-fee (compute-fee-amount price))
      (creator-net (net-settlement price))
      (blocks-per-period (* (get renewal-interval data) u144))
      (new-term-end (+ block-height blocks-per-period))
    )
      
      (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
      (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get authority))))
      (try! (as-contract (stx-transfer? creator-net tx-sender creator)))
      
      (map-set recurring-contracts
        { media-id: media-id, subscriber: tx-sender }
        {
          settlement-amount: price,
          start-block: (get start-block sub),
          term-end: new-term-end,
          renew-auto: (get renew-auto sub),
          refresh-block: block-height
        }
      )
      
      (ok true)
    )
  )
)

;; Cancel automatic renewal
(define-public (halt-auto-renewal (media-id uint))
  (let (
    (sub (unwrap! (map-get? recurring-contracts { media-id: media-id, subscriber: tx-sender }) NO-ACTIVE-SUB))
  )
    
    (map-set recurring-contracts
      { media-id: media-id, subscriber: tx-sender }
      {
        settlement-amount: (get settlement-amount sub),
        start-block: (get start-block sub),
        term-end: (get term-end sub),
        renew-auto: false,
        refresh-block: (get refresh-block sub)
      }
    )
    
    (ok true)
  )
)

;; Initiate refund request
(define-public (refund-purchase (media-id uint))
  (let (
    (data (unwrap! (map-get? media-registry { media-id: media-id }) MEDIA-MISSING))
    (txn (unwrap! (map-get? txn-log { media-id: media-id, purchaser: tx-sender }) MEDIA-MISSING))
  )
    
    (asserts! (not (get claimed-back txn)) PREVIOUSLY-REFUNDED)
    (asserts! (> (get return-window data) u0) REFUND-WINDOW-BAD)
    
    (let (
      (acq-block (get acquired-block txn))
      (refund-blocks (* (get return-window data) u6))
      (refund-cutoff (+ acq-block refund-blocks))
    )
      (asserts! (<= block-height refund-cutoff) REFUND-TIMEOUT)
      
      (let (
        (price (get settlement-amount txn))
        (creator (get uploader data))
        (platform-fee (compute-fee-amount price))
        (creator-net (net-settlement price))
      )
        (try! (as-contract (stx-transfer? price (as-contract tx-sender) tx-sender)))
        
        (map-set txn-log
          { media-id: media-id, purchaser: tx-sender }
          {
            settlement-amount: price,
            acquired-block: acq-block,
            claimed-back: true
          }
        )
        
        (ok true)
      )
    )
  )
)

;; Adjust platform fee (authority only)
(define-public (modify-fee-rate (new-bps uint))
  (begin
    (asserts! (is-authority) AUTH-FAILED)
    (asserts! (<= new-bps u1000) PRICE-INVALID)
    (var-set fee-amount-bps new-bps)
    (ok true)
  )
)

;; Transfer authority
(define-public (transfer-authority (new-authority principal))
  (begin
    (asserts! (is-authority) AUTH-FAILED)
    (var-set authority new-authority)
    (ok true)
  )
)