import 'dapple/test.sol';
import 'btc_tx.sol';

contract BTCTxTest is Test {
    function setUp() {
    }
    function testGetBytesLE16() {
        bytes memory data = new bytes(2);
        data[0] = 0x02;
        data[1] = 0x01;
        var val = BTC.getBytesLE(data, 0, 16);
        assertEq(val, 258);
    }
    function testGetBytesLE32() {
        bytes memory data = new bytes(4);
        data[0] = 0x04;
        data[1] = 0x03;
        data[2] = 0x02;
        data[3] = 0x01;
        var val = BTC.getBytesLE(data, 0, 32);
        assertEq(val, 16909060);
    }
    function testGetBytesLE64() {
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
        var (ret, pos) = BTC.parseVarInt(data, 0);
        assertEq(ret, 0);
        assertEq(pos, 1);

        data[0] = 0xfc;
        (ret, pos) = BTC.parseVarInt(data, 0);
        assertEq(ret, 252);
    }
    function testParseVarInt16() {
        bytes memory data = new bytes(3);
        data[0] = 0xfd;
        data[1] = 0x00;
        data[2] = 0x00;
        var (ret, pos) = BTC.parseVarInt(data, 0);
        assertEq(ret, 0);
        assertEq(pos, 3);
    }
}
