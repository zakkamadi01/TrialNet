;; TrialNet Participant Tracker Contract
;; Manages participant enrollment, demographics, and safety data
;; Ensures participant privacy through anonymization

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u2001))
(define-constant ERR-PARTICIPANT-NOT-FOUND (err u2002))
(define-constant ERR-PARTICIPANT-ALREADY-EXISTS (err u2003))
(define-constant ERR-TRIAL-NOT-ACTIVE (err u2004))
(define-constant ERR-INVALID-INPUT (err u2005))
(define-constant ERR-ALREADY-WITHDRAWN (err u2006))
(define-constant ERR-INVALID-AGE (err u2007))
(define-constant ERR-ENROLLMENT-FULL (err u2008))

;; Consent Status Constants
(define-constant CONSENT-PENDING u0)
(define-constant CONSENT-GIVEN u1)
(define-constant CONSENT-WITHDRAWN u2)

;; Participant Status Constants
(define-constant STATUS-ENROLLED u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-WITHDRAWN u3)
(define-constant STATUS-EXCLUDED u4)

;; Safety Event Severity
(define-constant SEVERITY-MILD u1)
(define-constant SEVERITY-MODERATE u2)
(define-constant SEVERITY-SEVERE u3)
(define-constant SEVERITY-LIFE-THREATENING u4)

;; Data Variables
(define-data-var next-participant-id uint u1)
(define-data-var total-participants uint u0)
(define-data-var active-participants uint u0)

;; Participant Data Structure
(define-map participants (string-ascii 64) {
  trial-id: uint,
  age-group: uint,
  gender: (string-ascii 1),
  enrollment-date: uint,
  status: uint,
  consent-status: uint,
  consent-date: (optional uint),
  withdrawal-date: (optional uint),
  withdrawal-reason: (optional (string-ascii 256)),
  completed-date: (optional uint),
  enrolled-by: principal,
  last-visit: (optional uint),
  visits-completed: uint,
  total-visits-planned: uint
})

;; Trial Enrollment Tracking
(define-map trial-enrollment uint {
  current-count: uint,
  target-count: uint,
  male-count: uint,
  female-count: uint,
  age-18-30: uint,
  age-31-50: uint,
  age-51-70: uint,
  age-over-70: uint
})

;; Adverse Events Tracking
(define-map adverse-events uint {
  participant-id: (string-ascii 64),
  trial-id: uint,
  event-description: (string-ascii 512),
  severity: uint,
  onset-date: uint,
  resolution-date: (optional uint),
  related-to-study: bool,
  reported-by: principal,
  reported-at: uint
})

(define-data-var next-event-id uint u1)

;; Participant Visit Records
(define-map participant-visits uint {
  participant-id: (string-ascii 64),
  trial-id: uint,
  visit-number: uint,
  visit-date: uint,
  visit-type: (string-ascii 64),
  completion-status: bool,
  notes: (string-ascii 256),
  conducted-by: principal
})

(define-data-var next-visit-id uint u1)

;; Trial Investigators (authorized to manage participants)
(define-map trial-investigators uint principal)

;; Public Functions

;; Set trial investigator (only contract owner can do this)
(define-public (set-trial-investigator (trial-id uint) (investigator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set trial-investigators trial-id investigator)
    (ok true)))

