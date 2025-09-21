;; TrialNet Trial Registry Contract
;; A comprehensive drug trial registration and management system
;; Provides transparent, immutable recording of clinical trial data

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-TRIAL-NOT-FOUND (err u1002))
(define-constant ERR-TRIAL-ALREADY-EXISTS (err u1003))
(define-constant ERR-INVALID-PHASE (err u1004))
(define-constant ERR-INVALID-STATUS (err u1005))
(define-constant ERR-TRIAL-COMPLETED (err u1006))
(define-constant ERR-INVALID-INPUT (err u1007))

;; Trial Status Constants
(define-constant STATUS-PLANNING u0)
(define-constant STATUS-RECRUITING u1)
(define-constant STATUS-ACTIVE u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-TERMINATED u4)

;; Data Variables
(define-data-var next-trial-id uint u1)
(define-data-var total-trials uint u0)
(define-data-var active-trials uint u0)

;; Trial Data Structure
(define-map trials uint {
  title: (string-ascii 256),
  description: (string-ascii 1024),
  sponsor: (string-ascii 128),
  principal-investigator: (string-ascii 128),
  phase: uint,
  status: uint,
  start-date: uint,
  end-date: (optional uint),
  target-enrollment: uint,
  current-enrollment: uint,
  primary-endpoint: (string-ascii 512),
  secondary-endpoint: (string-ascii 512),
  created-by: principal,
  created-at: uint,
  updated-at: uint
})

;; Trial Sponsors Mapping (for authorization)
(define-map trial-sponsors uint principal)

;; Sponsor Trials Count
(define-map sponsor-trial-count principal uint)

;; Trial Events Log
(define-map trial-events uint {
  trial-id: uint,
  event-type: (string-ascii 64),
  description: (string-ascii 256),
  timestamp: uint,
  author: principal
})

(define-data-var next-event-id uint u1)

;; Public Functions

;; Register a new clinical trial
(define-public (register-trial 
    (title (string-ascii 256))
    (description (string-ascii 1024))
    (phase uint)
    (sponsor (string-ascii 128))
    (principal-investigator (string-ascii 128))
    (target-enrollment uint)
    (primary-endpoint (string-ascii 512))
    (secondary-endpoint (string-ascii 512)))
  (let ((trial-id (var-get next-trial-id))
        (current-block-height burn-block-height))
    (begin
      ;; Validate inputs
      (asserts! (and (>= phase u1) (<= phase u4)) ERR-INVALID-PHASE)
      (asserts! (> target-enrollment u0) ERR-INVALID-INPUT)
      (asserts! (> (len title) u0) ERR-INVALID-INPUT)
      (asserts! (> (len description) u0) ERR-INVALID-INPUT)
      
      ;; Create trial record
      (map-set trials trial-id {
        title: title,
        description: description,
        sponsor: sponsor,
        principal-investigator: principal-investigator,
        phase: phase,
        status: STATUS-PLANNING,
        start-date: current-block-height,
        end-date: none,
        target-enrollment: target-enrollment,
        current-enrollment: u0,
        primary-endpoint: primary-endpoint,
        secondary-endpoint: secondary-endpoint,
        created-by: tx-sender,
        created-at: current-block-height,
        updated-at: current-block-height
      })
      
      ;; Set trial sponsor
      (map-set trial-sponsors trial-id tx-sender)
      
      ;; Update sponsor trial count
      (map-set sponsor-trial-count tx-sender 
        (+ (default-to u0 (map-get? sponsor-trial-count tx-sender)) u1))
      
      ;; Log trial registration event
      (log-trial-event trial-id "TRIAL_REGISTERED" "New clinical trial registered in system")
      
      ;; Update counters
      (var-set next-trial-id (+ trial-id u1))
      (var-set total-trials (+ (var-get total-trials) u1))
      
      (ok trial-id))))

;; Update trial status
(define-public (update-trial-status (trial-id uint) (new-status uint))
  (let ((trial (unwrap! (map-get? trials trial-id) ERR-TRIAL-NOT-FOUND))
        (current-block-height burn-block-height))
    (begin
      ;; Check authorization
      (asserts! (is-eq tx-sender (unwrap! (map-get? trial-sponsors trial-id) ERR-NOT-AUTHORIZED)) ERR-NOT-AUTHORIZED)
      
      ;; Validate status
      (asserts! (<= new-status STATUS-TERMINATED) ERR-INVALID-STATUS)
      
      ;; Don't allow status changes on completed trials
      (asserts! (not (is-eq (get status trial) STATUS-COMPLETED)) ERR-TRIAL-COMPLETED)
      
      ;; Update trial status
      (map-set trials trial-id (merge trial {
        status: new-status,
        updated-at: current-block-height,
        end-date: (if (or (is-eq new-status STATUS-COMPLETED) (is-eq new-status STATUS-TERMINATED))
                     (some current-block-height)
                     (get end-date trial))
      }))
      
      ;; Update active trials counter
      (if (is-eq new-status STATUS-ACTIVE)
          (var-set active-trials (+ (var-get active-trials) u1))
          (if (and (is-eq (get status trial) STATUS-ACTIVE)
                   (or (is-eq new-status STATUS-COMPLETED) (is-eq new-status STATUS-TERMINATED)))
              (var-set active-trials (- (var-get active-trials) u1))
              false))
      
      ;; Log status change event
      (log-trial-event trial-id "STATUS_CHANGED" 
        (if (is-eq new-status STATUS-RECRUITING) "Trial now recruiting participants"
        (if (is-eq new-status STATUS-ACTIVE) "Trial is now active"
        (if (is-eq new-status STATUS-COMPLETED) "Trial completed successfully"
        (if (is-eq new-status STATUS-TERMINATED) "Trial terminated"
            "Trial status updated")))))
      
      (ok new-status))))

