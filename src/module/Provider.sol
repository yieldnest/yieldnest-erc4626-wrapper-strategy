// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Provider {
    error UnsupportedAsset(address asset);

    address public immutable vault;
    address public immutable underlyingAsset;
    uint256 public immutable unitValue;
    uint256 public immutable shareUnitValue;

    constructor(address vault_, uint256 unitValue_) {
        vault = vault_;
        underlyingAsset = IERC4626(vault).asset();
        unitValue = unitValue_;
        shareUnitValue = 10 ** IERC20Metadata(vault).decimals();
    }

    function getRate(address asset) external view returns (uint256) {
        if (asset == underlyingAsset) {
            return unitValue;
        } else if (asset == vault) {
            return IERC4626(vault).convertToAssets(shareUnitValue);
        } else {
            revert UnsupportedAsset(asset);
        }
    }
}
