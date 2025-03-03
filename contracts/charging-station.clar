;; Constants
(define-constant err-not-owner (err u100))
(define-constant err-not-available (err u101))
(define-constant err-insufficient-payment (err u102))
(define-constant err-no-active-session (err u103))
(define-constant err-invalid-rate (err u104))
(define-constant err-session-limit-exceeded (err u105))
(define-constant err-station-maintenance (err u106))
(define-constant err-contract-paused (err u107))

;; System Constants
(define-constant base-charging-rate u10)
(define-constant reward-rate u5)
(define-constant max-session-duration u480)
(define-constant min-rate u5)
(define-constant max-rate u50)

;; Data Variables
(define-data-var owner principal tx-sender)
(define-data-var peak-multiplier uint u20)
(define-data-var contract-paused bool false)

;; Events
(define-data-var last-event-id uint u0)

;; Enhanced Data Maps
(define-map charging-stations
    principal
    {
        location: (string-ascii 50),
        rate-per-minute: uint,
        available: bool,
        current-user: (optional principal),
        peak-hours: (list 24 bool),
        maintenance-mode: bool,
        total-sessions: uint,
        total-duration: uint
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
        lifetime-charges: uint,
        tier: uint
    }
)

;; Emergency pause functionality
(define-public (toggle-pause)
    (begin
        (asserts! (is-eq tx-sender (var-get owner)) err-not-owner)
        (ok (var-set contract-paused (not (var-get contract-paused))))
    )
)

;; Enhanced station registration with metrics
(define-public (register-station (station-principal principal) (location (string-ascii 50)) (peak-hour-list (list 24 bool)))
    (let
        ((caller tx-sender))
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-eq caller (var-get owner)) err-not-owner)
        (begin
            (map-set charging-stations station-principal {
                location: location,
                rate-per-minute: base-charging-rate,
                available: true,
                current-user: none,
                peak-hours: peak-hour-list,
                maintenance-mode: false,
                total-sessions: u0,
                total-duration: u0
            })
            (ok true)))
)

;; ... [Previous functions remain unchanged]

;; Enhanced end charging with metrics update
(define-public (end-charging (station principal))
    (let
        ((station-data (unwrap! (map-get? charging-stations station) err-not-available))
         (session (unwrap! (map-get? charging-sessions tx-sender) err-no-active-session))
         (duration (- block-height (get start-time session)))
         (rewards (if (<= duration max-session-duration)
                    (* duration reward-rate)
                    (* max-session-duration reward-rate)))
         (current-rewards (default-to { points: u0, lifetime-charges: u0, tier: u0 } 
                         (map-get? user-rewards tx-sender)))
         (new-tier (determine-tier (+ (get points current-rewards) rewards)))
         (station-metrics {
             total-sessions: (+ (get total-sessions station-data) u1),
             total-duration: (+ (get total-duration station-data) duration)
         }))
        ;; ... [Rest of the function logic]
    )
)

;; New helper functions
(define-private (determine-tier (points uint))
    (if (>= points u10000)
        u3 ;; Platinum
        (if (>= points u5000)
            u2 ;; Gold
            (if (>= points u1000)
                u1 ;; Silver
                u0)))) ;; Bronze

;; New metrics query functions
(define-read-only (get-station-metrics (station principal))
    (let ((station-data (unwrap! (map-get? charging-stations station) err-not-available)))
        (ok {
            total-sessions: (get total-sessions station-data),
            total-duration: (get total-duration station-data)
        }))
)
