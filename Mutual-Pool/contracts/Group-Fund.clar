;; Decentralized Mutual Insurance Protocol Smart Contract
;; A blockchain-based mutual insurance platform where community members stake tokens
;; to build a collective insurance fund, earn proportional rewards on their stakes,
;; and receive coverage through transparent claim processing. The protocol ensures
;; stability through time-locked stakes and democratic governance mechanisms.

;; PROTOCOL CONSTANTS & PARAMETERS

;; Core protocol governance
(define-constant contract-admin tx-sender)
(define-constant min-stake-amount u1000000) ;; 1 STX minimum stake
(define-constant stake-lockup-period u144) ;; ~24 hours lockup period
(define-constant max-claim-amount u100000000) ;; 100 STX maximum claim
(define-constant max-annual-yield-rate u1000) ;; 10% max yield (basis points)
(define-constant min-claim-description-length u5) ;; Minimum description chars

;; Protocol error definitions
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-MEMBER-NOT-FOUND (err u102))
(define-constant ERR-CLAIM-ALREADY-PROCESSED (err u103))
(define-constant ERR-CLAIM-REJECTED (err u104))
(define-constant ERR-STAKE-BELOW-MINIMUM (err u105))
(define-constant ERR-STAKE-LOCKED (err u106))
(define-constant ERR-THRESHOLD-EXCEEDED (err u107))
(define-constant ERR-CLAIM-AMOUNT-INVALID (err u108))
(define-constant ERR-YIELD-RATE-TOO-HIGH (err u109))
(define-constant ERR-INVALID-PARAMETER (err u110))
(define-constant ERR-DESCRIPTION-TOO-SHORT (err u111))

;; DATA STORAGE STRUCTURES

;; Member stake information storage
(define-map member-stakes
  { member-address: principal }
  { 
    staked-amount: uint,
    stake-start-block: uint,
    last-reward-block: uint
  }
)

;; Insurance claim records storage
(define-map claim-records
  { claim-id: uint }
  { 
    claimant-address: principal,
    claim-amount: uint,
    claim-description: (string-utf8 256),
    submission-block: uint,
    status: (string-utf8 10) ;; "pending", "approved", "denied"
  }
)

;; PROTOCOL STATE VARS

(define-data-var total-pool-balance uint u0)
(define-data-var total-payouts-made uint u0)
(define-data-var next-claim-id uint u0)
(define-data-var annual-yield-rate uint u100) ;; 1% default (basis points)
(define-data-var approval-threshold uint u5100) ;; 51% consensus required

;; READ-ONLY QUERY FUNCTIONS

;; Get member stake information
(define-read-only (get-member-stake-info (member-address principal))
  (default-to
    { staked-amount: u0, stake-start-block: u0, last-reward-block: u0 }
    (map-get? member-stakes { member-address: member-address })
  )
)

;; Get claim details by ID
(define-read-only (get-claim-details (claim-id uint))
  (map-get? claim-records { claim-id: claim-id })
)

;; Get total insurance pool balance
(define-read-only (get-total-pool-balance)
  (var-get total-pool-balance)
)

;; Get total payouts distributed
(define-read-only (get-total-payouts)
  (var-get total-payouts-made)
)

;; Get current annual yield rate
(define-read-only (get-current-yield-rate)
  (var-get annual-yield-rate)
)

;; Get approval threshold
(define-read-only (get-approval-threshold)
  (var-get approval-threshold)
)

;; Helper function to validate string length
(define-read-only (get-string-length (input-string (string-utf8 256)))
  (len input-string)
)

;; Calculate pending rewards for a member
(define-read-only (calculate-pending-rewards (member-address principal))
  (let (
    (stake-info (get-member-stake-info member-address))
    (staked-tokens (get staked-amount stake-info))
    (last-claim-block (get last-reward-block stake-info))
    (blocks-elapsed (- block-height last-claim-block))
  )
    (if (> staked-tokens u0)
      ;; Formula: stake * blocks * yield-rate / 10000
      (/ (* (* staked-tokens blocks-elapsed) (var-get annual-yield-rate)) u10000)
      u0
    )
  )
)

;; Check if stake is unlocked
(define-read-only (is-stake-unlocked (member-address principal))
  (let (
    (stake-info (get-member-stake-info member-address))
    (stake-block (get stake-start-block stake-info))
    (blocks-passed (- block-height stake-block))
  )
    (>= blocks-passed stake-lockup-period)
  )
)

;; STAKING OPERATIONS

;; Stake tokens to join the insurance pool
(define-public (stake-tokens (amount uint))
  (let (
    (current-stake-info (get-member-stake-info tx-sender))
    (existing-stake (get staked-amount current-stake-info))
  )
    ;; Validate minimum stake requirement
    (asserts! (>= amount min-stake-amount) ERR-STAKE-BELOW-MINIMUM)
    
    ;; Transfer tokens to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update member stake record
    (if (> existing-stake u0)
      ;; Existing member - claim rewards first
      (begin
        (try! (claim-rewards))
        (map-set member-stakes
          { member-address: tx-sender }
          { 
            staked-amount: (+ existing-stake amount),
            stake-start-block: block-height,
            last-reward-block: block-height
          }
        )
      )
      ;; New member - create fresh record
      (map-set member-stakes
        { member-address: tx-sender }
        { 
          staked-amount: amount,
          stake-start-block: block-height,
          last-reward-block: block-height
        }
      )
    )
    
    ;; Update total pool balance
    (var-set total-pool-balance (+ (var-get total-pool-balance) amount))
    
    (ok amount)
  )
)

