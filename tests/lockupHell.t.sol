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
        bool rewardsColected18;
        bool rewardsColected7;
        uint32 longLockupPeriod;
        uint32 shortLockupPeriod;
        uint256 rewards18;
        uint256 rewards7;
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

    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/

    function testMetaData() public {
        assertEq(lockup.SGX(), address(SGX));
        assertEq(lockup.getShortLockupTime(), 7 days);
        assertEq(lockup.getLongLockupTime(), 18 days);
        assertEq(lockup.getShortPercentage(), 1200);
        assertEq(lockup.getLongPercentage(), 1800);
    }

    function testLockupRewards() public {
        SGX.mint(msg.sender, 10e18);
        hevm.prank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);
        
        hevm.prank(msg.sender); // Impersonate user
        lockup.lockupRewards(msg.sender, shortRewards, longRewards);

        assertEq(SGX.balanceOf(msg.sender), 4e18);
        
        LockupType memory test;
        
        (test.rewardsColected18, 
         test.rewardsColected7, 
         test.longLockupPeriod,
         test.shortLockupPeriod,
         test.rewards18,
         test.rewards7) = lockup.UsersLockup(msg.sender, 1);

        assertTrue(!test.rewardsColected18);
        assertTrue(!test.rewardsColected7);
        assertEq(test.longLockupPeriod, lockup.getLongLockupTime());
        assertEq(test.shortLockupPeriod, lockup.getShortLockupTime());
        assertEq(test.rewards7, shortRewards);
        assertEq(test.rewards18, longRewards);
    }

    function testClaimRewards() public {
        SGX.mint(msg.sender, 10e18);
        hevm.startPrank(msg.sender); // Impersonate user
        SGX.approve(address(lockup), 10e18);
        
        lockup.lockupRewards(msg.sender, 1e18, 5e18);

        // Jump in the future, 20 days.
        hevm.warp(block.timestamp + 20 days);

        uint32 index = lockup.UsersLockupLength(msg.sender);
        
        uint256 balanceBefore = SGX.balanceOf(msg.sender);
        
        lockup.claimShortLockup(index);

        assertEq(SGX.balanceOf(msg.sender), (balanceBefore+shortRewards));
        balanceBefore = SGX.balanceOf(msg.sender);

        lockup.claimLongLockup(index);
        assertEq(SGX.balanceOf(msg.sender), (balanceBefore+longRewards));
    }

    /*///////////////////////////////////////////////////////////////
                              FUZZ-TESTING
    //////////////////////////////////////////////////////////////*/

    function testMetaData(
        address token,
        uint32 longPercentage,
        uint32 shortPercentage,
        uint32 shortLockupTime,
        uint32 longLockupTime
    ) public {
        LockUpHell mockLockup = new LockUpHell(token);
        mockLockup.setLongPercentage(longPercentage);
        mockLockup.setShortPercentage(shortPercentage);
        mockLockup.setLongLockupTime(longLockupTime);
        mockLockup.setShortLockupTime(shortLockupTime);

        assertEq(mockLockup.SGX(), token);
        assertEq(mockLockup.getShortLockupTime(), shortLockupTime);
        assertEq(mockLockup.getLongLockupTime(), longLockupTime);
        assertEq(mockLockup.getShortPercentage(), shortPercentage);
        assertEq(mockLockup.getLongPercentage(), longPercentage);
    }
}
