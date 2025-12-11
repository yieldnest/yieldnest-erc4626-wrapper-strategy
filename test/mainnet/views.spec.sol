// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {MainnetContracts as MC} from "script/Contracts.sol";
import {BaseIntegrationTest} from "test/mainnet/BaseIntegrationTest.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";
import {console} from "forge-std/console.sol";

contract VaultViewsTest is BaseIntegrationTest {
    function setUp() public override {
        super.setUp();
    }

    function test_erc4626_basic_views() public {
        // Use the actual vault/strategy contract, not the adapter
        address asset = stakedLPStrategy.asset();
        assertEq(asset, MC.CURVE_ynRWAx_USDC_LP, "Vault underlying asset should be CURVE LP token");

        uint8 decimals = stakedLPStrategy.decimals();
        assertEq(decimals, 18, "Vault decimals should be 18");

        string memory name = stakedLPStrategy.name();
        assertEq(name, "Staked LP Strategy ynRWAx-USDC", "Vault name should match the expected name exactly");

        string memory symbol = stakedLPStrategy.symbol();
        assertEq(symbol, "sLP-ynRWAx-USDC", "Vault symbol should match the expected symbol exactly");

        uint256 totalAssets = stakedLPStrategy.totalAssets();
        assertEq(totalAssets, 0, "Initial totalAssets should be 0");

        address alice = makeAddr("alice");
        uint256 maxDeposit = stakedLPStrategy.maxDeposit(alice);
        assertEq(maxDeposit, type(uint256).max, "maxDeposit should be max");

        uint256 maxMint = stakedLPStrategy.maxMint(alice);
        assertEq(maxMint, type(uint256).max, "maxMint should be >0");

        uint256 maxWithdraw = stakedLPStrategy.maxWithdraw(alice);
        uint256 maxRedeem = stakedLPStrategy.maxRedeem(alice);

        assertEq(maxWithdraw, 0, "maxWithdraw for Alice should be 0 before deposit");
        assertEq(maxRedeem, 0, "maxRedeem for Alice should be 0 before deposit");

        // Get the assets array and assert its contents and length
        address[] memory assets = stakedLPStrategy.getAssets();
        assertEq(assets.length, 2, "Strategy should have 2 assets registered");
        assertEq(assets[0], MC.CURVE_ynRWAx_USDC_LP, "First asset should be CURVE_ynRWAx_USDC_LP");
        assertEq(assets[1], MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT, "Second asset should be StakeDaoGauge");
    }

    function test_previewDeposit() public {
        address alice = makeAddr("alice");
        uint256 depositAmount = 10_000e6;
        deal(MC.USDC, alice, depositAmount);

        // Preview deposit: stakedLPStrategy.previewDeposit
        uint256 previewShares = stakedLPStrategy.previewDeposit(depositAmount);
        assertGt(previewShares, 0, "previewDeposit should return >0 shares for deposit");
    }

    function test_previewMint() public view {
        uint256 mintAmount = 100e18; // 100 shares

        // Preview mint: how much USDC needed to get certain shares?
        uint256 previewMintAssets = stakedLPStrategy.previewMint(mintAmount);
        assertGt(previewMintAssets, 0, "previewMint should return >0 assets");
    }

    function test_previewWithdraw() public {
        // Make sure the vault is not empty to allow for previews
        address alice = makeAddr("alice");
        uint256 depositAmount = 1_000e6;
        deal(MC.USDC, alice, depositAmount);
        // Mint Curve LP by depositing USDC, then deposit that LP into the strategy.
        vm.startPrank(alice);
        IERC20(MC.USDC).approve(address(MC.CURVE_ynRWAx_USDC_LP), depositAmount);
        uint256[] memory amounts = new uint256[](2);
        amounts[1] = depositAmount;
        ICurvePool(MC.CURVE_ynRWAx_USDC_LP).add_liquidity(amounts, 0);
        uint256 lpBalance = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);

        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);
        stakedLPStrategy.deposit(lpBalance, alice);
        vm.stopPrank();

        // Preview withdraw: how many shares required to withdraw given assets?
        uint256 withdrawAmount = 1_000e6;
        uint256 previewWithdrawShares = stakedLPStrategy.previewWithdraw(withdrawAmount);
        assertGt(previewWithdrawShares, 0, "previewWithdraw returns shares required");
    }

    function test_previewRedeem() public {
        // What's deposited is the LP.
        address alice = makeAddr("alice");
        uint256 depositAmount = 1_000e6;
        deal(MC.USDC, alice, depositAmount);

        // Mint Curve LP by depositing USDC, then deposit that LP into the strategy.
        vm.startPrank(alice);
        IERC20(MC.USDC).approve(address(MC.CURVE_ynRWAx_USDC_LP), depositAmount);
        // Add liquidity with USDC to get LP tokens (USDC is index 1)
        uint256[] memory amounts = new uint256[](2);
        amounts[1] = depositAmount;
        ICurvePool(MC.CURVE_ynRWAx_USDC_LP).add_liquidity(amounts, 0);
        uint256 lpBalance = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);

        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);
        stakedLPStrategy.deposit(lpBalance, alice);
        vm.stopPrank();

        // Preview redeem: how many assets returned for given shares?
        uint256 redeemAmount = 1e18;
        uint256 previewRedeemAssets = stakedLPStrategy.previewRedeem(redeemAmount);
        assertGt(previewRedeemAssets, 0, "previewRedeem returns USDC for shares");
    }

    function test_totalAssets_and_max_functions() public {
        address alice = makeAddr("alice");
        uint256 depositAmount = 10_000e6;
        deal(MC.USDC, alice, depositAmount);

        vm.startPrank(alice);
        IERC20(MC.USDC).approve(address(MC.CURVE_ynRWAx_USDC_LP), depositAmount);
        uint256[] memory amounts = new uint256[](2);
        amounts[1] = depositAmount;
        ICurvePool(MC.CURVE_ynRWAx_USDC_LP).add_liquidity(amounts, 0);
        uint256 lpBalance = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);
        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);
        stakedLPStrategy.deposit(lpBalance, alice);
        vm.stopPrank();

        // Can check totalAssets and max functions
        uint256 totalAssets = stakedLPStrategy.totalAssets();
        assertGt(totalAssets, 0, "totalAssets should be >0");

        uint256 aliceMaxDeposit = stakedLPStrategy.maxDeposit(alice);
        uint256 aliceMaxMint = stakedLPStrategy.maxMint(alice);
        uint256 aliceMaxWithdraw = stakedLPStrategy.maxWithdraw(alice);
        uint256 aliceMaxRedeem = stakedLPStrategy.maxRedeem(alice);

        assertGt(aliceMaxDeposit, 0, "maxDeposit should be >0");
        assertGt(aliceMaxMint, 0, "maxMint should be >0");
        assertGt(aliceMaxWithdraw, 0, "maxWithdraw should be >0");
        assertGt(aliceMaxRedeem, 0, "maxRedeem should be >0");
    }

    function test_preview_withdraw_single_sided(uint256 depositAmount, uint256 withdrawLpAmount) public {
        depositAmount = bound(depositAmount, 1e6, 1_000_000e6);

        address alice = makeAddr("alice");

        deal(MC.USDC, alice, depositAmount);

        uint256 lpBalance = deposit_lp(alice, depositAmount);

        withdrawLpAmount = bound(withdrawLpAmount, 1, lpBalance);

        stakedLPStrategy.approve(address(strategyAdapter), withdrawLpAmount);

        uint256 redeemableAmount = strategyAdapter.previewWithdrawSingleSided(withdrawLpAmount);

        // Preview withdrawal from Curve
        uint256 expectedRedeemableAmount =
            ICurvePool(MC.CURVE_ynRWAx_USDC_LP).calc_withdraw_one_coin(withdrawLpAmount, 1);

        assertEq(redeemableAmount, expectedRedeemableAmount, "Redeemable amount mismatch");
    }
}
