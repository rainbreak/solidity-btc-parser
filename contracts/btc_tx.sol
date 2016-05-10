// Bitcoin transaction parsing library

// https://en.bitcoin.it/wiki/Protocol_documentation#tx
//
// Raw Bitcoin transaction structure:
//
// field     | size | type     | description
// version   | 4    | int32    | transaction version number
// n_tx_in   | 1-9  | var_int  | number of transaction inputs
// tx_in     | 41+  | tx_in[]  | list of transaction inputs
// n_tx_out  | 1-9  | var_int  | number of transaction outputs
// tx_out    | 9+   | tx_out[] | list of transaction outputs
// lock_time | 4    | uint32   | block number / timestamp at which tx locked
//
// Transaction input (tx_in) structure:
//
// field      | size | type     | description
// previous   | 36   | outpoint | Previous output transaction reference
// script_len | 1-9  | var_int  | Length of the signature script
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
// pk_script_len | 1-9  | var_int  | Length of the public key script
// pk_script     | ?    | uchar[]  | Public key as a Bitcoin script.
//
// Variable integers (var_int) can be encoded differently depending
// on the represented value, to save space. Variable integers always
// precede an array of a variable length data type (e.g. tx_in).
//
// Variable integer encodings as a function of represented value:
//
// value           | bytes  | format
// <0xFD (253)     | 1      | uint8
// <=0xFFFF (65535)| 3      | 0xFD followed by length as uint16
// <=0xFFFF FFFF   | 5      | 0xFE followed by length as uint32
// -               | 9      | 0xFF followed by length as uint64
//
// Public key scripts `pk_script` are set on the output and can
// take a number of forms. The regular transaction script is
// called 'pay-to-pubkey-hash':
//
// OP_DUP OP_HASH160 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
//
// OP_x are Bitcoin script opcodes. The bytes representation is:
//
// 0x76 0xA9 0x14 <pubKeyHash> 0x88 0xAC
//
// The <pubKeyHash> is the ripemd160 hash of the sha256 hash of
// the public key, preceded by a network version byte. (21 bytes total)
//
// Network version bytes: 0x00 (mainnet); 0x6f (testnet); 0x34 (namecoin)
//
// The Bitcoin address is derived from the pubKeyHash. The binary form is the
// pubKeyHash, plus a checksum at the end.  The checksum is the first 4 bytes
// of the (32 byte) double sha256 of the pubKeyHash. (25 bytes total)
// This is converted to base58 to form the publicly used Bitcoin address.