;; Unstake tokens from the insurance pool
(define-public (unstake-tokens (amount uint))
  (let (
    (stake-info (get-member-stake-info tx-sender))
    (current-stake (get staked-amount stake-info))
    (start-block (get stake-start-block stake-info))
  )
    ;; Validate sufficient stake balance
    (asserts! (>= current-stake amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Enforce lockup period
    (asserts! (>= (- block-height start-block) stake-lockup-period) ERR-STAKE-LOCKED)
    
    ;; Claim pending rewards
    (try! (claim-rewards))
    
    ;; Transfer tokens back to member
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
    
    ;; Update member stake record
    (map-set member-stakes
      { member-address: tx-sender }
      { 
        staked-amount: (- current-stake amount),
        stake-start-block: start-block,
        last-reward-block: block-height
      }
    )
    
    ;; Update total pool balance
    (var-set total-pool-balance (- (var-get total-pool-balance) amount))
    
    (ok amount)
  )
)

;; Claim accumulated staking rewards
(define-public (claim-rewards)
  (let (
    (stake-info (get-member-stake-info tx-sender))
    (staked-tokens (get staked-amount stake-info))
    (pending-rewards (calculate-pending-rewards tx-sender))
  )
    ;; Verify member has stake
    (asserts! (> staked-tokens u0) ERR-MEMBER-NOT-FOUND)
    
    ;; Distribute rewards if available
    (if (> pending-rewards u0)
      (begin
        ;; Transfer rewards to member
        (try! (as-contract (stx-transfer? pending-rewards (as-contract tx-sender) tx-sender)))
        
        ;; Update last reward claim block
        (map-set member-stakes
          { member-address: tx-sender }
          { 
            staked-amount: staked-tokens,
            stake-start-block: (get stake-start-block stake-info),
            last-reward-block: block-height
          }
        )
        
        (ok pending-rewards)
      )
      (ok u0)
    )
  )
)

;; CLAIM PROCESSING SYSTEM

;; Submit an insurance claim for review
(define-public (submit-claim (claim-amount uint) (description (string-utf8 256)))
  (let (
    (stake-info (get-member-stake-info tx-sender))
    (member-stake (get staked-amount stake-info))
    (current-id (var-get next-claim-id))
    (desc-length (get-string-length description))
  )
    ;; Verify member eligibility
    (asserts! (> member-stake u0) ERR-MEMBER-NOT-FOUND)
    
    ;; Validate claim amount
    (asserts! (and (> claim-amount u0) (<= claim-amount max-claim-amount)) 
              ERR-CLAIM-AMOUNT-INVALID)
    
    ;; Validate description length
    (asserts! (>= desc-length min-claim-description-length) 
              ERR-DESCRIPTION-TOO-SHORT)
    
    ;; Create claim record
    (map-set claim-records
      { claim-id: current-id }
      { 
        claimant-address: tx-sender,
        claim-amount: claim-amount,
        claim-description: description,
        submission-block: block-height,
        status: u"pending"
      }
    )
    
    ;; Increment claim ID counter
    (var-set next-claim-id (+ current-id u1))
    
    (ok current-id)
  )
)

;; Process insurance claim (admin function)
(define-public (process-claim (claim-id uint) (approve bool))
  (let (
    (claim-info (unwrap! (get-claim-details claim-id) ERR-MEMBER-NOT-FOUND))
    (claimant (get claimant-address claim-info))
    (amount (get claim-amount claim-info))
    (current-status (get status claim-info))
  )
    ;; Verify admin access
    (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Ensure claim is pending
    (asserts! (is-eq current-status u"pending") ERR-CLAIM-ALREADY-PROCESSED)
    
    ;; Check pool balance for approvals
    (asserts! (or (not approve) (>= (var-get total-pool-balance) amount)) 
              ERR-INSUFFICIENT-BALANCE)
    
    (if approve
      (begin
        ;; Process approved claim
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) claimant)))
        
        ;; Update claim status
        (map-set claim-records
          { claim-id: claim-id }
          (merge claim-info { status: u"approved" })
        )
        
        ;; Update protocol statistics
        (var-set total-payouts-made (+ (var-get total-payouts-made) amount))
        (var-set total-pool-balance (- (var-get total-pool-balance) amount))
        
        (ok true)
      )
      (begin
        ;; Process denied claim
        (map-set claim-records
          { claim-id: claim-id }
          (merge claim-info { status: u"denied" })
        )
        
        (ok false)
      )
    )
  )
)

;; GOVERNANCE FUNCTIONS

;; Update annual yield rate (admin only)
(define-public (set-yield-rate (new-rate uint))
  (begin
    ;; Verify admin access
    (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Validate rate limit
    (asserts! (<= new-rate max-annual-yield-rate) ERR-YIELD-RATE-TOO-HIGH)
    
    ;; Update yield rate
    (var-set annual-yield-rate new-rate)
    
    (ok new-rate)
  )
)

;; Update consensus threshold (admin only)
(define-public (set-approval-threshold (new-threshold uint))
  (begin
    ;; Verify admin access
    (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Validate threshold bounds
    (asserts! (<= new-threshold u10000) ERR-THRESHOLD-EXCEEDED)
    (asserts! (> new-threshold u0) ERR-INVALID-PARAMETER)
    
    ;; Update threshold
    (var-set approval-threshold new-threshold)
    
    (ok new-threshold)
  )
)

;; Emergency pause function (admin only)
(define-public (emergency-withdraw (amount uint) (recipient principal))
  (begin
    ;; Verify admin access
    (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Validate amount
    (asserts! (<= amount (var-get total-pool-balance)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Execute emergency withdrawal
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) recipient)))
    
    ;; Update pool balance
    (var-set total-pool-balance (- (var-get total-pool-balance) amount))
    
    (ok amount)
  )
)