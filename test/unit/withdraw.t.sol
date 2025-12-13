// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {BaseUnitTest} from "test/unit/BaseUnitTest.sol";
import "forge-std/console.sol";

contract WithdrawUnitTest is BaseUnitTest {
    address internal alice = address(0xA11CE);

    function setUp() public virtual override {
        super.setUp();
    }

    function test_withdraw_basic() public {
        // Arrange: give alice some tokens and deposit to the vault
        uint256 depositAmount = 1000e18;
        deal(address(mockERC20), alice, depositAmount);

        vm.startPrank(alice);
        mockERC20.approve(address(stakedLPStrategy), depositAmount);
        stakedLPStrategy.deposit(depositAmount, alice);
        vm.stopPrank();

        // Act: withdraw half of the assets
        uint256 withdrawAmount = 500e18;
        uint256 aliceSharesBefore = stakedLPStrategy.balanceOf(alice);
        uint256 aliceTokenBalanceBefore = mockERC20.balanceOf(alice);

        vm.startPrank(alice);
        stakedLPStrategy.withdraw(withdrawAmount, alice, alice);
        vm.stopPrank();

        // Assert: assets received
        uint256 aliceTokenBalanceAfter = mockERC20.balanceOf(alice);
        uint256 aliceSharesAfter = stakedLPStrategy.balanceOf(alice);

        assertEq(
            aliceTokenBalanceAfter - aliceTokenBalanceBefore, withdrawAmount, "Alice should receive withdrawn assets"
        );
        assertEq(aliceSharesBefore - aliceSharesAfter, withdrawAmount, "Shares burned should equal assets withdrawn");
    }

    function test_redeem_basic() public {
        // Arrange: give alice some tokens and deposit to the vault
        uint256 depositAmount = 1200e18;
        deal(address(mockERC20), alice, depositAmount);

        vm.startPrank(alice);
        mockERC20.approve(address(stakedLPStrategy), depositAmount);
        stakedLPStrategy.deposit(depositAmount, alice);
        vm.stopPrank();

        // Act: redeem some shares
        uint256 sharesToRedeem = 600e18;
        uint256 aliceTokenBalanceBefore = mockERC20.balanceOf(alice);

        vm.startPrank(alice);
        stakedLPStrategy.redeem(sharesToRedeem, alice, alice);
        vm.stopPrank();

        // Assert: Alice should receive assets equal to shares redeemed (1:1 for default mock)
        uint256 aliceTokenBalanceAfter = mockERC20.balanceOf(alice);
        uint256 aliceSharesAfter = stakedLPStrategy.balanceOf(alice);

        assertEq(
            aliceTokenBalanceAfter - aliceTokenBalanceBefore, sharesToRedeem, "Alice should receive correct assets"
        );
        assertEq(aliceSharesAfter, depositAmount - sharesToRedeem, "Alice's shares decrease by redeemed amount");
    }

    function test_withdraw_after_donation_to_vault() public {
        // Arrange: Alice deposits tokens
        uint256 depositAmount = 1000e18;
        deal(address(mockERC20), alice, depositAmount);

        vm.startPrank(alice);
        mockERC20.approve(address(stakedLPStrategy), depositAmount);
        stakedLPStrategy.deposit(depositAmount, alice);
        vm.stopPrank();

        // Someone else donates tokens directly to the underlying ERC4626 vault
        address donor = address(0xBEEF);
        uint256 donationAmount = 500e18;
        deal(address(mockERC20), donor, donationAmount);
        vm.startPrank(donor);
        mockERC20.transfer(address(mockERC4626), donationAmount);
        vm.stopPrank();

        // Alice tries to withdraw half her assets
        uint256 withdrawAmount = 500e18;
        uint256 aliceSharesBefore = stakedLPStrategy.balanceOf(alice);
        uint256 aliceTokenBalanceBefore = mockERC20.balanceOf(alice);

        uint256 strategyRateBefore = stakedLPStrategy.convertToAssets(1e18);

        vm.startPrank(alice);
        stakedLPStrategy.withdraw(withdrawAmount, alice, alice);
        vm.stopPrank();

        // After donation, shares are worth more assets per share, so Alice should burn less shares than assets withdrawn
        uint256 aliceTokenBalanceAfter = mockERC20.balanceOf(alice);
        uint256 aliceSharesAfter = stakedLPStrategy.balanceOf(alice);

        assertEq(aliceTokenBalanceAfter - aliceTokenBalanceBefore, withdrawAmount, "Alice receives assets requested");

        // Each share is worth 1.5 assets now, so withdrawing 500 assets should require burning only ~333.333... shares
        uint256 expectedSharesBurned = (withdrawAmount * 1e18) / strategyRateBefore;
        // Integer math: expect approximation
        assertApproxEqAbs(
            aliceSharesBefore - aliceSharesAfter,
            expectedSharesBurned,
            1e3, // 1e3 wei precision since deposit amountis 1000e18
            "Shares burned should equal assets/pricePerShare after donation"
        );
    }

    function test_redeem_after_donation_to_vault() public {
        // Arrange: Alice deposits tokens
        uint256 depositAmount = 900e18;
        deal(address(mockERC20), alice, depositAmount);

        vm.startPrank(alice);
        mockERC20.approve(address(stakedLPStrategy), depositAmount);
        stakedLPStrategy.deposit(depositAmount, alice);
        vm.stopPrank();

        // Someone donates tokens directly to the ERC4626 vault
        address donor = address(0xCAFE);
        uint256 donationAmount = 900e18;
        deal(address(mockERC20), donor, donationAmount);
        vm.startPrank(donor);
        mockERC20.transfer(address(mockERC4626), donationAmount);
        vm.stopPrank();

        assertApproxEqAbs(
            mockERC4626.convertToAssets(1e18),
            (depositAmount + donationAmount) * 1e18 / depositAmount,
            1,
            "Assets per share should be 1"
        );

        // Alice redeems half her shares
        uint256 sharesToRedeem = 450e18; // half of her shares
        uint256 assetsPerShare = mockERC4626.convertToAssets(1e18);
        uint256 expectedAssetsReceived = (sharesToRedeem * assetsPerShare) / 1e18;

        uint256 aliceTokenBalanceBefore = mockERC20.balanceOf(alice);

        vm.startPrank(alice);
        stakedLPStrategy.redeem(sharesToRedeem, alice, alice);
        vm.stopPrank();

        uint256 aliceTokenBalanceAfter = mockERC20.balanceOf(alice);
        uint256 aliceSharesAfter = stakedLPStrategy.balanceOf(alice);

        // Should receive the product of shares * asset/share at time of redemption
        assertApproxEqAbs(
            aliceTokenBalanceAfter - aliceTokenBalanceBefore,
            expectedAssetsReceived,
            1, // 1 wei accuracy
            "Alice should receive all assets per redeemed shares, including donation gain"
        );
        assertEq(aliceSharesAfter, depositAmount - sharesToRedeem, "Her shares reduce by redeemed amount");
    }

    function testFuzz_withdraw_basic(uint256 depositAmount, uint256 withdrawAmount) public {
        // Bound inputs to reasonable ranges
        depositAmount = bound(depositAmount, 1e18, 1e30);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        // Arrange: give alice some tokens and deposit to the vault
        deal(address(mockERC20), alice, depositAmount);

        vm.startPrank(alice);
        mockERC20.approve(address(stakedLPStrategy), depositAmount);
        stakedLPStrategy.deposit(depositAmount, alice);
        vm.stopPrank();

        // Act: withdraw assets
        uint256 aliceSharesBefore = stakedLPStrategy.balanceOf(alice);
        uint256 aliceTokenBalanceBefore = mockERC20.balanceOf(alice);

        vm.startPrank(alice);
        stakedLPStrategy.withdraw(withdrawAmount, alice, alice);
        vm.stopPrank();

        // Assert: assets received
        uint256 aliceTokenBalanceAfter = mockERC20.balanceOf(alice);
        uint256 aliceSharesAfter = stakedLPStrategy.balanceOf(alice);

        assertEq(
            aliceTokenBalanceAfter - aliceTokenBalanceBefore, withdrawAmount, "Alice should receive withdrawn assets"
        );
        assertEq(aliceSharesBefore - aliceSharesAfter, withdrawAmount, "Shares burned should equal assets withdrawn");
    }

    function testFuzz_redeem_basic(uint256 depositAmount, uint256 sharesToRedeem) public {
        // Bound inputs to reasonable ranges
        depositAmount = bound(depositAmount, 1e18, 1e30);
        sharesToRedeem = bound(sharesToRedeem, 1, depositAmount);

        // Arrange: give alice some tokens and deposit to the vault
        deal(address(mockERC20), alice, depositAmount);

        vm.startPrank(alice);
        mockERC20.approve(address(stakedLPStrategy), depositAmount);
        stakedLPStrategy.deposit(depositAmount, alice);
        vm.stopPrank();

        // Act: redeem some shares
        uint256 aliceTokenBalanceBefore = mockERC20.balanceOf(alice);

        vm.startPrank(alice);
        stakedLPStrategy.redeem(sharesToRedeem, alice, alice);
        vm.stopPrank();

        // Assert: Alice should receive assets equal to shares redeemed (1:1 for default mock)
        uint256 aliceTokenBalanceAfter = mockERC20.balanceOf(alice);
        uint256 aliceSharesAfter = stakedLPStrategy.balanceOf(alice);

        assertEq(
            aliceTokenBalanceAfter - aliceTokenBalanceBefore, sharesToRedeem, "Alice should receive correct assets"
        );
        assertEq(aliceSharesAfter, depositAmount - sharesToRedeem, "Alice's shares decrease by redeemed amount");
    }

    function testFuzz_withdraw_after_donation_to_vault(
        uint256 depositAmount,
        uint256 donationAmount,
        uint256 withdrawAmount
    ) public {
        // Bound inputs to reasonable ranges
        depositAmount = bound(depositAmount, 1e18, 1e30);
        donationAmount = bound(donationAmount, 1e18, 1e30);
        uint256 totalAssets = depositAmount + donationAmount;
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        // Arrange: Alice deposits tokens
        deal(address(mockERC20), alice, depositAmount);

        vm.startPrank(alice);
        mockERC20.approve(address(stakedLPStrategy), depositAmount);
        stakedLPStrategy.deposit(depositAmount, alice);
        vm.stopPrank();

        // Someone else donates tokens directly to the underlying ERC4626 vault
        address donor = address(0xBEEF);
        deal(address(mockERC20), donor, donationAmount);
        vm.startPrank(donor);
        mockERC20.transfer(address(mockERC4626), donationAmount);
        vm.stopPrank();

        // Alice tries to withdraw assets
        uint256 aliceSharesBefore = stakedLPStrategy.balanceOf(alice);
        uint256 aliceTokenBalanceBefore = mockERC20.balanceOf(alice);

        uint256 strategyRateBefore = stakedLPStrategy.convertToAssets(1e18);

        vm.startPrank(alice);
        stakedLPStrategy.withdraw(withdrawAmount, alice, alice);
        vm.stopPrank();

        // After donation, shares are worth more assets per share, so Alice should burn less shares than assets withdrawn
        uint256 aliceTokenBalanceAfter = mockERC20.balanceOf(alice);
        uint256 aliceSharesAfter = stakedLPStrategy.balanceOf(alice);

        assertEq(aliceTokenBalanceAfter - aliceTokenBalanceBefore, withdrawAmount, "Alice receives assets requested");

        // Calculate expected shares burned based on the rate before withdrawal
        uint256 expectedSharesBurned = (withdrawAmount * 1e18) / strategyRateBefore;
        // Integer math: expect approximation
        assertApproxEqAbs(
            aliceSharesBefore - aliceSharesAfter,
            expectedSharesBurned,
            1e3, // 1e3 wei precision
            "Shares burned should equal assets/pricePerShare after donation"
        );
    }

    function testFuzz_redeem_after_donation_to_vault(
        uint256 depositAmount,
        uint256 donationAmount,
        uint256 sharesToRedeem
    ) public {
        // Bound inputs to reasonable ranges
        depositAmount = bound(depositAmount, 1e18, 1e30);
        donationAmount = bound(donationAmount, 1e18, 1e30);
        sharesToRedeem = bound(sharesToRedeem, 1, depositAmount);

        // Arrange: Alice deposits tokens
        deal(address(mockERC20), alice, depositAmount);

        vm.startPrank(alice);
        mockERC20.approve(address(stakedLPStrategy), depositAmount);
        stakedLPStrategy.deposit(depositAmount, alice);
        vm.stopPrank();

        // Someone donates tokens directly to the ERC4626 vault
        address donor = address(0xCAFE);
        deal(address(mockERC20), donor, donationAmount);
        vm.startPrank(donor);
        mockERC20.transfer(address(mockERC4626), donationAmount);
        vm.stopPrank();

        // Alice redeems shares
        uint256 assetsPerShare = mockERC4626.convertToAssets(1e18);
        uint256 expectedAssetsReceived = (sharesToRedeem * assetsPerShare) / 1e18;

        uint256 aliceTokenBalanceBefore = mockERC20.balanceOf(alice);

        vm.startPrank(alice);
        stakedLPStrategy.redeem(sharesToRedeem, alice, alice);
        vm.stopPrank();

        uint256 aliceTokenBalanceAfter = mockERC20.balanceOf(alice);
        uint256 aliceSharesAfter = stakedLPStrategy.balanceOf(alice);

        // Should receive the product of shares * asset/share at time of redemption
        assertApproxEqAbs(
            aliceTokenBalanceAfter - aliceTokenBalanceBefore,
            expectedAssetsReceived,
            1, // 1 wei accuracy
            "Alice should receive all assets per redeemed shares, including donation gain"
        );
        assertEq(aliceSharesAfter, depositAmount - sharesToRedeem, "Her shares reduce by redeemed amount");
    }
}
