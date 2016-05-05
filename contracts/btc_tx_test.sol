import 'dapple/test.sol';
import 'btc_tx.sol';

contract BTCTxTest is Test {
    function setUp() {
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
}
