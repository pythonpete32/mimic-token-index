// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@mimic-fi/v2-helpers/contracts/utils/Denominations.sol';
import '@mimic-fi/v2-swap-connector/contracts/ISwapConnector.sol';
import '@mimic-fi/v2-smart-vaults-base/contracts/actions/BaseAction.sol';
import '@mimic-fi/v2-smart-vaults-base/contracts/actions/RelayedAction.sol';

abstract contract BaseIndex is BaseAction, RelayedAction {
    /* ====================================================================== */
    /*                               ERRORS
    /* ====================================================================== */

    error SlippageAboveOne();
    error AssetWeightsMissmatch();
    error WeightsNotOneHundredPercent();
    error RebalanceNotAllowed();

    /* ====================================================================== */
    /*                               EVENTS
    /* ====================================================================== */

    event MaxSlippageSet(uint256 maxSlippage);
    event PortfolioUpdated(address[] assets, uint256[] weights);

    /* ====================================================================== */
    /*                               STATE
    /* ====================================================================== */

    address[] public assets;
    uint256[] public weights;
    uint256 public maxSlippage;

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
            prices[i] = smartVault.getPrice(assets[i], smartVault.wrappedNativeToken());
            totalPortfolioValue += (balances[i] * prices[i]);
        }

        // Calculate the target balance for each element
        for (uint256 i = 0; i < len; i++) {
            targetBalances[i] = (totalPortfolioValue * weights[i]) / (prices[i] * 100);
        }

        return targetBalances;
    }

    /* ====================================================================== */
    /*                          GOVERNANCE FUNCTIONS
    /* ====================================================================== */

    function setMaxSlippage(uint256 newMaxSlippage) external auth {
        if (newMaxSlippage >= FixedPoint.ONE) revert SlippageAboveOne();
        maxSlippage = newMaxSlippage;
        emit MaxSlippageSet(newMaxSlippage);
    }

    function setPortfolio(address[] memory _assets, uint256[] memory _weights) external auth {
        uint256 totalWeights = 0;
        for (uint256 i = 0; i < _weights.length; i++) {
            totalWeights += _weights[i];
        }
        if (totalWeights != 1e18) revert WeightsNotOneHundredPercent();
        if (_assets.length != _weights.length) revert AssetWeightsMissmatch();

        assets = _assets;
        weights = _weights;

        emit PortfolioUpdated(_assets, _weights);
    }

    /* ====================================================================== */
    /*                           VALIDATION FUNCTIONS
    /* ====================================================================== */

    function _valdateRebalalance(uint256 _percentage) internal view returns (bool) {
        uint256[] memory targetBalances = getTargetBalances();
        uint256 len = assets.length;
        uint256[] memory balances = new uint256[](len);

        // Get the balances of the assets
        for (uint256 i = 0; i < len; i++) {
            balances[i] = IERC20(assets[i]).balanceOf(address(smartVault));
        }

        // Check if the actual balance of any of the assets is deviated by more than the percentage
        for (uint256 i = 0; i < len; i++) {
            // Calculate the acceptable range for the current asset
            uint256 minBalance = targetBalances[i] * (FixedPoint.ONE - _percentage);
            uint256 maxBalance = targetBalances[i] * (FixedPoint.ONE + _percentage);

            // Check if the actual balance is outside the acceptable range
            if (balances[i] < minBalance || balances[i] > maxBalance) {
                // Rebalance is allowed if the actual balance is outside the acceptable range
                return true;
            }
        }

        // Otherwise, rebalance is not allowed
        return false;
    }
}
