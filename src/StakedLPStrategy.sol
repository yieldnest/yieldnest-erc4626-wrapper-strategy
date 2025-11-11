// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {BaseStrategy} from "lib/yieldnest-vault/src/strategy/BaseStrategy.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";
import {IERC20} from "lib/yieldnest-vault/src/Common.sol";
import {IStakeDaoLiquidityGauge} from "src/interfaces/IStakeDaoLiquidityGauge.sol";
import {VaultLib} from "lib/yieldnest-vault/src/library/VaultLib.sol";
import {FeeMath} from "lib/yieldnest-vault/src/module/FeeMath.sol";

contract StakedLPStrategy is BaseStrategy {
    string public constant STAKED_LP_STRATEGY_VERSION = "0.1.0";

    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    struct InitParams {
        address admin;
        string name;
        string symbol;
        uint8 decimals_;
        bool alwaysComputeTotalAssets_;
        uint256 defaultAssetIndex_;
        address stakeDaoLPToken_;
        address provider_;
    }

    /**
     * @notice Initializes the strategy.
     * @param params The struct containing all initialization parameters.
     */
    function initialize(InitParams calldata params) external virtual initializer {
        _initialize(
            params.admin,
            params.name,
            params.symbol,
            params.decimals_,
            true, // paused
            false, // countNativeAsset_ is false because the strategy does not hold the native asset
            params.alwaysComputeTotalAssets_,
            params.defaultAssetIndex_
        );

        address curveLpToken = IStakeDaoLiquidityGauge(params.stakeDaoLPToken_).lp_token();

        _addAsset(curveLpToken, 18, true);
        _setAssetWithdrawable(curveLpToken, true);
        _addAsset(params.stakeDaoLPToken_, 18, false);

        VaultLib.setProvider(params.provider_);
    }

    //// FEES ////

    function _getFeeStorage() internal pure returns (FeeStorage storage) {
        return VaultLib.getFeeStorage();
    }

    /**
     * @notice Returns the fee on amount where the fee would get added on top of the amount.
     * @param amount The amount on which the fee would get added.
     * @param user The address of the user.
     * @return The fee amount.
     */
    function _feeOnRaw(uint256 amount, address user) public view override returns (uint256) {
        return FeeMath.feeOnRaw(amount, _feesToCharge(user));
    }

    /**
     * @notice Returns the fee amount where fee is already included in amount
     * @param amount The amount on which the fee is already included.
     * @param user The address of the user.
     * @return The fee amount.
     * @dev Calculates the fee part of an amount `amount` that already includes fees.
     * Used in {IERC4626-deposit} and {IERC4626-redeem} operations.
     */
    function _feeOnTotal(uint256 amount, address user) public view override returns (uint256) {
        return FeeMath.feeOnTotal(amount, _feesToCharge(user));
    }

    /**
     * @notice Returns the fee to charge for a user based on whether the fee is overridden for the user
     * @param user The address of the user.
     * @return The fee to charge.
     */
    function _feesToCharge(address user) internal view returns (uint64) {
        FeeStorage storage fees = _getFeeStorage();
        bool isFeeOverridenForUser = fees.overriddenBaseWithdrawalFee[user].isOverridden;
        if (isFeeOverridenForUser) {
            return fees.overriddenBaseWithdrawalFee[user].baseWithdrawalFee;
        } else {
            return fees.baseWithdrawalFee;
        }
    }

    //// FEES ADMIN ////

    /**
     * @notice Sets the base withdrawal fee for the vault
     * @param baseWithdrawalFee_ The new base withdrawal fee in basis points (1/10000)
     * @dev Only callable by accounts with FEE_MANAGER_ROLE
     */
    function setBaseWithdrawalFee(uint64 baseWithdrawalFee_) external virtual onlyRole(FEE_MANAGER_ROLE) {
        _setBaseWithdrawalFee(baseWithdrawalFee_);
    }

    /**
     * @notice Sets whether the withdrawal fee is exempted for a user
     * @param user_ The address of the user
     * @param baseWithdrawalFee_ The overridden base withdrawal fee in basis points (1/10000)
     * @param toOverride_ Whether to override the withdrawal fee for the user
     * @dev Only callable by accounts with FEE_MANAGER_ROLE
     */
    function overrideBaseWithdrawalFee(address user_, uint64 baseWithdrawalFee_, bool toOverride_)
        external
        virtual
        onlyRole(FEE_MANAGER_ROLE)
    {
        _overrideBaseWithdrawalFee(user_, baseWithdrawalFee_, toOverride_);
    }

    /**
     * @notice Internal function to set whether the withdrawal fee is exempted for a user
     * @param user_ The address of the user
     * @param baseWithdrawalFee_ The overridden base withdrawal fee in basis points (1/10000)
     * @param toOverride_ Whether to override the withdrawal fee for the user
     */
    function _overrideBaseWithdrawalFee(address user_, uint64 baseWithdrawalFee_, bool toOverride_) internal virtual {
        FeeStorage storage fees = _getFeeStorage();
        fees.overriddenBaseWithdrawalFee[user_] =
            OverriddenBaseWithdrawalFeeFields({baseWithdrawalFee: baseWithdrawalFee_, isOverridden: toOverride_});
        emit WithdrawalFeeOverridden(user_, baseWithdrawalFee_, toOverride_);
    }

    /**
     * @dev Internal implementation of setBaseWithdrawalFee
     * @param baseWithdrawalFee_ The new base withdrawal fee in basis points (1/10000)
     */
    function _setBaseWithdrawalFee(uint64 baseWithdrawalFee_) internal virtual {
        if (baseWithdrawalFee_ > FeeMath.BASIS_POINT_SCALE) revert ExceedsMaxBasisPoints(baseWithdrawalFee_);
        FeeStorage storage fees = _getFeeStorage();
        uint64 oldFee = fees.baseWithdrawalFee;
        fees.baseWithdrawalFee = baseWithdrawalFee_;
        emit SetBaseWithdrawalFee(oldFee, baseWithdrawalFee_);
    }

    /**
     * @notice Returns the base withdrawal fee
     * @return uint64 The base withdrawal fee in basis points (1/10000)
     */
    function baseWithdrawalFee() external view returns (uint64) {
        return _getFeeStorage().baseWithdrawalFee;
    }

    /**
     * @notice Returns whether the withdrawal fee is exempted for a user
     * @param user_ The address of the user
     * @return bool Whether the withdrawal fee is exempted for the user
     */
    function overriddenBaseWithdrawalFee(address user_)
        external
        view
        returns (OverriddenBaseWithdrawalFeeFields memory)
    {
        return _getFeeStorage().overriddenBaseWithdrawalFee[user_];
    }

    //// ASSETS ////

    /**
     * @notice Returns the available assets for the strategy. for the base asset (curve LP token)
     * it includes the balance of the curve LP token and the balance of the StakeDAO LP token.
     * @param asset_ The asset to check.
     * @return availableAssets The available assets.
     */
    function _availableAssets(address asset_) internal view virtual override returns (uint256 availableAssets) {
        address[] memory assets = getAssets();
        if (asset_ == assets[0]) {
            availableAssets =
                IERC20(asset_).balanceOf(address(this)) + IStakeDaoLiquidityGauge(assets[1]).balanceOf(address(this));
        } else {
            availableAssets = super._availableAssets(asset_);
        }
    }
}
