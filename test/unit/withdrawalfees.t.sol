pragma solidity ^0.8.24;

import {BaseUnitTest} from "test/unit/BaseUnitTest.sol";

contract WithdrawalFeesUnitTest is BaseUnitTest {
    address internal alice = address(0xA11CE);

    function setUp() public virtual override {
        super.setUp();
    }

    function test_set_withdrawal_fee_and_withdraw() public {
        // Setup: set withdrawal fee to 1% (100 basis points)
        vm.startPrank(ADMIN);
        uint64 withdrawalFee = 0.01e8;
        stakedLPStrategy.setBaseWithdrawalFee(withdrawalFee); // 1% fee
        vm.stopPrank();

        // Ensure the getter returns correct value
        assertEq(stakedLPStrategy.baseWithdrawalFee(), withdrawalFee, "Withdraw fee should be 1% (100 bps)");

        // Give 'alice' some tokens and deposit
        uint256 depositAmount = 1000e18;
        deal(address(mockERC20), alice, depositAmount);
        vm.startPrank(alice);
        mockERC20.approve(address(stakedLPStrategy), depositAmount);
        stakedLPStrategy.deposit(depositAmount, alice);

        uint256 sharesToWithdraw = stakedLPStrategy.balanceOf(alice);
        // Withdraw to Alice - she should receive (99%) of the assets
        uint256 assetsPreview = stakedLPStrategy.previewRedeem(sharesToWithdraw);
        uint256 expectedAssets = (mockERC4626.convertToAssets(sharesToWithdraw) * (1e8 - withdrawalFee)) / 1e8;

        // previewRedeem should match expected

        // 990099009900990099009 !~= 990000000000000000000
        assertApproxEqRel(assetsPreview, expectedAssets, 1e15, "previewRedeem should consider withdrawal fee");

        uint256 aliceBalanceBefore = mockERC20.balanceOf(alice);
        // Actually redeem
        stakedLPStrategy.redeem(sharesToWithdraw, alice, alice);

        // Alice should receive 99% of assets (1% fee taken)
        uint256 aliceBalanceAfter = mockERC20.balanceOf(alice);
        uint256 receivedAssets = aliceBalanceAfter - aliceBalanceBefore;
        assertApproxEqRel(receivedAssets, expectedAssets, 1e15, "Alice should receive assets minus withdraw fee");

        vm.stopPrank();
    }
}
