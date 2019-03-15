#!/bin/bash

# Usage: ./testlocal.sh

# Assumptions: nodeos already running
# Otherwise, run nodeos with command:

# nodeos -e -p eosio --http-validate-host=false --delete-all-blocks --contracts-console --plugin eosio::chain_api_plugin --plugin eosio::history_api_plugin --plugin eosio::producer_plugin --plugin eosio::http_plugin

#=================================================================================#
# Config Constants
NODEOS_HOST="127.0.0.1"
NODEOS_PROTOCOL="http"
NODEOS_PORT="8888"
NODEOS_LOCATION="${NODEOS_PROTOCOL}://${NODEOS_HOST}:${NODEOS_PORT}"

alias cleos="cleos --url=${NODEOS_LOCATION}"

# Helper scripts
COMPILE="./compile.sh"

# Contract accounts
CONTRACT="daiqcontract"
CONTRACT_WASM="$CONTRACT.wasm"
CONTRACT_ABI="$CONTRACT.abi"

TOKEN_CONTRACT="everipediaiq"
TOKEN_WASM="$TOKEN_CONTRACT.wasm"
TOKEN_ABI="$TOKEN_CONTRACT.abi"

# Wallet name prereq... 
# set WALLET environment variable via: 

# rm ~/eosio-wallet/default.wallet
# cleos wallet create --to-console
# export wallet="default"

if [[ -z "${WALLET}" ]]; then
  echo "ERROR: run 'export WALLET=[wallet_name] to set your wallet name'"
  exit 1
else
  WALLET="${WALLET}"
fi

# Wallet password prereq...
# set PASSWORD environment variable via:
# export PASSWORD="PW5JjGjm4FjESLYWUqgpEP4sfVCFoCLfNRccSv2XZNd4cgBJBXnDV"

if [[ -z "${PASSWORD}" ]]; then
  echo "ERROR: run 'export PASSWORD=[password] to set your wallet password'"
  exit 1
else
  PASSWORD="${PASSWORD}"
fi

# Account Private keys, first one for eosio
EOSIO_ACCT="5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3"

# To create new keys run:
# cleos create key --to-console

OWNER_ACCT="5J3TQGkkiRQBKcg8Gg2a7Kk5a2QAQXsyGrkCnnq4krSSJSUkW12"
ACTIVE_ACCT="5J3TQGkkiRQBKcg8Gg2a7Kk5a2QAQXsyGrkCnnq4krSSJSUkW12"
# Account public keys
OWNER_KEY="EOS6TnW2MQbZwXHWDHAYQazmdc3Sc1KGv4M9TSgsKZJSo43Uxs2Bx"
ACTIVE_KEY="EOS6TnW2MQbZwXHWDHAYQazmdc3Sc1KGv4M9TSgsKZJSo43Uxs2Bx"

## Make sure keys are in the wallet
cleos wallet import -n $WALLET --private-key $EOSIO_ACCT 
cleos wallet import -n $WALLET --private-key $OWNER_ACCT
cleos wallet import -n $WALLET --private-key $ACTIVE_ACCT

# 0) Unlock wallet
echo "=== UNLOCKING WALLET ==="
cleos wallet unlock -n $WALLET --password $PASSWORD

# 1) Create contract accounts
echo "=== CREATING CONTRACT ACCOUNTS ==="
cleos create account eosio $CONTRACT $OWNER_KEY $ACTIVE_KEY
cleos create account eosio $TOKEN_CONTRACT $OWNER_KEY $ACTIVE_KEY

# 2) Create test accounts
echo "=== CREATING USER ACCOUNTS ==="
cleos create account eosio rick $OWNER_KEY $ACTIVE_KEY
cleos create account eosio dick $OWNER_KEY $ACTIVE_KEY

# 3) Compile and Deploy contracts
echo "=== COMPILING CONTRACTS ==="
"$COMPILE" $CONTRACT
"$COMPILE" $TOKEN_CONTRACT

echo "=== DEPLOYING CONTRACTS ==="
cleos set contract $CONTRACT . $CONTRACT_WASM $CONTRACT_ABI
cleos set contract $TOKEN_CONTRACT . $TOKEN_WASM $TOKEN_ABI

# cleos --url https://jungle.eosio.cr:443 system newaccount --stake-net "10.0000 EOS" --stake-cpu "10.0000 EOS" --buy-ram-kbytes 12 $CREATOR_ACCOUNT $NEW_ACCOUNT $OWNER_KEY $ACTIVE_KEY
# cleos --url https://jungle.eosio.cr:443 system buyram $CREATOR_ACCOUNT $NEW_ACCOUNT "50 EOS"

