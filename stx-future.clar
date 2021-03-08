;; This is alpha-quality code.  I have written some tests in the tests/ directory of this repo to
;; verify most code paths, but this code really needs to be audited and tailored to your specific needs.
;; You should definitely deploy this to a testnet environment and (ab)use it extensively before
;; trying it out with other peoples' real-world tokens.  YOU HAVE BEEN WARNED.

;;;;;;;;;;;;;;;;;;;;;; Begin configuration ;;;;;;;;;;;;;;;;;;;;;;

;; Hard-coded list of principals who'll do the Stacking.
;; Change to your liking.
(define-constant AUTHORIZED-STACKERS (list
    'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D
    'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D.auth-proxy
    'S1G2081040G2081040G2081040G208105NK8PE5
))

;; Hard-coded reward cycle in which the contained STX tokens shall lock.
;; Change to your liking.  Must be greater than the current reward cycle.
(define-constant FIRST-REWARD-CYCLE u1)

;; Hard-coded length of the lock-up.
;; Change to your liking.  Can be between 1 and 12, inclusive.
(define-constant REWARD-CYCLE-LOCK-PERIOD u1)

;;;;;;;;;;;;;;;;;;;;;; End of configuration ;;;;;;;;;;;;;;;;;;;;;;

;; self-consistency check
(begin
    (asserts! (> FIRST-REWARD-CYCLE (burn-height-to-reward-cycle burn-block-height))
        (err "Invalid configuration -- bad FIRST-REWARD-CYCLE"))
    (asserts! (and (>= REWARD-CYCLE-LOCK-PERIOD u1) (<= REWARD-CYCLE-LOCK-PERIOD u12))
        (err "Invalid configuration -- bad REWARD-CYCLE-LOCK-PERIOD"))
    (asserts! (> (len AUTHORIZED-STACKERS) u0)
        (err "Invalid configuration -- empty AUTHORIZED-STACKERS list"))
)

;; error constants
(define-constant ERR-UNAUTHORIZED u1)
(define-constant ERR-IN-PROGRESS u2)
(define-constant ERR-INSUFFICIENT-BALANCE u3)
(define-constant ERR-REQUEST-TOO-LARGE u4)
(define-constant ERR-ALREADY-LOCKED u5)
(define-constant ERR-NOT-YET-REDEEMABLE u6)

;; the actual token
(define-fungible-token stx-future)

;; if set to true, then the tokens have been locked already in PoX
(define-data-var locked bool false)

