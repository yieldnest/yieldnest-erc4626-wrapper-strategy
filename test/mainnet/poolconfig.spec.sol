// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {MainnetContracts as MC} from "script/Contracts.sol";
import {BaseIntegrationTest} from "test/mainnet/BaseIntegrationTest.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";
import {ICurveStableSwapFactoryNG} from "src/interfaces/ICurveStableSwapFactoryNG.sol";
import {console} from "forge-std/console.sol";
import {MockERC4626} from "lib/yieldnest-vault/test/mainnet/mocks/MockERC4626.sol";

contract VaultBasicFunctionalityTest is BaseIntegrationTest {
    // Use alice as the liquidity provider and write a generic function for depositing to the pool

    address alice = address(0x1111);

    function setUp() public override {
        super.setUp();
    }

    function test_create_pool() public {
        uint256 A = 120;
        uint256 fee = 3500000;
        uint256 offpegFeeMultiplier = 120000000000;
        uint256 ma_exp_time = 1010;

        address poolAddress = create_pool(A, fee, offpegFeeMultiplier, ma_exp_time);
        assertNotEq(poolAddress, address(0));
    }

    function create_pool(uint256 A, uint256 fee, uint256 offpegFeeMultiplier, uint256 ma_exp_time)
        public
        returns (address)
    {
        address[] memory coins = new address[](2);
        coins[0] = MC.YNRWAX;
        coins[1] = MC.GHO;

        uint8[] memory assetTypes = new uint8[](2);
        assetTypes[0] = 3;
        assetTypes[1] = 0;

        bytes4[] memory methodIds = new bytes4[](2);
        methodIds[0] = bytes4(0x00000000);
        methodIds[1] = bytes4(0x00000000);

        address[] memory oracles = new address[](2);
        oracles[0] = address(0x0000000000000000000000000000000000000000);
        oracles[1] = address(0x0000000000000000000000000000000000000000);

        address poolAddress = ICurveStableSwapFactoryNG(MC.CURVE_STABLE_SWAP_FACTORY_NG).deploy_plain_pool(
            "ynRWAx/GHO-test-pool",
            "TynRWAxGHO",
            coins,
            A,
            fee,
            offpegFeeMultiplier,
            ma_exp_time,
            0,
            assetTypes,
            methodIds,
            oracles
        );
        return poolAddress;
    }

    function _depositToPool(address poolAddress, address alice, uint256 amount1, uint256 amount2) internal {
        // USDC and coin order: [ynRWAx, GHO]
        address ynRWAx = MC.YNRWAX;
        address GHO = MC.GHO;

        // Mint or allocate USDC to alice, then allocate USDC to ynRWAx via test logic (assume a swap/mint simulation)
        deal(MC.USDC, alice, amount1);

        // Simulate logic where alice allocates USDC to ynRWAx (abstracted for brevity; replace as needed)
        // For test: directly mint ynRWAx tokens to alice, as if she swapped USDC for ynRWAx somehow.
        deal(ynRWAx, alice, amount1);

        // Also mint GHO tokens to alice for the second leg of the pair
        deal(GHO, alice, amount2);

        // alice approves the pool to spend her tokens
        vm.startPrank(alice);
        IERC20(ynRWAx).approve(poolAddress, amount1);
        IERC20(GHO).approve(poolAddress, amount2);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        // Deposit them both at the same time to the pool
        ICurvePool(poolAddress).add_liquidity(amounts, 0);
        vm.stopPrank();
    }

    function test_A_50_offpeg_fee_multiplier_5() public {
        uint256 A = 50;
        uint256 offpegFeeMultiplier = 5e10; // 10 decimals
        uint256 fee = 3000000;
        uint256 ma_exp_time = 1010;

        address poolAddress = create_pool(A, fee, offpegFeeMultiplier, ma_exp_time);

        uint256 amount = 1_000_000 * 1e18; // using 18 decimals for the test

        _depositToPool(poolAddress, alice, 1e18, 1e18);
    }
}