;; Enroll a new participant
(define-public (enroll-participant 
    (participant-id (string-ascii 64))
    (trial-id uint)
    (age uint)
    (gender (string-ascii 1))
    (total-visits uint))
  (let ((current-enrollment (default-to {current-count: u0, target-count: u1000, male-count: u0, female-count: u0, 
                                        age-18-30: u0, age-31-50: u0, age-51-70: u0, age-over-70: u0} 
                                       (map-get? trial-enrollment trial-id)))
        (age-group (calculate-age-group age))
        (current-block burn-block-height))
    (begin
      ;; Check authorization
      (asserts! (or (is-eq tx-sender CONTRACT-OWNER) 
                    (is-eq tx-sender (default-to tx-sender (map-get? trial-investigators trial-id)))) 
                ERR-NOT-AUTHORIZED)
      
      ;; Validate inputs
      (asserts! (is-none (map-get? participants participant-id)) ERR-PARTICIPANT-ALREADY-EXISTS)
      (asserts! (and (>= age u18) (<= age u100)) ERR-INVALID-AGE)
      (asserts! (or (is-eq gender "M") (is-eq gender "F")) ERR-INVALID-INPUT)
      (asserts! (> total-visits u0) ERR-INVALID-INPUT)
      
      ;; Check enrollment capacity
      (asserts! (< (get current-count current-enrollment) (get target-count current-enrollment)) ERR-ENROLLMENT-FULL)
      
      ;; Create participant record
      (map-set participants participant-id {
        trial-id: trial-id,
        age-group: age-group,
        gender: gender,
        enrollment-date: current-block,
        status: STATUS-ENROLLED,
        consent-status: CONSENT-PENDING,
        consent-date: none,
        withdrawal-date: none,
        withdrawal-reason: none,
        completed-date: none,
        enrolled-by: tx-sender,
        last-visit: none,
        visits-completed: u0,
        total-visits-planned: total-visits
      })
      
      ;; Update enrollment statistics
      (map-set trial-enrollment trial-id {
        current-count: (+ (get current-count current-enrollment) u1),
        target-count: (get target-count current-enrollment),
        male-count: (if (is-eq gender "M") (+ (get male-count current-enrollment) u1) (get male-count current-enrollment)),
        female-count: (if (is-eq gender "F") (+ (get female-count current-enrollment) u1) (get female-count current-enrollment)),
        age-18-30: (if (is-eq age-group u1) (+ (get age-18-30 current-enrollment) u1) (get age-18-30 current-enrollment)),
        age-31-50: (if (is-eq age-group u2) (+ (get age-31-50 current-enrollment) u1) (get age-31-50 current-enrollment)),
        age-51-70: (if (is-eq age-group u3) (+ (get age-51-70 current-enrollment) u1) (get age-51-70 current-enrollment)),
        age-over-70: (if (is-eq age-group u4) (+ (get age-over-70 current-enrollment) u1) (get age-over-70 current-enrollment))
      })
      
      ;; Update counters
      (var-set next-participant-id (+ (var-get next-participant-id) u1))
      (var-set total-participants (+ (var-get total-participants) u1))
      
      (ok participant-id))))

;; Record participant consent
(define-public (record-consent (participant-id (string-ascii 64)) (consent-given bool))
  (let ((participant (unwrap! (map-get? participants participant-id) ERR-PARTICIPANT-NOT-FOUND)))
    (begin
      ;; Check authorization
      (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                    (is-eq tx-sender (default-to tx-sender (map-get? trial-investigators (get trial-id participant))))
                    (is-eq tx-sender (get enrolled-by participant))) 
                ERR-NOT-AUTHORIZED)
      
      ;; Update consent status
      (map-set participants participant-id (merge participant {
        consent-status: (if consent-given CONSENT-GIVEN CONSENT-WITHDRAWN),
        consent-date: (some burn-block-height),
        status: (if consent-given STATUS-ACTIVE STATUS-WITHDRAWN)
      }))
      
      ;; Update active participants counter
      (if consent-given
          (var-set active-participants (+ (var-get active-participants) u1))
          false)
      
      (ok consent-given))))

;; Withdraw participant from trial
(define-public (withdraw-participant (participant-id (string-ascii 64)) (reason (string-ascii 256)))
  (let ((participant (unwrap! (map-get? participants participant-id) ERR-PARTICIPANT-NOT-FOUND)))
    (begin
      ;; Check authorization
      (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                    (is-eq tx-sender (default-to tx-sender (map-get? trial-investigators (get trial-id participant))))
                    (is-eq tx-sender (get enrolled-by participant))) 
                ERR-NOT-AUTHORIZED)
      
      ;; Check not already withdrawn
      (asserts! (not (is-eq (get status participant) STATUS-WITHDRAWN)) ERR-ALREADY-WITHDRAWN)
      
      ;; Update participant status
      (map-set participants participant-id (merge participant {
        status: STATUS-WITHDRAWN,
        consent-status: CONSENT-WITHDRAWN,
        withdrawal-date: (some burn-block-height),
        withdrawal-reason: (some reason)
      }))
      
      ;; Update active participants counter
      (if (is-eq (get status participant) STATUS-ACTIVE)
          (var-set active-participants (- (var-get active-participants) u1))
          false)
      
      (ok true))))

;; Record participant visit
(define-public (record-visit 
    (participant-id (string-ascii 64))
    (visit-number uint)
    (visit-type (string-ascii 64))
    (completed bool)
    (notes (string-ascii 256)))
  (let ((participant (unwrap! (map-get? participants participant-id) ERR-PARTICIPANT-NOT-FOUND))
        (visit-id (var-get next-visit-id)))
    (begin
      ;; Check authorization
      (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                    (is-eq tx-sender (default-to tx-sender (map-get? trial-investigators (get trial-id participant))))) 
                ERR-NOT-AUTHORIZED)
      
      ;; Create visit record
      (map-set participant-visits visit-id {
        participant-id: participant-id,
        trial-id: (get trial-id participant),
        visit-number: visit-number,
        visit-date: burn-block-height,
        visit-type: visit-type,
        completion-status: completed,
        notes: notes,
        conducted-by: tx-sender
      })
      
      ;; Update participant's visit count and last visit
      (if completed
          (map-set participants participant-id (merge participant {
            visits-completed: (+ (get visits-completed participant) u1),
            last-visit: (some burn-block-height),
            status: (if (is-eq (+ (get visits-completed participant) u1) (get total-visits-planned participant))
                        STATUS-COMPLETED
                        (get status participant)),
            completed-date: (if (is-eq (+ (get visits-completed participant) u1) (get total-visits-planned participant))
                               (some burn-block-height)
                               (get completed-date participant))
          }))
          false)
      
      ;; Update counter
      (var-set next-visit-id (+ visit-id u1))
      
      (ok visit-id))))

