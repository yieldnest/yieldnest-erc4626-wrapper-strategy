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

contract VaultBasicFunctionalityTest is BaseIntegrationTest {
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
        coins[0] = address(0x01Ba69727E2860b37bc1a2bd56999c1aFb4C15D8);
        coins[1] = address(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f);

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

    function test_A_50_offpeg_fee_multiplier_5() public {
        uint256 A = 50;
        uint256 offpegFeeMultiplier = 5e10; // 10 decimals
        uint256 fee = 3000000;
        uint256 ma_exp_time = 1010;

        address poolAddress = create_pool(A, fee, offpegFeeMultiplier, ma_exp_time);
    }
}
