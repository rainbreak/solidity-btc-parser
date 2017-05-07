pragma solidity ^0.4.11;

import 'ds-test/test.sol';
import './btc_tx.sol';

contract BasicParseTest is DSTest {
    function testGetBytesLittleEndian8() {
        bytes memory data = hex"fa";
        var val = BTC.getBytesLE(data, 0, 8);
        assertEq(val, 250);
    }
    function testGetBytesLittleEndian16() {
        bytes memory data = hex"0201";
        var val = BTC.getBytesLE(data, 0, 16);
        assertEq(val, 258);
    }
    function testGetBytesLittleEndian32() {
        bytes memory data = hex"04030201";
        var val = BTC.getBytesLE(data, 0, 32);
        assertEq(val, 16909060);
    }
    function testGetBytesLittleEndian64() {
        bytes memory data = hex"0807060504030201";
        var val = BTC.getBytesLE(data, 0, 64);
        assertEq(val, 72623859790382856);
    }
    function testParseVarInt8() {
        bytes memory data = hex"00";
        var (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 0);
        assertEq(pos, 1);

        data = hex"fc";
        (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 252);
    }
    function testParseVarInt16() {
        bytes memory data = hex"fd0000";
        var (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 0);
        assertEq(pos, 3);

        data = hex"fd0102";
        (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 513);
    }
    function testParseVarInt32() {
        bytes memory data = hex"fe00000000";
        var (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 0);
        assertEq(pos, 5);

        data = hex"fe00000102";
        (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 33619968);
    }
    function testParseVarInt64() {
        bytes memory data = hex"ff0000000000000000";
        var (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 0);
        assertEq(pos, 9);

        data = hex"ff0000000000000102";
        (val, pos) = BTC.parseVarInt(data, 0);
        assertEq(val, 144396663052566528);
    }
}

contract SolidityTest is DSTest {
    // check how solidity deals with partially decoded byte strings.
    // In Python, '\x' characters will be presented decoded if possible.
    function testSolidityBytesEquivalence() {
        // original hex: '01 5b 2b 99'
        bytes memory data = '\x01[+\x99';
        bytes memory raw_data = '\x01\x5b\x2b\x99';
        bytes memory hex_data = hex"015b2b99";

        assertEq0(data,     raw_data);
        assertEq0(data,     hex_data);
        assertEq0(raw_data, hex_data);
    }
}

