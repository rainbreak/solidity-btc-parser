[![Build Status](https://api.travis-ci.org/rainbeam/solidity-btc-parser.svg?branch=master)](https://travis-ci.org/rainbeam/solidity-btc-parser)

## Bitcoin transaction parsing library for Solidity

This is a library of useful functions for dealing with raw Bitcoin
transaction bytes inside of Ethereum contracts written in Solidity.

It has been created with the intention of on-chain processing of
output from [BTC-relay][btcrelay].

[btcrelay]: https://github.com/ethereum/btcrelay

This library is still in development and should **not be relied
upon**. There are probably bugs and the API may change.


### Usage

Verify that the `raw_transaction` has an output sending at least
`value` to `btc_address`:

```
var success = BTC.checkValueSent(raw_transaction, btc_address, value);
success == true;
```

n.b. `btc_address` must be in binary form (not the standard Base58Check).

Both P2PKH (normal addresses beginning '1...') and P2SH ('3...')
outputs are supported.

There are other functions, but I'd only rely on `checkValueSent` for
now.

Important note: `checkValueSent` checks if there is *an output* that
sends *at least* `value` to `btc_address`. If there are multiple
outputs sending to the same address then they don't get added
together.
