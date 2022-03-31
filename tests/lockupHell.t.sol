// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../contracts/Subgenix.sol";
import {VaultFactory} from "../contracts/VaultFactory.sol";
import {LockupHell} from "../contracts/lockupHell.sol";
import {GovernanceSGX} from "../contracts/Governancesgx.sol";
import {MockWAVAX} from "./utils/mocks/MockWAVAX.sol";

contract LockUpHellTest is DSTestPlus {
    VaultFactory internal vault;
    LockupHell internal lockup;
    Subgenix internal sgx;
    MockWAVAX internal wavax;
    GovernanceSGX internal gsgx;
    address internal treasury = address(0xBEEF);
    address internal research = address(0xABCD);

    uint256 internal shortRewards = 1e18;
    uint256 internal longRewards = 5e18;

    struct LockupType {
        bool longRewardsColected;  // True if user colected long rewards, false otherwise.
        bool shortRewardsColected; // True if user colected short rewards, false otherwise.
        uint32 longLockupPeriod;   // Time (in Unit time stamp) in the future when long lockup rewards will be unlocked.
        uint32 shortLockupPeriod;  // Time (in Unit time stamp) in the future when short lockup rewards will be unlocked.
        uint256 longRewards;       // The amount of rewards available to the user after longLockupPeriod.
        uint256 shortRewards;      // The amount of rewards available to the user after shortLockupPeriod.
    }
    
    function setUp() public {
        wavax = new MockWAVAX();
        sgx = new Subgenix("Subgenix Currency", "SGX", 18);
        gsgx = new GovernanceSGX(address(sgx));
        lockup = new LockupHell(address(sgx));
        
        vault = new VaultFactory(
            address(wavax),    // Wrapped avax.
            address(sgx),      // Underlying token.
            address(gsgx),     // Governance token.
            treasury,          // treasury address.
            research,          // research address.
            address(lockup)    // Lockup contract.
        );

        lockup.setLongPercentage(18e16);   // Percentage to be locked up for 18 days, 18e16 = 18%.
        lockup.setShortPercentage(12e16);  // Percentage to be locked up for 07 days, 12e16 = 12%.
        lockup.setLongLockupTime(18 days); // 18 days in seconds
        lockup.setShortLockupTime(7 days); // 07 days in seconds
        lockup.setVaultFactory(address(vault));

        vault.setInterestRate(1e16);        // Daily rewards, 1e16 = 1%
        vault.setBurnPercent(2e16);         // Percentage burned when claiming rewards, 2e16 = 2%.
        vault.setgSGXPercent(13e16);        // Percentage of rewards converted to gSGX 13e16 = 13%.
        vault.setgSGXDistributed(5e16);     // Percentage of rewards sent to the gSGX contract. 5e16 = 5%.
        vault.setMinVaultDeposit(1e18);     // Minimum amount required to deposite in Vault.
        vault.setNetworkBoost(1e18);        // SGX booster.
        vault.setRewardsWaitTime(24 hours); // rewards wait time.

        sgx.setManager(address(vault), true);
        sgx.setManager(msg.sender, true);

        gsgx.setWithdrawCeil(100000e18);
    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/

    function testLockupRewards() public {
        address user = address(0x0ABCD);
        uint256 depositAmount = 10e18;
        
        sgx.mint(address(vault), depositAmount);

        hevm.prank(address(vault));
        sgx.approve(address(lockup), depositAmount);

        hevm.prank(address(user)); // Impersonate user

        // Assert User has 0 lockups before doing anything.
        assertEq(lockup.usersLockupLength(address(user)), 0);
        
        hevm.prank(address(vault)); // Impersonate vaultFactory
        lockup.lockupRewards(address(user), shortRewards, longRewards);

        // Assert User has 1 lockup.
        uint32 index = lockup.usersLockupLength(address(user));
        assertEq(index, 1);
        
        LockupType memory userLockup;
        
        // Get lockup Info
        (userLockup.longRewardsColected, 
         userLockup.shortRewardsColected, 
         userLockup.longLockupPeriod,
         userLockup.shortLockupPeriod,
         userLockup.longRewards,
         userLockup.shortRewards) = lockup.usersLockup(address(user), index);

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

        hevm.stopPrank();
    }

    function testClaimShortLockup() public {
        address user = address(0x0ABCD);
        uint256 depositAmount = 10e18;
        
        sgx.mint(address(vault), depositAmount);

        hevm.startPrank(address(vault));
        sgx.approve(address(lockup), depositAmount);
    
        lockup.lockupRewards(address(user), shortRewards, longRewards);

        hevm.stopPrank();

        hevm.startPrank(address(user)); // Impersonate user

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.usersLockupLength(address(user));
        
        uint256 balanceBefore = sgx.balanceOf(address(user));

        LockupType memory userLockup;
        
        lockup.claimShortLockup(address(user), index);

        // Get lockup Info
        ( , 
         userLockup.shortRewardsColected, 
          ,
          ,
          ,
         userLockup.shortRewards) = lockup.usersLockup(address(user), index);

        assertTrue(userLockup.shortRewardsColected);
        assertEq(userLockup.shortRewards, 0);
        assertEq(sgx.balanceOf(address(user)), (balanceBefore+shortRewards));
        balanceBefore = sgx.balanceOf(address(user));

        hevm.stopPrank();
    }

    function testClaimLongLockup() public {
        address user = address(0x0ABCD);
        uint256 depositAmount = 10e18;
        
        sgx.mint(address(vault), depositAmount);

        hevm.prank(address(vault));
        sgx.approve(address(lockup), depositAmount);
        
        hevm.prank(address(vault)); // Impersonate vaultFactory
        lockup.lockupRewards(address(user), shortRewards, longRewards);

        hevm.startPrank(address(user)); // Impersonate user

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.usersLockupLength(address(user));
        
        uint256 balanceBefore = sgx.balanceOf(address(user));

        LockupType memory userLockup;
        
        lockup.claimLongLockup(address(user), index);

        // Get lockup Info
        (userLockup.longRewardsColected, 
          , 
          ,
          ,
         userLockup.longRewards,
          ) = lockup.usersLockup(address(user), index);

        assertTrue(userLockup.longRewardsColected);
        assertEq(userLockup.longRewards, 0);
        assertEq(sgx.balanceOf(address(user)), (balanceBefore+longRewards));

        hevm.stopPrank();
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
        assertEq(lockup.getLongPercentage(), 18e16);
    }

    function testGetShortPercentage() public {
        assertEq(lockup.getShortPercentage(), 12e16);
    }

    // <----------------------------------------------------> //
    // <---------------- TEST SET FUNCTIONS ----------------> //
    // <----------------------------------------------------> //

    function testSetLongLockupTime() public {
        lockup.setLongLockupTime(12 days);
        assertEq(lockup.getLongLockupTime(), 12 days);
    }

    function testSetShortLockupTime() public {
        lockup.setShortLockupTime(10 days);
        assertEq(lockup.getShortLockupTime(), 10 days);
    }

    function testSetLongPercentage() public {
        lockup.setLongPercentage(12e16);
        assertEq(lockup.getLongPercentage(), 12e16);
    }

    function testSetShortPercentage() public {
        lockup.setShortPercentage(10e16);
        assertEq(lockup.getShortPercentage(), 10e16);
    }

    // <----------------------------------------------------> //
    // <-------------------- TEST  FAIL --------------------> //
    // <----------------------------------------------------> //

    function testFailLockupRewardsNotUser() public {
        
        sgx.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        sgx.approve(address(lockup), 10e18);

        lockup.lockupRewards(address(0xbeef), shortRewards, longRewards);
    }

    function testFailLockupRewardsInsufficientFunds() public {
        
        sgx.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        sgx.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, 15e18);
    }

    function testFailclaimShortLockupIndexInvalid() public {
        sgx.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        sgx.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);
        
        lockup.claimShortLockup(msg.sender, 2);
    }

    function testFailclaimShortLockupAlreadyClaimed() public {
        sgx.mint(msg.sender, 10e18);
        
        hevm.startPrank(msg.sender); // Impersonate user
        sgx.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.usersLockupLength(msg.sender);
        
        // Claim once.
        lockup.claimShortLockup(msg.sender, index);

        // Try to claim again.
        lockup.claimShortLockup(msg.sender, index);
    }

    function testFailclaimShortLockupTooEarly() public {
        sgx.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        sgx.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 1 day in the future.
        hevm.warp(block.timestamp + 24 hours);

        uint32 index = lockup.usersLockupLength(msg.sender);
        
        lockup.claimShortLockup(msg.sender, index);
    }

    function testFailclaimLongLockupIndexInvalid() public {
        sgx.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        sgx.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);
        
        lockup.claimLongLockup(msg.sender, 2);
    }

    function testFailclaimLongLockupAlreadyClaimed() public {
        sgx.mint(msg.sender, 10e18);
        
        hevm.startPrank(msg.sender); // Impersonate user
        sgx.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.usersLockupLength(msg.sender);
        
        // Claim once.
        lockup.claimLongLockup(msg.sender, index);

        // Try to claim again.
        lockup.claimLongLockup(msg.sender, index);
    }

    function testFailclaimLongLockupTooEarly() public {
        sgx.mint(msg.sender, 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        sgx.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 1 day in the future.
        hevm.warp(block.timestamp + 24 hours);

        uint32 index = lockup.usersLockupLength(msg.sender);
        
        lockup.claimLongLockup(msg.sender, index);
    }
}
