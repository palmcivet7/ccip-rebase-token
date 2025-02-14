// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RebaseToken, IRebaseToken, Ownable, AccessControl} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    RebaseToken internal rebaseToken;
    Vault internal vault;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(address(rebaseToken));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(vault).call{value: 1e18}("");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/
    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2. check rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console2.log("startBalance", startBalance);
        assertEq(startBalance, amount);
        // 3. warp time and check balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);
        // 4. warp time again and check balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        // 2. redeem
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        // 2. warp time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        // 2. (b) add rewards to the vault
        vm.deal(owner, balanceAfterSomeTime - amount);
        vm.prank(owner);
        _addRewardsToVault(balanceAfterSomeTime - amount);

        // 3. redeem
        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, amount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // 1. deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        uint256 userBalance = rebaseToken.balanceOf(user);
        assertEq(user2Balance, 0);
        assertEq(userBalance, amount);

        // 2. owner reduces interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // 3. transfer
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, amount - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        // check user interest rate has been inherited
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn() public {
        bytes32 mintAndBurnRole = rebaseToken.getMintAndBurnRole();

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user, mintAndBurnRole)
        );
        rebaseToken.mint(user, 1e18);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user, mintAndBurnRole)
        );
        rebaseToken.burn(user, 1e18);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public {
        assertEq(vault.getRebaseToken(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint256).max);
        vm.prank(owner);
        vm.expectRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(initialInterestRate, rebaseToken.getInterestRate());
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function _addRewardsToVault(uint256 amount) internal {
        (bool success,) = payable(vault).call{value: amount}("");
        require(success, "Vault__AddRewardsFailed");
    }
}
