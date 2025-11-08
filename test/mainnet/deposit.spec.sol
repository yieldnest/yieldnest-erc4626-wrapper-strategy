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

    function test_deposit_lp() public {
        uint256 depositAmount = 100e6;

        // Assume 'alice' address is available (e.g. from makeAddr("alice"))
        address alice = makeAddr("alice");

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

        // Interface for YNRWAX should have a deposit or mint method
        // For the purpose of modelling, let's assume it's: function deposit(uint256 amount) public returns (uint256);
        // (You may need to adapt this call based on actual YNRWAX interface)
        IERC4626(ynrwax).deposit(halfAmount, alice);

        // After this, alice has (halfAmount) YNRWAX and (halfAmount) USDC

        // Approve LP pool to spend USDC and YNRWAX for adding liquidity
        IERC20(usdc).approve(curveLp, halfAmount);
        IERC20(ynrwax).approve(curveLp, halfAmount); // or actual balance of YNRWAX minted

        // Add both tokens as liquidity to the LP (assuming it's a 2-coin pool [YNRWAX, USDC] and add_liquidity signature)
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = halfAmount;
        amounts[1] = halfAmount;
        ICurvePool(curveLp).add_liquidity(amounts, 0);

        address gauge = MC.STAKEDAO_CURVE_ynRWAx_USDC_LP;

        // Find how much LP tokens alice received (query balance)
        uint256 lpBalance = IERC20(curveLp).balanceOf(alice);

        // Approve Gauge to spend LP tokens
        IERC20(curveLp).approve(gauge, lpBalance);

        console.log("LP balance:", lpBalance);
        // Log alice's gauge balance before deposit
        console.log("Gauge balance before:", IERC20(gauge).balanceOf(alice));

        // Deposit all LP tokens into the Gauge as alice
        IStakeDaoLiquidityGauge(gauge).deposit(lpBalance);

        // Log alice's gauge balance after deposit
        console.log("Gauge balance after:", IERC20(gauge).balanceOf(alice));

        vm.stopPrank();
    }
}
