// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IHooks} from "lib/yieldnest-vault/src/interface/IHooks.sol";
import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";
import {BaseVault} from "lib/yieldnest-vault/src/BaseVault.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {IERC20} from "lib/yieldnest-vault/src/Common.sol";

contract StakedLpStrategyHooks is IHooks {
    error NotSupported();

    IVault public immutable vault;
    IStakeDaoLiquidityGauge public immutable stakeDaoLiquidityGauge;

    constructor(address _vault, address _stakeDaoLiquidityGauge) {
        vault = IVault(_vault);
        stakeDaoLiquidityGauge = IStakeDaoLiquidityGauge(_stakeDaoLiquidityGauge);
    }

    modifier onlyVault() {
        if (msg.sender != address(vault)) {
            revert CallerNotVault();
        }
        _;
    }

    /**
     * @notice Returns the name of the hooks module
     * @return The name of the hooks module
     */
    function name() external pure override returns (string memory) {
        return "StakedLpStrategyHooks";
    }

    /**
     * @notice Returns the vault that the hooks are attached to
     * @return The vault contract interface
     */
    function VAULT() external view override returns (IVault) {
        return vault;
    }

    /**
     * @notice Sets the hooks configuration
     * @param config_ The configuration struct containing hook permissions
     */
    function setConfig(Config memory config_) external override {
        revert NotSupported();
    }

    /**
     * @notice Gets the current hooks configuration
     * @return The configuration struct containing hook permissions
     */
    function getConfig() external view override returns (Config memory) {
        return Config({
            beforeDeposit: false,
            afterDeposit: true,
            beforeMint: false,
            afterMint: true,
            beforeRedeem: true,
            afterRedeem: false,
            beforeWithdraw: true,
            afterWithdraw: false,
            beforeProcessAccounting: false,
            afterProcessAccounting: false
        });
    }

    function handleAfterDeposit(address asset, uint256 assets) internal {
        if (asset == vault.asset()) {
            address[] memory targets = new address[](2);
            uint256[] memory values = new uint256[](2);
            bytes[] memory data = new bytes[](2);

            // 1. approve asset to StakeDAO gauge
            targets[0] = asset;
            values[0] = 0;
            data[0] = abi.encodeWithSignature("approve(address,uint256)", address(stakeDaoLiquidityGauge), assets);

            // 2. call deposit/Stake on stake dao (assuming deposit(uint256) interface)
            targets[1] = address(stakeDaoLiquidityGauge);
            values[1] = 0;
            data[1] = abi.encodeWithSignature("deposit(uint256)", assets);

            BaseVault(payable(address(vault))).processor(targets, values, data);
        }
    }

    function handleBeforeRedeem(address asset, uint256 assets) internal {
        if (asset == vault.asset()) {
            address[] memory targets = new address[](1);
            uint256[] memory values = new uint256[](1);
            bytes[] memory data = new bytes[](1);

            // 1. Call withdraw on the StakeDAO gauge (assuming withdraw(uint256) interface)
            targets[0] = address(stakeDaoLiquidityGauge);
            values[0] = 0;
            data[0] = abi.encodeWithSignature("withdraw(uint256)", assets);

            BaseVault(payable(address(vault))).processor(targets, values, data);
        }
    }

    /**
     * @notice Hook called before deposit is processed
     * @param params The deposit parameters
     */
    function beforeDeposit(DepositParams memory params) external override onlyVault {
        // no-op
    }

    /**
     * @notice Hook called after deposit is processed
     * @param params The deposit parameters
     */
    function afterDeposit(DepositParams memory params) external override onlyVault {
        handleAfterDeposit(params.asset, params.assets);
    }

    /**
     * @notice Hook called before mint is processed
     * @param params The mint parameters
     */
    function beforeMint(MintParams memory params) external override onlyVault {}

    /**
     * @notice Hook called after mint is processed
     * @param params The mint parameters
     */
    function afterMint(MintParams memory params) external override onlyVault {
        handleAfterDeposit(params.asset, params.assets);
    }

    /**
     * @notice Hook called before redeem is processed
     * @param params The redeem parameters
     */
    function beforeRedeem(RedeemParams memory params) external override onlyVault {
        handleBeforeRedeem(params.asset, params.assets);
    }

    /**
     * @notice Hook called after redeem is processed
     * @param params The redeem parameters
     */
    function afterRedeem(RedeemParams memory params) external override onlyVault {
        // no-op
    }

    /**
     * @notice Hook called before withdraw is processed
     * @param params The withdraw parameters
     */
    function beforeWithdraw(WithdrawParams memory params) external override onlyVault {
        handleBeforeRedeem(params.asset, params.assets);
    }

    /**
     * @notice Hook called after withdraw is processed
     * @param params The withdraw parameters
     */
    function afterWithdraw(WithdrawParams memory params) external override onlyVault {
        // no-op
    }

    /**
     * @notice Hook called before process accounting is executed
     * @param params The before process accounting parameters
     */
    function beforeProcessAccounting(BeforeProcessAccountingParams memory params) external override onlyVault {
        // no-op
    }

    /**
     * @notice Hook called after process accounting is executed
     * @param params The after process accounting parameters
     */
    function afterProcessAccounting(AfterProcessAccountingParams memory params) external override onlyVault {
        // no-op
    }
}
