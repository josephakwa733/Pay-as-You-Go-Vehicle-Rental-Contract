(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_INVALID_TIER (err u400))

(define-constant BRONZE_THRESHOLD u5)
(define-constant SILVER_THRESHOLD u15)
(define-constant GOLD_THRESHOLD u30)

(define-constant BRONZE_DISCOUNT u5)
(define-constant SILVER_DISCOUNT u10)
(define-constant GOLD_DISCOUNT u15)

(define-map user-loyalty-stats
  { user: principal }
  {
    total-rentals: uint,
    current-tier: uint,
    total-points: uint
  }
)

(define-public (record-rental-completion (renter principal) (cost uint))
  (let
    (
      (current-stats (default-to 
        { total-rentals: u0, current-tier: u0, total-points: u0 }
        (map-get? user-loyalty-stats { user: renter })
      ))
      (new-rental-count (+ (get total-rentals current-stats) u1))
      (points-earned (/ cost u10))
      (new-points (+ (get total-points current-stats) points-earned))
      (new-tier (calculate-tier new-rental-count))
    )
    (map-set user-loyalty-stats
      { user: renter }
      {
        total-rentals: new-rental-count,
        current-tier: new-tier,
        total-points: new-points
      }
    )
    (ok new-tier)
  )
)

(define-public (apply-loyalty-discount (base-cost uint) (user principal))
  (let
    (
      (user-stats (map-get? user-loyalty-stats { user: user }))
      (tier (default-to u0 (get current-tier user-stats)))
      (discount-percent (get-discount-for-tier tier))
      (discount-amount (/ (* base-cost discount-percent) u100))
    )
    (ok (- base-cost discount-amount))
  )
)

(define-read-only (calculate-tier (rental-count uint))
  (if (>= rental-count GOLD_THRESHOLD)
    u3
    (if (>= rental-count SILVER_THRESHOLD)
      u2
      (if (>= rental-count BRONZE_THRESHOLD)
        u1
        u0
      )
    )
  )
)

(define-read-only (get-discount-for-tier (tier uint))
  (if (is-eq tier u3)
    GOLD_DISCOUNT
    (if (is-eq tier u2)
      SILVER_DISCOUNT
      (if (is-eq tier u1)
        BRONZE_DISCOUNT
        u0
      )
    )
  )
)

(define-read-only (get-user-loyalty-stats (user principal))
  (map-get? user-loyalty-stats { user: user })
)

(define-read-only (get-tier-name (tier uint))
  (if (is-eq tier u3)
    "Gold"
    (if (is-eq tier u2)
      "Silver" 
      (if (is-eq tier u1)
        "Bronze"
        "Basic"
      )
    )
  )
)
