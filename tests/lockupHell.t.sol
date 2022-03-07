// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Subgenix} from "../contracts/Subgenix.sol";
import {VaultFactory} from "../contracts/VaultFactory.sol";
import {LockUpHell} from "../contracts/lockupHell.sol";
import {Hevm} from "./utils/Hevm.sol";
import {gSGX} from "../contracts/gSGX.sol";

contract LockUpHellTest is DSTest {
    Hevm hevm = Hevm(HEVM_ADDRESS);
    VaultFactory vault;
    LockUpHell lockup;
    Subgenix SGX;
    gSGX gsgx;
    address Treasury = address(0xBEEF);

    uint256 shortRewards = 1e18;
    uint256 longRewards = 5e18;

    struct LockupType {
        bool longRewardsColected;  // True if user colected long rewards, false otherwise.
        bool shortRewardsColected; // True if user colected short rewards, false otherwise.
        uint32 longLockupPeriod;   // Time (in Unit time stamp) in the future when long lockup rewards will be unlocked.
        uint32 shortLockupPeriod;  // Time (in Unit time stamp) in the future when short lockup rewards will be unlocked.
        uint256 longRewards;       // The amount of rewards available to the user after longLockupPeriod.
        uint256 shortRewards;      // The amount of rewards available to the user after shortLockupPeriod.
    }
    
    function setUp() public {
        SGX = new Subgenix("Subgenix Currency", "SGX", 18);
        gsgx = new gSGX(address(SGX));
        lockup = new LockUpHell(address(SGX));
        
        vault = new VaultFactory(
            address(SGX),      // Underlying token.
            address(gsgx),     // Governance token.
            Treasury,          // Treasury address.
            address(lockup)    // Lockup contract.
        );

        lockup.setLongPercentage(1800);    // Percentage to be locked up for 18 days, 1800 = 18%
        lockup.setShortPercentage(1200);   // Percentage to be locked up for 07 days, 1200 = 12%
        lockup.setLongLockupTime(18 days); // 18 days in seconds
        lockup.setShortLockupTime(7 days); // 07 days in seconds

        vault.setInterestRate(1e16);      // Daily rewards, 1e16 = 1%
        vault.setBurnPercent(200);         // Percentage burned when claiming rewards, 200 = 2%.
        vault.setgSGXPercent(1300);        // Percentage of rewards converted to gSGX
        vault.setgSGXDistributed(500);     // Percentage of rewards sent to the gSGX contract.
        vault.setMinVaultDeposit(1e18);    // Minimum amount required to deposite in Vault.

        SGX.setManager(address(vault), true);
        SGX.setManager(msg.sender, true);

        gsgx.setWithdrawCeil(100000e18);
    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/

    function testMetaData() public {
        assertEq(lockup.SGX(), address(SGX));
    }

    function testLockupRewards() public {
        uint256 depositAmount = 10e18;
        SGX.mint(msg.sender, depositAmount);
        
        hevm.prank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), depositAmount);

        // Assert User has 0 lockups before doing anything.
        assertEq(lockup.UsersLockupLength(msg.sender), 0);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Assert User has 1 lockup.
        uint32 index = lockup.UsersLockupLength(msg.sender);
        assertEq(index, 1);

        // Assert current balance of SGX == pastAmount - (shortRewards + longRewards)
        uint256 currentAmount = depositAmount - (shortRewards + longRewards);
        assertEq(SGX.balanceOf(msg.sender), currentAmount);
        
        LockupType memory userLockup;
        
        // Get lockup Info
        (userLockup.longRewardsColected, 
         userLockup.shortRewardsColected, 
         userLockup.longLockupPeriod,
         userLockup.shortLockupPeriod,
         userLockup.longRewards,
         userLockup.shortRewards) = lockup.UsersLockup(msg.sender, index);

        // Assert User has not colected longRewards yet.
        assertTrue(!userLockup.longRewardsColected);
        // Assert User has not colected shortRewards yet.
        assertTrue(!userLockup.shortRewardsColected);
        // Assert longLockupPeriod is equal to what we set it to be.
        assertEq(userLockup.longLockupPeriod, lockup.getLongLockupTime());
        // Assert shortLockupPeriod is equal to what we set it to be.
        assertEq(userLockup.shortLockupPeriod, lockup.getShortLockupTime());
        // Assert shortRewards are equal to what we set it to be.
        assertEq(userLockup.shortRewards, shortRewards);
        // Assert longtRewards are equal to what we set it to be.
        assertEq(userLockup.longRewards, longRewards);
    }

    function testClaimShortLockup() public {
        uint256 depositAmount = 10e18;
        SGX.mint(msg.sender, depositAmount);
        
        hevm.startPrank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), depositAmount);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.UsersLockupLength(msg.sender);
        
        uint256 balanceBefore = SGX.balanceOf(msg.sender);

        LockupType memory userLockup;
        
        lockup.claimShortLockup(index);

        // Get lockup Info
        ( , 
         userLockup.shortRewardsColected, 
          ,
          ,
          ,
         userLockup.shortRewards) = lockup.UsersLockup(msg.sender, index);

        assertTrue(userLockup.shortRewardsColected);
        assertEq(userLockup.shortRewards, 0);
        assertEq(SGX.balanceOf(msg.sender), (balanceBefore+shortRewards));
        balanceBefore = SGX.balanceOf(msg.sender);
    }

    function testClaimLongLockup() public {
        uint256 depositAmount = 10e18;
        SGX.mint(msg.sender, depositAmount);
        
        hevm.startPrank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), depositAmount);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.UsersLockupLength(msg.sender);
        
        uint256 balanceBefore = SGX.balanceOf(msg.sender);

        LockupType memory userLockup;
        
        lockup.claimLongLockup(index);

        // Get lockup Info
        (userLockup.longRewardsColected, 
          , 
          ,
          ,
         userLockup.longRewards,
          ) = lockup.UsersLockup(msg.sender, index);

        assertTrue(userLockup.longRewardsColected);
        assertEq(userLockup.longRewards, 0);
        assertEq(SGX.balanceOf(msg.sender), (balanceBefore+longRewards));
    }

    // <----------------------------------------------------> //
    // <---------------- TEST VEW FUNCTIONS ----------------> //
    // <----------------------------------------------------> //
    function testGetLongLockupTime() public {
        assertEq(lockup.getLongLockupTime(), 18 days);
    }

    function testGetShortLockupTime() public {
        assertEq(lockup.getShortLockupTime(), 7 days);
    }

    function testGetLongPercentage() public {
        assertEq(lockup.getLongPercentage(), 1800);
    }

    function testGetShortPercentage() public {
        assertEq(lockup.getShortPercentage(), 1200);
    }

    // <----------------------------------------------------> //
    // <---------------- TEST SET FUNCTIONS ----------------> //
    // <----------------------------------------------------> //

    function testSetLongLockupTime() public {
        lockup.setLongLockupTime(12 days);
        assertEq(lockup.getLongLockupTime(), 12 days);
    }

    function testSetShortLockupTime() public {
        uint32 value = 10 days;
        lockup.setShortLockupTime(10 days);
        assertEq(lockup.getShortLockupTime(), 10 days);
    }

    function testSetLongPercentage() public {
        lockup.setLongPercentage(1200);
        assertEq(lockup.getLongPercentage(), 1200);
    }

    function testSetShortPercentage() public {
        lockup.setShortPercentage(1000);
        assertEq(lockup.getShortPercentage(), 1000);
    }

    // <----------------------------------------------------> //
    // <-------------------- TEST  FAIL --------------------> //
    // <----------------------------------------------------> //

    function testFailLockupRewardsNotUser() public {
        
        SGX.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);

        lockup.lockupRewards(address(0xbeef), shortRewards, longRewards);
    }

    function testFailLockupRewardsInsufficientFunds() public {
        
        SGX.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, 15e18);
    }

    function testFailclaimShortLockupIndexInvalid() public {
        SGX.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);
        
        lockup.claimShortLockup(2);
    }

    function testFailclaimShortLockupAlreadyClaimed() public {
        SGX.mint(msg.sender, 10e18);
        
        hevm.startPrank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.UsersLockupLength(msg.sender);

        LockupType memory userLockup;
        
        // Claim once.
        lockup.claimShortLockup(index);

        // Try to claim again.
        lockup.claimShortLockup(index);
    }

    function testFailclaimShortLockupTooEarly() public {
        SGX.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 1 day in the future.
        hevm.warp(block.timestamp + 24 hours);

        uint32 index = lockup.UsersLockupLength(msg.sender);
        
        lockup.claimShortLockup(index);
    }

    function testFailclaimLongLockupIndexInvalid() public {
        SGX.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);
        
        lockup.claimLongLockup(2);
    }

    function testFailclaimLongLockupAlreadyClaimed() public {
        SGX.mint(msg.sender, 10e18);
        
        hevm.startPrank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.UsersLockupLength(msg.sender);

        LockupType memory userLockup;
        
        // Claim once.
        lockup.claimLongLockup(index);

        // Try to claim again.
        lockup.claimLongLockup(index);
    }

    function testFailclaimLongLockupTooEarly() public {
        SGX.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 1 day in the future.
        hevm.warp(block.timestamp + 24 hours);

        uint32 index = lockup.UsersLockupLength(msg.sender);
        
        lockup.claimLongLockup(index);
    }
}
