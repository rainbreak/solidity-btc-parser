import 'dapple/test.sol';
import 'btc_tx.sol';

contract BTCTxTest is Test {
    BTCTxParser BTC;
    function setUp() {
        BTC = new BTCTxParser();
    }
    function testGetBytesLittleEndian8() {
        bytes memory data = new bytes(1);
        data[0] = 0xfa;
        var val = BTC.getBytesLE(data, 0, 8);
        assertEq(val, 250);
    }
    function testGetBytesLittleEndian16() {
        bytes memory data = new bytes(2);
        data[0] = 0x02;
        data[1] = 0x01;
        var val = BTC.getBytesLE(data, 0, 16);
        assertEq(val, 258);
    }
    function testGetBytesLittleEndian32() {
        bytes memory data = new bytes(4);
        data[0] = 0x04;
        data[1] = 0x03;
        data[2] = 0x02;
        data[3] = 0x01;
        var val = BTC.getBytesLE(data, 0, 32);
        assertEq(val, 16909060);
    }
    function testGetBytesLittleEndian64() {
        bytes memory data = new bytes(8);
        data[0] = 0x08;
        data[1] = 0x07;
        data[2] = 0x06;
        data[3] = 0x05;
        data[4] = 0x04;
        data[5] = 0x03;
        data[6] = 0x02;
        data[7] = 0x01;
        var val = BTC.getBytesLE(data, 0, 64);
        assertEq(val, 72623859790382856);
    }
    function testParseVarInt8() {
        bytes memory data = new bytes(1);
        data[0] = 0x00;
        var (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 0);
        assertEq(pos, 1);

        data[0] = 0xfc;
        (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 252);
    }
    function testParseVarInt16() {
        bytes memory data = new bytes(3);
        data[0] = 0xfd;
        var (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 0);
        assertEq(pos, 3);

        data[1] = 0x01;
        data[2] = 0x02;
        (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 513);
    }
    function testParseVarInt32() {
        bytes memory data = new bytes(5);
        data[0] = 0xfe;
        var (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 0);
        assertEq(pos, 5);

        data[3] = 0x01;
        data[4] = 0x02;
        (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 33619968);
    }
    function testParseVarInt64() {
        bytes memory data = new bytes(9);
        data[0] = 0xff;
        var (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 0);
        assertEq(pos, 9);

        data[7] = 0x01;
        data[8] = 0x02;
        (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 144396663052566528);
    }
    // check how solidity deals with partially decoded byte strings.
    // In Python, '\x' characters will be presented decoded if possible.
    function testSolidityBytesEquivalence() {
        // original hex: '01 5b 2b 99'
        bytes memory data = '\x01[+\x99';
        bytes memory raw_data = '\x01\x5b\x2b\x99';
        bytes memory array_data = new bytes(4);
        array_data[0] = 0x01;
        array_data[1] = 0x5b;
        array_data[2] = 0x2b;
        array_data[3] = 0x99;

        assertEq0(data, raw_data);
        assertEq0(data, array_data);
        assertEq0(raw_data, array_data);
    }
    function testGetFirstTwoOutputs() {
        // transaction data generated with ./generate_bitcoin_transaction.sh
        // txid: 015bb217e9b83dd5d9d1c26e856873ff10325fc77141a153cb1df2a43f3d1033
        // value: 12345678
        // value: 11223344
        // address: 1MaTeTiCCGFvgmZxK2R1pmD9LDWvkmU9BS
        // address: 16A81uRvSkHCn6Kpm7dLWM9Du9E9cwBPkM
        // script: OP_DUP OP_HASH160 e1b67c3a7f8977fac55a15dbdb19c7a175676d73 OP_EQUALVERIFY OP_CHECKSIG
        // script: OP_DUP OP_HASH160 38923a989763397163a08d5498d903a0b86b9ac9 OP_EQUALVERIFY OP_CHECKSIG
        bytes memory transaction = "\x01\x00\x00\x00\x01\xa5\x8c\xbb\xcb\xad\x45\x62\x5f\x5e\xd1\xf2\x04\x58\xf3\x93\xfe\x1d\x15\x07\xe2\x54\x26\x5f\x09\xd9\x74\x62\x32\xda\x48\x00\x24\x00\x00\x00\x00\x00\xff\xff\xff\xff\x02\x4e\x61\xbc\x00\x00\x00\x00\x00\x19\x76\xa9\x14\xe1\xb6\x7c\x3a\x7f\x89\x77\xfa\xc5\x5a\x15\xdb\xdb\x19\xc7\xa1\x75\x67\x6d\x73\x88\xac\x30\x41\xab\x00\x00\x00\x00\x00\x19\x76\xa9\x14\x38\x92\x3a\x98\x97\x63\x39\x71\x63\xa0\x8d\x54\x98\xd9\x03\xa0\xb8\x6b\x9a\xc9\x88\xac\x00\x00\x00\x00";

        var (ov1, oa1, ov2, oa2) = BTC.getFirstTwoOutputs(transaction);

        // expected output values in satoshis
        uint ev1 = 12345678;
        uint ev2 = 11223344;
        assertEq(uint(ov1), ev1);
        assertEq(uint(ov2), ev2);

        // expected addresses in binary
        bytes20 ea1 = "\xe1\xb6\x7c\x3a\x7f\x89\x77\xfa\xc5\x5a\x15\xdb\xdb\x19\xc7\xa1\x75\x67\x6d\x73";
        bytes20 ea2 = "\x38\x92\x3a\x98\x97\x63\x39\x71\x63\xa0\x8d\x54\x98\xd9\x03\xa0\xb8\x6b\x9a\xc9";
        assertEq20(oa1, ea1);
        assertEq20(oa2, ea2);
    }
    function testIdP2pkh() {
        bytes memory pk_script = "\x76\xa9\x14\xe1\xb6\x7c\x3a\x7f\x89\x77\xfa\xc5\x5a\x15\xdb\xdb\x19\xc7\xa1\x75\x67\x6d\x73\x88\xac";

        assertTrue(BTC.isP2PKH(pk_script, 0, 25));
        assertFalse(BTC.isP2PKH(pk_script, 0, 24));

        pk_script = "\x77\xa9\x14\xe1\xb6\x7c\x3a\x7f\x89\x77\xfa\xc5\x5a\x15\xdb\xdb\x19\xc7\xa1\x75\x67\x6d\x73\x88\xac";
        assertFalse(BTC.isP2PKH(pk_script, 0, 25));
    }
    function testFailIdShortP2pkh() {
        bytes memory pk_script = "\x76\xa9\x14";
        BTC.isP2PKH(pk_script, 0, 25);
    }
    function testParseOutputScript() logs_gas() {
        bytes memory pk_script = "\x76\xa9\x14\xe1\xb6\x7c\x3a\x7f\x89\x77\xfa\xc5\x5a\x15\xdb\xdb\x19\xc7\xa1\x75\x67\x6d\x73\x88\xac";
        bytes20 rpkhash = bytes20("\xe1\xb6\x7c\x3a\x7f\x89\x77\xfa\xc5\x5a\x15\xdb\xdb\x19\xc7\xa1\x75\x67\x6d\x73");

        var pkhash = BTC.parseOutputScript(pk_script, 0, 25);

        assertEq20(pkhash, rpkhash);
    }
    function testCheckValueSent() logs_gas() {
        // same transaction as in testGetFirstTwoOutputs
        bytes memory transaction = "\x01\x00\x00\x00\x01\xa5\x8c\xbb\xcb\xad\x45\x62\x5f\x5e\xd1\xf2\x04\x58\xf3\x93\xfe\x1d\x15\x07\xe2\x54\x26\x5f\x09\xd9\x74\x62\x32\xda\x48\x00\x24\x00\x00\x00\x00\x00\xff\xff\xff\xff\x02\x4e\x61\xbc\x00\x00\x00\x00\x00\x19\x76\xa9\x14\xe1\xb6\x7c\x3a\x7f\x89\x77\xfa\xc5\x5a\x15\xdb\xdb\x19\xc7\xa1\x75\x67\x6d\x73\x88\xac\x30\x41\xab\x00\x00\x00\x00\x00\x19\x76\xa9\x14\x38\x92\x3a\x98\x97\x63\x39\x71\x63\xa0\x8d\x54\x98\xd9\x03\xa0\xb8\x6b\x9a\xc9\x88\xac\x00\x00\x00\x00";

        bytes20 address1 = "\xe1\xb6\x7c\x3a\x7f\x89\x77\xfa\xc5\x5a\x15\xdb\xdb\x19\xc7\xa1\x75\x67\x6d\x73";
        bytes20 address2 = "\x38\x92\x3a\x98\x97\x63\x39\x71\x63\xa0\x8d\x54\x98\xd9\x03\xa0\xb8\x6b\x9a\xc9";

        assertTrue(BTC.checkValueSent(transaction, address1, 1000));
        assertTrue(BTC.checkValueSent(transaction, address2, 1000));
        assertTrue(BTC.checkValueSent(transaction, address1, 12345678));
        assertTrue(BTC.checkValueSent(transaction, address2, 11223344));
        assertFalse(BTC.checkValueSent(transaction, address1, 12345679));
        assertFalse(BTC.checkValueSent(transaction, address2, 11223345));
    }
    function testCheckValueSentMulti() logs_gas {
        bytes memory transaction = "\x01\x00\x00\x00\x01\xa5\x8c\xbb\xcb\xad\x45\x62\x5f\x5e\xd1\xf2\x04\x58\xf3\x93\xfe\x1d\x15\x07\xe2\x54\x26\x5f\x09\xd9\x74\x62\x32\xda\x48\x00\x24\x00\x00\x00\x00\x00\xff\xff\xff\xff\x05\x4e\x61\xbc\x00\x00\x00\x00\x00\x19\x76\xa9\x14\xcb\xb3\x82\x98\x56\xd7\x7a\x8b\x65\xb1\xbd\x95\xdc\xd3\x25\x4d\x5e\xa2\xcc\x14\x88\xac\x30\x41\xab\x00\x00\x00\x00\x00\x19\x76\xa9\x14\x15\x88\xd7\x22\xa2\xa4\x52\xb5\xf4\x8b\x23\x54\x06\xdb\x35\x6a\x72\xd6\xf9\xf6\x88\xac\x55\xa0\xfc\x01\x00\x00\x00\x00\x19\x76\xa9\x14\xed\xd1\xd8\x73\xc4\x79\x67\x48\xb7\x3e\x19\xda\xa5\x7f\xca\x3b\xa4\x9d\xab\x62\x88\xac\x1c\x2b\xa6\x02\x00\x00\x00\x00\x19\x76\xa9\x14\x50\xf8\x7c\x16\x81\x08\x96\xe9\x9e\x2c\xeb\x18\x6e\xcc\x68\xd9\xc7\x5b\x7e\x6b\x88\xac\xe3\xb5\x4f\x03\x00\x00\x00\x00\x19\x76\xa9\x14\x7d\x23\x10\xb8\xc6\xcb\x53\x85\x71\xdb\xc5\x17\x0d\xcc\x58\x2c\x5f\x32\xa4\x4c\x88\xac\x00\x00\x00\x00";

        bytes20 address1 = "\xcb\xb3\x82\x98\x56\xd7\x7a\x8b\x65\xb1\xbd\x95\xdc\xd3\x25\x4d\x5e\xa2\xcc\x14";
        bytes20 address2 = "\x15\x88\xd7\x22\xa2\xa4\x52\xb5\xf4\x8b\x23\x54\x06\xdb\x35\x6a\x72\xd6\xf9\xf6";
        bytes20 address3 = "\xed\xd1\xd8\x73\xc4\x79\x67\x48\xb7\x3e\x19\xda\xa5\x7f\xca\x3b\xa4\x9d\xab\x62";
        bytes20 address4 = "\x50\xf8\x7c\x16\x81\x08\x96\xe9\x9e\x2c\xeb\x18\x6e\xcc\x68\xd9\xc7\x5b\x7e\x6b";
        bytes20 address5 = "\x7d\x23\x10\xb8\xc6\xcb\x53\x85\x71\xdb\xc5\x17\x0d\xcc\x58\x2c\x5f\x32\xa4\x4c";

        assertTrue(BTC.checkValueSent(transaction, address1, 1));
        assertTrue(BTC.checkValueSent(transaction, address2, 1));
        assertTrue(BTC.checkValueSent(transaction, address3, 1));
        assertTrue(BTC.checkValueSent(transaction, address4, 1));
        assertTrue(BTC.checkValueSent(transaction, address5, 1));

        assertTrue(BTC.checkValueSent(transaction, address4, 44444444));
        assertTrue(BTC.checkValueSent(transaction, address5, 55555555));

        assertFalse(BTC.checkValueSent(transaction, address4, 44444445));
        assertFalse(BTC.checkValueSent(transaction, address5, 55555556));
    }
}
