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

        gsgx.setWithdrawCeil(100000e18);
    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/

    function testLockupRewards(address user, uint256 shortRewards) public {

        uint256 longRewards = 100_000_000e18;

        hevm.assume(shortRewards > vault.minVaultDeposit() && shortRewards < longRewards);

        sgx.mint(address(vault), (shortRewards+longRewards));

        hevm.startPrank(address(vault));
        sgx.approve(address(lockup), (shortRewards+longRewards));
        lockup.lockupRewards(user, shortRewards, longRewards);
        hevm.stopPrank();

        // Assert User has 1 lockup.
        uint32 index = lockup.usersLockupLength(user);
        assertEq(index, 1);

        LockupType memory userLockup;
        
        // Get lockup Info
        // solhint-disable-next-line
        (userLockup.longRewardsColected, 
         userLockup.shortRewardsColected, 
         userLockup.longLockupPeriod,
         userLockup.shortLockupPeriod,
         userLockup.longRewards,
         userLockup.shortRewards) = lockup.usersLockup(user, index);

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

    function testClaimShortLockup(address user, uint256 shortRewards) public {
        
        uint256 longRewards = 100_000_000e18;

        hevm.assume(shortRewards > vault.minVaultDeposit() && shortRewards < longRewards);

        sgx.mint(address(vault), (shortRewards + longRewards));

        hevm.startPrank(address(vault));
        sgx.approve(address(lockup), (shortRewards + longRewards));
        lockup.lockupRewards(user, shortRewards, longRewards);
        hevm.stopPrank();

        hevm.startPrank(user); // Impersonate user

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.usersLockupLength(user);
        
        uint256 balanceBefore = sgx.balanceOf(user);

        LockupType memory userLockup;
        
        lockup.claimShortLockup(user, index);

        // Get lockup Info
        // solhint-disable-next-line
        ( , 
         userLockup.shortRewardsColected, 
          ,
          ,
          ,
         userLockup.shortRewards) = lockup.usersLockup(user, index);

        assertTrue(userLockup.shortRewardsColected);
        assertEq(userLockup.shortRewards, 0);
        assertEq(sgx.balanceOf(user), (balanceBefore+shortRewards));
        balanceBefore = sgx.balanceOf(user);

        hevm.stopPrank();
    }

    function testClaimLongLockup(address user, uint256 shortRewards) public {

        uint256 longRewards = 100_000_000e18;

        hevm.assume(shortRewards > vault.minVaultDeposit() && shortRewards < longRewards);
        
        sgx.mint(address(vault), (shortRewards + longRewards));

        hevm.startPrank(address(vault));
        sgx.approve(address(lockup), (shortRewards + longRewards));
        lockup.lockupRewards(user, shortRewards, longRewards);
        hevm.stopPrank();

        hevm.startPrank(user); // Impersonate user

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.usersLockupLength(user);
        
        uint256 balanceBefore = sgx.balanceOf(user);

        LockupType memory userLockup;
        
        lockup.claimLongLockup(user, index);

        // Get lockup Info
        // solhint-disable-next-line
        (userLockup.longRewardsColected, 
          , 
          ,
          ,
         userLockup.longRewards,
        ) = lockup.usersLockup(user, index);

        assertTrue(userLockup.longRewardsColected);
        assertEq(userLockup.longRewards, 0);
        assertEq(sgx.balanceOf(user), (balanceBefore+longRewards));

        hevm.stopPrank();
    }

    // <----------------------------------------------------> //
    // <---------------- TEST SET FUNCTIONS ----------------> //
    // <----------------------------------------------------> //

    function testSetLongLockupTime(uint32 time) public {
        lockup.setLongLockupTime(time);
        assertEq(lockup.getLongLockupTime(), time);
    }

    function testSetShortLockupTime(uint32 time) public {
        lockup.setShortLockupTime(time);
        assertEq(lockup.getShortLockupTime(), time);
    }

    function testSetLongPercentage(uint256 time) public {
        lockup.setLongPercentage(time);
        assertEq(lockup.getLongPercentage(), time);
    }

    function testSetShortPercentage(uint256 time) public {
        lockup.setShortPercentage(time);
        assertEq(lockup.getShortPercentage(), time);
    }

    // <----------------------------------------------------> //
    // <-------------------- TEST  FAIL --------------------> //
    // <----------------------------------------------------> //

    function testFailLockupRewardsNotUser(
        address user,
        uint256 shortRewards, 
        uint256 longRewards
        ) public {
        
        sgx.approve(address(lockup), 10e18);
        lockup.lockupRewards(user, shortRewards, longRewards);
    }

    function testFailLockupRewardsInsufficientFunds(
        address user,
        uint256 shortRewards, 
        uint256 longRewards
    ) public {
        hevm.assume(shortRewards > 0 && longRewards > 0);

        hevm.startPrank(address(vault));
        sgx.approve(address(lockup), (shortRewards + longRewards));
        lockup.lockupRewards(user, shortRewards, longRewards);
        hevm.stopPrank();
    }

    function testFailclaimShortLockupIndexInvalid(
        uint32 index,
        uint256 shortRewards, 
        uint256 longRewards
        ) public {

        hevm.assume(index >= 2);

        sgx.approve(address(lockup), 10e18);
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);
        
        lockup.claimShortLockup(msg.sender, index);
    }

    function testFailclaimShortLockupTooEarly(
        uint256 time,
        uint256 shortRewards, 
        uint256 longRewards
        ) public {
        
        hevm.assume(time < lockup.getShortLockupTime());

        sgx.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 1 day in the future.
        hevm.warp(block.timestamp + time);
        
        lockup.claimShortLockup(msg.sender, lockup.usersLockupLength(msg.sender));
    }

    function testFailclaimLongLockupIndexInvalid(
        uint32 index,
        uint256 shortRewards, 
        uint256 longRewards
        ) public {
        
        hevm.assume(index >= 2);
        sgx.approve(address(lockup), 10e18);
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 20 days in the future.
        hevm.warp(block.timestamp + 20 days);
        
        lockup.claimLongLockup(msg.sender, index);
    }

    function testFailclaimLongLockupTooEarly(
        uint256 time,
        uint256 shortRewards, 
        uint256 longRewards
        ) public {

        hevm.assume(time < lockup.getLongLockupTime());

        sgx.approve(address(lockup), 10e18);        
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        // Jump 1 day in the future.
        hevm.warp(block.timestamp + time);
        
        lockup.claimLongLockup(msg.sender, lockup.usersLockupLength(msg.sender));
    }
}
