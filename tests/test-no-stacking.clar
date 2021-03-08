;; setup PoX
(begin
    ;; (define-public (set-burnchain-parameters (first-burn-height uint) (prepare-cycle-length uint) (reward-cycle-length uint) (rejection-fraction uint))
    (contract-call? 'SP000000000000000000002Q6VF78.pox set-burnchain-parameters u1 u3 u5 u25))

;; list of tests to run (also includes unit tests)
(define-public (list-tests)
    (begin
       (unwrap-panic (unit-tests))
       (ok (list
           "block-5"
           "block-6"
       ))
    )
)

(define-private (test-authorization)
    (begin
        (print "test authorization")
        (asserts! (is-authorized 'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D)
            (err "Auth check failed for standard principal"))

        (asserts! (is-authorized 'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D.auth-proxy)
            (err "Auth check failed for contract principal"))

        (asserts! (not (is-authorized 'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D.nope))
            (err "Auth check permitted unauthorized contract"))

        (ok u0)
    )
)

(define-public (unit-tests)
    (begin
        (print "unit tests")

        (asserts! (is-eq burn-block-height u4)
            (err "Burn block height is not 4"))

        (asserts! (is-eq u0 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 0"))

        (unwrap! (test-authorization) (err "test-authorization failed"))
        (print "all unit tests pass")
        (ok u0)
    )
)

(define-public (block-5)
    (begin
        (print "test block-5: can buy futures")
        
        (asserts! (is-eq burn-block-height u5)
            (err "Burn block height is not 5"))

        (asserts! (is-eq u0 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 0"))

        (print "check initial balances")
        (asserts! (is-eq u30001 (stx-get-balance tx-sender))
            (err "Failed to get principal balance"))
        (asserts! (is-eq (ok u0) (get-balance-of tx-sender))
            (err "Failed to get principal balance via get-balance-of"))
        (asserts! (is-eq u0 (stx-get-balance (as-contract tx-sender)))
            (err "Failed to get balance of contract"))

        (print "buy stx futures 10000")
        (asserts! (is-eq (ok true) (buy-stx-futures u10000))
            (err "Failed to buy u10000 stx futures"))

        (print "check balances at 10000")
        (asserts! (is-eq u20001 (stx-get-balance tx-sender))
            (err "Failed to get principal balance after buying u10000 futures"))
        (asserts! (is-eq (ok u10000) (get-balance-of tx-sender))
            (err "Failed to get principal balance after buying u10000 futures via get-balance-of"))
        (asserts! (is-eq u10000 (stx-get-balance (as-contract tx-sender)))
            (err "Failed to get balance of contract after buying u10000 futures"))

        (print "buy stx futures 20000")
        (asserts! (is-eq (ok true) (buy-stx-futures u20000))
            (err "Failed to get principal balance after buying u20000 futures"))

        (print "check balances at 20000")
        (asserts! (is-eq u1 (stx-get-balance tx-sender))
            (err "Failed to get principal balance after buying u20000 futures via get-balance-of"))
        (asserts! (is-eq (ok u30000) (get-balance-of tx-sender))
            (err "Failed to get principal balance after buying u20000 futures via get-balance-of"))
        (asserts! (is-eq u30000 (stx-get-balance (as-contract tx-sender)))
            (err "Failed to get balance of contract after buying u20000 futures"))

        (print "buy stx futures with invalid balance (should fail)")
        (asserts! (is-eq (err ERR-INSUFFICIENT-BALANCE)
                         (buy-stx-futures u100000000000))
            (err "Permitted buying more futures than the buyer has STX"))

        (print "transfer stx-future tokens")
        (asserts! (is-eq (ok u0) (get-balance-of 'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D))
            (err "Recipient must have empty balance"))
        (asserts! (is-eq (ok true) (transfer u100 tx-sender 'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D))
            (err "Failed to transfer u100 stx-futures"))
        (asserts! (is-eq (ok u100) (get-balance-of 'SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D))
            (err "Transfer of u100 stx-futures failed"))

        (print "test block-5: can't redeem too early")

        ;; haven't stacked yet, but it's too early to redeem
        (asserts! (is-eq (err ERR-NOT-YET-REDEEMABLE) (redeem-stx-futures u123))
            (err "Allowed early redemption"))

        ;; can't redeem -- too many futures asked for
        (asserts! (is-eq (err ERR-REQUEST-TOO-LARGE) (redeem-stx-futures u10000000))
            (err "Allowed redeeming too many tokens"))

        (ok u0)
    )
)

;;; reward cycle boundary

(define-public (block-6)
    (begin
        (print "test block-6: can redeem if operator fails to stack")

        (asserts! (is-eq burn-block-height u6)
            (err "Burn block height is not 6"))

        (asserts! (is-eq u1 (burn-height-to-reward-cycle burn-block-height))
            (err "Reward cycle is not 1"))

        (asserts! (is-eq u1 (stx-get-balance tx-sender))
            (err "failed to get principal balance before redeeming u123 futures"))
        (asserts! (is-eq (ok u29900) (get-balance-of tx-sender))
            (err "failed to get principal balance before redeeming u123 futures via via get-balance-of"))
        (asserts! (is-eq u30000 (stx-get-balance (as-contract tx-sender)))
            (err "failed to get balance of contract before redeeming u123 futures"))

        ;; didn't stack, and in FIRST-REWARD-CYCLE, so we can redeem now.
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