;; Report adverse event
(define-public (report-adverse-event 
    (participant-id (string-ascii 64))
    (description (string-ascii 512))
    (severity uint)
    (related-to-study bool))
  (let ((participant (unwrap! (map-get? participants participant-id) ERR-PARTICIPANT-NOT-FOUND))
        (event-id (var-get next-event-id)))
    (begin
      ;; Check authorization
      (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                    (is-eq tx-sender (default-to tx-sender (map-get? trial-investigators (get trial-id participant))))) 
                ERR-NOT-AUTHORIZED)
      
      ;; Validate severity
      (asserts! (and (>= severity SEVERITY-MILD) (<= severity SEVERITY-LIFE-THREATENING)) ERR-INVALID-INPUT)
      
      ;; Create adverse event record
      (map-set adverse-events event-id {
        participant-id: participant-id,
        trial-id: (get trial-id participant),
        event-description: description,
        severity: severity,
        onset-date: burn-block-height,
        resolution-date: none,
        related-to-study: related-to-study,
        reported-by: tx-sender,
        reported-at: burn-block-height
      })
      
      ;; Update counter
      (var-set next-event-id (+ event-id u1))
      
      (ok event-id))))

;; Read-Only Functions

;; Get participant information
(define-read-only (get-participant (participant-id (string-ascii 64)))
  (map-get? participants participant-id))

;; Get trial enrollment statistics
(define-read-only (get-trial-enrollment (trial-id uint))
  (map-get? trial-enrollment trial-id))

;; Get participant visit record
(define-read-only (get-visit (visit-id uint))
  (map-get? participant-visits visit-id))

;; Get adverse event
(define-read-only (get-adverse-event (event-id uint))
  (map-get? adverse-events event-id))

;; Get system statistics
(define-read-only (get-system-stats)
  {
    total-participants: (var-get total-participants),
    active-participants: (var-get active-participants),
    next-participant-id: (var-get next-participant-id)
  })

;; Get participant completion status
(define-read-only (get-participant-progress (participant-id (string-ascii 64)))
  (match (map-get? participants participant-id)
    participant (ok {
      visits-completed: (get visits-completed participant),
      total-visits: (get total-visits-planned participant),
      completion-percentage: (if (> (get total-visits-planned participant) u0)
                               (/ (* (get visits-completed participant) u100) (get total-visits-planned participant))
                               u0)
    })
    ERR-PARTICIPANT-NOT-FOUND))

;; Check if participant is active
(define-read-only (is-participant-active (participant-id (string-ascii 64)))
  (match (map-get? participants participant-id)
    participant (ok (is-eq (get status participant) STATUS-ACTIVE))
    ERR-PARTICIPANT-NOT-FOUND))

;; Get age group name
(define-read-only (get-age-group-name (age-group uint))
  (if (is-eq age-group u1) "18-30 years"
  (if (is-eq age-group u2) "31-50 years"
  (if (is-eq age-group u3) "51-70 years"
  (if (is-eq age-group u4) "Over 70 years"
      "Unknown Age Group")))))

;; Get status name
(define-read-only (get-status-name (status uint))
  (if (is-eq status STATUS-ENROLLED) "Enrolled"
  (if (is-eq status STATUS-ACTIVE) "Active"
  (if (is-eq status STATUS-COMPLETED) "Completed"
  (if (is-eq status STATUS-WITHDRAWN) "Withdrawn"
  (if (is-eq status STATUS-EXCLUDED) "Excluded"
      "Unknown Status"))))))

;; Get severity name
(define-read-only (get-severity-name (severity uint))
  (if (is-eq severity SEVERITY-MILD) "Mild"
  (if (is-eq severity SEVERITY-MODERATE) "Moderate"
  (if (is-eq severity SEVERITY-SEVERE) "Severe"
  (if (is-eq severity SEVERITY-LIFE-THREATENING) "Life-threatening"
      "Unknown Severity")))))

;; Private Functions

;; Calculate age group based on age
(define-private (calculate-age-group (age uint))
  (if (<= age u30) u1
  (if (<= age u50) u2
  (if (<= age u70) u3
      u4))))

