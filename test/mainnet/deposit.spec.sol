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

        address vault = MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT;

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

        console.log("Alice's LP balance:", lpBalance);

        // Deposit to the strategy (assumes deposit(uint256, address) present, else update selector)
        uint256 shares = stakedLPStrategy.deposit(lpBalance, alice);

        // Alice's strategy share balance increases
        uint256 aliceShareBalance = IERC20(stakedLPStrategy).balanceOf(alice);
        console.log("Alice strategy share balance:", aliceShareBalance);

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
}