;; Update participant enrollment count
(define-public (update-enrollment (trial-id uint) (new-enrollment uint))
  (let ((trial (unwrap! (map-get? trials trial-id) ERR-TRIAL-NOT-FOUND)))
    (begin
      ;; Check authorization
      (asserts! (is-eq tx-sender (unwrap! (map-get? trial-sponsors trial-id) ERR-NOT-AUTHORIZED)) ERR-NOT-AUTHORIZED)
      
      ;; Validate enrollment doesn't exceed target
      (asserts! (<= new-enrollment (get target-enrollment trial)) ERR-INVALID-INPUT)
      
      ;; Update enrollment
      (map-set trials trial-id (merge trial {
        current-enrollment: new-enrollment,
        updated-at: burn-block-height
      }))
      
      ;; Log enrollment update
      (log-trial-event trial-id "ENROLLMENT_UPDATED" 
        "Participant enrollment count updated")
      
      (ok new-enrollment))))

;; Add trial milestone or note
(define-public (add-trial-note (trial-id uint) (note (string-ascii 256)))
  (let ((trial (unwrap! (map-get? trials trial-id) ERR-TRIAL-NOT-FOUND)))
    (begin
      ;; Check authorization
      (asserts! (is-eq tx-sender (unwrap! (map-get? trial-sponsors trial-id) ERR-NOT-AUTHORIZED)) ERR-NOT-AUTHORIZED)
      
      ;; Log the note as an event
      (log-trial-event trial-id "NOTE_ADDED" note)
      
      (ok true))))

;; Read-Only Functions

;; Get trial information
(define-read-only (get-trial (trial-id uint))
  (map-get? trials trial-id))

;; Get trial sponsor
(define-read-only (get-trial-sponsor (trial-id uint))
  (map-get? trial-sponsors trial-id))

;; Get trials by sponsor
(define-read-only (get-sponsor-trial-count (sponsor principal))
  (default-to u0 (map-get? sponsor-trial-count sponsor)))

;; Get system statistics
(define-read-only (get-system-stats)
  {
    total-trials: (var-get total-trials),
    active-trials: (var-get active-trials),
    next-trial-id: (var-get next-trial-id)
  })

;; Get trial enrollment progress
(define-read-only (get-enrollment-progress (trial-id uint))
  (match (map-get? trials trial-id)
    trial (ok {
      current: (get current-enrollment trial),
      target: (get target-enrollment trial),
      percentage: (if (> (get target-enrollment trial) u0)
                     (/ (* (get current-enrollment trial) u100) (get target-enrollment trial))
                     u0)
    })
    ERR-TRIAL-NOT-FOUND))

;; Check if trial is active
(define-read-only (is-trial-active (trial-id uint))
  (match (map-get? trials trial-id)
    trial (ok (is-eq (get status trial) STATUS-ACTIVE))
    ERR-TRIAL-NOT-FOUND))

;; Get trial phase name
(define-read-only (get-phase-name (phase uint))
  (if (is-eq phase u1) "Phase I"
  (if (is-eq phase u2) "Phase II"
  (if (is-eq phase u3) "Phase III"
  (if (is-eq phase u4) "Phase IV"
      "Unknown Phase")))))

;; Get status name
(define-read-only (get-status-name (status uint))
  (if (is-eq status STATUS-PLANNING) "Planning"
  (if (is-eq status STATUS-RECRUITING) "Recruiting"
  (if (is-eq status STATUS-ACTIVE) "Active"
  (if (is-eq status STATUS-COMPLETED) "Completed"
  (if (is-eq status STATUS-TERMINATED) "Terminated"
      "Unknown Status"))))))

;; Private Functions

;; Log trial events for audit trail
(define-private (log-trial-event (trial-id uint) (event-type (string-ascii 64)) (description (string-ascii 256)))
  (let ((event-id (var-get next-event-id)))
    (begin
      (map-set trial-events event-id {
        trial-id: trial-id,
        event-type: event-type,
        description: description,
        timestamp: burn-block-height,
        author: tx-sender
      })
      (var-set next-event-id (+ event-id u1))
      event-id)))