// parse a raw bitcoin transaction byte array
contract BTCTxParser {
    uint constant BYTES_1 = 2 ** 8;
    uint constant BYTES_2 = 2 ** 16;
    uint constant BYTES_3 = 2 ** 24;
    uint constant BYTES_4 = 2 ** 32;
    uint constant BYTES_5 = 2 ** 40;
    uint constant BYTES_6 = 2 ** 48;
    uint constant BYTES_7 = 2 ** 56;
    // Convert a variable integer into something useful and return it and
    // the index to after it.
    function parseVarInt(bytes txBytes, uint pos) returns (uint, uint) {
        // the first byte tells us how big the integer is
        var ibit = uint8(txBytes[pos]);
        pos += 1;  // skip ibit

        if (ibit < 0xfd) {
            return (ibit, pos);
        } else if (ibit == 0xfd) {
            return (getBytesLE(txBytes, pos, 16), pos + 2);
        } else if (ibit == 0xfe) {
            return (getBytesLE(txBytes, pos, 32), pos + 4);
        } else if (ibit == 0xff) {
            return (getBytesLE(txBytes, pos, 64), pos + 8);
        }
    }
    // convert little endian bytes to uint
    function getBytesLE(bytes data, uint pos, uint bits) returns (uint) {
        if (bits == 8) {
            return uint8(data[pos]);
        } else if (bits == 16) {
            return uint16(data[pos])
                 + uint16(data[pos + 1]) * BYTES_1;
        } else if (bits == 32) {
            return uint32(data[pos])
                 + uint32(data[pos + 1]) * BYTES_1
                 + uint32(data[pos + 2]) * BYTES_2
                 + uint32(data[pos + 3]) * BYTES_3;
        } else if (bits == 64) {
            return uint64(data[pos])
                 + uint64(data[pos + 1]) * BYTES_1
                 + uint64(data[pos + 2]) * BYTES_2
                 + uint64(data[pos + 3]) * BYTES_3
                 + uint64(data[pos + 4]) * BYTES_4
                 + uint64(data[pos + 5]) * BYTES_5
                 + uint64(data[pos + 6]) * BYTES_6
                 + uint64(data[pos + 7]) * BYTES_7;
        }
    }
    // scan the full transaction bytes and return the first two output
    // values (in satoshis) and addresses (in binary)
    function getFirstTwoOutputs(bytes txBytes)
             returns (uint, bytes20, uint, bytes20)
    {
        uint pos;
        uint[] memory input_script_lens = new uint[](2);
        uint[] memory output_script_lens = new uint[](2);
        uint[] memory script_starts = new uint[](2);
        uint[] memory output_values = new uint[](2);
        bytes20[] memory output_addresses = new bytes20[](2);

        pos = 4;  // skip version

        (input_script_lens, pos) = scanInputs(txBytes, pos, 0);

        (output_values, script_starts, output_script_lens, pos) = scanOutputs(txBytes, pos, 2);

        for (uint i = 0; i < 2; i++) {
            var pkhash = parseOutputScript(txBytes, script_starts[i], output_script_lens[i]);
            output_addresses[i] = pkhash;
        }

        return (output_values[0], output_addresses[0],
                output_values[1], output_addresses[1]);
    }
    // Check whether `btcAddress` is in the transaction outputs *and*
    // whether *at least* `value` has been sent to it.
    function checkValueSent(bytes txBytes, bytes20 btcAddress, uint value)
             returns (bool)
    {
        var (value1, address1, value2, address2) = getFirstTwoOutputs(txBytes);
        if (btcAddress == address1 && value1 >= value) {
            return true;
        } else if (btcAddress == address2 && value2 >= value) {
            return true;
        } else {
            return false;
        }
    }
    // scan the inputs and find the script lengths.
    // return an array of script lengths and the end position
    // of the inputs.
    // takes a 'stop' argument which sets the maximum number of
    // outputs to scan through. stop=0 => scan all.
    function scanInputs(bytes txBytes, uint pos, uint stop)
             returns (uint[], uint)
    {
        uint n_inputs;
        uint halt;
        uint script_len;

        (n_inputs, pos) = parseVarInt(txBytes, pos);

        if (stop == 0 || stop > n_inputs) {
            halt = n_inputs;
        } else {
            halt = stop;
        }

        uint[] memory script_lens = new uint[](halt);

        for (var i = 0; i < halt; i++) {
            pos += 36;  // skip outpoint
            (script_len, pos) = parseVarInt(txBytes, pos);
            script_lens[i] = script_len;
            pos += script_len + 4;  // skip sig_script, seq
        }

        return (script_lens, pos);
    }
    // scan the outputs and find the values and script lengths.
    // return array of values, array of script lengths and the
    // end position of the outputs.
    // takes a 'stop' argument which sets the maximum number of
    // outputs to scan through. stop=0 => scan all.
    function scanOutputs(bytes txBytes, uint pos, uint stop)
             returns (uint[], uint[], uint[], uint)
    {
        uint n_outputs;
        uint halt;
        uint script_len;

        (n_outputs, pos) = parseVarInt(txBytes, pos);

        if (stop == 0 || stop > n_outputs) {
            halt = n_outputs;
        } else {
            halt = stop;
        }

        uint[] memory script_starts = new uint[](halt);
        uint[] memory script_lens = new uint[](halt);
        uint[] memory output_values = new uint[](halt);

        for (var i = 0; i < halt; i++) {
            output_values[i] = getBytesLE(txBytes, pos, 64);
            pos += 8;

            (script_len, pos) = parseVarInt(txBytes, pos);
            script_starts[i] = pos;
            script_lens[i] = script_len;
            pos += script_len;
        }

        return (output_values, script_starts, script_lens, pos);
    }
    function assert(bool assertion) internal {
        if (!assertion) throw;
    }
    // Get the pubkeyhash from an output script. Assumes standard
    // pay-to-pubkey-hash (P2PKH) transaction, i.e. NOT P2SH / Multisig.
    // Returns the pubkeyhash and the end position of the script.
    function parseOutputScript(bytes txBytes, uint pos, uint script_len)
             returns (bytes20)
    {
        assert(txBytes[pos] == 0x76);       // OP_DUP
        assert(txBytes[pos + 1] == 0xa9);   // OP_HASH160
        assert(txBytes[pos + 2] == 0x14);   // bytes to push
        assert(script_len == 25);           // 20 byte pubkeyhash + 5 bytes of script
        assert(txBytes[pos + 23] == 0x88);  // OP_EQUALVERIFY
        assert(txBytes[pos + 24] == 0xac);  // OP_CHECKSIG

        // TODO: this is well inefficient to be doing every time
        Bytes160 BYTES160 = new Bytes160();

        uint160 pubkeyhash = 0;
        for (uint160 i = 0; i < 20; i++) {
            pubkeyhash += uint160(txBytes[i + pos + 3]) * BYTES160.get(i);
        }
        return bytes20(pubkeyhash);
    }
}

// library can't have non constant state variables and constant arrays
// are not yet supported, so create the precomputed powers array in a contract.
contract Bytes160 {
    uint160 constant BYTES_1 = 2 ** 8;
    uint160 constant BYTES_2 = 2 ** 16;
    uint160 constant BYTES_3 = 2 ** 24;
    uint160 constant BYTES_4 = 2 ** 32;
    uint160 constant BYTES_5 = 2 ** 40;
    uint160 constant BYTES_6 = 2 ** 48;
    uint160 constant BYTES_7 = 2 ** 56;
    uint160 constant BYTES_8 = 2 ** 64;
    uint160 constant BYTES_9 = 2 ** 72;
    uint160 constant BYTES_10 = 2 ** 80;
    uint160 constant BYTES_11 = 2 ** 88;
    uint160 constant BYTES_12 = 2 ** 96;
    uint160 constant BYTES_13 = 2 ** 104;
    uint160 constant BYTES_14 = 2 ** 112;
    uint160 constant BYTES_15 = 2 ** 120;
    uint160 constant BYTES_16 = 2 ** 128;
    uint160 constant BYTES_17 = 2 ** 136;
    uint160 constant BYTES_18 = 2 ** 144;
    uint160 constant BYTES_19 = 2 ** 152;

    uint160[20] public BYTES_160 = [BYTES_19,
                                    BYTES_18,
                                    BYTES_17,
                                    BYTES_16,
                                    BYTES_15,
                                    BYTES_14,
                                    BYTES_13,
                                    BYTES_12,
                                    BYTES_11,
                                    BYTES_10,
                                    BYTES_9,
                                    BYTES_8,
                                    BYTES_7,
                                    BYTES_6,
                                    BYTES_5,
                                    BYTES_4,
                                    BYTES_3,
                                    BYTES_2,
                                    BYTES_1,
                                    1];

    function get(uint i) constant returns (uint160){
        return BYTES_160[i];
    }
}
