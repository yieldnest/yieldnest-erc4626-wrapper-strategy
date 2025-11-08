// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {AssertUtils} from "lib/yieldnest-vault/test/utils/AssertUtils.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {StakedLPStrategy} from "src/StakedLPStrategy.sol";
import {TransparentUpgradeableProxy} from "lib/yieldnest-vault/src/Common.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {Provider} from "src/module/Provider.sol";
import {DeployStakedLPStrategy} from "script/DeployStakedLPStrategy.sol";
import {BaseScript} from "script/BaseScript.sol";

contract BaseIntegrationTest is Test, AssertUtils {
    StakedLPStrategy public stakedLPStrategy;
    DeployStakedLPStrategy public deployment;

    address public ADMIN = makeAddr("admin");

    function setUp() public virtual {
        deployment = new DeployStakedLPStrategy();

        deployment.setDeploymentParameters(
            BaseScript.DeploymentParameters({
                name: "Staked LP Strategy ynRWAx-USDC",
                symbol_: "sLP-ynRWAx-USDC",
                decimals: 18,
                stakeDaoLpToken: MC.STAKEDAO_CURVE_ynRWAx_USDC_LP
            })
        );
        deployment.setEnv(BaseScript.Env.TEST);
        deployment.run();

        stakedLPStrategy = StakedLPStrategy(deployment.strategy());
    }
}
