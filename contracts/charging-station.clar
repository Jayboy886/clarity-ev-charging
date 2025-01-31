;; Constants
(define-constant err-not-owner (err u100))
(define-constant err-not-available (err u101))
(define-constant err-insufficient-payment (err u102))
(define-constant err-no-active-session (err u103))
(define-constant err-invalid-rate (err u104))
(define-constant base-charging-rate u10) ;; Base cost per minute in microSTX
(define-constant reward-rate u5) ;; Reward points earned per minute

;; Data Variables
(define-data-var owner principal tx-sender)
(define-data-var peak-multiplier uint u20) ;; 2x multiplier stored as u20 (2.0)

;; Data Maps
(define-map charging-stations
    principal
    {
        location: (string-ascii 50),
        rate-per-minute: uint,
        available: bool,
        current-user: (optional principal),
        peak-hours: (list 24 bool)
    }
)

(define-map charging-sessions
    principal
    {
        station: principal,
        start-time: uint,
        paid-amount: uint,
        rewards-earned: uint
    }
)

(define-map user-rewards
    principal
    {
        points: uint,
        lifetime-charges: uint
    }
)

;; Register a new charging station
(define-public (register-station (station-principal principal) (location (string-ascii 50)) (peak-hour-list (list 24 bool)))
    (let
        ((caller tx-sender))
        (if (is-eq caller (var-get owner))
            (begin
                (map-set charging-stations station-principal {
                    location: location,
                    rate-per-minute: base-charging-rate,
                    available: true,
                    current-user: none,
                    peak-hours: peak-hour-list
                })
                (ok true))
            err-not-owner)))

;; Update station rate
(define-public (update-station-rate (station principal) (new-rate uint))
    (let
        ((caller tx-sender))
        (if (and
                (is-eq caller (var-get owner))
                (> new-rate u0))
            (begin
                (map-set charging-stations station
                    (merge (unwrap! (map-get? charging-stations station) err-not-available)
                        { rate-per-minute: new-rate }))
                (ok true))
            err-invalid-rate)))

;; Start charging session
(define-public (start-charging (station principal) (payment uint))
    (let
        ((station-data (unwrap! (map-get? charging-stations station) err-not-available))
         (caller tx-sender))
        (if (get available station-data)
            (begin
                (map-set charging-stations station
                    (merge station-data {
                        available: false,
                        current-user: (some caller)
                    }))
                (map-set charging-sessions caller {
                    station: station,
                    start-time: block-height,
                    paid-amount: payment,
                    rewards-earned: u0
                })
                (stx-transfer? payment caller (var-get owner)))
            err-not-available)))

;; End charging session with rewards
(define-public (end-charging (station principal))
    (let
        ((station-data (unwrap! (map-get? charging-stations station) err-not-available))
         (session (unwrap! (map-get? charging-sessions tx-sender) err-no-active-session))
         (duration (- block-height (get start-time session)))
         (rewards (* duration reward-rate))
         (current-rewards (default-to { points: u0, lifetime-charges: u0 } 
                          (map-get? user-rewards tx-sender)))
         (peak-rate (if (is-peak-hour) 
                      (/ (* (var-get peak-multiplier) base-charging-rate) u10)
                      base-charging-rate))
         (total-cost (* duration peak-rate)))
        (if (and
                (is-eq station (get station session))
                (is-eq (some tx-sender) (get current-user station-data)))
            (begin
                (map-set charging-stations station
                    (merge station-data {
                        available: true,
                        current-user: none
                    }))
                (map-set user-rewards tx-sender {
                    points: (+ (get points current-rewards) rewards),
                    lifetime-charges: (+ (get lifetime-charges current-rewards) u1)
                })
                (map-delete charging-sessions tx-sender)
                (ok {total-cost: total-cost, rewards-earned: rewards}))
            err-not-available)))

;; Read only functions
(define-read-only (get-station-info (station principal))
    (map-get? charging-stations station))

(define-read-only (get-session-info (user principal))
    (map-get? charging-sessions user))
    
(define-read-only (get-user-rewards (user principal))
    (map-get? user-rewards user))
    
(define-read-only (get-base-rate)
    base-charging-rate)
    
(define-read-only (get-peak-multiplier)
    (var-get peak-multiplier))
    
;; Helper function to check if current block time is peak hour
(define-private (is-peak-hour)
    (let ((current-hour (mod block-height u24)))
        (unwrap-panic (element-at (get peak-hours 
            (unwrap-panic (map-get? charging-stations tx-sender))) current-hour))))
