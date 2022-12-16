// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import './BaseIndex.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

enum OrderType {
    Buy,
    Sell
}

contract SimpleIndex is BaseIndex {
    /* ====================================================================== */
    /*                               ERRORS
    /* ====================================================================== */

    error ThresholdAboveOne();

    /* ====================================================================== */
    /*                               STATE
    /* ====================================================================== */

    uint256 public constant override BASE_GAS = 35e3;
    uint256 public rebalanceThreshold; // 1e18 == 1%

    constructor(address admin, address registry, uint256 threshold) BaseAction(admin, registry) {
        if (threshold >= FixedPoint.ONE) revert ThresholdAboveOne();
        rebalanceThreshold = threshold;
    }

    /* ====================================================================== */
    /*                               ACTION FUNCTIONS
    /* ====================================================================== */

    function call() external auth {
        (isRelayer[msg.sender] ? _relayedCall : _call)();
    }

    function _relayedCall() internal redeemGas {
        _call();
    }

    function _call() internal {
        _valdateRebalalance(rebalanceThreshold);

        uint256 len = assets.length;
        uint256[] memory targetBalances = getTargetBalances();

        // sell tokens first
        for (uint256 i = 0; i < len; i++) {
            uint256 balance = IERC20(assets[i]).balanceOf(address(smartVault));
            if (balance > targetBalances[i]) {
                swap(assets[i], balance - targetBalances[i], OrderType.Sell);
            }
        }

        // then buy tokens
        for (uint256 i = 0; i < len; i++) {
            uint256 balance = IERC20(assets[i]).balanceOf(address(smartVault));
            if (balance < targetBalances[i]) {
                swap(assets[i], targetBalances[i] - balance, OrderType.Buy);
            }
        }

        emit Executed();
    }

    /* ====================================================================== */
    /*                               INTERNAL FUNCTIONS
    /* ====================================================================== */

    function swap(address token, uint256 amount, OrderType order) internal {
        order == OrderType.Buy
            ? smartVault.swap(
                0, // use uniswap v2
                smartVault.wrappedNativeToken(),
                token,
                amount,
                ISmartVault.SwapLimit.Slippage,
                maxSlippage,
                new bytes(0) // single hop
            )
            : smartVault.swap(
                0, // use uniswap v2
                token,
                smartVault.wrappedNativeToken(),
                amount,
                ISmartVault.SwapLimit.Slippage,
                maxSlippage,
                new bytes(0) // single hop
            );
    }
}
