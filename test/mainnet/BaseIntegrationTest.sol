// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {AssertUtils} from "lib/yieldnest-vault/test/utils/AssertUtils.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {StakedLPStrategy} from "src/StakedLPStrategy.sol";
import {TransparentUpgradeableProxy} from "lib/yieldnest-vault/src/Common.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {Provider} from "src/module/Provider.sol";

contract BaseIntegrationTest is Test, AssertUtils {
    StakedLPStrategy public stakedLPStrategy;

    address public ADMIN = makeAddr("admin");

    function setUp() public virtual {
        stakedLPStrategy = new StakedLPStrategy();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(stakedLPStrategy), ADMIN, "");
        stakedLPStrategy = StakedLPStrategy(payable(address(proxy)));

        Provider provider = new Provider(MC.STAKEDAO_CURVE_ynRWAx_USDC_LP);

        StakedLPStrategy.InitParams memory initParams = StakedLPStrategy.InitParams({
            admin: ADMIN,
            name: "Staked LP Strategy ynRWAx/USDC",
            symbol: "sLP-ynRWAx/USDC",
            decimals_: 18,
            alwaysComputeTotalAssets_: false,
            defaultAssetIndex_: 0,
            stakeDaoLPToken_: MC.STAKEDAO_CURVE_ynRWAx_USDC_LP,
            provider_: address(provider)
        });

        stakedLPStrategy.initialize(initParams);
    }
}
