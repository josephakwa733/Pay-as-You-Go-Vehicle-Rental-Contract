(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_VEHICLE_NOT_FOUND (err u404))
(define-constant ERR_VEHICLE_NOT_AVAILABLE (err u409))
(define-constant ERR_RENTAL_NOT_FOUND (err u404))
(define-constant ERR_RENTAL_ALREADY_ENDED (err u410))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))
(define-constant ERR_INVALID_AMOUNT (err u400))

(define-data-var next-vehicle-id uint u1)
(define-data-var next-rental-id uint u1)
(define-data-var rate-per-minute uint u10)

(define-map vehicles
  { vehicle-id: uint }
  {
    owner: principal,
    vehicle-type: (string-ascii 20),
    location: (string-ascii 50),
    available: bool,
    rate-override: (optional uint)
  }
)

(define-map rentals
  { rental-id: uint }
  {
    vehicle-id: uint,
    renter: principal,
    start-block: uint,
    end-block: (optional uint),
    total-cost: (optional uint),
    paid: bool
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map active-rentals
  { vehicle-id: uint }
  { rental-id: uint }
)

(define-public (register-vehicle (vehicle-type (string-ascii 20)) (location (string-ascii 50)))
  (let
    (
      (vehicle-id (var-get next-vehicle-id))
    )
    (asserts! (> (len vehicle-type) u0) ERR_INVALID_AMOUNT)
    (asserts! (> (len location) u0) ERR_INVALID_AMOUNT)
    (map-set vehicles
      { vehicle-id: vehicle-id }
      {
        owner: tx-sender,
        vehicle-type: vehicle-type,
        location: location,
        available: true,
        rate-override: none
      }
    )
    (var-set next-vehicle-id (+ vehicle-id u1))
    (ok vehicle-id)
  )
)

(define-public (deposit-funds (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-balances
      { user: tx-sender }
      { balance: (+ (get-user-balance tx-sender) amount) }
    )
    (ok true)
  )
)

(define-public (start-rental (vehicle-id uint))
  (let
    (
      (vehicle (unwrap! (map-get? vehicles { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
      (rental-id (var-get next-rental-id))
      (current-block stacks-block-height)
    )
    (asserts! (get available vehicle) ERR_VEHICLE_NOT_AVAILABLE)
    (asserts! (is-none (map-get? active-rentals { vehicle-id: vehicle-id })) ERR_VEHICLE_NOT_AVAILABLE)
    (map-set vehicles
      { vehicle-id: vehicle-id }
      (merge vehicle { available: false })
    )
    (map-set rentals
      { rental-id: rental-id }
      {
        vehicle-id: vehicle-id,
        renter: tx-sender,
        start-block: current-block,
        end-block: none,
        total-cost: none,
        paid: false
      }
    )
    (map-set active-rentals
      { vehicle-id: vehicle-id }
      { rental-id: rental-id }
    )
    (var-set next-rental-id (+ rental-id u1))
    (ok rental-id)
  )
)

(define-public (end-rental (vehicle-id uint))
  (let
    (
      (active-rental-data (unwrap! (map-get? active-rentals { vehicle-id: vehicle-id }) ERR_RENTAL_NOT_FOUND))
      (rental-id (get rental-id active-rental-data))
      (rental (unwrap! (map-get? rentals { rental-id: rental-id }) ERR_RENTAL_NOT_FOUND))
      (vehicle (unwrap! (map-get? vehicles { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
      (current-block stacks-block-height)
      (duration (- current-block (get start-block rental)))
      (rate (default-to (var-get rate-per-minute) (get rate-override vehicle)))
      (total-cost (* duration rate))
      (user-balance (get-user-balance tx-sender))
    )
    (asserts! (is-eq (get renter rental) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (get end-block rental)) ERR_RENTAL_ALREADY_ENDED)
    (asserts! (>= user-balance total-cost) ERR_INSUFFICIENT_BALANCE)
    (map-set user-balances
      { user: tx-sender }
      { balance: (- user-balance total-cost) }
    )
    (try! (as-contract (stx-transfer? total-cost tx-sender (get owner vehicle))))
    (map-set rentals
      { rental-id: rental-id }
      (merge rental {
        end-block: (some current-block),
        total-cost: (some total-cost),
        paid: true
      })
    )
    (map-set vehicles
      { vehicle-id: vehicle-id }
      (merge vehicle { available: true })
    )
    (map-delete active-rentals { vehicle-id: vehicle-id })
    (ok total-cost)
  )
)

(define-public (emergency-end-rental (vehicle-id uint))
  (let
    (
      (active-rental-data (unwrap! (map-get? active-rentals { vehicle-id: vehicle-id }) ERR_RENTAL_NOT_FOUND))
      (rental-id (get rental-id active-rental-data))
      (rental (unwrap! (map-get? rentals { rental-id: rental-id }) ERR_RENTAL_NOT_FOUND))
      (vehicle (unwrap! (map-get? vehicles { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get owner vehicle)) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
    (map-set rentals
      { rental-id: rental-id }
      (merge rental {
        end-block: (some stacks-block-height),
        total-cost: (some u0),
        paid: true
      })
    )
    (map-set vehicles
      { vehicle-id: vehicle-id }
      (merge vehicle { available: true })
    )
    (map-delete active-rentals { vehicle-id: vehicle-id })
    (ok true)
  )
)

(define-public (update-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> new-rate u0) ERR_INVALID_AMOUNT)
    (var-set rate-per-minute new-rate)
    (ok true)
  )
)

(define-public (set-vehicle-rate (vehicle-id uint) (rate (optional uint)))
  (let
    (
      (vehicle (unwrap! (map-get? vehicles { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vehicle)) ERR_NOT_AUTHORIZED)
    (map-set vehicles
      { vehicle-id: vehicle-id }
      (merge vehicle { rate-override: rate })
    )
    (ok true)
  )
)

(define-public (withdraw-balance (amount uint))
  (let
    (
      (user-balance (get-user-balance tx-sender))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-balance amount) ERR_INSUFFICIENT_BALANCE)
    (map-set user-balances
      { user: tx-sender }
      { balance: (- user-balance amount) }
    )
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (ok true)
  )
)

(define-read-only (get-vehicle (vehicle-id uint))
  (map-get? vehicles { vehicle-id: vehicle-id })
)

(define-read-only (get-rental (rental-id uint))
  (map-get? rentals { rental-id: rental-id })
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-active-rental (vehicle-id uint))
  (map-get? active-rentals { vehicle-id: vehicle-id })
)

(define-read-only (get-current-rate)
  (var-get rate-per-minute)
)

(define-read-only (calculate-current-cost (vehicle-id uint))
  (match (map-get? active-rentals { vehicle-id: vehicle-id })
    active-rental-data
    (let
      (
        (rental-id (get rental-id active-rental-data))
        (rental (unwrap-panic (map-get? rentals { rental-id: rental-id })))
        (vehicle (unwrap-panic (map-get? vehicles { vehicle-id: vehicle-id })))
        (duration (- stacks-block-height (get start-block rental)))
        (rate (default-to (var-get rate-per-minute) (get rate-override vehicle)))
      )
      (some (* duration rate))
    )
    none
  )
)
