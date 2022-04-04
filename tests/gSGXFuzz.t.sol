// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../contracts/Subgenix.sol";
import {VaultFactory} from "../contracts/VaultFactory.sol";
import {GovernanceSGX} from "../contracts/Governancesgx.sol";


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
        uint256 mintAmount, 
        uint256 deposit
    ) public {
        
        hevm.assume(deposit < mintAmount);
        sgx.mint(user, mintAmount);

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
        sgx.mint(user, deposit);

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
        sgx.mint(user, amount);
        gsgx.deposit(user, amount);
    }

    function testFailDepositNotEnoughFunds(address user, uint256 amount) public {
        hevm.assume(amount > 0);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), amount);
        gsgx.deposit(msg.sender, amount);
        hevm.stopPrank();

    }

    function testFailWithdrawAmountTooBig(
        address user,
        uint256 mintAmount,
        uint256 withdrawAmount 
    ) public {
        hevm.assume(mintAmount < withdrawAmount);
        sgx.mint(user, mintAmount);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), mintAmount);
        gsgx.deposit(user, mintAmount);

        gsgx.withdraw(withdrawAmount);
        
        hevm.stopPrank();
    }
    
    function testFailWithdrawHittingWithdrawCeiling(
        address user,
        uint256 withdrawCeiling,
        uint256 mintAmount,
        uint256 deposit

    ) public {
        hevm.assume(withdrawCeiling < deposit);
        gsgx.setWithdrawCeil(withdrawCeiling);

        sgx.mint(user, mintAmount);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(user, deposit);

        gsgx.withdraw(deposit);
        hevm.stopPrank();
    }
}