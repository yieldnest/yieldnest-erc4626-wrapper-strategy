// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IActors} from "lib/yieldnest-vault/script/Actors.sol";
import {IProvider} from "lib/yieldnest-vault/src/interface/IProvider.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC4626WrapperStrategy} from "src/ERC4626WrapperStrategy.sol";
import {TransparentUpgradeableProxy} from "lib/yieldnest-vault/src/Common.sol";
import {BaseRoles} from "script/roles/BaseRoles.sol";
import {SafeRules, IVault} from "@yieldnest-vault-script/rules/SafeRules.sol";
import {Provider} from "src/module/Provider.sol";
import {ERC4626WrapperHooks} from "src/hooks/ERC4626WrapperHooks.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {BaseRules} from "lib/yieldnest-vault/script/rules/BaseRules.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";

contract StrategyDeployer {
    error InvalidDeploymentParams(string);
    error DeploymentDone();

    struct DeploymentParams {
        string name;
        string symbol;
        uint8 decimals;
        IActors actors;
        address targetVault;
        bool countNativeAsset;
        Implementations implementations;
    }

    struct Implementations {
        ERC4626WrapperStrategy stakedLpStrategyImplementation;
        TimelockController timelockController;
    }

    ERC4626WrapperStrategy public strategy;

    address public deployer;
    string public name;
    string public symbol_;
    uint8 public decimals;
    bool public countNativeAsset;
    IProvider public rateProvider;
    TimelockController public timelock;
    IActors public actors;
    Implementations public implementations;
    address public targetVault;
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
        targetVault = params.targetVault;
        countNativeAsset = params.countNativeAsset;
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
        strategy = ERC4626WrapperStrategy(
            payable(
                address(
                    new TransparentUpgradeableProxy(
                        address(implementations.stakedLpStrategyImplementation),
                        address(timelock),
                        abi.encodeWithSelector(
                            ERC4626WrapperStrategy.initialize.selector,
                            // Pass as a single InitParams struct as required in StakedLPStrategy
                            ERC4626WrapperStrategy.InitParams({
                                admin: admin,
                                name: name,
                                symbol: symbol_,
                                decimals_: decimals,
                                alwaysComputeTotalAssets_: true, // for fee collection
                                defaultAssetIndex_: 0,
                                countNativeAsset_: countNativeAsset
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

        {
            // Configure assets and provider

            address underlyingAsset = IERC4626(targetVault).asset();

            // depositable and withdrawable
            strategy.addAsset(underlyingAsset, 18, true, true);
            // not depositable and not withdrawable
            strategy.addAsset(targetVault, false, false);

            strategy.setProvider(address(rateProvider));
        }

        ERC4626WrapperHooks hooks = new ERC4626WrapperHooks(address(strategy), targetVault);
        strategy.setHooks(address(hooks));

        strategy.grantRole(strategy.PROCESSOR_ROLE(), address(hooks));

        {
            address underlyingAsset = IERC4626(targetVault).asset();
            SafeRules.RuleParams[] memory rules = new SafeRules.RuleParams[](3);
            rules[0] = BaseRules.getDepositRule(targetVault, address(strategy));
            rules[1] = BaseRules.getWithdrawRule(targetVault, address(strategy));
            rules[2] = BaseRules.getApprovalRule(underlyingAsset, targetVault);

            // Set processor rules using SafeRules
            SafeRules.setProcessorRules(IVault(address(strategy)), rules, true);
        }

        strategy.unpause();

        BaseRoles.renounceTemporaryRolesStrategy(strategy, deployer);
    }

    function deployRateProvider() internal {
        rateProvider = IProvider(address(new Provider(targetVault)));
    }
}
