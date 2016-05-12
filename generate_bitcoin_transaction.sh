#!/bin/bash
#
# generate a fake bitcoin transaction
#
# This is free and unencumbered software released into the public domain.
#
# Requires bc, dc, openssl, xxd, bitcoin-tx
#
# Originally by grondilu from https://bitcointalk.org/index.php?topic=10970.msg156708#msg156708
# Modified by rainbeam

base58=({1..9} {A..H} {J..N} {P..Z} {a..k} {m..z})
bitcoinregex="^[$(printf "%s" "${base58[@]}")]{34}$"

if [ `uname -s` = 'Darwin' ]; then
  TAC="tail -r "
else
  TAC="tac"
fi

decodeBase58() {
    local s=$1
    for i in {0..57}
    do s="${s//${base58[i]}/ $i}"
    done
    dc <<< "16o0d${s// /+58*}+f"
}

encodeBase58() {
    # 58 = 0x3A
    bc <<<"ibase=16; n=${1^^}; while(n>0) { n%3A ; n/=3A }" | #it's still throwing an error here on osx
    $TAC |
    while read n
    do echo -n ${base58[n]}
    done
}

checksum() {
    xxd -p -r <<<"$1" |
    openssl dgst -sha256 -binary |
    openssl dgst -sha256 -binary |
    xxd -p -c 80 |
    head -c 8
}

checkBitcoinAddress() {
    if [[ "$1" =~ $bitcoinregex ]]
    then
        h=$(decodeBase58 "$1")
        checksum "00${h::${#h}-8}" |
        grep -qi "^${h: -8}$"
    else return 2
    fi
}

hash160() {
    openssl dgst -sha256 -binary |
    openssl dgst -rmd160 -binary |
    xxd -p -c 80
}

hash160ToAddress() {
    printf "%34s\n" "$(encodeBase58 "00$1$(checksum "00$1")")" |
    sed "y/ /1/"
}

publicKeyToAddress() {
    hash160ToAddress $(
    openssl ec -pubin -pubout -outform DER |
    tail -c 65 |
    hash160
    )
}

newBitcoinAddress() {
    openssl ecparam -name secp256k1 -genkey | openssl ec -pubout | publicKeyToAddress
}

newTxHash() {
    echo 'fake tx' | openssl dgst -sha256 -binary | xxd -p | tr -d '\n'
}

newTransaction() {
    bitcoin-tx -create -json \
        in=$(newTxHash):0 \
        outaddr=$1:$(newBitcoinAddress) \
        outaddr=$2:$(newBitcoinAddress)
}

hexLiteral() {
    sed 's/../\\x\0/g'
}

# redirect openssl stderr to null
tx=$(newTransaction ${1:-0.12345678} ${2:-0.11223344} 2> /dev/null)

# create \x escaped hex string and insert as additional element
tx_hex_literal=$(echo $tx | jq -r .hex | hexLiteral)
txid_hex_literal=$(echo $tx | jq -r .txid | hexLiteral)

tx_hexl=$(echo $tx | jq --arg hexl $tx_hex_literal --arg txidl $txid_hex_literal '. + {$hexl} + {$txidl}')

echo $tx_hexl | jq -r '@text "txid: \(.txid)",
                       @text "txid literal: \(.txidl)",
                       @text "value: \(.vout[].value * 1E8)",
                       @text "address: \(.vout[].scriptPubKey.addresses[0])",
                       @text "script: \(.vout[].scriptPubKey.asm)",
                       @text "hex: \(.hex)",
                       @text "hex literal: \(.hexl)"'
