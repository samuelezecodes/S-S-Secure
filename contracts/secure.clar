;; Protocol Coverage Contract

;; Define error constants with more specific messages
(define-constant ERR_INVALID_VALUE (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_REQUEST_NOT_FOUND (err u102))
(define-constant ERR_NOT_PERMITTED (err u103))
(define-constant ERR_ALREADY_COVERED (err u104))
(define-constant ERR_INVALID_USER (err u105))
(define-constant ERR_NOT_COVERED (err u106))
(define-constant ERR_ZERO_VALUE (err u107))
(define-constant ERR_REQUEST_PROCESSED (err u108))
(define-constant ERR_RESERVE_EMPTY (err u109))
(define-constant ERR_REQUEST_NOT_EXPIRED (err u110))
(define-constant ERR_REQUEST_EXCEEDS_COVERAGE (err u111))

;; Define the contract
(define-data-var coverage-reserve uint u0)
(define-data-var protocol-admin principal tx-sender)
(define-map covered-protocols principal uint)
(define-map coverage-requests { requestor: principal, value: uint } { state: (string-ascii 20), block: uint, processed-value: uint })

;; Define the request expiration period (e.g., 30 days in blocks, assuming 10-minute block times)
(define-constant REQUEST_EXPIRATION_PERIOD u4320)

;; Function to acquire coverage
(define-public (acquire-coverage (value uint))
  (let ((user tx-sender))
    (asserts! (> value u0) ERR_ZERO_VALUE)
    (asserts! (is-none (map-get? covered-protocols user)) ERR_ALREADY_COVERED)
    (match (stx-transfer? value user (as-contract tx-sender))
      success (begin
        (var-set coverage-reserve (+ (var-get coverage-reserve) value))
        (map-set covered-protocols user value)
        (print { event: "coverage-acquired", covered-value: value, user: user })
        (ok true))
      error (err error))))

;; Function to submit request
(define-public (submit-request (request-value uint))
  (let (
    (user tx-sender)
    (covered-value (default-to u0 (map-get? covered-protocols user)))
  )
    (asserts! (> request-value u0) ERR_ZERO_VALUE)
    (asserts! (is-some (map-get? covered-protocols user)) ERR_NOT_COVERED)
    (asserts! (>= covered-value request-value) ERR_INSUFFICIENT_BALANCE)
    (asserts! (is-none (map-get? coverage-requests { requestor: user, value: request-value })) ERR_REQUEST_PROCESSED)
    (map-set coverage-requests { requestor: user, value: request-value } { state: "pending", block: block-height, processed-value: u0 })
    (print { event: "request-submitted", requestor: user, request-value: request-value, block: block-height })
    (ok true)))

;; Helper function to calculate payout value
(define-private (calculate-payout-value (request-value uint) (reserve-balance uint))
  (if (>= reserve-balance request-value)
      request-value
      reserve-balance))

;; Function to approve and process request
(define-public (approve-request (requestor principal) (request-value uint))
  (let (
    (request-key { requestor: requestor, value: request-value })
    (request-data (unwrap! (map-get? coverage-requests request-key) ERR_REQUEST_NOT_FOUND))
    (reserve-balance (var-get coverage-reserve))
    (covered-value (unwrap! (map-get? covered-protocols requestor) ERR_NOT_COVERED))
  )
    (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR_NOT_PERMITTED)
    (asserts! (is-eq (get state request-data) "pending") ERR_REQUEST_PROCESSED)
    (asserts! (> reserve-balance u0) ERR_RESERVE_EMPTY)
    (asserts! (<= request-value covered-value) ERR_REQUEST_EXCEEDS_COVERAGE)
    (asserts! (< (- block-height (get block request-data)) REQUEST_EXPIRATION_PERIOD) ERR_REQUEST_NOT_EXPIRED)
    (let ((payout-value (calculate-payout-value request-value reserve-balance)))
      (match (as-contract (stx-transfer? payout-value tx-sender requestor))
        success (begin
          (var-set coverage-reserve (- reserve-balance payout-value))
          (if (< payout-value request-value)
              (map-set coverage-requests request-key { state: "partial", block: block-height, processed-value: payout-value })
              (begin
                (map-delete coverage-requests request-key)
                (map-delete covered-protocols requestor)))
          (print { event: "request-approved", requestor: requestor, request-value: request-value, payout-value: payout-value })
          (ok payout-value))
        error (err error)))))

;; Function to decline request
(define-public (decline-request (requestor principal) (request-value uint))
  (let (
    (request-key { requestor: requestor, value: request-value })
    (request-data (unwrap! (map-get? coverage-requests request-key) ERR_REQUEST_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR_NOT_PERMITTED)
    (asserts! (is-eq (get state request-data) "pending") ERR_REQUEST_PROCESSED)
    (asserts! (< (- block-height (get block request-data)) REQUEST_EXPIRATION_PERIOD) ERR_REQUEST_NOT_EXPIRED)
    (map-set coverage-requests request-key { state: "declined", block: (get block request-data), processed-value: u0 })
    (print { event: "request-declined", requestor: requestor, request-value: request-value })
    (ok true)))

;; Function to check and expire request
(define-public (check-and-expire-request (requestor principal) (request-value uint))
  (let (
    (request-key { requestor: requestor, value: request-value })
    (request-data (unwrap! (map-get? coverage-requests request-key) ERR_REQUEST_NOT_FOUND))
  )
    (if (and (is-eq (get state request-data) "pending")
             (>= (- block-height (get block request-data)) REQUEST_EXPIRATION_PERIOD))
        (begin
          (map-set coverage-requests request-key { state: "expired", block: (get block request-data), processed-value: u0 })
          (print { event: "request-expired", requestor: requestor, request-value: request-value })
          (ok true))
        (ok false))))

;; Function to update admin
(define-public (update-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR_NOT_PERMITTED)
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) ERR_INVALID_USER)
    (print { event: "admin-updated", old-admin: (var-get protocol-admin), new-admin: new-admin })
    (ok (var-set protocol-admin new-admin))))

;; Function to get current reserve balance
(define-read-only (get-reserve-balance)
  (ok (var-get coverage-reserve)))

;; Function to check if protocol is covered
(define-read-only (is-covered (protocol principal))
  (is-some (map-get? covered-protocols protocol)))

;; Function to get covered amount
(define-read-only (get-covered-amount (protocol principal))
  (ok (default-to u0 (map-get? covered-protocols protocol))))

;; Function to get request status
(define-read-only (get-request-status (requestor principal) (request-value uint))
  (match (map-get? coverage-requests { requestor: requestor, value: request-value })
    request-data (ok { state: (get state request-data), block: (get block request-data), processed-value: (get processed-value request-data) })
    ERR_REQUEST_NOT_FOUND))