;; Backport of .pox's burn-height-to-reward-cycle
(define-private (burn-height-to-reward-cycle (height uint)) 
    (let (
        (pox-info (unwrap-panic (contract-call? 'SP000000000000000000002Q6VF78.pox get-pox-info)))
    )
    (/ (- height (get first-burnchain-block-height pox-info)) (get reward-cycle-length pox-info)))
)

;; Backport of .pox's reward-cycle-to-burn-height
(define-private (reward-cycle-to-burn-height (cycle uint))
    (let (
        (pox-info (unwrap-panic (contract-call? 'SP000000000000000000002Q6VF78.pox get-pox-info)))
    )
    (+ (get first-burnchain-block-height pox-info) (* cycle (get reward-cycle-length pox-info))))
)

;; Self-service endpoint for buying STX futures for STX that will be locked in the tranche's reward cycle.
(define-public (buy-stx-futures (amount-ustx uint))
    (let (
        (cur-reward-cycle (burn-height-to-reward-cycle burn-block-height))
        (unlock-cycle (+ u1 FIRST-REWARD-CYCLE REWARD-CYCLE-LOCK-PERIOD))
        (locked? (var-get locked))
    )
    (begin
        ;; can't buy futures for a reward cycle that's already in progress
        (asserts! (< cur-reward-cycle FIRST-REWARD-CYCLE)
            (err ERR-IN-PROGRESS))

        ;; can't buy futures if the STX for this reward cycle are already stacked
        (asserts! (not locked?)
            (err ERR-ALREADY-LOCKED))

        ;; buyer has to have enough STX
        (asserts! (<= amount-ustx (stx-get-balance tx-sender))
            (err ERR-INSUFFICIENT-BALANCE))

        ;; do the transfer and mint, but abort entirely if this fails
        (unwrap-panic (stx-transfer? amount-ustx tx-sender (as-contract tx-sender)))
        (unwrap-panic (ft-mint? stx-future amount-ustx tx-sender))
        
        (ok true)
    ))
)

;; Self-service endpoint for redeeming STX that have unlocked (or were never locked)
;; Anyone with some `stx-future` tokens can call this endpoint to redeem them for
;; the given tranche's STX.
(define-public (redeem-stx-futures (amount-futures uint))
    (let (
        (sender-futures (ft-get-balance stx-future tx-sender))
        (contract-ustx (stx-get-balance (as-contract tx-sender)))
        (unlock-cycle (+ FIRST-REWARD-CYCLE REWARD-CYCLE-LOCK-PERIOD))
        (locked? (var-get locked))
        (cur-reward-cycle (burn-height-to-reward-cycle burn-block-height))
        (caller-id tx-sender)
    )
    (begin
        ;; caller must have this many stx-futures to burn
        (asserts! (<= amount-futures sender-futures)
            (err ERR-REQUEST-TOO-LARGE))

        ;; contract must have this many STX to redeem
        (asserts! (<= amount-futures contract-ustx)
            (err ERR-REQUEST-TOO-LARGE))

        ;; the STX must have unlocked by the time of this call,
        ;; OR,
        ;; the STX used to buy these stx-futures are not Stacked 
        ;; and the intended reward cycle has already begun (i.e. the operator
        ;; of this contract forgot to Stack).
        (asserts! (or (>= cur-reward-cycle unlock-cycle)
                      (and (>= cur-reward-cycle FIRST-REWARD-CYCLE) (not locked?)))
            (err ERR-NOT-YET-REDEEMABLE))

        ;; destroy the stx-future token and redeem the STX
        (as-contract
            (unwrap-panic (stx-transfer? amount-futures tx-sender caller-id)))
        (unwrap-panic (ft-burn? stx-future amount-futures tx-sender))

        (ok true)
    ))
)

;; inner fold function for verifying that the `candidate` is authorized to Stack a tranche's STX.
(define-private (auth-check (candidate principal) (data { caller: principal, was-allowed: bool }))
    {
        caller: (get caller data),
        was-allowed: (if (is-eq candidate (get caller data))
                        true
                        (get was-allowed data))
    }
)

;; Determine that the given `stacker` is allowed to Stack a STX tranche
(define-private (is-authorized (stacker principal))
    (get was-allowed
        (fold auth-check AUTHORIZED-STACKERS { caller: stacker, was-allowed: false }))
)

;; Stack the STX tranche, and send the rewards to the given pox-addr.
(define-public (stack-stx-tranche (pox-addr { version: (buff 1), hashbytes: (buff 20) }))
    (if (is-authorized tx-sender)
        (let (
            (already-locked (var-get locked))
            (contract-balance (stx-get-balance (as-contract tx-sender)))
            (caller-id tx-sender)
            (cur-reward-cycle (burn-height-to-reward-cycle burn-block-height))
        )
        (begin
            ;; contract has STX to Stack
            (asserts! (< u0 contract-balance)
                (err 18))   ;; ERR_STACKING_INVALID_AMOUNT in .pox

            ;; can only do this successfully once
            (asserts! (not already-locked)
                (err 3))    ;; ERR_STACKING_ALREADY_STACKED in .pox

            ;; must happen before the intended start of locking
            (asserts! (< cur-reward-cycle FIRST-REWARD-CYCLE)
                (err 24))   ;; ERR_INVALID_START_BURN_HEIGHT in .pox

            (let (
                ;; do the actual stacking.
                (pox-result (as-contract
                    (unwrap-panic (contract-call? 'SP000000000000000000002Q6VF78.pox stack-stx contract-balance pox-addr burn-block-height REWARD-CYCLE-LOCK-PERIOD)))
                )
            )
            (begin
                ;; don't lock in this reward cycle again
                (var-set locked true)
                (ok pox-result)
            ))
        ))
        (err 9)     ;; ERR_PERMISSION_DENIED in .pox
    )
)

;;;;;;;;;;;;;;;;;;;;; SIP 010 ;;;;;;;;;;;;;;;;;;;;;;

(define-public (transfer (amount uint) (from principal) (to principal))
    (begin
        (asserts! (is-eq from tx-sender)
            (err ERR-UNAUTHORIZED))

        (ft-transfer? stx-future amount from to)
    )
)

(define-public (get-name)
    (ok "STX-futures"))

(define-public (get-symbol)
    (ok "STXF"))

(define-public (get-decimals)
    (ok u6))

(define-public (get-balance-of (user principal))
    (ok (ft-get-balance stx-future user)))

(define-public (get-total-supply)
    (ok (stx-get-balance (as-contract tx-sender))))

(define-public (get-token-uri)
    (ok none))