# 4) Set up permissions for contracts to send deferred actions
echo "===SETTING PERMISSIONS==="
cleos set account permission $CONTRACT active ./perm.json -p $CONTRACT@active

#=================================================================================#
# OPEN
echo "=== DEPOSITING IQ ==="

# on first run, when given cdp type doesn't exist yet, 
# "test" will simply pre-fund accounts with tokens

# !!!!!!!!! UNCOMMENT FOR LOCAL TESTING !!!!!!!!!!
#cleos push action $CONTRACT test '["rick"]' -p rick
#cleos push action $CONTRACT test '["dick"]' -p dick

cleos push action $TOKEN_CONTRACT create '["everipediaiq", "100000000000.000 IQ"]' -p $TOKEN_CONTRACT
cleos push action $TOKEN_CONTRACT issue '["rick", "10000000.000 IQ", "init balance"]' -p $TOKEN_CONTRACT
cleos push action $TOKEN_CONTRACT transfer '["rick", "daiqcontract", "1000.000 IQ", "deposit"]' -p rick

# verify that balances have entry for tracking rick's tokens
cleos get table $CONTRACT "IQ" accounts # verify first run

# verify second run
# cleos get table $CONTRACT "USD" accounts
# cleos get table $CONTRACT "EOS" accounts
# cleos get table $CONTRACT "FUD" cdp

#=================================================================================#
# SHUT...uncomment all other actions below to test this
#echo "=== Closing CDP  ==="
#cleos push action $CONTRACT shut '["rick", "FUD"]' -p rick

# verify that rick's cdp was in fact shut
#cleos get table $CONTRACT "FUD" cdp

#=================================================================================#
# PROPOSE
echo "=== Proposing new CDP type  ==="

cleos push action $CONTRACT propose '["rick", "FUD", "EOS", "USD", 2000, 2000000000, 50, 10, 20, 150, 30, 5, "dick"]' -p rick

#propose global settlement 
#cleos push action $CONTRACT propose '["rick", "FUD", "EOS", "USD", 0, 0, 0, 0, 0, 0, 0, 0, "dick"]' -p rick

# verify that stats have temporary entry for storing rick's proposed cdp type
cleos get table $CONTRACT rick stat

#=================================================================================#
# VOTE
echo "=== Voting FOR proposal ===" 

cleos push action $CONTRACT vote '["rick", "FUD", false, "0.001 IQ" ]' -p rick

# vote against the proposal, for testing tie
#cleos push action $CONTRACT vote '["rick", "FUD", true, "0.001 IQ" ]' -p rick

# verify that balances have entry for tracking rick's vote
cleos get table $CONTRACT "FUD" accounts
cleos get table $CONTRACT $CONTRACT prop

echo "=== Waiting for referendum... ==="
# wait for referended to get called automatically via deferred transaction
sleep 10

# or call referended manually...
#cleos push action $CONTRACT referended '["rick", "FUD"]' -p daiqcontract

# for tie
#cleos push action $CONTRACT vote '["rick", "FUD", true, "0.002 IQ" ]' -p rick
#sleep 10

# verify that the vote tokens were refunded to rick after referended
cleos get table $CONTRACT "FUD" accounts
# verify that prop entry was deleted
cleos get table $CONTRACT $CONTRACT prop
# verify that stat entry for this cdp type was referended into existence
cleos get table $CONTRACT $CONTRACT stat

#=================================================================================#
# CREATE PRICE FEEDS
echo "=== Creating price feeds ==="

cleos push action $CONTRACT upfeed '["dick", "1.00 USD", "FUD", "EOS"]' -f -p dick
cleos push action $CONTRACT upfeed '["daiqcontract", "1.00 USD", "FUD", "IQ"]' -f -p daiqcontract
cleos push action $CONTRACT upfeed '["daiqcontract", "1.00 USD", "FUD", "USD"]' -f -p daiqcontract

# verify that price was updated
cleos get table $CONTRACT $CONTRACT feed

#=================================================================================#
# GIVE
#echo "=== Giving CDP  to dick==="

#cleos push action $CONTRACT give '["rick", "dick" "FUD"]' -p rick
# verify that rick's cdp was transfered to dick
#cleos get table $CONTRACT "FUD" cdp

