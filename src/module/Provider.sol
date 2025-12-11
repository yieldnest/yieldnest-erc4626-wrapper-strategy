// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";

contract Provider {
    error UnsupportedAsset(address asset);

    address public immutable vault;
    address public immutable underlyingAsset;

    constructor(address vault_) {
        vault = vault_;
        underlyingAsset = IERC4626(vault).asset();
    }

    function getRate(address asset) external view returns (uint256) {
        if (asset == underlyingAsset) {
            return 1e18;
        } else if (asset == vault) {
            return IERC4626(vault).convertToAssets(1e18);
        } else {
            revert UnsupportedAsset(asset);
        }
    }
}
