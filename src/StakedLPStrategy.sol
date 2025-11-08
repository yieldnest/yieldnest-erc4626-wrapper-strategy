// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {BaseStrategy} from "lib/yieldnest-vault/src/strategy/BaseStrategy.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";
import {IERC20} from "lib/yieldnest-vault/src/Common.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";

contract StakedLPStrategy is BaseStrategy {
    /**
     * @notice Initializes the strategy.
     * @param admin The address of the admin.
     * @param name The name of the vault.
     * @param symbol The symbol of the vault.
     * @param decimals_ The number of decimals for the vault token.
     * @param countNativeAsset_ Whether the vault should count the native asset.
     * @param alwaysComputeTotalAssets_ Whether the vault should always compute total assets.
     * @param defaultAssetIndex_ The index of the default asset in the asset list.
     * @param stakeDaoLPToken_ The address of the StakeDao token.
     */
    function initialize(
        address admin,
        string memory name,
        string memory symbol,
        uint8 decimals_,
        bool countNativeAsset_,
        bool alwaysComputeTotalAssets_,
        uint256 defaultAssetIndex_,
        address stakeDaoLPToken_
    ) external virtual initializer {
        _initialize(
            admin, name, symbol, decimals_, true, countNativeAsset_, alwaysComputeTotalAssets_, defaultAssetIndex_
        );

        address curveLpToken = IStakeDaoLiquidityGauge(stakeDaoLPToken_).lp_token();

        _addAsset(curveLpToken, 18, true);
        _addAsset(stakeDaoLPToken_, 18, true);
    }

    // TODO: Add the fee logic that exempts the StrategyAdapter from the fees.

    // Implement the required functions with stub returns, to be replaced with actual logic.
    function _feeOnRaw(uint256, address) public view override returns (uint256) {
        // TODO: implement fee calculation logic
        return 0;
    }

    function _feeOnTotal(uint256, address) public view override returns (uint256) {
        // TODO: implement fee calculation logic
        return 0;
    }

    function _availableAssets(address asset_) internal view virtual override returns (uint256 availableAssets) {
        address[] memory assets = getAssets();
        if (asset_ == assets[0]) {
            availableAssets =
                IERC20(asset_).balanceOf(address(this)) + IStakeDaoLiquidityGauge(assets[1]).balanceOf(address(this));
        } else {
            availableAssets = super._availableAssets(asset_);
        }
    }
}