#echo "=== Giving CDP back to rick  ==="
#cleos push action $CONTRACT open '["dick", "FUD", "dick"]' -p dick
#cleos push action $CONTRACT give '["dick", "rick" "FUD"]' -p dick

# OPEN
cleos push action $CONTRACT open '["rick", "FUD", "rick"]' -p rick

# verify that dick's cdp was transfered back to rick
cleos get table $CONTRACT "FUD" cdp

#=================================================================================#
# LOCK
echo "=== Push collateral ==="

cleos push action $CONTRACT lock '["rick", "FUD", "6.0000 EOS"]' -p rick

# verify that rick's clatrl balance was updated
cleos get table $CONTRACT "EOS" accounts
# verify that clatrl amount was pushed
cleos get table $CONTRACT "FUD" cdp

#=================================================================================#
# DRAW
echo "=== Pull Dai ==="

cleos push action $CONTRACT draw '["rick", "FUD", "4.00 USD"]' -p rick

# verify that stabl amount was pulled
cleos get table $CONTRACT "FUD" cdp
# verify that rick's stabl balance was updated
cleos get table $CONTRACT "USD" accounts

#=================================================================================#
# WIPE 
echo "=== Push Dai ==="

cleos push action $CONTRACT wipe '["rick", "FUD", "2.00 USD", "0.001 IQ"]' -p rick

# verify that stabl amount was pushed
cleos get table $CONTRACT "FUD" cdp
#verify that rick's stabl balance was updated
cleos get table $CONTRACT "USD" accounts

#=================================================================================#
#BAIL
echo "=== Pull collateral ==="

cleos push action $CONTRACT bail '["rick", "FUD", "1.0000 EOS"]' -p rick

# verify that clatrl amount was pulled
cleos get table $CONTRACT "FUD" cdp
# verify that rick's clatrl balance was updated
cleos get table $CONTRACT "EOS" accounts

sleep 2

#=================================================================================#
# UPDATE EOS PRICE FEED - DOWN
echo "=== Make EOS price go down ==="

cleos push action $CONTRACT upfeed '["dick", "0.01 USD", "FUD", "EOS"]' -f -p dick

#=================================================================================#
# LIQUIFY
echo "=== Liquifying rick's cdp ==="

cleos get table $CONTRACT "FUD" cdp
#verify rick's balances during liquidation
cleos get table $CONTRACT "USD" accounts


cleos push action $CONTRACT liquify '["dick", "rick", "FUD", "2.25 USD"]' -p dick
sleep 1
cleos push action $CONTRACT liquify '["dick", "rick", "FUD", "2.75 USD"]' -p dick

# wait for round to expire and switch to selling off IQ for the remaining balance
echo "=== First round auction done, waiting for round to expire... ==="
cleos get table $CONTRACT "FUD" cdp
sleep 5

# in order to test round 3, change the amount here to and uncomment below
cleos push action $CONTRACT liquify '["dick", "rick", "FUD", "0.25 USD"]' -p dick
sleep 5

echo "=== Second round auction mid ==="
#cleos get table $CONTRACT "FUD" cdp

#cleos push action $CONTRACT liquify '["dick", "rick", "FUD", "1.00 USD"]' -p dick

# auction covered more than the cdp debt, proceed to take bids in IQ for the diff
# echo "=== Second round auction done, waiting for round to expire... ==="
# cleos get table $CONTRACT "FUD" cdp
# sleep 5

# cleos push action $CONTRACT liquify '["dick", "rick", "FUD", "0.200 IQ"]' -p dick
# sleep 1
# cleos push action $CONTRACT liquify '["dick", "rick", "FUD", "0.400 IQ"]' -p dick
# sleep 1

# echo "=== Third round auction mid ==="
# cleos get table $CONTRACT "FUD" cdp

# cleos push action $CONTRACT liquify '["dick", "rick", "FUD", "0.500 IQ"]' -p dick

# echo "=== Third round auction done, balance closed ==="

#verify that bid entry and cdp were in fact erased
cleos get table $CONTRACT "FUD" cdp
cleos get table $CONTRACT "FUD" bid
#verify rick's balances after liquidation
cleos get table $CONTRACT "USD" accounts
cleos get table $CONTRACT "EOS" accounts
cleos get table $CONTRACT "IQ" accounts

#=================================================================================#
# SETTLE
echo "=== Global settlement ==="

cleos push action $CONTRACT settle '["FUD"]' -p daiqcontract
#verify that FUD cdp type is not live
cleos get table $CONTRACT $CONTRACT stat

# Exit on success
exit 0