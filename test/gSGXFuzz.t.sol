// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../src/Subgenix.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {GovernanceSGX} from "../src/Governancesgx.sol";


contract GSGXTest is DSTestPlus {
    Subgenix internal sgx;
    GovernanceSGX internal gsgx;
    address internal treasury = address(0xBEEF);

    function setUp() public {
        sgx = new Subgenix("Subgenix Currency", "SGX", 18);
        gsgx = new GovernanceSGX(address(sgx));

        gsgx.setWithdrawCeil(100000e18);
    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/

    function testDeposit(
        address user,
        uint256 deposit
    ) public {

        uint256 transferAmount = 6_000_000e18;
        
        hevm.assume(deposit < transferAmount);
        
        sgx.transfer(user, transferAmount);

        uint256 balanceBefore = sgx.balanceOf(user);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(user, deposit);
        hevm.stopPrank();

        assertEq(gsgx.balanceOf(user), deposit);
        assertEq(sgx.balanceOf(user), balanceBefore - deposit);
    }

    function testWithdraw(address user, uint256 deposit) public {

        hevm.assume(deposit > 0 && deposit < gsgx.withdrawCeil());
        
        sgx.transfer(user, deposit);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(user, deposit);

        gsgx.withdraw(deposit);
        hevm.stopPrank();

        assertEq(sgx.balanceOf(user), deposit);
        assertEq(gsgx.balanceOf(user), 0);
    }

    function testSetWithdrawCeil(uint256 amount) public {

        gsgx.setWithdrawCeil(amount);

        assertEq(gsgx.withdrawCeil(), amount);
    }

    // <----------------------------------------------------> //
    // <-------------------- TEST  FAIL --------------------> //
    // <----------------------------------------------------> //

    function testFailDepositNotApproved(address user, uint256 amount) public {
        hevm.assume(amount > 0);
        gsgx.deposit(user, amount);
    }

    function testFailDepositNotEnoughFunds(address user, uint256 amount) public {
        hevm.assume(amount > 0 && user != msg.sender);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), amount);
        gsgx.deposit(msg.sender, amount);
        hevm.stopPrank();

    }

    function testFailWithdrawAmountTooBig(address user, uint256 withdrawAmount) public {
        uint256 transferAmount = 6_000_000e18;
        hevm.assume(withdrawAmount > transferAmount);
        sgx.transfer(user, transferAmount);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), transferAmount);
        gsgx.deposit(user, transferAmount);

        gsgx.withdraw(withdrawAmount);
        
        hevm.stopPrank();
    }
    
    function testFailWithdrawHittingWithdrawCeiling(
        address user,
        uint256 withdrawCeiling,
        uint256 deposit
    ) public {
        uint256 transferAmount = 6_000_000e18;
        hevm.assume(deposit > withdrawCeiling && transferAmount > deposit);
        gsgx.setWithdrawCeil(withdrawCeiling);

        sgx.transfer(user, deposit);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(user, deposit);

        gsgx.withdraw(deposit);
        hevm.stopPrank();
    }
}