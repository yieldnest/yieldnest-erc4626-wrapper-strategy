// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IActors} from "lib/yieldnest-vault/script/Actors.sol";
import {IProvider} from "lib/yieldnest-vault/src/interface/IProvider.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {StakedLPStrategy} from "src/StakedLPStrategy.sol";
import {TransparentUpgradeableProxy} from "lib/yieldnest-vault/src/Common.sol";
import {BaseRoles} from "script/roles/BaseRoles.sol";
import {SafeRules, IVault} from "@yieldnest-vault-script/rules/SafeRules.sol";
import {Provider} from "src/module/Provider.sol";

contract StakedLPStrategyDeployer {
    error InvalidDeploymentParams(string);
    error DeploymentDone();

    struct DeploymentParams {
        string name;
        string symbol;
        string accountTokenName;
        string accountTokenSymbol;
        uint8 decimals;
        IActors actors;
        address stakeDaoLpToken;
        Implementations implementations;
    }

    struct Implementations {
        StakedLPStrategy stakedLpStrategyImplementation;
        TimelockController timelockController;
    }

    StakedLPStrategy public strategy;

    address public deployer;
    string public name;
    string public symbol_;
    uint8 public decimals;
    IProvider public rateProvider;
    TimelockController public timelock;
    IActors public actors;
    Implementations public implementations;
    address public stakeDaoLpToken;
    address public curvePool;

    bool public deploymentDone;

    constructor(DeploymentParams memory params) {
        // the contract is the deployer
        deployer = address(this);
        actors = params.actors;

        // Set deployment parameters
        name = params.name;
        symbol_ = params.symbol;
        decimals = params.decimals;
        stakeDaoLpToken = params.stakeDaoLpToken;
        implementations = params.implementations;
    }

    function deploy() public virtual {
        if (deploymentDone) {
            revert DeploymentDone();
        }
        deploymentDone = true;

        address admin = deployer;

        timelock = implementations.timelockController;

        deployRateProvider();

        // Adapt initialization to match StakedLPStrategy.InitParams
        // See StakedLPStrategy.sol for the correct order/fields.
        strategy = StakedLPStrategy(
            payable(
                address(
                    new TransparentUpgradeableProxy(
                        address(implementations.stakedLpStrategyImplementation),
                        address(timelock),
                        abi.encodeWithSelector(
                            StakedLPStrategy.initialize.selector,
                            // Pass as a single InitParams struct as required in StakedLPStrategy
                            StakedLPStrategy.InitParams({
                                admin: admin,
                                name: name,
                                symbol: symbol_,
                                decimals_: decimals,
                                alwaysComputeTotalAssets_: true, // for fee collection
                                defaultAssetIndex_: 0,
                                stakeDaoLPToken_: stakeDaoLpToken,
                                provider_: address(rateProvider)
                            })
                        )
                    )
                )
            )
        );

        configureStrategy();
    }

    function configureStrategy() internal virtual {
        BaseRoles.configureDefaultRolesStrategy(strategy, address(timelock), actors);
        BaseRoles.configureTemporaryRolesStrategy(strategy, deployer);

        strategy.unpause();

        BaseRoles.renounceTemporaryRolesStrategy(strategy, deployer);
    }

    function deployRateProvider() internal {
        rateProvider = IProvider(address(new Provider(stakeDaoLpToken)));
    }
}
