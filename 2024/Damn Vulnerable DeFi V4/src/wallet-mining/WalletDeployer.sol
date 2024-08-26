// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

/**
 * @notice A contract that allows deployers of Gnosis Safe wallets to be rewarded.
 *         Includes an optional authorization mechanism to ensure only expected accounts
 *         are rewarded for certain deployments.
 */
contract WalletDeployer {
    // Addresses of a Safe factory and copy on this chain
    SafeProxyFactory public immutable cook;
    address public immutable cpy;

    uint256 public constant pay = 1 ether;
    address public immutable chief = msg.sender;
    //支付奖励的代币地址
    address public immutable gem;
    //授权合约的地址
    address public mom;
    //未使用的变量
    address public hat;

    error Boom();

    constructor(address _gem, address _cook, address _cpy) {
        gem = _gem;
        cook = SafeProxyFactory(_cook);
        cpy = _cpy;
    }

    /**
     * @notice Allows the chief to set an authorizer contract.
     */
    //只能被调用一次，而且只能用chief调用
    function rule(address _mom) external {
        if (msg.sender != chief || _mom == address(0) || mom != address(0)) {
            revert Boom();
        }
        mom = _mom;
    }

    /**
     * @notice Allows the caller to deploy a new Safe account and receive a payment in return.
     *         If the authorizer is set, the caller must be authorized to execute the deployment
     */
    // wat是部署Safe的初始化数据
    // num是nonce
    function drop(address aim, bytes memory wat, uint256 num) external returns (bool) {
        //如果mom不为空，则检查msg.sender是否被授权
        if (mom != address(0) && !can(msg.sender, aim)) {
            return false;
        }

        if (address(cook.createProxyWithNonce(cpy, wat, num)) != aim) {
            return false;
        }

        if (IERC20(gem).balanceOf(address(this)) >= pay) {
            IERC20(gem).transfer(msg.sender, pay);
        }
        return true;
    }

    function can(address u, address a) public view returns (bool y) {
        assembly {
            let m := sload(0)
            if iszero(extcodesize(m)) { stop() }
            let p := mload(0x40)
            mstore(0x40, add(p, 0x44))
            mstore(p, shl(0xe0, 0x4538c4eb))
            mstore(add(p, 0x04), u)
            mstore(add(p, 0x24), a)
            if iszero(staticcall(gas(), m, p, 0x44, p, 0x20)) { stop() }
            y := mload(p)
        }
    }
}
