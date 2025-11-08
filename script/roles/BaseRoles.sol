// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {IActors} from "lib/yieldnest-vault/script/Actors.sol";

import {StakedLPStrategy} from "src/StakedLPStrategy.sol";
import {SafeRules, IVault} from "@yieldnest-vault-script/rules/SafeRules.sol";

library BaseRoles {
    function configureDefaultRoles(StakedLPStrategy strategy, address timelock, IActors actors) internal {
        // set admin roles
        strategy.grantRole(strategy.DEFAULT_ADMIN_ROLE(), actors.ADMIN());
        strategy.grantRole(strategy.PROCESSOR_ROLE(), actors.PROCESSOR());
        strategy.grantRole(strategy.PAUSER_ROLE(), actors.PAUSER());
        strategy.grantRole(strategy.UNPAUSER_ROLE(), actors.UNPAUSER());

        // set timelock roles
        strategy.grantRole(strategy.PROVIDER_MANAGER_ROLE(), timelock);
        strategy.grantRole(strategy.ASSET_MANAGER_ROLE(), timelock);
        strategy.grantRole(strategy.BUFFER_MANAGER_ROLE(), timelock);
        strategy.grantRole(strategy.PROCESSOR_MANAGER_ROLE(), timelock);
        strategy.grantRole(strategy.ALLOCATOR_MANAGER_ROLE(), timelock);
        strategy.grantRole(strategy.HOOKS_MANAGER_ROLE(), timelock);
    }

    function configureDefaultRolesStrategy(StakedLPStrategy strategy, address timelock, IActors actors) internal {
        configureDefaultRoles(strategy, timelock, actors);
    }

    function configureTemporaryRoles(StakedLPStrategy strategy, address deployer) internal {
        strategy.grantRole(strategy.DEFAULT_ADMIN_ROLE(), deployer);
        strategy.grantRole(strategy.PROCESSOR_MANAGER_ROLE(), deployer);
        strategy.grantRole(strategy.BUFFER_MANAGER_ROLE(), deployer);
        strategy.grantRole(strategy.PROVIDER_MANAGER_ROLE(), deployer);
        strategy.grantRole(strategy.ASSET_MANAGER_ROLE(), deployer);
        strategy.grantRole(strategy.UNPAUSER_ROLE(), deployer);
        strategy.grantRole(strategy.ALLOCATOR_MANAGER_ROLE(), deployer);
        strategy.grantRole(strategy.HOOKS_MANAGER_ROLE(), deployer);
    }

    function configureTemporaryRolesStrategy(StakedLPStrategy strategy, address deployer) internal {
        configureTemporaryRoles(strategy, deployer);
    }

    function renounceTemporaryRoles(StakedLPStrategy strategy, address deployer) internal {
        strategy.renounceRole(strategy.DEFAULT_ADMIN_ROLE(), deployer);
        strategy.renounceRole(strategy.PROCESSOR_MANAGER_ROLE(), deployer);
        strategy.renounceRole(strategy.BUFFER_MANAGER_ROLE(), deployer);
        strategy.renounceRole(strategy.PROVIDER_MANAGER_ROLE(), deployer);
        strategy.renounceRole(strategy.ASSET_MANAGER_ROLE(), deployer);
        strategy.renounceRole(strategy.UNPAUSER_ROLE(), deployer);
        strategy.renounceRole(strategy.ALLOCATOR_MANAGER_ROLE(), deployer);
        strategy.renounceRole(strategy.HOOKS_MANAGER_ROLE(), deployer);
    }

    function renounceTemporaryRolesStrategy(StakedLPStrategy strategy, address deployer) internal {
        renounceTemporaryRoles(strategy, deployer);
    }
}
