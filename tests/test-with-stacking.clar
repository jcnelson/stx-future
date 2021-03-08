;; setup PoX
(begin
    ;; (define-public (set-burnchain-parameters (first-burn-height uint) (prepare-cycle-length uint) (reward-cycle-length uint) (rejection-fraction uint))
    (contract-call? 'SP000000000000000000002Q6VF78.pox set-burnchain-parameters u1 u3 u5 u25))

;; list of tests to run (also includes unit tests)
(define-public (list-tests)
    (begin
       (ok (list
           "block-5"
           "block-6"
           "block-7"
           "block-8"
           "block-9"
           "block-10"
           "block-11"
       ))
    )
)

(define-public (block-5)
    (begin
        (print "test block-5: buy futures")

        (asserts! (is-eq burn-block-height u5)
            (err "Burn block height is not 5"))

        (asserts! (is-eq u0 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 0"))

        (print "buy stx futures 30000")
        (asserts! (is-eq (ok true) (buy-stx-futures u30000))
            (err "Failed to buy u10000 stx futures"))

        (print "check balances at 30000")
        (asserts! (is-eq u1 (stx-get-balance tx-sender))
            (err "Failed to get principal balance after buying u20000 futures via get-balance-of"))
        (asserts! (is-eq (ok u30000) (get-balance-of tx-sender))
            (err "Failed to get principal balance after buying u20000 futures via get-balance-of"))
        (asserts! (is-eq u30000 (stx-get-balance (as-contract tx-sender)))
            (err "Failed to get balance of contract after buying u20000 futures"))

        (print "transfer stx-future tokens")
        (asserts! (is-eq (ok u0) (get-balance-of 'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D))
            (err "Recipient must have empty balance"))
        (asserts! (is-eq (ok true) (transfer u100 tx-sender 'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D))
            (err "Failed to transfer u100 stx-futures"))
        (asserts! (is-eq (ok u100) (get-balance-of 'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D))
            (err "Transfer of u100 stx-futures did not update receiver balance"))
        (asserts! (is-eq (ok u29900) (get-balance-of tx-sender))
            (err "Transfer of u100 stx-futures did not update sender balance"))

        (print "test block-5: stack the STX")

        (match (stack-stx-tranche { version: 0x01, hashbytes: 0x0000000000000000000000000000000000000000 })
            pox-result
                (begin
                    (print "PoX stack-stx succeeded")
                    (print pox-result)
                    true
                )
            error
                (begin
                    (print "PoX failed")
                    (print error)
                    (asserts! false (err "PoX failed"))
                )
        )

        ;; should fail the second time -- no more STX to stack!
        (match (stack-stx-tranche { version: 0x01, hashbytes: 0x0000000000000000000000000000000000000000 })
            pox-result
                (asserts! false (err "Stacked a second time"))
            error
                (begin
                    (print "PoX failed, as expected, with error:")
                    (print error)
                    (asserts! (is-eq error 3) (err "Did not get error 3"))
                )
        )

        (print "tx-sender balance is") (print (stx-get-balance tx-sender))
        (print "contract balance is") (print (stx-get-balance (as-contract tx-sender)))

        (asserts! (is-eq u1 (stx-get-balance tx-sender))
            (err "Failed to get principal balance after buying all futures and stacking all STX"))

        ;; can't redeem -- all tokens locked
        (asserts! (is-eq (err ERR-NOT-YET-REDEEMABLE) (redeem-stx-futures u123))
            (err "Allowed early redemption"))

        ;; can't buy more futures -- tokens are locked in
        (asserts! (is-eq (err ERR-ALREADY-LOCKED) (buy-stx-futures u1))
            (err "Allowed buying more futures"))

        ;; our balances haven't changed
        (asserts! (is-eq u1 (stx-get-balance tx-sender))
            (err "Failed to get principal balance after buying all futures"))
        (asserts! (is-eq (ok u29900) (get-balance-of tx-sender))
            (err "Failed to get principal balance after buying all futures via get-balance-of"))
        (asserts! (is-eq u30000 (stx-get-balance (as-contract tx-sender)))
            (err "Failed to get balance of contract after locking STX"))

        (ok u0)
    )
)

;; reward cycle boundary -- tokens are locked!

(define-public (block-6)
    (begin
        (print "test block-6: can redeem if operator fails to stack")

        (asserts! (is-eq burn-block-height u6)
            (err "Burn block height is not 6"))

        (asserts! (is-eq u1 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 1"))

        ;; should fail -- we're too late
        (match (stack-stx-tranche { version: 0x01, hashbytes: 0x0000000000000000000000000000000000000000 })
            pox-result
                (asserts! false (err "Stacked a second time"))
            error
                (begin
                    (print "PoX failed, as expected, with error:")
                    (print error)
                    (asserts! (is-eq error 24) (err "Did not get error 24"))
                )
        )

        ;; can't redeem -- all tokens locked
        (asserts! (is-eq (err ERR-NOT-YET-REDEEMABLE) (redeem-stx-futures u123))
            (err "Allowed early redemption"))
        
        ;; can't buy more futures -- in progress
        (asserts! (is-eq (err ERR-IN-PROGRESS) (buy-stx-futures u1))
            (err "Allowed buying more futures"))

        (ok u0)
    )
)

(define-public (block-7)
    (begin
        (print "test block-7")

        (asserts! (is-eq burn-block-height u7)
            (err "Burn block height is not 7"))

        (asserts! (is-eq u1 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 1"))

        ;; can't redeem -- all tokens locked
        (asserts! (is-eq (err ERR-NOT-YET-REDEEMABLE) (redeem-stx-futures u123))
            (err "Allowed early redemption"))
        
        ;; can't buy more futures -- in progress
        (asserts! (is-eq (err ERR-IN-PROGRESS) (buy-stx-futures u1))
            (err "Allowed buying more futures"))

        (ok u0)
    )
)

(define-public (block-8)
    (begin
        (print "test block-8")

        (asserts! (is-eq burn-block-height u8)
            (err "Burn block height is not 8"))

        (asserts! (is-eq u1 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 1"))

        ;; can't redeem -- all tokens locked
        (asserts! (is-eq (err ERR-NOT-YET-REDEEMABLE) (redeem-stx-futures u123))
            (err "Allowed early redemption"))
        
        ;; can't buy more futures -- in progress
        (asserts! (is-eq (err ERR-IN-PROGRESS) (buy-stx-futures u1))
            (err "Allowed buying more futures"))

        (ok u0)
    )
)

(define-public (block-9)
    (begin
        (print "test block-9")

        (asserts! (is-eq burn-block-height u9)
            (err "Burn block height is not 9"))

        (asserts! (is-eq u1 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 1"))

        ;; can't redeem -- all tokens locked
        (asserts! (is-eq (err ERR-NOT-YET-REDEEMABLE) (redeem-stx-futures u123))
            (err "Allowed early redemption"))
        
        ;; can't buy more futures -- in progress
        (asserts! (is-eq (err ERR-IN-PROGRESS) (buy-stx-futures u1))
            (err "Allowed buying more futures"))

        (ok u0)
    )
)

(define-public (block-10)
    (begin
        (print "test block-10")

        (asserts! (is-eq burn-block-height u10)
            (err "Burn block height is not 10"))

        (asserts! (is-eq u1 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 1"))

        ;; can't redeem -- all tokens locked
        (asserts! (is-eq (err ERR-NOT-YET-REDEEMABLE) (redeem-stx-futures u123))
            (err "Allowed early redemption"))
        
        ;; can't buy more futures -- in progress
        (asserts! (is-eq (err ERR-IN-PROGRESS) (buy-stx-futures u1))
            (err "Allowed buying more futures"))

        (ok u0)
    )
)

;; reward cycle boundary -- tokens unlocked!

(define-public (block-11)
    (begin
        (print "test block-11")

        (asserts! (is-eq burn-block-height u11)
            (err "Burn block height is not 11"))

        (asserts! (is-eq u2 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 2"))

        ;; can't buy more futures -- in progress
        (asserts! (is-eq (err ERR-IN-PROGRESS) (buy-stx-futures u1))
            (err "Allowed buying more futures"))

        ;; can now redeem -- all tokens unlocked
        (asserts! (is-eq u1 (stx-get-balance tx-sender))
            (err "failed to get principal balance before redeeming u123 futures"))
        (asserts! (is-eq (ok u29900) (get-balance-of tx-sender))
            (err "failed to get principal balance before redeeming u123 futures via via get-balance-of"))
        (asserts! (is-eq u30000 (stx-get-balance (as-contract tx-sender)))
            (err "failed to get balance of contract before redeeming u123 futures"))

        (asserts! (is-eq (ok true) (redeem-stx-futures u123))
            (err "Failed to redeem u123 futures"))

        (asserts! (is-eq (+ u1 u123) (stx-get-balance tx-sender))
            (err "failed to get principal balance after redeeming u123 futures"))
        (asserts! (is-eq (ok (- u29900 u123)) (get-balance-of tx-sender))
            (err "failed to get principal balance after redeeming u123 futures via via get-balance-of"))
        (asserts! (is-eq (- u30000 u123) (stx-get-balance (as-contract tx-sender)))
            (err "failed to get balance of contract after redeeming u123 futures"))

        (ok u0)
    )
)
