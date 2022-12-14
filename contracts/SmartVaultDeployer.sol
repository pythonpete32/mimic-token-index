// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import '@mimic-fi/v2-helpers/contracts/utils/Arrays.sol';
import '@mimic-fi/v2-registry/contracts/registry/IRegistry.sol';
import '@mimic-fi/v2-smart-vault/contracts/SmartVault.sol';
import '@mimic-fi/v2-smart-vaults-base/contracts/Deployer.sol';
import '@mimic-fi/v2-smart-vaults-base/contracts/actions/IAction.sol';

import './actions/SimpleIndex.sol';

contract SmartVaultDeployer {
    struct Params {
        IRegistry registry;
        IndexActionParams indexActionParams;
        Deployer.SmartVaultParams smartVaultParams;
    }

    struct IndexActionParams {
        address impl;
        address admin;
        address[] managers;
        address[] tokens;
        uint256[] weights;
        uint256 maxSlippage;
        Deployer.RelayedActionParams relayedActionParams;
    }

    function deploy(Params memory params) external {
        SmartVault smartVault = Deployer.createSmartVault(params.registry, params.smartVaultParams, false);
        _setupIndexAction(smartVault, params.indexActionParams);
        Deployer.transferAdminPermissions(smartVault, params.smartVaultParams.admin);
    }

    function _setupIndexAction(SmartVault smartVault, IndexActionParams memory params) internal returns (IAction) {
        // Create and setup action
        SimpleIndex index = SimpleIndex(params.impl);
        Deployer.setupBaseAction(index, params.admin, address(smartVault));
        address[] memory executors = Arrays.from(params.admin, params.managers, params.relayedActionParams.relayers);

        // authorise owner permissions
        index.authorize(address(params.admin), index.call.selector);

        // set max slippage
        index.authorize(address(params.admin), index.setMaxSlippage.selector);
        index.authorize(address(this), index.setMaxSlippage.selector);
        index.setMaxSlippage(params.maxSlippage);
        index.unauthorize(address(this), index.call.selector);

        // setup portfolio
        index.authorize(address(params.admin), index.setPortfolio.selector);
        index.authorize(address(this), index.setPortfolio.selector);
        index.setPortfolio(params.tokens, params.weights);
        index.unauthorize(address(this), index.setPortfolio.selector);

        Deployer.setupActionExecutors(index, executors, index.call.selector);
        Deployer.setupRelayedAction(index, params.admin, params.relayedActionParams);
        Deployer.transferAdminPermissions(index, params.admin);

        // Authorize action to swap from Smart Vault
        smartVault.authorize(address(index), smartVault.swap.selector);
        return index;
    }
}
