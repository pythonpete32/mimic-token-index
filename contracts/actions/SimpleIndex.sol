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
    /*                               STATE
    /* ====================================================================== */

    uint256 public constant override BASE_GAS = 35e3;
    IERC20 public WETH;

    /* ====================================================================== */
    /*                               ACTION FUNCTIONS
    /* ====================================================================== */

    constructor(address weth, address admin, address registry) BaseAction(admin, registry) {
        WETH = IERC20(weth);
    }

    function call() external auth {
        (isRelayer[msg.sender] ? _relayedCall : _call)();
    }

    function _relayedCall() internal redeemGas {
        _call();
    }

    function _call() internal {
        _valdateRebalalance();

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
    /*                               VIEW FUNCTIONS
    /* ====================================================================== */

    function getTargetBalances() public view returns (uint256[] memory) {
        uint256 len = assets.length;
        uint256[] memory balances = new uint256[](len);
        uint256[] memory prices = new uint256[](len);
        uint256[] memory targetBalances = new uint256[](len);
        uint256 totalPortfolioValue = 0;

        // Get the balances and prices of the assets
        for (uint256 i = 0; i < len; i++) {
            balances[i] = IERC20(assets[i]).balanceOf(address(smartVault));
            prices[i] = smartVault.getPrice(assets[i], address(WETH));
            totalPortfolioValue += (balances[i] * prices[i]);
        }

        // Calculate the target balance for each element
        for (uint256 i = 0; i < len; i++) {
            targetBalances[i] = (totalPortfolioValue * weights[i]) / (prices[i] * 100);
        }

        return targetBalances;
    }

    /* ====================================================================== */
    /*                               INTERNAL FUNCTIONS
    /* ====================================================================== */

    function swap(address token, uint256 amount, OrderType order) internal {
        order == OrderType.Buy
            ? smartVault.swap(
                0, // use uniswap v2
                address(WETH),
                token,
                amount,
                ISmartVault.SwapLimit.Slippage,
                maxSlippage,
                new bytes(0) // single hop
            )
            : smartVault.swap(
                0, // use uniswap v2
                token,
                address(WETH),
                amount,
                ISmartVault.SwapLimit.Slippage,
                maxSlippage,
                new bytes(0) // single hop
            );
    }
}
