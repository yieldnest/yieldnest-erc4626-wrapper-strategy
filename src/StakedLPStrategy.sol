// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {BaseStrategy} from "lib/yieldnest-vault/src/strategy/BaseStrategy.sol";

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
     */
    function initialize(
        address admin,
        string memory name,
        string memory symbol,
        uint8 decimals_,
        bool countNativeAsset_,
        bool alwaysComputeTotalAssets_,
        uint256 defaultAssetIndex_,
        address curveLpToken_
    ) external virtual initializer {
        _initialize(
            admin, name, symbol, decimals_, true, countNativeAsset_, alwaysComputeTotalAssets_, defaultAssetIndex_
        );

        _addAsset(curveLpToken_, 18, true);
    }

    // Implement the required functions with stub returns, to be replaced with actual logic.
    function _feeOnRaw(uint256, address) public view override returns (uint256) {
        // TODO: implement fee calculation logic
        return 0;
    }

    function _feeOnTotal(uint256, address) public view override returns (uint256) {
        // TODO: implement fee calculation logic
        return 0;
    }
}
