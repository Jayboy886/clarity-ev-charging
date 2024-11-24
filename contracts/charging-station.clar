;; Constants
(define-constant err-not-owner (err u100))
(define-constant err-not-available (err u101))
(define-constant err-insufficient-payment (err u102))
(define-constant err-no-active-session (err u103))
(define-constant charging-rate u10) ;; Cost per minute in microSTX

;; Data Variables
(define-data-var owner principal tx-sender)

;; Data Maps
(define-map charging-stations
    principal
    {
        location: (string-ascii 50),
        rate-per-minute: uint,
        available: bool,
        current-user: (optional principal)
    }
)

(define-map charging-sessions
    principal
    {
        station: principal,
        start-time: uint,
        paid-amount: uint
    }
)

;; Register a new charging station
(define-public (register-station (station-principal principal) (location (string-ascii 50)))
    (let
        ((caller tx-sender))
        (if (is-eq caller (var-get owner))
            (begin
                (map-set charging-stations station-principal {
                    location: location,
                    rate-per-minute: charging-rate,
                    available: true,
                    current-user: none
                })
                (ok true))
            err-not-owner)))

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
                    paid-amount: payment
                })
                (stx-transfer? payment caller (var-get owner)))
            err-not-available)))

;; End charging session
(define-public (end-charging (station principal))
    (let
        ((station-data (unwrap! (map-get? charging-stations station) err-not-available))
         (session (unwrap! (map-get? charging-sessions tx-sender) err-no-active-session))
         (duration (- block-height (get start-time session)))
         (total-cost (* duration charging-rate)))
        (if (and
                (is-eq station (get station session))
                (is-eq (some tx-sender) (get current-user station-data)))
            (begin
                (map-set charging-stations station
                    (merge station-data {
                        available: true,
                        current-user: none
                    }))
                (map-delete charging-sessions tx-sender)
                (ok total-cost))
            err-not-available)))

;; Read only functions
(define-read-only (get-station-info (station principal))
    (map-get? charging-stations station))

(define-read-only (get-session-info (user principal))
    (map-get? charging-sessions user))

(define-read-only (get-charging-rate)
    charging-rate)
