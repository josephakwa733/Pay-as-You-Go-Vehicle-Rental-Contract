(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_VEHICLE_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INTERVAL (err u400))
(define-constant ERR_NOT_UNDER_MAINTENANCE (err u405))

(define-data-var next-maintenance-log-id uint u1)

(define-map vehicle-maintenance-config
  { vehicle-id: uint }
  {
    owner: principal,
    maintenance-interval-blocks: uint,
    last-maintenance-block: uint,
    blocks-since-maintenance: uint,
    under-maintenance: bool
  }
)

(define-map maintenance-logs
  { log-id: uint }
  {
    vehicle-id: uint,
    maintenance-block: uint,
    technician-note: (string-ascii 100),
    blocks-serviced: uint
  }
)

(define-map vehicle-maintenance-logs
  { vehicle-id: uint }
  { log-ids: (list 50 uint) }
)

(define-public (register-vehicle-maintenance (vehicle-id uint) (interval-blocks uint))
  (begin
    (asserts! (> interval-blocks u0) ERR_INVALID_INTERVAL)
    (map-set vehicle-maintenance-config
      { vehicle-id: vehicle-id }
      {
        owner: tx-sender,
        maintenance-interval-blocks: interval-blocks,
        last-maintenance-block: stacks-block-height,
        blocks-since-maintenance: u0,
        under-maintenance: false
      }
    )
    (ok true)
  )
)

(define-public (record-usage (vehicle-id uint) (blocks-used uint))
  (let
    (
      (config (unwrap! (map-get? vehicle-maintenance-config { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner config)) ERR_NOT_AUTHORIZED)
    (map-set vehicle-maintenance-config
      { vehicle-id: vehicle-id }
      (merge config { blocks-since-maintenance: (+ (get blocks-since-maintenance config) blocks-used) })
    )
    (ok true)
  )
)

(define-public (mark-under-maintenance (vehicle-id uint))
  (let
    (
      (config (unwrap! (map-get? vehicle-maintenance-config { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner config)) ERR_NOT_AUTHORIZED)
    (map-set vehicle-maintenance-config
      { vehicle-id: vehicle-id }
      (merge config { under-maintenance: true })
    )
    (ok true)
  )
)

(define-public (complete-maintenance (vehicle-id uint) (note (string-ascii 100)))
  (let
    (
      (config (unwrap! (map-get? vehicle-maintenance-config { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
      (log-id (var-get next-maintenance-log-id))
      (current-logs (default-to (list) (get log-ids (map-get? vehicle-maintenance-logs { vehicle-id: vehicle-id }))))
    )
    (asserts! (is-eq tx-sender (get owner config)) ERR_NOT_AUTHORIZED)
    (asserts! (get under-maintenance config) ERR_NOT_UNDER_MAINTENANCE)
    (map-set maintenance-logs
      { log-id: log-id }
      {
        vehicle-id: vehicle-id,
        maintenance-block: stacks-block-height,
        technician-note: note,
        blocks-serviced: (get blocks-since-maintenance config)
      }
    )
    (map-set vehicle-maintenance-logs
      { vehicle-id: vehicle-id }
      { log-ids: (unwrap-panic (as-max-len? (append current-logs log-id) u50)) }
    )
    (map-set vehicle-maintenance-config
      { vehicle-id: vehicle-id }
      (merge config {
        last-maintenance-block: stacks-block-height,
        blocks-since-maintenance: u0,
        under-maintenance: false
      })
    )
    (var-set next-maintenance-log-id (+ log-id u1))
    (ok log-id)
  )
)

(define-read-only (get-maintenance-config (vehicle-id uint))
  (map-get? vehicle-maintenance-config { vehicle-id: vehicle-id })
)

(define-read-only (is-maintenance-due (vehicle-id uint))
  (match (map-get? vehicle-maintenance-config { vehicle-id: vehicle-id })
    config (>= (get blocks-since-maintenance config) (get maintenance-interval-blocks config))
    false
  )
)

(define-read-only (get-maintenance-log (log-id uint))
  (map-get? maintenance-logs { log-id: log-id })
)

(define-read-only (get-vehicle-logs (vehicle-id uint))
  (map-get? vehicle-maintenance-logs { vehicle-id: vehicle-id })
)
