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

    function deposit_lp(address alice, uint256 depositAmount) public returns (uint256) {
        // Deal USDC to alice
        uint256 aliceAmount = depositAmount;
        deal(MC.USDC, alice, aliceAmount);

        // Half of alice's USDC to deposit into YNRWAX
        uint256 halfAmount = aliceAmount / 2;

        // Addresses required
        address usdc = MC.USDC;
        address curveLp = MC.CURVE_ynRWAx_USDC_LP;

        // Use YNRWAX constant directly
        address ynrwax = MC.YNRWAX;

        // Prank as alice for interacting from her address
        vm.startPrank(alice);

        // Approve YNRWAX contract to spend USDC, then deposit half to YNRWAX
        IERC20(usdc).approve(ynrwax, halfAmount);

        IERC4626(ynrwax).deposit(halfAmount, alice);

        // Interface for YNRWAX should have a deposit or mint method
        // For the purpose of modelling, let's assume it's: function deposit(uint256 amount) public returns (uint256);
        // (You may need to adapt this call based on actual YNR

        // Approve LP pool to spend USDC and YNRWAX for adding liquidity
        IERC20(usdc).approve(curveLp, halfAmount);
        IERC20(ynrwax).approve(curveLp, halfAmount); // or actual balance of YNRWAX minted

        // Add both tokens as liquidity to the LP (assuming it's a 2-coin pool [YNRWAX, USDC] and add_liquidity signature)
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = halfAmount;
        amounts[1] = halfAmount;
        return ICurvePool(curveLp).add_liquidity(amounts, 0);
    }

    function test_deposit_lp() public {
        uint256 depositAmount = 100e6;

        // Assume 'alice' address is available (e.g. from makeAddr("alice"))
        address alice = makeAddr("alice");

        deposit_lp(alice, depositAmount);

        address gauge = MC.STAKEDAO_CURVE_ynRWAx_USDC_LP;

        // Find how much LP tokens alice received (query balance)
        uint256 lpBalance = IERC20(MC.CURVE_ynRWAx_USDC_LP).balanceOf(alice);

        // Approve Gauge to spend LP tokens
        IERC20(MC.CURVE_ynRWAx_USDC_LP).approve(gauge, lpBalance);

        console.log("LP balance:", lpBalance);
        // Log alice's gauge balance before deposit
        console.log("Gauge balance before:", IERC20(gauge).balanceOf(alice));

        // Deposit all LP tokens into the Gauge as alice
        IStakeDaoLiquidityGauge(gauge).deposit(lpBalance);

        // Log alice's gauge balance after deposit
        console.log("Gauge balance after:", IERC20(gauge).balanceOf(alice));

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

        assertEq(aliceShareBalance, shares, "Share amount mismatch after fuzz deposit");

        vm.stopPrank();
    }
}
