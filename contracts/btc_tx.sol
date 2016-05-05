// Bitcoin transaction parsing library

// https://en.bitcoin.it/wiki/Protocol_documentation#tx
//
// Raw Bitcoin transaction structure:
//
// field     | size | type     | description
// version   | 4    | int32    | transaction version number
// n_tx_in   | 1+   | var_int  | number of transaction inputs
// tx_in     | 41+  | tx_in[]  | list of transaction inputs
// n_tx_out  | 1+   | var_int  | number of transaction outputs
// tx_out    | 9+   | tx_out[] | list of transaction outputs
// lock_time | 4    | uint32   | block number / timestamp at which tx locked
//
// Transaction input (tx_in) structure:
//
// field      | size | type     | description
// previous   | 36   | outpoint | Previous output transaction reference
// script_len | 1+   | var_int  | Length of the signature script
// sig_script | ?    | uchar[]  | Script for confirming transaction authorization
// sequence   | 4    | uint32   | Sender transaction version
//
// OutPoint structure:
//
// field      | size | type     | description
// hash       | 32   | char[32] | The hash of the referenced transaction
// index      | 4    | uint32   | The index of this output in the referenced transaction
//
// Transaction output (tx_out) structure:
//
// field         | size | type     | description
// value         | 8    | int64    | Transaction value (Satoshis)
// pk_script_len | 1+   | var_int  | Length of the public key script
// pk_script     | ?    | uchar[]  | Public key as a Bitcoin script.
//
// Variable integers (var_int) can be encoded differently depending
// on the represented value, to save space. Variable integers always
// precede an array of a variable length data type (e.g. tx_in).
//
// Variable integer encodings as a function of represented value:
//
// value           | storage length (hex)  | format
// <0xFD (253)     | 1                     | uint8
// <=0xFFFF (65535)| 3                     | 0xFD followed by length as uint16
// <=0xFFFF FFFF   | 5                     | 0xFE followed by length as uint32
// -               | 9                     | 0xFF followed by length as uint64

// parse a raw bitcoin transaction byte array
library BTC {
    // Convert a variable integer into something useful and return it and
    // the index to after it.
    function parseVarInt(bytes txBytes, uint pos) returns (uint, uint) {
        // the first byte tells us how big the integer is
        var ibit = uint8(txBytes[pos]);
        pos += 1;  // skip ibit

        if (ibit < 0xfd) {
            return (ibit, pos);
        } else if (ibit == 0xfd) {
            return (getBytesLE(txBytes, pos, 16), pos + 3);
        } else if (ibit == 0xfe) {
            return (getBytesLE(txBytes, pos, 32), pos + 5);
        } else if (ibit == 0xff) {
            return (getBytesLE(txBytes, pos, 64), pos + 9);
        }
    }
    // convert little endian bytes to uint
    function getBytesLE(bytes data, uint pos, uint bits) returns (uint) {
        if (bits == 16) {
            return uint(data[pos])
                 + uint(data[pos + 1]) * 2**8;
        } else if (bits == 32) {
            return uint(data[pos])
                 + uint(data[pos + 1]) * 2 ** 8
                 + uint(data[pos + 2]) * 2 ** 16
                 + uint(data[pos + 3]) * 2 ** 24;
        } else if (bits == 64) {
            return uint(data[pos])
                 + uint(data[pos + 1]) * 2 ** 8
                 + uint(data[pos + 2]) * 2 ** 16
                 + uint(data[pos + 3]) * 2 ** 24
                 + uint(data[pos + 4]) * 2 ** 32
                 + uint(data[pos + 5]) * 2 ** 40
                 + uint(data[pos + 6]) * 2 ** 48
                 + uint(data[pos + 6]) * 2 ** 56;
        }
    }
    function getFirstTwoOutputs(bytes txBytes) {
        uint pos;
        uint n_inputs;
        uint n_outputs;
        uint script_len;

        pos = 4;  // skip version

        (n_inputs, pos) = parseVarInt(txBytes, pos);

        for (var i = 0; i < n_inputs; i++) {
            pos += 36;  // skip outpoint
            (script_len, pos) = parseVarInt(txBytes, pos);
            pos += script_len + 4;  // skip sig_script, seq
        }

        (n_outputs, pos) = parseVarInt(txBytes, pos);

        if (n_outputs < 2) {
            return;
        }

    }

}
