// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {MainnetContracts as MC} from "script/Contracts.sol";
import {BaseIntegrationTest} from "test/mainnet/BaseIntegrationTest.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";
import {console} from "forge-std/console.sol";

contract VaultBasicFunctionalityTest is BaseIntegrationTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_initial_withdraw_success(uint256 depositAmount, uint256 withdrawShares) public {
        // Fuzz deposit bounds: 1 USDC min, 1_000_000 USDC max (6 decimals)
        depositAmount = bound(depositAmount, 1e6, 1_000_000e6);

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
        uint256 preStakeDaoBalance = IERC20(MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT).balanceOf(address(stakedLPStrategy));

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
        uint256 postStakeDaoBalance = IERC20(MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT).balanceOf(address(stakedLPStrategy));
        assertEq(
            postStakeDaoBalance,
            preStakeDaoBalance - assetsWithdrawn,
            "StakeDao LP balance in vault did not decrease by withdrawn amount"
        );

        vm.stopPrank();
    }

    function test_fuzz_initial_redeem_success(uint256 depositAmount, uint256 redeemAmount) public {
        // Fuzz deposit bounds: 1 USDC min, 1_000_000 USDC max (6 decimals)
        depositAmount = bound(depositAmount, 1e6, 1_000_000e6);

        address alice = makeAddr("alice");

        deal(MC.USDC, alice, depositAmount);

        uint256 lpBalance = deposit_lp(alice, depositAmount);

        assertEq(IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice), lpBalance, "Alice's stakedao LP balance mismatch");

        vm.startPrank(alice);

        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);

        uint256 shares = stakedLPStrategy.deposit(lpBalance, alice);

        uint256 aliceShareBalance = IERC20(stakedLPStrategy).balanceOf(alice);

        assertEq(aliceShareBalance, shares, "Share amount mismatch after fuzz deposit");

        redeemAmount = bound(redeemAmount, 1, depositAmount);

        uint256 withdrawShares = shares;

        uint256 preLpBalance = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);
        uint256 preStakeDaoBalance = IERC20(MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT).balanceOf(address(stakedLPStrategy));

        uint256 assetsRedeemed = stakedLPStrategy.redeem(shares, alice, alice);

        // LP tokens should increase by exactly assetsRedeemed
        uint256 postLpBalance = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);
        assertEq(
            postLpBalance, preLpBalance + assetsRedeemed, "LP token balance did not increase as expected after redeem"
        );

        // Alice's share balance should go to zero (all shares redeemed)
        uint256 aliceBalanceAfter = IERC20(stakedLPStrategy).balanceOf(alice);
        assertEq(aliceBalanceAfter, 0, "Share balance should be zero after redeem");

        // Assert the StakeDao gauge LP balance in the vault decreased by assetsRedeemed
        uint256 postStakeDaoBalance = IERC20(MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT).balanceOf(address(stakedLPStrategy));
        assertEq(
            postStakeDaoBalance,
            preStakeDaoBalance - assetsRedeemed,
            "StakeDao LP balance in vault did not decrease by redeemed amount"
        );

        vm.stopPrank();
    }

    function test_withdraw_single_sided() public {
        address alice = makeAddr("alice");

        uint256 depositAmount = 100e6;
        deal(MC.USDC, alice, depositAmount);

        uint256 lpBalance = deposit_lp(alice, depositAmount);

        assertEq(IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice), lpBalance, "Alice's stakedao LP balance mismatch");

        vm.startPrank(alice);

        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);
        uint256 shares = stakedLPStrategy.deposit(lpBalance, alice);

        assertEq(IERC20(stakedLPStrategy).balanceOf(alice), shares, "Alice's strategy shares balance mismatch");

        stakedLPStrategy.approve(address(strategyAdapter), shares);

        uint256 withdrawSingleSidedAmount = 1e18;

        uint256 redeemableAmount = strategyAdapter.previewWithdrawSingleSided(withdrawSingleSidedAmount);

        // Withdraw all shares single-sided (receiving USDC)
        strategyAdapter.withdrawSingleSided(withdrawSingleSidedAmount, 0);

        assertEq(IERC20(MC.USDC).balanceOf(alice), redeemableAmount, "Alice's USDC balance mismatch");

        assertGt(IERC20(MC.USDC).balanceOf(alice), 1e6, "Alice's USDC balance mismatch");

        vm.stopPrank();
    }

    function test_fuzz_withdraw_single_sided(uint256 depositAmount, uint256 withdrawAmount) public {
        // depositAmount: fuzz the deposit in USDC
        // withdrawAmount: fuzz the single-sided withdraw in shares

        address alice = makeAddr("alice");
        // Constrain inputs to reasonable values
        depositAmount = bound(depositAmount, 1e6, 1_000_000e6); // Between $1 and $1,000,000 USDC
        deal(MC.USDC, alice, depositAmount);

        uint256 lpBalance = deposit_lp(alice, depositAmount);

        // Alice must have >0 LP balance to continue
        vm.assume(lpBalance > 0);

        vm.startPrank(alice);

        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);
        uint256 shares = stakedLPStrategy.deposit(lpBalance, alice);

        assertEq(IERC20(stakedLPStrategy).balanceOf(alice), shares, "Alice's strategy shares balance mismatch");

        stakedLPStrategy.approve(address(strategyAdapter), shares);

        // Constrain withdrawAmount to Alice's available shares
        withdrawAmount = bound(withdrawAmount, 1, shares);

        uint256 aliceUSDCBefore = IERC20(MC.USDC).balanceOf(alice);

        uint256 redeemableAmount = strategyAdapter.previewWithdrawSingleSided(withdrawAmount);

        strategyAdapter.withdrawSingleSided(withdrawAmount, 0);

        uint256 aliceUSDCAfter = IERC20(MC.USDC).balanceOf(alice);

        // Check Alice received USDC
        assertEq(aliceUSDCAfter, aliceUSDCBefore + redeemableAmount, "USDC received does not match preview");

        // Check shares decreased
        uint256 aliceSharesAfter = IERC20(stakedLPStrategy).balanceOf(alice);
        assertEq(aliceSharesAfter, shares - withdrawAmount, "Alice's shares didn't decrease by withdrawn shares");

        vm.stopPrank();
    }

    function test_withdraw_after_deposit_and_donation() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        // Alice and Bob are both funded with USDC to mint LP tokens
        uint256 depositAmount = 100_000e6;
        deal(MC.USDC, alice, depositAmount);
        deal(MC.USDC, bob, depositAmount);

        // Alice receives LP tokens and deposits them into the strategy
        uint256 aliceLp = deposit_lp(alice, depositAmount);
        vm.startPrank(alice);
        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), aliceLp);
        uint256 aliceShares = stakedLPStrategy.deposit(aliceLp, alice);
        vm.stopPrank();

        // Bob mints LP tokens, but DONATES them directly to the vault (does not call deposit)
        uint256 bobLp = deposit_lp(bob, depositAmount);
        // Send LP directly to the strategy, increasing totalAssets but not shares
        deal(MC.CURVE_ynRWAx_USDC_LP, bob, bobLp);
        vm.startPrank(bob);
        IERC20(MC.CURVE_ynRWAx_USDC_LP).transfer(address(stakedLPStrategy), bobLp);
        vm.stopPrank();

        // At this point alice has all the shares, but the vault has double the assets
        uint256 totalAssets = stakedLPStrategy.totalAssets();
        assertEq(totalAssets, aliceLp + bobLp, "Total assets should include Alice's deposit and Bob's donation");
        assertEq(stakedLPStrategy.totalSupply(), aliceShares, "Total supply should only be Alice's shares");

        // Alice withdra    ws all her shares for LP tokens
        vm.startPrank(alice);
        uint256 aliceInitialShares = stakedLPStrategy.balanceOf(alice);

        uint256 aliceLpBalanceBefore = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);

        // previewRedeem: how many LP tokens should Alice receive for redeeming all her shares?
        uint256 previewAssets = stakedLPStrategy.previewRedeem(aliceInitialShares);

        uint256 withdrawn = stakedLPStrategy.redeem(aliceInitialShares, alice, alice);

        assertEq(withdrawn, previewAssets, "Alice withdrawn LP should match previewRedeem");
        assertEq(stakedLPStrategy.balanceOf(alice), 0, "Alice should have 0 shares after redeeming all");

        // Alice gets more than her original deposit, due to Bob's donation
        uint256 aliceLpBalanceAfter = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);
        assertGt(aliceLpBalanceAfter - aliceLpBalanceBefore, aliceLp, "Alice profit includes Bob's donation");

        // The strategy vault should now have only Bob's donation (since Alice withdrew her share)
        assertEq(stakedLPStrategy.totalAssets(), totalAssets - withdrawn, "Vault assets should decrease by withdrawn");
        assertEq(stakedLPStrategy.totalSupply(), 0, "All shares burned after Alice's withdrawal");
        vm.stopPrank();
    }

    function test_redeem_total_assets_and_share_supply_handles_asset_donation() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        // Alice and Bob are both funded with USDC to mint LP tokens
        uint256 depositAmount = 100_000e6;
        deal(MC.USDC, alice, depositAmount);
        deal(MC.USDC, bob, depositAmount);

        // Alice receives LP tokens and deposits them into the strategy
        uint256 aliceLp = deposit_lp(alice, depositAmount);
        vm.startPrank(alice);
        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), aliceLp);
        uint256 aliceShares = stakedLPStrategy.deposit(aliceLp, alice);
        vm.stopPrank();

        // Bob mints LP tokens, but DONATES them directly to the vault (does not call deposit)
        uint256 bobLp = deposit_lp(bob, depositAmount);
        // Send LP directly to the strategy, increasing totalAssets but not shares
        deal(MC.CURVE_ynRWAx_USDC_LP, bob, bobLp);
        vm.startPrank(bob);
        IERC20(MC.CURVE_ynRWAx_USDC_LP).transfer(address(stakedLPStrategy), bobLp);
        vm.stopPrank();

        // At this point alice has all the shares, but the vault has double the assets
        uint256 totalAssets = stakedLPStrategy.totalAssets();
        assertEq(totalAssets, aliceLp + bobLp, "Total assets should include Alice's deposit and Bob's donation");
        assertEq(stakedLPStrategy.totalSupply(), aliceShares, "Total supply should only be Alice's shares");

        // Alice redeems all her shares for LP tokens
        vm.startPrank(alice);
        uint256 aliceInitialShares = stakedLPStrategy.balanceOf(alice);

        uint256 aliceLpBalanceBefore = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);

        // previewRedeem: how many LP tokens should Alice receive for redeeming all her shares?
        uint256 previewAssets = stakedLPStrategy.previewRedeem(aliceInitialShares);

        uint256 withdrawn = stakedLPStrategy.redeem(aliceInitialShares, alice, alice);

        assertEq(withdrawn, previewAssets, "Alice withdrawn LP should match previewRedeem");
        assertEq(stakedLPStrategy.balanceOf(alice), 0, "Alice should have 0 shares after redeeming all");

        // Alice gets more than her original deposit, due to Bob's donation
        uint256 aliceLpBalanceAfter = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);
        assertGt(aliceLpBalanceAfter - aliceLpBalanceBefore, aliceLp, "Alice profit includes Bob's donation");

        // The strategy vault should now have only Bob's donation (since Alice withdrew her share)
        assertEq(stakedLPStrategy.totalAssets(), totalAssets - withdrawn, "Vault assets should decrease by withdrawn");
        assertEq(stakedLPStrategy.totalSupply(), 0, "All shares burned after Alice's redeem");
        vm.stopPrank();
    }
}
