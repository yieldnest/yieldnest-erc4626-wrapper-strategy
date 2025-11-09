// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {MainnetContracts as MC} from "script/Contracts.sol";
import {BaseIntegrationTest} from "test/mainnet/BaseIntegrationTest.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";
import {console} from "forge-std/console.sol";

contract VaultBasicFunctionalityTest is BaseIntegrationTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_initial_withdraw_success()
        // uint256 depositAmount, uint256 withdrawShares
        public
    {
        // Fuzz deposit bounds: 1 USDC min, 1_000_000 USDC max (6 decimals)
        // depositAmount = bound(depositAmount, 1e6, 1_000_000e6);

        uint256 depositAmount = 100e6;

        address alice = makeAddr("alice");

        deal(MC.USDC, alice, depositAmount);

        uint256 lpBalance = deposit_lp(alice, depositAmount);

        assertEq(IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice), lpBalance, "Alice's stakedao LP balance mismatch");

        vm.startPrank(alice);

        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);

        uint256 shares = stakedLPStrategy.deposit(lpBalance, alice);

        uint256 aliceShareBalance = IERC20(stakedLPStrategy).balanceOf(alice);

        assertEq(aliceShareBalance, shares, "Share amount mismatch after fuzz deposit");

        // Bound withdrawShares between 0 and shares
        // withdrawShares = bound(withdrawShares, 1, shares - 100);

        uint256 withdrawShares = shares;

        uint256 preLpBalance = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);
        uint256 preStakeDaoBalance = IERC20(MC.STAKEDAO_CURVE_ynRWAx_USDC_LP).balanceOf(address(stakedLPStrategy));

        uint256 assetsWithdrawn = stakedLPStrategy.withdraw(withdrawShares, alice, alice);

        // LP tokens should increase by at least assetsWithdrawn
        uint256 postLpBalance = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);
        assertEq(
            postLpBalance,
            preLpBalance + assetsWithdrawn,
            "LP token balance did not increase as expected after withdraw"
        );

        // Alice's share balance should reduce exactly by withdrawn shares
        uint256 aliceBalanceAfter = IERC20(stakedLPStrategy).balanceOf(alice);
        assertEq(aliceBalanceAfter, shares - withdrawShares, "Share balance did not decrease by withdrawn shares");

        // Assert the StakeDao gauge LP balance in the vault decreased by assetsWithdrawn
        uint256 postStakeDaoBalance = IERC20(MC.STAKEDAO_CURVE_ynRWAx_USDC_LP).balanceOf(address(stakedLPStrategy));
        assertEq(
            postStakeDaoBalance,
            preStakeDaoBalance - assetsWithdrawn,
            "StakeDao LP balance in vault did not decrease by withdrawn amount"
        );

        vm.stopPrank();
    }
}
