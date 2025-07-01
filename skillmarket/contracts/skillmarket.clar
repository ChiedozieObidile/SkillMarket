;; SkillMarket - Merit-Based Professional Network
;; A decentralized ecosystem for professional reputation tracking with community arbitration

;; Constants
(define-constant ADMIN_ADDRESS tx-sender)
(define-constant ERROR_ACCESS_DENIED (err u100))
(define-constant ERROR_RECORD_MISSING (err u101))
(define-constant ERROR_INVALID_VALUE (err u102))
(define-constant ERROR_DUPLICATE_ENTRY (err u103))
(define-constant ERROR_INVALID_STATE (err u104))
(define-constant ERROR_INSUFFICIENT_DEPOSIT (err u105))
(define-constant ERROR_DEADLINE_PASSED (err u106))

;; Configuration Variables
(define-data-var minimum-arbitrator-deposit uint u1000000) ;; 1 STX minimum
(define-data-var arbitration-window uint u1008) ;; ~7 days in blocks
(define-data-var arbitrator-compensation-rate uint u10) ;; 10%

;; Data Storage Maps
(define-map service-provider-records
  principal
  {
    credibility-rating: uint,
    finished-assignments: uint,
    cumulative-revenue: uint,
    arbitrations-won: uint,
    arbitrations-lost: uint,
    account-enabled: bool
  }
)

(define-map service-buyer-records
  principal
  {
    assignments-created: uint,
    cumulative-expenditure: uint,
    credibility-rating: uint,
    account-enabled: bool
  }
)

(define-map assignment-agreements
  uint
  {
    buyer: principal,
    provider: principal,
    payment-amount: uint,
    work-description: (string-ascii 500),
    current-state: (string-ascii 20), ;; "awaiting", "in-progress", "finished", "under-arbitration"
    initiation-block: uint,
    completion-block: (optional uint),
    arbitration-start-block: (optional uint)
  }
)

(define-map assignment-feedback
  uint
  {
    buyer-score: uint,
    provider-score: uint,
    buyer-comments: (string-ascii 500),
    provider-comments: (string-ascii 500),
    feedback-timestamp: uint
  }
)

(define-map arbitration-cases
  uint
  {
    assignment-reference: uint,
    case-opener: principal,
    dispute-explanation: (string-ascii 500),
    case-status: (string-ascii 20), ;; "accepting", "deliberating", "concluded"
    case-start-block: uint,
    decision-deadline: uint,
    arbitrator-panel: (list 5 principal),
    buyer-support-votes: uint,
    provider-support-votes: uint,
    winning-party: (optional principal)
  }
)

(define-map arbitrator-deposits
  { case-reference: uint, arbitrator: principal }
  { deposit-amount: uint, decision: (optional bool) } ;; true = buyer, false = provider
)

;; Sequential ID Counters
(define-data-var next-assignment-reference uint u1)
(define-data-var next-case-reference uint u1)

;; Public Interface Functions

;; Enroll as service provider
(define-public (enroll-as-provider)
  (let ((applicant tx-sender))
    (asserts! (is-none (map-get? service-provider-records applicant)) ERROR_DUPLICATE_ENTRY)
    (ok (map-set service-provider-records applicant {
      credibility-rating: u100,
      finished-assignments: u0,
      cumulative-revenue: u0,
      arbitrations-won: u0,
      arbitrations-lost: u0,
      account-enabled: true
    }))
  )
)

;; Enroll as service buyer
(define-public (enroll-as-buyer)
  (let ((applicant tx-sender))
    (asserts! (is-none (map-get? service-buyer-records applicant)) ERROR_DUPLICATE_ENTRY)
    (ok (map-set service-buyer-records applicant {
      assignments-created: u0,
      cumulative-expenditure: u0,
      credibility-rating: u100,
      account-enabled: true
    }))
  )
)

;; Establish assignment agreement
(define-public (establish-assignment (provider principal) (payment-amount uint) (work-description (string-ascii 500)))
  (let (
    (assignment-reference (var-get next-assignment-reference))
    (requester tx-sender)
  )
    (asserts! (> payment-amount u0) ERROR_INVALID_VALUE)
    (asserts! (is-some (map-get? service-buyer-records requester)) ERROR_ACCESS_DENIED)
    (asserts! (is-some (map-get? service-provider-records provider)) ERROR_RECORD_MISSING)
    
    ;; Lock payment in escrow
    (try! (stx-transfer? payment-amount requester (as-contract tx-sender)))
    
    ;; Create assignment record
    (map-set assignment-agreements assignment-reference {
      buyer: requester,
      provider: provider,
      payment-amount: payment-amount,
      work-description: work-description,
      current-state: "awaiting",
      initiation-block: block-height,
      completion-block: none,
      arbitration-start-block: none
    })
    
    ;; Update buyer statistics
    (match (map-get? service-buyer-records requester)
      buyer-data (map-set service-buyer-records requester (merge buyer-data {
        assignments-created: (+ (get assignments-created buyer-data) u1)
      }))
      false
    )
    
    ;; Advance assignment counter
    (var-set next-assignment-reference (+ assignment-reference u1))
    (ok assignment-reference)
  )
)

