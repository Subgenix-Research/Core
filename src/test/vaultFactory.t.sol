// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Subgenix} from "../Subgenix.sol";
import {ERC20User} from "./utils/users/ERC20User.sol";
import {VaultFactory} from "../VaultFactory.sol";
import {LockUpHell} from "../lockupHell.sol";
import {Hevm} from "./utils/Hevm.sol";


contract VaultFactoryTest is DSTest {
    Hevm hevm = Hevm(HEVM_ADDRESS);
    VaultFactory vault;
    LockUpHell lockup;
    Subgenix SGX;
    address Treasury = address(0xBEEF);

    function setUp() public {
        SGX = new Subgenix("Subgenix Currency", "SGX", 18);
        lockup = new LockUpHell(address(SGX));
        
        vault = new VaultFactory(
            address(SGX),      // Underlying token.
            Treasury,          // Treasury address.
            address(lockup)    // Lockup contract.
        );

        lockup.setLongPercentage(1800);    // Percentage to be locked up for 18 days, 1800 = 18%
        lockup.setShortPercentage(1200);   // Percentage to be locked up for 07 days, 1200 = 12%
        lockup.setLongLockupTime(1555200); // 18 days in seconds
        lockup.setShortLockupTime(604800); // 07 days in seconds

        vault.setRewardPercent(1e16);      // Daily rewards, 1e16 = 1%
        vault.setBurnPercent(200);         // Percentage burned when claiming rewards, 200 = 2%.
        vault.setMinVaultDeposit(1e18);    // Minimum amount required to deposite in Vault.
        vault.setNetworkBoost(1);          // SGX booster.

        SGX.setManager(address(vault), true);
    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/
    
    function testMetaData() public { 
        assertEq(address(vault.SGX()), address(SGX)); 
        assertEq(vault.Treasury(), Treasury); 
        assertEq(vault.minVaultDeposit(), 1e18); 
        assertEq(vault.rewardPercent(), 1e16);
    }
    
    function testCreateVault() public {
        ERC20User user = new ERC20User(SGX);
        uint256 amount = 200e18;
        bool created; 
        uint32 lastClaimTime;
        uint32 vesting;
        uint256 rewards; 
        uint256 balance;
        
        assertEq(vault.totalVaultsCreated(), 0);
 
        // 1. Mint token to account.
        SGX.mint(address(user), amount);
        uint256 balanceBefore = SGX.balanceOf(address(user));
        assertEq(balanceBefore, amount);

        // 2. Approve this address to spend impersonated account tokens.
        user.approve(address(vault), amount);
         
        // 3. Impersonate user. 
        hevm.startPrank(address(user));
        vault.createVault(amount);

        (created, lastClaimTime, vesting, rewards, balance) = vault.getVaultInfo();

        assertEq(vault.totalVaultsCreated(), 1);
        assertEq(SGX.balanceOf(Treasury), amount);
        assertTrue(created);
        assertEq(balance, amount);
        assertEq(SGX.balanceOf(address(user)), balanceBefore - amount);

        hevm.stopPrank();
    }


    function testDepositInVault() public {
        uint256 amount = 400e18;
        uint256 deposit = 101e18;
        uint256 balance;
        uint256 balance2;

        // 1. Mint token to account.
        SGX.mint(msg.sender, amount);
        uint256 balanceBefore = SGX.balanceOf(msg.sender);

        hevm.startPrank(msg.sender);
        // 2. Approve this address to spend impersonated account tokens.
        SGX.approve(address(vault), amount);
         
        // 3. Impersonate user
        vault.createVault(deposit);
        
        ( , , , , balance) = vault.getVaultInfo();

        uint256 currentBalance = balanceBefore - deposit;

        
        vault.depositInVault(msg.sender, deposit); 
        
        ( , , , , balance2) = vault.getVaultInfo();

        uint256 currentBalance2 = currentBalance - deposit;

        assertEq(balance2, balance+deposit);
        assertEq(SGX.balanceOf(msg.sender), currentBalance2);
        hevm.stopPrank();
    }


    function testClaimRewards() public {
        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;
        uint256 vesting;
        uint256 lastClaimTime;


        emit log_named_address("Sender: ", msg.sender);
        // 1. Mint token to account.
        SGX.mint(msg.sender, amount);
        uint256 balanceBefore = SGX.balanceOf(msg.sender);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.prank(msg.sender);
        SGX.approve(address(vault), amount);
         
        // 3. Impersonate user. 
        hevm.prank(msg.sender);
        vault.createVault(deposit);

        hevm.prank(msg.sender);
        ( , , , , balance) = vault.getVaultInfo();

        uint256 userSGXBalance = amount - deposit;
        
       
        // *---- Jump in time and claim rewards ----* //

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 1% rewards.

        uint256 reward = 1e16; // 1%
        uint256 burnAmount = vault.calculatePercentage(reward, vault.getBurnPercentage()); 
        uint256 lockup7    = vault.calculatePercentage(reward, lockup.getShortPercentage()); 
        uint256 lockup18   = vault.calculatePercentage(reward, lockup.getLongPercentage()); 
        
        reward -= burnAmount;
        reward -= lockup7;
        reward -= lockup18;

        uint256 result = (amount - deposit) + reward;
        
        // Approve
        hevm.prank(msg.sender);
        SGX.approve(address(lockup), (lockup7 + lockup18));
        
        hevm.prank(msg.sender);
        vault.claimRewards(address(msg.sender));
         
        hevm.prank(msg.sender);
        assertEq(SGX.balanceOf(msg.sender), result);
    }


    // TEST VIEW FUNCTIONS

    function testGetSGXAddress() public {
        assertEq(vault.getSGXAddress(), address(vault.SGX()));
    }

    function testGetTreasuryAddress() public {
        assertEq(vault.getTreasuryAddress(), vault.Treasury());
    }

    function testGetMinVaultDeposit() public {
        assertEq(vault.getMinVaultDeposit(), vault.minVaultDeposit());
    }

    function testGetVaultReward() public {
        assertEq(vault.getVaultReward(), vault.rewardPercent());
    }
    
    /*///////////////////////////////////////////////////////////////
                              FUZZ-TESTING
    //////////////////////////////////////////////////////////////*/
    function testMetaData(
        address mockToken,
        address mockTreasury,
        address mockLockup
    ) public { 

        VaultFactory mockVault = new VaultFactory(
            mockToken,
            mockTreasury,
            mockLockup
        );

        assertEq(address(mockVault.SGX()), mockToken); 
        assertEq(mockVault.Treasury(), mockTreasury); 
    }
}
