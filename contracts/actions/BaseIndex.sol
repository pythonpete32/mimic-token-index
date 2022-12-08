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
        if (totalWeights != 1) revert WeightsNotOneHundredPercent();
        if (_assets.length != _weights.length) revert AssetWeightsMissmatch();

        assets = _assets;
        weights = _weights;

        emit PortfolioUpdated(_assets, _weights);
    }

    /* ====================================================================== */
    /*                           VALIDATION FUNCTIONS
    /* ====================================================================== */

    // TODO: guards around when its ok for bots to rebalance
    function _valdateRebalalance() internal pure returns (bool) {
        return true;
    }
}
