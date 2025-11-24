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
import {MockERC4626, ERC20} from "lib/yieldnest-vault/test/mainnet/mocks/MockERC4626.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract VaultBasicFunctionalityTest is BaseIntegrationTest {
    // Use alice as the liquidity provider and write a generic function for depositing to the pool

    address alice = address(0x1111);

    MockERC4626 public assetA;
    MockERC4626 public assetB;

    address baseAsset = MC.USDS;

    function setUp() public override {
        super.setUp();

        assetA = new MockERC4626(ERC20(baseAsset), "Mock USDC", "MUSDC");
        assetB = new MockERC4626(ERC20(baseAsset), "Mock USDC", "MUSDC");

        // Mint 20e6 USDC to bob, approve both assets, and deposit into both MockERC4626 vaults
        address bob = address(0x2222);

        uint256 totalAmount = 20 * 10 ** IERC20Metadata(baseAsset).decimals();
        deal(baseAsset, bob, totalAmount);

        vm.startPrank(bob);

        IERC20(baseAsset).approve(address(assetA), totalAmount / 2);
        IERC20(baseAsset).approve(address(assetB), totalAmount / 2);

        assetA.deposit(totalAmount / 2, bob);
        assetB.deposit(totalAmount / 2, bob);

        vm.stopPrank();
    }

    function test_create_pool() public {
        uint256 A = 120;
        uint256 fee = 3500000;
        uint256 offpegFeeMultiplier = 120000000000;
        uint256 ma_exp_time = 1010;

        address poolAddress = create_pool(A, fee, offpegFeeMultiplier, ma_exp_time);
        assertNotEq(poolAddress, address(0));
    }

    function test_create_pool_withdraw_liquidity_one_coin() public {
        uint256 A = 120;
        uint256 fee = 3000000;
        uint256 offpegFeeMultiplier = 120000000000;
        uint256 ma_exp_time = 1010;

        address poolAddress = create_pool(A, fee, offpegFeeMultiplier, ma_exp_time);
        assertNotEq(poolAddress, address(0));

        uint256 amount = 1_000_000 * 1e18; // using 18 decimals for the test

        _depositToPool(poolAddress, alice, 1e18, 1e18);

        uint256 lpBalance = IERC20(poolAddress).balanceOf(alice);

        console.log("lpBalance:", lpBalance);

        // uint256 redeemableAmount = ICurvePool(MC.CURVE_ynRWAx_USDC_LP).calc_withdraw_one_coin(lpBalance, 1);
        // assertEq(redeemableAmount, amount, "Redeemable amount mismatch");
    }

    function create_pool(uint256 A, uint256 fee, uint256 offpegFeeMultiplier, uint256 ma_exp_time)
        public
        returns (address)
    {
        address[] memory coins = new address[](2);
        coins[0] = address(assetA);
        coins[1] = address(assetB);

        uint8[] memory assetTypes = new uint8[](2);
        assetTypes[0] = 3;
        assetTypes[1] = 3;

        bytes4[] memory methodIds = new bytes4[](2);
        methodIds[0] = bytes4(0x00000000);
        methodIds[1] = bytes4(0x00000000);

        address[] memory oracles = new address[](2);
        oracles[0] = address(0x0000000000000000000000000000000000000000);
        oracles[1] = address(0x0000000000000000000000000000000000000000);

        address poolAddress = ICurveStableSwapFactoryNG(MC.CURVE_STABLE_SWAP_FACTORY_NG).deploy_plain_pool(
            "AA/AB-test-pool",
            "TynAB",
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
        address assetA = ICurvePool(poolAddress).coins(0);
        address assetB = ICurvePool(poolAddress).coins(1);

        uint256 assetAShares;
        uint256 assetBShares;

        {
            deal(baseAsset, alice, amount1);

            vm.startPrank(alice);
            // Deposit amount1 to assetA using ERC4626, store returned shares
            IERC20(baseAsset).approve(address(assetA), amount1);
            assetAShares = IERC4626(assetA).deposit(amount1, alice);
            vm.stopPrank();
        }

        {
            // Mint or allocate USDC to alice, then allocate USDC to ynRWAx via test logic (assume a swap/mint simulation)
            deal(baseAsset, alice, amount2);

            vm.startPrank(alice);
            // Deposit amount2 to assetB using ERC4626, store returned shares
            IERC20(baseAsset).approve(address(assetB), amount2);
            assetBShares = IERC4626(assetB).deposit(amount2, alice);
            vm.stopPrank();
        }

        // alice approves the pool to spend her tokens
        vm.startPrank(alice);
        IERC20(assetA).approve(poolAddress, assetAShares);
        IERC20(assetB).approve(poolAddress, assetBShares);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = assetAShares;
        amounts[1] = assetBShares;

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
