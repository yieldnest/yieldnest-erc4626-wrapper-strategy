// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {MainnetContracts as MC} from "script/Contracts.sol";
import {BaseIntegrationTest} from "test/mainnet/BaseIntegrationTest.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {console} from "forge-std/console.sol";

contract VaultBasicFunctionalityTest is BaseIntegrationTest {
    function setUp() public override {
        super.setUp();
    }

    function test_deposit_lp() public {
        uint256 depositAmount = 100e6;

        // Assume 'alice' address is available (e.g. from makeAddr("alice"))
        address alice = makeAddr("alice");

        deposit_lp(alice, depositAmount);

        // Find how much LP tokens alice received (query balance)
        uint256 lpBalance = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);

        // The gauge is a vault, so use the vault address for approval and deposit
        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT, lpBalance);

        // Deposit all LP tokens into the Vault as alice
        IERC4626(MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT).deposit(lpBalance, alice);

        assertEq(
            IERC20(MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT).balanceOf(alice), lpBalance, "Vault share balance mismatch"
        );

        vm.stopPrank();
    }

    function test_initial_deposit_success() public {
        uint256 depositAmount = 100e6;

        // Assume 'alice' address is available (e.g. from makeAddr("alice"))
        address alice = makeAddr("alice");

        deal(MC.USDC, alice, depositAmount);

        uint256 lpBalance = deposit_lp(alice, depositAmount);

        assertEq(IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice), lpBalance, "Alice's stakedao LP balance mismatch");

        vm.startPrank(alice);

        // Alice approves strategy to spend her stakedao LP tokens
        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);

        // Deposit to the strategy
        uint256 shares = stakedLPStrategy.deposit(lpBalance, alice);

        // Alice's strategy share balance increases, equals shares, equals lpBalance
        uint256 aliceShareBalance = IERC20(stakedLPStrategy).balanceOf(alice);

        assertEq(aliceShareBalance, shares, "Share amount mismatch after deposit");
        assertEq(aliceShareBalance, lpBalance, "Alice strategy share balance should match lpBalance");
        assertEq(
            IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice),
            0,
            "Alice's stakedao LP balance should be zero after strategy deposit"
        );
        assertEq(stakedLPStrategy.balanceOf(alice), lpBalance, "Alice's stakedao gauge balance mismatch");
        assertEq(stakedLPStrategy.totalAssets(), lpBalance, "Total assets mismatch after deposit");
        assertEq(stakedLPStrategy.totalSupply(), lpBalance, "Total supply mismatch after deposit");

        vm.stopPrank();
    }

    function testFuzz_initial_deposit_success(uint256 depositAmount) public {
        // Fuzz bounds: 1 USDC min, 1_000_000 USDC max (6 decimals)
        depositAmount = bound(depositAmount, 1e6, 1_000_000e6);

        address alice = makeAddr("alice");

        deal(MC.USDC, alice, depositAmount);

        uint256 lpBalance = deposit_lp(alice, depositAmount);

        assertEq(IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice), lpBalance, "Alice's stakedao LP balance mismatch");

        vm.startPrank(alice);

        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);

        uint256 shares = stakedLPStrategy.deposit(lpBalance, alice);

        uint256 aliceShareBalance = IERC20(stakedLPStrategy).balanceOf(alice);

        vm.stopPrank();

        assertEq(aliceShareBalance, shares, "Share amount mismatch after fuzz deposit");

        assertEq(IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice), 0, "Alice's stakedao LP balance mismatch");

        assertEq(stakedLPStrategy.balanceOf(alice), lpBalance, "Alice's stakedao gauge balance mismatch");

        assertEq(stakedLPStrategy.totalAssets(), lpBalance, "Alice's stakedao gauge total assets mismatch");

        assertEq(stakedLPStrategy.totalSupply(), lpBalance, "Alice's stakedao gauge total supply mismatch");

        assertEq(
            IERC20(MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT).balanceOf(address(stakedLPStrategy)),
            lpBalance,
            "Vault balance of stakedao LP mismatch"
        );
    }

    function test_initial_mint_success() public {
        uint256 mintAmount = 100e6;

        address alice = makeAddr("alice");

        deal(MC.USDC, alice, mintAmount);

        uint256 lpBalance = deposit_lp(alice, mintAmount);

        assertEq(IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice), lpBalance, "Alice's stakedao LP balance mismatch");

        // Record totalAssets and totalSupply before mint
        uint256 beforeTotalAssets = stakedLPStrategy.totalAssets();
        uint256 beforeTotalSupply = stakedLPStrategy.totalSupply();

        vm.startPrank(alice);

        // Alice approves strategy to spend her stakedao LP tokens
        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);

        uint256 desiredShares = stakedLPStrategy.previewDeposit(lpBalance);

        // Mint desired shares
        uint256 assetsDeposited = stakedLPStrategy.mint(desiredShares, alice);

        assertEq(IERC20(stakedLPStrategy).balanceOf(alice), desiredShares, "Alice's stakedao gauge balance mismatch");
        assertEq(assetsDeposited, lpBalance, "Assets deposited mismatch");

        // Assert totalAssets and totalSupply changed accordingly
        uint256 afterTotalAssets = stakedLPStrategy.totalAssets();
        uint256 afterTotalSupply = stakedLPStrategy.totalSupply();

        assertEq(afterTotalAssets, beforeTotalAssets + lpBalance, "totalAssets did not increase by deposited assets");
        assertEq(afterTotalSupply, beforeTotalSupply + desiredShares, "totalSupply did not increase by minted shares");

        vm.stopPrank();
    }

    function test_fuzz_initial_mint(uint256 mintAmount) public {
        // Bound mintAmount between 1 and 100,000 USDC (6 decimals)
        mintAmount = bound(mintAmount, 1000, 100_000 * 1e6);

        address alice = makeAddr("alice");

        deal(MC.USDC, alice, mintAmount);

        // Deposit LP tokens to Alice (simulates initial deposit to get LP tokens)
        uint256 lpBalance = deposit_lp(alice, mintAmount);

        // Record pre-mint stats
        uint256 beforeTotalAssets = stakedLPStrategy.totalAssets();
        uint256 beforeTotalSupply = stakedLPStrategy.totalSupply();

        vm.startPrank(alice);

        // Approve strategy to use Alice's LP
        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(address(stakedLPStrategy), lpBalance);

        // Preview shares to be minted for this LP balance
        uint256 previewShares = stakedLPStrategy.previewDeposit(lpBalance);
        vm.assume(previewShares > 0);

        // Perform mint with previewed shares
        uint256 assetsRequired = stakedLPStrategy.mint(previewShares, alice);

        // User gets intended shares, vault assets increased, only the required lp tokens moved
        assertEq(IERC20(address(stakedLPStrategy)).balanceOf(alice), previewShares, "Share balance mismatch on mint");
        assertEq(assetsRequired, lpBalance, "Mint did not use all deposited LP assets");

        uint256 afterTotalAssets = stakedLPStrategy.totalAssets();
        uint256 afterTotalSupply = stakedLPStrategy.totalSupply();

        assertEq(
            afterTotalAssets, beforeTotalAssets + lpBalance, "totalAssets not increased correctly after mint (fuzz)"
        );
        assertEq(
            afterTotalSupply, beforeTotalSupply + previewShares, "totalSupply not increased correctly after mint (fuzz)"
        );
        vm.stopPrank();
    }
}
