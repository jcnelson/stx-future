#!/bin/bash

contract="../stx-future.clar"
pox="./pox.clar"
pox_mainnet="./pox-mainnet.clar"
initial_allocations="./initial-balances.json"
contract_addr="SPP5ERW9P30ZQ9S7KGEBH042E7EJHWDT2Z5K086D"
contract_id="$contract_addr.stx-future"
tx_sender="S1G2081040G2081040G2081040G208105NK8PE5"

specific_test="$1"

set -ueo pipefail

which clarity-cli >/dev/null 2>&1 || ( echo >&2 "No clarity-cli in PATH"; exit 1 )

run_test() {
   local test_name="$1"
   local test_dir="$2"
   echo "Run test $test_name"

   local result="$(clarity-cli execute "$test_dir" "$contract_id" "$test_name" "$tx_sender" 2>&1)"
   local rc=$?
   printf "$result\n"
   if [ $rc -ne 0 ] || [ -n "$(echo "$result" | egrep '^Aborted: ')" ]; then
      echo "Test $test_name failed"
      exit 1
   fi
}

for contract_test in test-no-stacking.clar test-with-stacking.clar; do
   if [ -n "$specific_test" ] && [ "$contract_test" != "$specific_test" ]; then
      continue;
   fi

   test_dir="/tmp/vm-stx-future-$contract_test.db"
   test -d "$test_dir" && rm -rf "$test_dir"

   mkdir -p "$test_dir"
   cat "$contract" "$contract_test" > "$test_dir/contract-with-tests.clar"
   cat "$pox_mainnet" "$pox" > "$test_dir/pox.clar"

   clarity-cli initialize "$initial_allocations" "$test_dir"

   echo "Instantiate PoX"
   clarity-cli launch "SP000000000000000000002Q6VF78.pox" "$test_dir/pox.clar" "$test_dir"

   echo "Tests begin at line $(wc -l "$contract" | cut -d ' ' -f 1)"

   echo "Instantiate $contract_id"
   clarity-cli launch "$contract_id" "$test_dir/contract-with-tests.clar" "$test_dir"

   echo "Authorize $contract_id for PoX operations on behalf of $tx_sender"
   clarity-cli execute "$test_dir" "SP000000000000000000002Q6VF78.pox" "allow-contract-caller" "$tx_sender" "'$contract_id" "none"

   echo "Run tests"
   tests="$(clarity-cli execute "$test_dir" "$contract_id" "list-tests" "$tx_sender" 2>&1 | \
      grep 'Transaction executed and committed. Returned: ' | \
      sed -r -e 's/Transaction executed and committed. Returned: \((.+)\)/\1/g' -e 's/"//g')"

   echo "$tests"
   set -- $tests

   testname=""
   for i in $(seq 1 $#); do
      eval "test_name=$(echo "\$""$i")"
      run_test "$test_name" "$test_dir"
   done
done
