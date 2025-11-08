// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {AssertUtils} from "lib/yieldnest-vault/test/utils/AssertUtils.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {StakedLPStrategy} from "src/StakedLPStrategy.sol";
import {TransparentUpgradeableProxy} from "lib/yieldnest-vault/src/Common.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";

contract BaseIntegrationTest is Test, AssertUtils {
    StakedLPStrategy public stakedLPStrategy;

    address public ADMIN = makeAddr("admin");

    function setUp() public virtual {
        stakedLPStrategy = new StakedLPStrategy();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(stakedLPStrategy), ADMIN, "");
        stakedLPStrategy = StakedLPStrategy(payable(address(proxy)));

        StakedLPStrategy.InitParams memory initParams = StakedLPStrategy.InitParams({
            admin: ADMIN,
            name: "Staked LP Strategy",
            symbol: "sLP",
            decimals_: 18,
            countNativeAsset_: true,
            alwaysComputeTotalAssets_: true,
            defaultAssetIndex_: 0,
            stakeDaoLPToken_: MC.STAKEDAO_CURVE_ynRWAx_USDC_LP
        });

        stakedLPStrategy.initialize(initParams);
    }
}
