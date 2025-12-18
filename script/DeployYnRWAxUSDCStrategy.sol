import {DeployStrategy} from "script/DeployStrategy.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";

contract DeployYnRWAxUSDCStrategy is DeployStrategy {
    function run() public override {
        setDeploymentParameters(
            DeploymentParameters({
                name: "Staked LP Strategy ynRWAx-USDC",
                symbol_: "sLP-ynRWAx-USDC",
                decimals: 18,
                baseAsset: MC.CURVE_ynRWAx_USDC_LP,
                targetVault: MC.STAKEDAO_CURVE_ynRWAx_USDC_VAULT,
                skipTargetVault: false,
                countNativeAsset: false
            })
        );
        setEnv(Env.PROD);
        super.run();
    }
}
