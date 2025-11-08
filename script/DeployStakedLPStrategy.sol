// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {BaseRoles} from "script/roles/BaseRoles.sol";
import {console} from "forge-std/console.sol";
import {SafeRules, IVault} from "@yieldnest-vault-script/rules/SafeRules.sol";
import {StakedLPStrategyDeployer} from "script/StakedLPStrategyDeployer.sol";
import {StakedLPStrategy} from "src/StakedLPStrategy.sol";
import {BaseScript} from "script/BaseScript.sol";
import {ProxyUtils} from "lib/yieldnest-vault/script/ProxyUtils.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IProvider} from "lib/yieldnest-vault/src/interface/IProvider.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";
import {Script} from "forge-std/Script.sol";

// forge script DeployFlexStrategy --rpc-url <MAINNET_RPC_URL>  --slow --broadcast --account
// <CAST_WALLET_ACCOUNT>  --sender <SENDER_ADDRESS>  --verify --etherscan-api-key <ETHERSCAN_API_KEY>  -vvv
contract DeployFlexStrategy is BaseScript {
    error InvalidRules();
    error InvalidRateProvider();
    error InvalidDeploymentParams(string);

    function symbol() public view override returns (string memory) {
        return symbol_;
    }

    function _verifySetup() public view override {
        super._verifySetup();
    }

    function createDeployer(StakedLPStrategyDeployer.Implementations memory implementations)
        internal
        virtual
        returns (StakedLPStrategyDeployer)
    {
        return new StakedLPStrategyDeployer(
            StakedLPStrategyDeployer.DeploymentParams({
                name: name,
                symbol: symbol_,
                decimals: decimals,
                actors: actors,
                stakeDaoLpToken: stakeDaoLpToken,
                implementations: implementations
            })
        );
    }

    function run() public virtual {
        vm.startBroadcast();

        _setup();
        assignDeploymentParameters();
        _verifyDeploymentParams();

        _deployTimelockController();

        StakedLPStrategyDeployer.Implementations memory implementations;
        implementations.stakedLpStrategyImplementation = new StakedLPStrategy();
        implementations.timelockController = timelock;

        StakedLPStrategyDeployer strategyDeployer = createDeployer(implementations);
        // The Deployer is the Strategy Deployer contract
        deployer = address(strategyDeployer);

        strategyDeployer.deploy();
        readDeployedContracts(strategyDeployer);

        _verifySetup();

        _saveDeployment(deploymentEnv);

        vm.stopBroadcast();
    }

    function readDeployedContracts(StakedLPStrategyDeployer strategyDeployer) internal virtual {
        strategy = strategyDeployer.strategy();
        rateProvider = strategyDeployer.rateProvider();
        timelock = strategyDeployer.timelock();
    }

    function assignDeploymentParameters() internal virtual {
        if (decimals == 0) {
            revert("Not pre-configured");
        }
        baseAsset = IStakeDaoLiquidityGauge(stakeDaoLpToken).lp_token();
    }

    function _verifyDeploymentParams() internal view virtual {
        if (bytes(name).length == 0) {
            revert InvalidDeploymentParams("strategy name not set");
        }

        if (bytes(symbol_).length == 0) {
            revert InvalidDeploymentParams("strategy symbol not set");
        }

        if (decimals == 0) {
            revert InvalidDeploymentParams("strategy decimals not set");
        }

        if (stakeDaoLpToken == address(0)) {
            revert InvalidDeploymentParams("stakeDaoLpToken is not set");
        }
    }
}
