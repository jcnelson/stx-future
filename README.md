# stx-future

A Clarity smart contract for creating futures tranches for Stacked STX.

**This code is for educational and demonstration purposes only**.

## How To Use

One instance of this contract represents a tranche of STX futures that are
all Stacked together under the same PoX reward address, and all
unlock at the same reward cycle.  Tokens within the same tranche are fungible --
this contract implements the upcoming
[SIP-010](https://github.com/stacksgov/sips/pull/5) interface to make them
tradable on exchanges that support it.  Tokens within different tranches are
treated as separate tokens.

This contract is meant to help Stacking pool operators and exchanges that want to
offer Stacking as a custodial service.  Your users send their STX to this contract,
and in doing so, receive a `stx-future` fungible token that they can later use
to redeem their STX when they unlock.  You, the pool operator, will need to 
call the `stack-stx-tranche` function before the target reward cycle's anchor
block in order to Stack the users' tokens.  This way, users can trade their
locked STX for real STX, which the receiver can then redeem for the user's
original STX once they unlock.

## How To Deploy 

You will need to deploy an instance of this contract for each batch of STX
tokens you will Stack.  But to do so, you will need to modify some constant 
fields in the contract code.

There are three constants defined in the beginning of `stx-future.clar` that
govern how this contract works.  They are:

* `AUTHORIZED-STACKERS` -- a list of principals that are allowed to call
  `stx-stack-tranche`.
* `FIRST-REWARD-CYCLE` -- the reward cycle number for which this contract's STX
  will be Stacked.
* `REWARD-CYCLE-PERIOD` -- the number of reward cycles for which this contract's
  STX will be locked up.

The code has some basic sanity checks to make sure the above values aren't
obviously wrong, but you will need to tailor these values to whatever Stacking
service you want to offer users.

## Contract Lifecycle

Once you deploy this contract, you should call the `allow-contract-caller` method
in the PoX contract to allow the `stack-stx` method to be called from this
contract.  You will need to do this sometime before calling `stack-stx-tranche`.

Because this is a custodial contract, you will need to supply the single PoX
address for accumulating the PoX rewards.  You are then responsible for disbursing
the PoX rewards to your users.

Once you call `stack-stx-tranche` successfully, no more `stx-future` will be
minted, and the STX will be locked in PoX for Stacking.  Once they unlock,
bearers of this contract's `stx-future` tokens can redeem them for the real STX.

If you fail to call `stack-stx-tranche` in time, your users will be able to
redeem their `stx-futures` for STX immediately.

## Limitations and Caveats

* This contract places a lot of trust in the custodian, who must not only
  authorize this contract to call `stack-stx`, but also call `stack-stx-tranche`
in a timely fashion and disburse the PoX rewards in a timely and equitable
manner.  **The custodian can simply steal the PoX rewards.**

* The contract takes possession of the users' STX, so they can all be Stacked at
  once.  **This is not a delegation service**.  As such, users are both trusting
the custodian to disburse rewards, as well as trusting this contract not to have
bugs that could lead to loss or theft of their real STX.

* I have included some tests in the `tests/` directory, but they are by no means
  exhaustive.  **No security audits have been performed on this code.**

## How to Develop

To run (and hack on) the tests, you will need to build and install `clarity-cli` from the
[Stacks Blockchain](https://github.com/blockstack/stacks-blockchain) repo, and
put it in your `$PATH`.  From there, you can run the tests as follows:

```bash
$ cd tests/ && ./stx-future.sh
```

The test framework is very rudimentary -- it simply concatenates the
`stx-future.clar` contract with another snippet of Clarity code containing the
unit tests, sets up an instance of the PoX contract and some initial balances,
grabs a list of test functions from a `list-tests` function, and
executes them in order via the `clarity-cli` binary.