;; Confirm assignment acceptance (provider)
(define-public (confirm-assignment (assignment-reference uint))
  (let (
    (confirmer tx-sender)
    (assignment-data (unwrap! (map-get? assignment-agreements assignment-reference) ERROR_RECORD_MISSING))
  )
    (asserts! (is-eq confirmer (get provider assignment-data)) ERROR_ACCESS_DENIED)
    (asserts! (is-eq (get current-state assignment-data) "awaiting") ERROR_INVALID_STATE)
    
    (ok (map-set assignment-agreements assignment-reference (merge assignment-data {
      current-state: "in-progress"
    })))
  )
)

;; Finalize assignment and disburse payment
(define-public (finalize-assignment (assignment-reference uint))
  (let (
    (finalizer tx-sender)
    (assignment-data (unwrap! (map-get? assignment-agreements assignment-reference) ERROR_RECORD_MISSING))
    (provider (get provider assignment-data))
    (payment-amount (get payment-amount assignment-data))
  )
    (asserts! (is-eq finalizer (get buyer assignment-data)) ERROR_ACCESS_DENIED)
    (asserts! (is-eq (get current-state assignment-data) "in-progress") ERROR_INVALID_STATE)
    
    ;; Transfer payment to provider
    (try! (as-contract (stx-transfer? payment-amount tx-sender provider)))
    
    ;; Mark assignment as completed
    (map-set assignment-agreements assignment-reference (merge assignment-data {
      current-state: "finished",
      completion-block: (some block-height)
    }))
    
    ;; Update provider statistics
    (match (map-get? service-provider-records provider)
      provider-data (map-set service-provider-records provider (merge provider-data {
        finished-assignments: (+ (get finished-assignments provider-data) u1),
        cumulative-revenue: (+ (get cumulative-revenue provider-data) payment-amount),
        credibility-rating: (+ (get credibility-rating provider-data) u5)
      }))
      false
    )
    
    ;; Update buyer expenditure statistics
    (match (map-get? service-buyer-records finalizer)
      buyer-data (map-set service-buyer-records finalizer (merge buyer-data {
        cumulative-expenditure: (+ (get cumulative-expenditure buyer-data) payment-amount)
      }))
      false
    )
    
    (ok true)
  )
)

;; Record performance feedback
(define-public (record-feedback (assignment-reference uint) (performance-score uint) (written-feedback (string-ascii 500)))
  (let (
    (reviewer tx-sender)
    (assignment-data (unwrap! (map-get? assignment-agreements assignment-reference) ERROR_RECORD_MISSING))
  )
    (asserts! (is-eq (get current-state assignment-data) "finished") ERROR_INVALID_STATE)
    (asserts! (and (>= performance-score u1) (<= performance-score u5)) ERROR_INVALID_VALUE)
    (asserts! (or (is-eq reviewer (get buyer assignment-data)) 
                  (is-eq reviewer (get provider assignment-data))) ERROR_ACCESS_DENIED)
    
    (let ((current-feedback (map-get? assignment-feedback assignment-reference)))
      (if (is-some current-feedback)
        ;; Modify existing feedback entry
        (let ((feedback-data (unwrap-panic current-feedback)))
          (if (is-eq reviewer (get buyer assignment-data))
            ;; Buyer feedback update
            (ok (map-set assignment-feedback assignment-reference (merge feedback-data {
              buyer-score: performance-score,
              buyer-comments: written-feedback
            })))
            ;; Provider feedback update
            (ok (map-set assignment-feedback assignment-reference (merge feedback-data {
              provider-score: performance-score,
              provider-comments: written-feedback
            })))
          )
        )
        ;; Initialize new feedback entry
        (if (is-eq reviewer (get buyer assignment-data))
          ;; Buyer initiating feedback
          (ok (map-set assignment-feedback assignment-reference {
            buyer-score: performance-score,
            provider-score: u0,
            buyer-comments: written-feedback,
            provider-comments: "",
            feedback-timestamp: block-height
          }))
          ;; Provider initiating feedback
          (ok (map-set assignment-feedback assignment-reference {
            buyer-score: u0,
            provider-score: performance-score,
            buyer-comments: "",
            provider-comments: written-feedback,
            feedback-timestamp: block-height
          }))
        )
      )
    )
  )
)