contract BTCTxTest is DSTest {
    function testGetFirstTwoOutputs() {
        // transaction data generated with ./generate_bitcoin_transaction.sh
        // txid: 015bb217e9b83dd5d9d1c26e856873ff10325fc77141a153cb1df2a43f3d1033
        // value: 12345678
        // value: 11223344
        // address: 1MaTeTiCCGFvgmZxK2R1pmD9LDWvkmU9BS
        // address: 16A81uRvSkHCn6Kpm7dLWM9Du9E9cwBPkM
        // script: OP_DUP OP_HASH160 e1b67c3a7f8977fac55a15dbdb19c7a175676d73 OP_EQUALVERIFY OP_CHECKSIG
        // script: OP_DUP OP_HASH160 38923a989763397163a08d5498d903a0b86b9ac9 OP_EQUALVERIFY OP_CHECKSIG
        bytes memory transaction = hex"0100000001a58cbbcbad45625f5ed1f20458f393fe1d1507e254265f09d9746232da4800240000000000ffffffff024e61bc00000000001976a914e1b67c3a7f8977fac55a15dbdb19c7a175676d7388ac3041ab00000000001976a91438923a989763397163a08d5498d903a0b86b9ac988ac00000000";

        var (ov1, oa1, ov2, oa2) = BTC.getFirstTwoOutputs(transaction);

        // expected output values in satoshis
        uint ev1 = 12345678;
        uint ev2 = 11223344;
        assertEq(uint(ov1), ev1);
        assertEq(uint(ov2), ev2);

        // expected addresses in binary
        bytes20 ea1 = hex"e1b67c3a7f8977fac55a15dbdb19c7a175676d73";
        bytes20 ea2 = hex"38923a989763397163a08d5498d903a0b86b9ac9";
        assertEq(oa1, ea1);
        assertEq(oa2, ea2);
    }
    function testIdP2pkh() {
        bytes memory pk_script = hex"76a914e1b67c3a7f8977fac55a15dbdb19c7a175676d7388ac";

        assert(BTC.isP2PKH(pk_script, 0, 25));
        assert(!BTC.isP2PKH(pk_script, 0, 24));
        assert(!BTC.isP2PKH(pk_script, 0, 26));

        pk_script = hex"77a914e1b67c3a7f8977fac55a15dbdb19c7a175676d7388ac";
        assert(!BTC.isP2PKH(pk_script, 0, 25));
    }
    function testFailIdShortP2pkh() {
        bytes memory pk_script = hex"76a914";
        BTC.isP2PKH(pk_script, 0, 25);
    }
    function testParseP2pkhOutputScript() logs_gas() {
        bytes memory pk_script = hex"76a914e1b67c3a7f8977fac55a15dbdb19c7a175676d7388ac";
        bytes20 rpkhash = hex"e1b67c3a7f8977fac55a15dbdb19c7a175676d73";

        var pkhash = BTC.parseOutputScript(pk_script, 0, 25);

        assertEq(pkhash, rpkhash);
    }
    // all p2sh example data from http://www.soroushjp.com/2014/12/20/bitcoin-multisig-the-hard-way-understanding-raw-multisignature-bitcoin-transactions
    function testIdP2sh() {
        bytes memory script = hex"a9141a8b0026343166625c7475f01e48b5ede8c0252e87";

        assert(BTC.isP2SH(script, 0, 23));
        assert(!BTC.isP2SH(script, 0, 22));
        assert(!BTC.isP2SH(script, 0, 24));

        script = hex"a9151a8b0026343166625c7475f01e48b5ede8c0252e87";
        assert(!BTC.isP2SH(script, 0, 23));
    }
    function testFailIdShortP2sh() {
        bytes memory script = hex"a9141a8b0026343166625c7475f01e48b5ede8c0252e";
        BTC.isP2SH(script, 0, 23);
    }
    function testParseP2shOutputScript() {
        bytes memory script = hex"a9141a8b0026343166625c7475f01e48b5ede8c0252e87";
        bytes20 rscript_hash = hex"1a8b0026343166625c7475f01e48b5ede8c0252e";

        var script_hash = BTC.parseOutputScript(script, 0, 23);

        assertEq(script_hash, rscript_hash);
    }
    function testCheckValueSentP2pkh() logs_gas() {
        // same transaction as in testGetFirstTwoOutputs
        bytes memory transaction = hex"0100000001a58cbbcbad45625f5ed1f20458f393fe1d1507e254265f09d9746232da4800240000000000ffffffff024e61bc00000000001976a914e1b67c3a7f8977fac55a15dbdb19c7a175676d7388ac3041ab00000000001976a91438923a989763397163a08d5498d903a0b86b9ac988ac00000000";

        bytes20 address1 = hex"e1b67c3a7f8977fac55a15dbdb19c7a175676d73";
        bytes20 address2 = hex"38923a989763397163a08d5498d903a0b86b9ac9";

        assert(BTC.checkValueSent(transaction, address1, 1000));
        assert(BTC.checkValueSent(transaction, address2, 1000));
        assert(BTC.checkValueSent(transaction, address1, 12345678));
        assert(BTC.checkValueSent(transaction, address2, 11223344));
        assert(!BTC.checkValueSent(transaction, address1, 12345679));
        assert(!BTC.checkValueSent(transaction, address2, 11223345));
    }
    function testCheckValueSentMultiP2pkh() logs_gas {
        bytes memory transaction = hex"0100000001a58cbbcbad45625f5ed1f20458f393fe1d1507e254265f09d9746232da4800240000000000ffffffff054e61bc00000000001976a914cbb3829856d77a8b65b1bd95dcd3254d5ea2cc1488ac3041ab00000000001976a9141588d722a2a452b5f48b235406db356a72d6f9f688ac55a0fc01000000001976a914edd1d873c4796748b73e19daa57fca3ba49dab6288ac1c2ba602000000001976a91450f87c16810896e99e2ceb186ecc68d9c75b7e6b88ace3b54f03000000001976a9147d2310b8c6cb538571dbc5170dcc582c5f32a44c88ac00000000";

        bytes20 address1 = hex"cbb3829856d77a8b65b1bd95dcd3254d5ea2cc14";
        bytes20 address2 = hex"1588d722a2a452b5f48b235406db356a72d6f9f6";
        bytes20 address3 = hex"edd1d873c4796748b73e19daa57fca3ba49dab62";
        bytes20 address4 = hex"50f87c16810896e99e2ceb186ecc68d9c75b7e6b";
        bytes20 address5 = hex"7d2310b8c6cb538571dbc5170dcc582c5f32a44c";

        assert(BTC.checkValueSent(transaction, address1, 1));
        assert(BTC.checkValueSent(transaction, address2, 1));
        assert(BTC.checkValueSent(transaction, address3, 1));
        assert(BTC.checkValueSent(transaction, address4, 1));
        assert(BTC.checkValueSent(transaction, address5, 1));

        assert(BTC.checkValueSent(transaction, address4, 44444444));
        assert(BTC.checkValueSent(transaction, address5, 55555555));

        assert(!BTC.checkValueSent(transaction, address4, 44444445));
        assert(!BTC.checkValueSent(transaction, address5, 55555556));
    }
    function testCheckValueSentP2sh() {
        bytes memory transaction = hex"0100000001acc6fb9ec2c3884d3a12a89e7078c83853d9b7912281cefb14bac00a2737d33a000000008a47304402204e63d034c6074f17e9c5f8766bc7b5468a0dce5b69578bd08554e8f21434c58e0220763c6966f47c39068c8dcd3f3dbd8e2a4ea13ac9e9c899ca1fbc00e2558cbb8b01410431393af9984375830971ab5d3094c6a7d02db3568b2b06212a7090094549701bbb9e84d9477451acc42638963635899ce91bacb451a1bb6da73ddfbcf596bddfffffffff01400001000000000017a9141a8b0026343166625c7475f01e48b5ede8c0252e8700000000";

        bytes20 script_hash = hex"1a8b0026343166625c7475f01e48b5ede8c0252e";

        assert(BTC.checkValueSent(transaction, script_hash, 1));
        assert(BTC.checkValueSent(transaction, script_hash, 65600));
        assert(!BTC.checkValueSent(transaction, script_hash, 65601));
    }
}

