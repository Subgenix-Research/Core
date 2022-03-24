// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../contracts/Subgenix.sol";
import {VaultFactory} from "../contracts/VaultFactory.sol";
import {Hevm} from "./utils/Hevm.sol";
import {GovernanceSGX} from "../contracts/Governancesgx.sol";


contract GSGXTest is DSTestPlus {
    Subgenix internal sgx;
    GovernanceSGX internal gsgx;
    address internal treasury = address(0xBEEF);

    function setUp() public {
        sgx = new Subgenix("Subgenix Currency", "SGX", 18);
        gsgx = new GovernanceSGX(address(sgx));

        sgx.setManager(msg.sender, true);

        gsgx.setWithdrawCeil(100000e18);

    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/

    function testDeposit() public {
        uint256 deposit = 2e18;
        sgx.mint(msg.sender, 10e18);
        uint256 balanceBefore = sgx.balanceOf(msg.sender);

        hevm.startPrank(msg.sender);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(msg.sender, deposit);

        uint256 balanceAfter = sgx.balanceOf(msg.sender);

        hevm.stopPrank();

        assertEq(gsgx.balanceOf(msg.sender), deposit);
        assertEq(balanceAfter, balanceBefore - deposit);
    }

    function testWithdraw() public {
        uint256 deposit = 2e18;
        sgx.mint(msg.sender, 10e18);
        uint256 balanceBefore = sgx.balanceOf(msg.sender);

        hevm.startPrank(msg.sender);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(msg.sender, deposit);

        uint256 balanceAfter = sgx.balanceOf(msg.sender);

        uint256 gSGXBalance = gsgx.balanceOf(msg.sender);

        assertEq(gSGXBalance, deposit);
        assertEq(balanceAfter, balanceBefore - deposit);

        gsgx.withdraw(gSGXBalance);

        gSGXBalance = gsgx.balanceOf(msg.sender);

        assertEq(sgx.balanceOf(msg.sender), balanceAfter + deposit);
        assertEq(gSGXBalance, 0);

        hevm.stopPrank();
    }

    function testSetWithdrawCeil() public {
        
        gsgx.setWithdrawCeil(100e18);

        assertEq(gsgx.withdrawCeil(), 100e18);
    }

    // <----------------------------------------------------> //
    // <-------------------- TEST  FAIL --------------------> //
    // <----------------------------------------------------> //

    function testFailDepositNotApproved() public {
        sgx.mint(msg.sender, 10e18);

        hevm.prank(msg.sender);
        gsgx.deposit(msg.sender, 2e18);
    }

    function testFailDepositNotEnoughFunds() public {
        uint256 deposit = 20e18;
        sgx.mint(msg.sender, 10e18);

        hevm.startPrank(msg.sender);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(msg.sender, deposit);

        hevm.stopPrank();
    }

    function testFailWithdrawIncorrectWithdrawAmount() public {
        uint256 deposit = 2e18;
        sgx.mint(msg.sender, 10e18);

        hevm.startPrank(msg.sender);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(msg.sender, deposit);

        gsgx.withdraw(20e18);

        hevm.stopPrank();
    }
    
    function testFailWithdrawHittingWithdrawCeiling() public {
        gsgx.setWithdrawCeil(1e18);

        uint256 deposit = 2e18;
        sgx.mint(msg.sender, 10e18);

        hevm.startPrank(msg.sender);
        sgx.approve(address(gsgx), deposit);
        gsgx.deposit(msg.sender, deposit);

        gsgx.withdraw(deposit);

        hevm.stopPrank();
    }
}