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

    function testDeposit() public {
        address user = address(0xABCD);
        uint256 deposit = 2e18;
        
        sgx.transfer(user, 10e18);

        uint256 balanceBefore = sgx.balanceOf(user);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(user, deposit);
        hevm.stopPrank();

        assertEq(gsgx.balanceOf(user), deposit);
        assertEq(sgx.balanceOf(user), balanceBefore - deposit);
    }

    function testWithdraw() public {
        address user = address(0xABCD);
        uint256 deposit = 2e18;

        sgx.transfer(user, 10e18);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(user, deposit);

        uint256 balanceAfter = sgx.balanceOf(user);

        gsgx.withdraw(deposit);
        hevm.stopPrank();

        assertEq(sgx.balanceOf(user), balanceAfter + deposit);
        assertEq(gsgx.balanceOf(user), 0);

    }

    function testSetWithdrawCeil() public {
        
        gsgx.setWithdrawCeil(100e18);

        assertEq(gsgx.withdrawCeil(), 100e18);
    }

    // <----------------------------------------------------> //
    // <-------------------- TEST  FAIL --------------------> //
    // <----------------------------------------------------> //

    function testFailDepositNotApproved() public {
        gsgx.deposit(msg.sender, 2e18);
    }

    function testFailDepositNotEnoughFunds() public {
        address user = address(0xABCD);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), 10e18);
        gsgx.deposit(msg.sender, 10e18);
        hevm.stopPrank();
    }

    function testFailWithdrawAmountTooBig() public {
        address user = address(0xABCD);
        
        sgx.transfer(user, 10e18);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), 2e18);
        gsgx.deposit(user, 2e18);

        gsgx.withdraw(20e18);
        
        hevm.stopPrank();
    }
    
    function testFailWithdrawHittingWithdrawCeiling() public {
        address user = address(0xABCD);
        gsgx.setWithdrawCeil(1e18);

        uint256 deposit = 2e18;
        sgx.transfer(user, 10e18);

        hevm.startPrank(user);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(user, deposit);

        gsgx.withdraw(deposit);
        hevm.stopPrank();
    }
}