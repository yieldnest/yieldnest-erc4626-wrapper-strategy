// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {BaseStrategy} from "lib/yieldnest-vault/src/strategy/BaseStrategy.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";
import {IERC20} from "lib/yieldnest-vault/src/Common.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";

contract StakedLPStrategy is BaseStrategy {
    string public constant STAKED_LP_STRATEGY_VERSION = "0.1.0";

    struct InitParams {
        address admin;
        string name;
        string symbol;
        uint8 decimals_;
        bool alwaysComputeTotalAssets_;
        uint256 defaultAssetIndex_;
        address stakeDaoLPToken_;
    }

    /**
     * @notice Initializes the strategy.
     * @param params The struct containing all initialization parameters.
     */
    function initialize(InitParams calldata params) external virtual initializer {
        _initialize(
            params.admin,
            params.name,
            params.symbol,
            params.decimals_,
            true, // paused
            false, // countNativeAsset_ is false because the strategy does not hold the native asset
            params.alwaysComputeTotalAssets_,
            params.defaultAssetIndex_
        );

        address curveLpToken = IStakeDaoLiquidityGauge(params.stakeDaoLPToken_).lp_token();

        _addAsset(curveLpToken, 18, true);
        _addAsset(params.stakeDaoLPToken_, 18, false);
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

    /**
     * @notice Returns the available assets for the strategy. for the base asset (curve LP token)
     * it includes the balance of the curve LP token and the balance of the StakeDAO LP token.
     * @param asset_ The asset to check.
     * @return availableAssets The available assets.
     */
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
