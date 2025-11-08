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

        stakedLPStrategy.initialize(ADMIN, "Staked LP Strategy", "sLP", 18, true, true, 0, MC.CURVE_ynRWAx_USDC_LP);
    }
}
