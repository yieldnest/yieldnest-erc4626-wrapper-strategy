// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {StakedLPStrategy} from "src/StakedLPStrategy.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StrategyAdapter {
    using SafeERC20 for IERC20;

    StakedLPStrategy public stakedLPStrategy;

    int128 curveAssetIndex;

    constructor(address stakedLPStrategyAddress, int128 _curveAssetIndex) {
        stakedLPStrategy = StakedLPStrategy(payable(stakedLPStrategyAddress));
        curveAssetIndex = _curveAssetIndex;
    }

    function withdrawSingleSided(uint256 amount) public {
        stakedLPStrategy.withdraw(amount, address(this), msg.sender);

        // STEP 1: redeem the staked LP tokens single-sided
        ICurvePool pool = ICurvePool(stakedLPStrategy.asset());

        uint256 redeemedAmount = pool.remove_liquidity_one_coin(amount, curveAssetIndex, 0);

        // STEP 2: apply extra withdrawal fee

        // STEP 3: transfer the assets to the caller
        address curveAsset = pool.coins(uint256(uint128(curveAssetIndex)));
        IERC20(curveAsset).safeTransfer(msg.sender, redeemedAmount);
    }
}
