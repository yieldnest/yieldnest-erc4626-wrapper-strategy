// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {AssertUtils} from "lib/yieldnest-vault/test/utils/AssertUtils.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {ERC4626WrapperStrategy} from "src/ERC4626WrapperStrategy.sol";
import {TransparentUpgradeableProxy} from "lib/yieldnest-vault/src/Common.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {Provider} from "src/module/Provider.sol";
import {DeployStrategy} from "script/DeployStrategy.sol";
import {BaseScript} from "script/BaseScript.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";
import {StrategyAdapter} from "test/helpers/StrategyAdapter.sol";

contract BaseIntegrationTest is Test, AssertUtils {
    ERC4626WrapperStrategy public stakedLPStrategy;
    DeployStrategy public deployment;
    StrategyAdapter public strategyAdapter;

    address underlyingAsset;
    address targetVault;

    address public ADMIN = makeAddr("admin");

    function setUp() public virtual {
        deployment = new DeployStrategy();

        underlyingAsset = MC.CURVE_ynRWAx_USDC_LP;
        targetVault = MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT;

        deployment.setDeploymentParameters(
            BaseScript.DeploymentParameters({
                name: "Staked LP Strategy ynRWAx-USDC",
                symbol_: "sLP-ynRWAx-USDC",
                decimals: 18,
                targetVault: targetVault,
                countNativeAsset: false
            })
        );
        deployment.setEnv(BaseScript.Env.TEST);
        deployment.run();

        stakedLPStrategy = ERC4626WrapperStrategy(deployment.strategy());

        // Deploy the StrategyAdapter as a proxy, then call initialize after
        strategyAdapter =
            StrategyAdapter(address(new TransparentUpgradeableProxy(address(new StrategyAdapter()), ADMIN, "")));
        strategyAdapter.initialize(address(stakedLPStrategy), 1); // Use the correct index if needed
    }

    function deposit_lp(address alice, uint256 depositAmount) public returns (uint256) {
        // Deal USDC to alice
        uint256 aliceAmount = depositAmount;
        deal(MC.USDC, alice, aliceAmount);

        // Half of alice's USDC to deposit into YNRWAX
        uint256 halfAmount = aliceAmount / 2;

        // Addresses required
        address usdc = MC.USDC;
        address curveLp = underlyingAsset;

        // Use YNRWAX constant directly
        address ynrwax = MC.YNRWAX;

        // Prank as alice for interacting from her address
        vm.startPrank(alice);

        // Approve YNRWAX contract to spend USDC, then deposit half to YNRWAX
        IERC20(usdc).approve(ynrwax, halfAmount);

        IERC4626(ynrwax).deposit(halfAmount, alice);

        // Interface for YNRWAX should have a deposit or mint method
        // For the purpose of modelling, let's assume it's: function deposit(uint256 amount) public returns (uint256);
        // (You may need to adapt this call based on actual YNR

        // Approve LP pool to spend USDC and YNRWAX for adding liquidity
        IERC20(usdc).approve(curveLp, halfAmount);
        IERC20(ynrwax).approve(curveLp, halfAmount); // or actual balance of YNRWAX minted

        // Add both tokens as liquidity to the LP (assuming it's a 2-coin pool [YNRWAX, USDC] and add_liquidity signature)
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = halfAmount;
        amounts[1] = halfAmount;
        return ICurvePool(curveLp).add_liquidity(amounts, 0);

        vm.stopPrank();
    }
}