// real data from https://blockchain.info/strange-transactions
// use curl https://blockchain.info/rawtx/TXHASH?format={hex|json} to get the data
contract StrangeTransactionTest is DSTest {
    function testA() {
        // P2SH, OP_RETURN, P2SH
        // hash: 19631dbcca350b703cc7276b13e2866e30df5fd90a05c8cbf5c16772add2ac10

        // outputs:
        // "addr":"3KW5pjgfDuVTftXsyLqbtxs7nAUd35Jqts",
        // "value":2730,
        // "script":"a914c360f1a8e6af948e8ae55a23293be19003f6329387"

        // (OP_RETURN)
        // "value":0,
        // "script":"6a146f6d6e69000000000000001f0000005d21dba000"

        // "addr":"3BbDtxBSjgfTRxaBUgR2JACWRukLKtZdiQ",
        // "value":9376312,
        // "script":"a9146c98c19a033bdbd421a9c7d24ad5e0e3a3318ec187"
        bytes memory transaction = hex"0100000001fd4d4952d7428c421370ccefb201b915133a5dec0828b0529cf21684547e8784010000006f00473044022045a8b16c43874c82ba846b349a82cb26352d3b4902805d27a397087bb17b044702201ac9e15ae99a61d6df97c771968ee8a5adc1e6808b1c296f3f97836f7220e31901255121030ec111fb923515ba4747f3c7005b4398e81d816a66ba50306aacac2f405ac72651aeffffffff03aa0a00000000000017a914c360f1a8e6af948e8ae55a23293be19003f63293870000000000000000166a146f6d6e69000000000000001f0000005d21dba00038128f000000000017a9146c98c19a033bdbd421a9c7d24ad5e0e3a3318ec18700000000";

        bytes20 address1 = hex"c360f1a8e6af948e8ae55a23293be19003f63293";
        bytes20 address2 = hex"6c98c19a033bdbd421a9c7d24ad5e0e3a3318ec1";

        assert(BTC.checkValueSent(transaction, address1, 2730));
        assert(!BTC.checkValueSent(transaction, address1, 2731));

        assert(BTC.checkValueSent(transaction, address2, 9376312));
        assert(!BTC.checkValueSent(transaction, address2, 9376313));
    }
    function testB() {
        // OP_RETURN, P2SH, P2PKH, P2PKH
        // hash: be8c30b9e5dd56ed3b0eaf93365cdd84bc36e512d4aebdd25a38584d7f2fdfbc

        // "value":0,
        // "script":"6a104f4101000280d0acf30e80d0acf30e00"

        // "addr":"3JxhW1U3R8Ju4AzfLkfAKgBF9jdDYr7Lxf",
        // "value":600,
        // "script":"a914bd716a3a6c9b0c4fc11be9cd3581741d3b4f29b587"

        // "addr":"1KStr8jyMSJt4YBqzKPynJASZjaBwSUjkw",
        // "value":600,
        // "script":"76a914ca57f16593cf2423d1d17ed7481d25fdefbc290288ac"

        // "addr":"1KStr8jyMSJt4YBqzKPynJASZjaBwSUjkw",
        // "value":149400,
        // "script":"76a914ca57f16593cf2423d1d17ed7481d25fdefbc290288ac"

        bytes memory transaction = hex"01000000029fb72ab2598464da312d344ca91ff2ac91e7d224186d7a93d2808db772840de6010000006b4830450221008e27827ea5f7ad7b38b2cc7e016b5a119acbe1851a6517a3538f89148ee97c0c022079de598c498f47b872143bd830bae4b483e85ad2e187ac528632bc50d8065742012103edc405c12ec2643ae58b4298a482a71278979cbace4948754ead4040f1dea82affffffff5d5ac48f0442317fbb4a31a5291700764736b2dab15d43c0dbb79121f9d2ba2c000000006a47304402204a927502759e6bad02e7b4d74ac57c6d2965d9e271915f66ec5f365fb922d930022053e9cdb66b727c58a89a0799fd680cee6f045333e4b816fcf420434fe85cb7c0012103edc405c12ec2643ae58b4298a482a71278979cbace4948754ead4040f1dea82affffffff040000000000000000126a104f4101000280d0acf30e80d0acf30e00580200000000000017a914bd716a3a6c9b0c4fc11be9cd3581741d3b4f29b58758020000000000001976a914ca57f16593cf2423d1d17ed7481d25fdefbc290288ac98470200000000001976a914ca57f16593cf2423d1d17ed7481d25fdefbc290288ac00000000";

        bytes20 address1 = hex"bd716a3a6c9b0c4fc11be9cd3581741d3b4f29b5";
        // edge case: repeated output addresses
        // bytes20 address2 = "ca57f16593cf2423d1d17ed7481d25fdefbc2902";
        bytes20 address3 = hex"ca57f16593cf2423d1d17ed7481d25fdefbc2902";

        assert(BTC.checkValueSent(transaction, address1, 600));
        assert(BTC.checkValueSent(transaction, address3, 149400));
        assert(!BTC.checkValueSent(transaction, address3, 149401));
    }
}
