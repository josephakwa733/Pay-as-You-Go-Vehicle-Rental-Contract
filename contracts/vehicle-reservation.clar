(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_VEHICLE_NOT_FOUND (err u404))
(define-constant ERR_RESERVATION_NOT_FOUND (err u404))
(define-constant ERR_RESERVATION_EXISTS (err u409))
(define-constant ERR_RESERVATION_EXPIRED (err u410))
(define-constant ERR_INVALID_WINDOW (err u400))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u402))

(define-constant RESERVATION_FEE u50)
(define-constant MIN_RESERVATION_BLOCKS u10)
(define-constant MAX_RESERVATION_BLOCKS u1440)

(define-data-var next-reservation-id uint u1)

(define-map reservations
  { reservation-id: uint }
  {
    vehicle-id: uint,
    reserver: principal,
    start-block: uint,
    end-block: uint,
    fee-paid: uint,
    claimed: bool,
    cancelled: bool
  }
)

(define-map active-vehicle-reservations
  { vehicle-id: uint }
  { reservation-id: uint }
)

(define-public (reserve-vehicle (vehicle-id uint) (duration-blocks uint))
  (let
    (
      (reservation-id (var-get next-reservation-id))
      (current-block stacks-block-height)
      (end-block (+ current-block duration-blocks))
    )
    (asserts! (>= duration-blocks MIN_RESERVATION_BLOCKS) ERR_INVALID_WINDOW)
    (asserts! (<= duration-blocks MAX_RESERVATION_BLOCKS) ERR_INVALID_WINDOW)
    (asserts! (is-none (map-get? active-vehicle-reservations { vehicle-id: vehicle-id })) ERR_RESERVATION_EXISTS)
    (try! (stx-transfer? RESERVATION_FEE tx-sender (as-contract tx-sender)))
    (map-set reservations
      { reservation-id: reservation-id }
      {
        vehicle-id: vehicle-id,
        reserver: tx-sender,
        start-block: current-block,
        end-block: end-block,
        fee-paid: RESERVATION_FEE,
        claimed: false,
        cancelled: false
      }
    )
    (map-set active-vehicle-reservations
      { vehicle-id: vehicle-id }
      { reservation-id: reservation-id }
    )
    (var-set next-reservation-id (+ reservation-id u1))
    (ok reservation-id)
  )
)

(define-public (claim-reservation (vehicle-id uint))
  (let
    (
      (active-res (unwrap! (map-get? active-vehicle-reservations { vehicle-id: vehicle-id }) ERR_RESERVATION_NOT_FOUND))
      (reservation-id (get reservation-id active-res))
      (reservation (unwrap! (map-get? reservations { reservation-id: reservation-id }) ERR_RESERVATION_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get reserver reservation)) ERR_NOT_AUTHORIZED)
    (asserts! (<= current-block (get end-block reservation)) ERR_RESERVATION_EXPIRED)
    (map-set reservations
      { reservation-id: reservation-id }
      (merge reservation { claimed: true })
    )
    (map-delete active-vehicle-reservations { vehicle-id: vehicle-id })
    (try! (as-contract (stx-transfer? (get fee-paid reservation) tx-sender tx-sender)))
    (ok true)
  )
)

(define-public (cancel-expired-reservation (vehicle-id uint) (owner-address principal))
  (let
    (
      (active-res (unwrap! (map-get? active-vehicle-reservations { vehicle-id: vehicle-id }) ERR_RESERVATION_NOT_FOUND))
      (reservation-id (get reservation-id active-res))
      (reservation (unwrap! (map-get? reservations { reservation-id: reservation-id }) ERR_RESERVATION_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (> current-block (get end-block reservation)) ERR_RESERVATION_EXPIRED)
    (map-set reservations
      { reservation-id: reservation-id }
      (merge reservation { cancelled: true })
    )
    (map-delete active-vehicle-reservations { vehicle-id: vehicle-id })
    (try! (as-contract (stx-transfer? (get fee-paid reservation) tx-sender owner-address)))
    (ok true)
  )
)

(define-read-only (get-reservation (reservation-id uint))
  (map-get? reservations { reservation-id: reservation-id })
)

(define-read-only (get-active-reservation (vehicle-id uint))
  (map-get? active-vehicle-reservations { vehicle-id: vehicle-id })
)

(define-read-only (is-vehicle-reserved (vehicle-id uint))
  (is-some (map-get? active-vehicle-reservations { vehicle-id: vehicle-id }))
)

(define-read-only (get-reservation-fee)
  RESERVATION_FEE
)