;; Open arbitration case
(define-public (open-arbitration-case (assignment-reference uint) (dispute-explanation (string-ascii 500)))
  (let (
    (case-opener tx-sender)
    (assignment-data (unwrap! (map-get? assignment-agreements assignment-reference) ERROR_RECORD_MISSING))
    (case-reference (var-get next-case-reference))
  )
    (asserts! (or (is-eq case-opener (get buyer assignment-data)) 
                  (is-eq case-opener (get provider assignment-data))) ERROR_ACCESS_DENIED)
    (asserts! (is-eq (get current-state assignment-data) "in-progress") ERROR_INVALID_STATE)
    
    ;; Change assignment to arbitration status
    (map-set assignment-agreements assignment-reference (merge assignment-data {
      current-state: "under-arbitration",
      arbitration-start-block: (some block-height)
    }))
    
    ;; Initialize arbitration case
    (map-set arbitration-cases case-reference {
      assignment-reference: assignment-reference,
      case-opener: case-opener,
      dispute-explanation: dispute-explanation,
      case-status: "accepting",
      case-start-block: block-height,
      decision-deadline: (+ block-height (var-get arbitration-window)),
      arbitrator-panel: (list),
      buyer-support-votes: u0,
      provider-support-votes: u0,
      winning-party: none
    })
    
    (var-set next-case-reference (+ case-reference u1))
    (ok case-reference)
  )
)

;; Become arbitrator for case (requires deposit)
(define-public (become-arbitrator (case-reference uint))
  (let (
    (volunteer tx-sender)
    (case-data (unwrap! (map-get? arbitration-cases case-reference) ERROR_RECORD_MISSING))
    (required-deposit (var-get minimum-arbitrator-deposit))
  )
    (asserts! (is-eq (get case-status case-data) "accepting") ERROR_INVALID_STATE)
    (asserts! (< (len (get arbitrator-panel case-data)) u5) ERROR_INVALID_STATE)
    
    ;; Lock arbitrator deposit
    (try! (stx-transfer? required-deposit volunteer (as-contract tx-sender)))
    
    ;; Add to arbitrator panel
    (map-set arbitration-cases case-reference (merge case-data {
      arbitrator-panel: (unwrap! (as-max-len? (append (get arbitrator-panel case-data) volunteer) u5) ERROR_INVALID_STATE),
      case-status: (if (is-eq (+ (len (get arbitrator-panel case-data)) u1) u5) "deliberating" "accepting")
    }))
    
    ;; Document deposit
    (map-set arbitrator-deposits { case-reference: case-reference, arbitrator: volunteer } {
      deposit-amount: required-deposit,
      decision: none
    })
    
    (ok true)
  )
)

;; Submit arbitration decision
(define-public (submit-arbitration-decision (case-reference uint) (support-buyer bool))
  (let (
    (arbitrator tx-sender)
    (case-data (unwrap! (map-get? arbitration-cases case-reference) ERROR_RECORD_MISSING))
    (deposit-data (unwrap! (map-get? arbitrator-deposits { case-reference: case-reference, arbitrator: arbitrator }) ERROR_ACCESS_DENIED))
  )
    (asserts! (is-eq (get case-status case-data) "deliberating") ERROR_INVALID_STATE)
    (asserts! (< block-height (get decision-deadline case-data)) ERROR_DEADLINE_PASSED)
    (asserts! (is-none (get decision deposit-data)) ERROR_DUPLICATE_ENTRY)
    
    ;; Log arbitrator decision
    (map-set arbitrator-deposits { case-reference: case-reference, arbitrator: arbitrator } (merge deposit-data {
      decision: (some support-buyer)
    }))
    
    ;; Tally votes
    (if support-buyer
      (map-set arbitration-cases case-reference (merge case-data {
        buyer-support-votes: (+ (get buyer-support-votes case-data) u1)
      }))
      (map-set arbitration-cases case-reference (merge case-data {
        provider-support-votes: (+ (get provider-support-votes case-data) u1)
      }))
    )
    
    (ok true)
  )
)

;; Query Functions

(define-read-only (get-provider-profile (provider principal))
  (map-get? service-provider-records provider)
)

(define-read-only (get-buyer-profile (buyer principal))
  (map-get? service-buyer-records buyer)
)

(define-read-only (get-assignment-details (assignment-reference uint))
  (map-get? assignment-agreements assignment-reference)
)

(define-read-only (get-assignment-feedback (assignment-reference uint))
  (map-get? assignment-feedback assignment-reference)
)

(define-read-only (get-arbitration-case (case-reference uint))
  (map-get? arbitration-cases case-reference)
)

(define-read-only (get-current-assignment-id)
  (var-get next-assignment-reference)
)

(define-read-only (get-current-case-id)
  (var-get next-case-reference)
)