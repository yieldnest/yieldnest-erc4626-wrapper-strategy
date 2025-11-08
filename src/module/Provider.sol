// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";

contract Provider {
    error UnsupportedAsset(address asset);

    address public immutable stakeDAOLpToken;
    address public immutable lpToken;

    constructor(address _stakeDAOLpToken) {
        stakeDAOLpToken = _stakeDAOLpToken;
        lpToken = IStakeDaoLiquidityGauge(stakeDAOLpToken).lp_token();
    }

    function getRate(address asset) external view returns (uint256) {
        if (asset == lpToken) {
            return 1e18;
        } else if (asset == stakeDAOLpToken) {
            return 1e18;
        } else {
            revert UnsupportedAsset(asset);
        }
    }
}
