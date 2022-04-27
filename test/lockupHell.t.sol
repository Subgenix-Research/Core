// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../src/Subgenix.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {LockupHell} from "../src/lockupHell.sol";
import {GovernanceSGX} from "../src/Governancesgx.sol";
import {MockWAVAX} from "../src/mocks/mockWAVAX.sol";

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
        bool longRewardsCollected;     // True if user collected long rewards, false otherwise.
        bool shortRewardsCollected;    // True if user collected short rewards, false otherwise.
        uint32 longLockupUnlockDate;   // Time (in Unit time stamp) when long lockup rewards will be unlocked.
        uint32 shortLockupUnlockDate;  // Time (in Unit time stamp) when short lockup rewards will be unlocked.
        uint256 longRewards;           // The amount of rewards available to the user after longLockupUnlockDate.
        uint256 shortRewards;          // The amount of rewards available to the user after shortLockupUnlockDate.
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
        lockup.setVaultFactory(address(vault));

        vault.setInterestRate(1e16);        // Daily rewards, 1e16 = 1%
        vault.setBurnPercent(2e16);         // Percentage burned when claiming rewards, 2e16 = 2%.
        vault.setgSGXPercent(13e16);        // Percentage of rewards converted to gSGX 13e16 = 13%.
        vault.setgSGXDistributed(5e16);     // Percentage of rewards sent to the gSGX contract. 5e16 = 5%.
        vault.setMinVaultDeposit(1e18);     // Minimum amount required to deposite in Vault.
        vault.setNetworkBoost(1e18);        // SGX booster.
        vault.setRewardsWaitTime(24 hours); // rewards wait time.
        vault.setDepositSwapPercentage(33e16);         // 33% swap when depositing in the vault.
        vault.setCreateSwapPercentage(66e16);          // 66% swap when creating a vault.

        sgx.setManager(address(vault), true);

        gsgx.setWithdrawCeil(100000e18);
    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/

    function testLockupRewards() public {
        address user = address(0x0ABCD);
        uint256 depositAmount = 10e18;

        sgx.transfer(address(vault), depositAmount);

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
        // solhint-disable-next-line
        (userLockup.longRewardsCollected, 
         userLockup.shortRewardsCollected, 
         userLockup.longLockupUnlockDate,
         userLockup.shortLockupUnlockDate,
         userLockup.longRewards,
         userLockup.shortRewards) = lockup.usersLockup(address(user), index);

        // Assert User has not colected longRewards yet.
        assertTrue(!userLockup.longRewardsCollected);
        // Assert User has not colected shortRewards yet.
        assertTrue(!userLockup.shortRewardsCollected);
        // Assert longLockupUnlockDate is equal to what we set it to be.
        assertEq(userLockup.longLockupUnlockDate, lockup.longLockupTime());
        // Assert shortLockupUnlockDate is equal to what we set it to be.
        assertEq(userLockup.shortLockupUnlockDate, lockup.shortLockupTime());
        // Assert shortRewards are equal to what we set it to be.
        assertEq(userLockup.shortRewards, shortRewards);
        // Assert longtRewards are equal to what we set it to be.
        assertEq(userLockup.longRewards, longRewards);

        hevm.stopPrank();
    }

    function testClaimShortLockup() public {
        address user = address(0x0ABCD);
        uint256 depositAmount = 10e18;
        
        sgx.transfer(address(vault), depositAmount);

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
        
        lockup.claimShortLockup(index);

        // Get lockup Info
        // solhint-disable-next-line
        ( , 
         userLockup.shortRewardsCollected, 
          ,
          ,
          ,
         userLockup.shortRewards) = lockup.usersLockup(address(user), index);

        assertTrue(userLockup.shortRewardsCollected);
        assertEq(userLockup.shortRewards, 0);
        assertEq(sgx.balanceOf(address(user)), (balanceBefore+shortRewards));
        balanceBefore = sgx.balanceOf(address(user));

        hevm.stopPrank();
    }

    function testClaimLongLockup() public {
        address user = address(0x0ABCD);
        uint256 depositAmount = 10e18;
        
        sgx.transfer(address(vault), depositAmount);

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
        
        lockup.claimLongLockup(index);

        // Get lockup Info
        // solhint-disable-next-line
        (userLockup.longRewardsCollected, 
          , 
          ,
          ,
         userLockup.longRewards,
          ) = lockup.usersLockup(address(user), index);

        assertTrue(userLockup.longRewardsCollected);
        assertEq(userLockup.longRewards, 0);
        assertEq(sgx.balanceOf(address(user)), (balanceBefore+longRewards));

        hevm.stopPrank();
    }

    // <----------------------------------------------------> //
    // <---------------- TEST VEW FUNCTIONS ----------------> //
    // <----------------------------------------------------> //
    function testGetLongLockupTime() public {
        assertEq(lockup.longLockupTime(), 14 days);
    }

    function testGetShortLockupTime() public {
        assertEq(lockup.shortLockupTime(), 7 days);
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
        
        sgx.approve(address(lockup), 10e18);
        lockup.lockupRewards(address(0xbeef), shortRewards, longRewards);
    }

    function testFailLockupRewardsInsufficientFunds() public {
        
        sgx.approve(address(lockup), 10e18);
        lockup.lockupRewards(msg.sender, shortRewards, 15e18);
    }

    function testFailclaimShortLockupIndexInvalid() public {

        
        sgx.approve(address(lockup), 10e18);
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);
        
        lockup.claimShortLockup(2);
    }

    function testFailclaimShortLockupAlreadyClaimed() public {
        
        sgx.approve(address(lockup), 10e18);
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.usersLockupLength(msg.sender);
        
        // Claim once.
        lockup.claimShortLockup(index);

        // Try to claim again.
        lockup.claimShortLockup(index);
    }

    function testFailclaimShortLockupTooEarly() public {
        
        sgx.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 1 day in the future.
        hevm.warp(block.timestamp + 24 hours);

        uint32 index = lockup.usersLockupLength(msg.sender);
        
        lockup.claimShortLockup(index);
    }

    function testFailclaimLongLockupIndexInvalid() public {
        
        sgx.approve(address(lockup), 10e18);
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);
        
        lockup.claimLongLockup(2);
    }

    function testFailclaimLongLockupAlreadyClaimed() public {

        sgx.approve(address(lockup), 10e18);        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.usersLockupLength(msg.sender);
        
        // Claim once.
        lockup.claimLongLockup(index);

        // Try to claim again.
        lockup.claimLongLockup(index);
    }

    function testFailclaimLongLockupTooEarly() public {

        sgx.approve(address(lockup), 10e18);        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 1 day in the future.
        hevm.warp(block.timestamp + 24 hours);

        uint32 index = lockup.usersLockupLength(msg.sender);
        
        lockup.claimLongLockup(index);
    }
}
