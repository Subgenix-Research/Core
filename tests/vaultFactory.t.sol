// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Subgenix} from "../contracts/Subgenix.sol";
import {ERC20User} from "./utils/users/ERC20User.sol";
import {VaultFactory} from "../contracts/VaultFactory.sol";
import {LockUpHell} from "../contracts/lockupHell.sol";
import {FullMath} from "../contracts/utils/FullMath.sol";
import {Hevm} from "./utils/Hevm.sol";
import {GovernanceSGX} from "../contracts/GovernanceSGX.sol";


contract VaultFactoryTest is DSTest {
    Hevm hevm = Hevm(HEVM_ADDRESS);
    VaultFactory vault;
    LockUpHell lockup;
    Subgenix SGX;
    GovernanceSGX GSGX;
    address Treasury = address(0xBEEF);
    address Research = address(0xABCD);

    using FullMath for uint256;

    function setUp() public {
        SGX = new Subgenix("Subgenix Currency", "SGX", 18);
        
        lockup = new LockUpHell(address(SGX));
        
        GSGX = new GovernanceSGX(address(SGX));
        
        vault = new VaultFactory(
            address(SGX),      // Underlying token.
            address(GSGX),     // Governance token
            Treasury,          // Treasury address.
            Research,          // Research address.
            address(lockup)    // Lockup contract.
        );

        lockup.setLongPercentage(18e16);    // Percentage to be locked up for 18 days, 1800 = 18%
        lockup.setShortPercentage(12e16);   // Percentage to be locked up for 07 days, 1200 = 12%
        lockup.setLongLockupTime(1555200); // 18 days in seconds
        lockup.setShortLockupTime(604800); // 07 days in seconds
        lockup.setVaultFactory(address(vault));

        vault.setInterestRate(1e17);        // Daily rewards, 1e17 = 10%
        vault.setBurnPercent(2e16);         // Percentage burned when claiming rewards, 200 = 2%.
        vault.setgSGXPercent(13e16);        // Percentage of rewards converted to gSGX
        vault.setgSGXDistributed(5e16);     // Percentage of rewards sent to the gSGX contract.
        vault.setMinVaultDeposit(1e18);     // Minimum amount required to deposite in Vault.
        vault.setNetworkBoost(1);           // SGX booster.
        vault.setRewardsWaitTime(24 hours); // rewards wait time.

        SGX.setManager(address(vault), true);

        hevm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/
    
    function testMetaData() public { 
        assertEq(vault.treasury(), Treasury); 
        assertEq(vault.minVaultDeposit(), 1e18); 
        assertEq(vault.interestRate(), 1e17);
    }

    function testCreateVault() public {
        ERC20User user = new ERC20User(SGX);
        uint256 amount = 200e18;
        uint256 balance;
        
        assertEq(vault.totalNetworkVaults(), 0);
 
        // 1. Mint token to account.
        SGX.mint(address(user), amount);
        uint256 balanceBefore = SGX.balanceOf(address(user));
        assertEq(balanceBefore, amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user));
        user.approve(address(vault), amount);

        // 3. Impersonate user. 
        vault.createVault(amount);

        ( , , balance, ) = vault.getVaultInfo(address(user));

        assertEq(vault.totalNetworkVaults(), 1);
        assertEq(SGX.balanceOf(Treasury), amount);
        assertEq(balance, amount);
        assertEq(SGX.balanceOf(address(user)), balanceBefore - amount);

        hevm.stopPrank();
    }


    function testDepositInVault() public {
        ERC20User user = new ERC20User(SGX);

        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;
        uint256 balance2;

        // 1. Mint token to account.
        SGX.mint(address(user), amount);
        uint256 balanceBefore = SGX.balanceOf(address(user));

        hevm.startPrank(address(user));
        // 2. Approve this address to spend impersonated account tokens.
        SGX.approve(address(vault), deposit+deposit);

        vault.createVault(deposit);
        
        ( , , balance, ) = vault.getVaultInfo(address(user));

        uint256 currentBalance = balanceBefore - deposit;

        vault.depositInVault(deposit); 
        
        ( , , balance2, ) = vault.getVaultInfo(address(user));

        uint256 currentBalance2 = (currentBalance - deposit);

        assertEq(balance2, balance+deposit);
        assertEq(SGX.balanceOf(address(user)), currentBalance2);
        
        hevm.stopPrank();
    }

    function testLiquidateVault() public {
        ERC20User user = new ERC20User(SGX);
        uint256 amount = 200e18;
        uint256 balance;
        bool exists;
 
        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        hevm.startPrank(address(user), address(user));
        // 2. Approve this address to spend impersonated account tokens.
        user.approve(address(vault), amount);

        // 3. Impersonate user. 
        vault.createVault(amount);
        
        (exists, , , , , ) = vault.usersVault(address(user));

        assertTrue(exists);

        vault.liquidateVault(address(user));

        (exists, , , , , ) = vault.usersVault(address(user));

        assertTrue(!exists);

        hevm.stopPrank();
    }

    function testClaimRewards() public {
        ERC20User user = new ERC20User(SGX);

        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;
        uint256 vesting;
        uint256 lastClaimTime;

        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user), address(user));
        SGX.approve(address(vault), amount);
         
        vault.createVault(deposit);

        ( , , balance, ) = vault.getVaultInfo(address(user));
       
        // *---- Jump in time and claim rewards ----* //

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 10% rewards.

        uint256 reward = 1e17; // 10%
        uint256 burnAmount = reward.mulDiv(vault.burnPercent(), 1e18); 
        uint256 lockup7    = reward.mulDiv(lockup.getShortPercentage(), 1e18); 
        uint256 lockup18   = reward.mulDiv(lockup.getLongPercentage(), 1e18); 
        uint256 gSGXDistributed = reward.mulDiv(vault.gSGXDistributed(), 1e18);
        uint256 gSGXPercentage = reward.mulDiv(vault.gSGXPercent(), 1e18);

        reward -= burnAmount;
        reward -= lockup7;
        reward -= lockup18;
        reward -= gSGXDistributed;
        reward -= gSGXPercentage;

        uint256 result = (amount - deposit) + reward;
        
        // Approve
        SGX.approve(address(lockup), lockup7+lockup18);

        vault.claimRewards(address(user));

        assertEq(SGX.balanceOf(address(user)), result);
        hevm.stopPrank();
    }


    function testDepositInVaultWithInterestChange() public {
        ERC20User user = new ERC20User(SGX);

        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;
        uint256 balance2;

        // 1. Mint token to account.
        SGX.mint(address(user), amount);
        uint256 balanceBefore = SGX.balanceOf(address(user));

        hevm.startPrank(address(user));
        // 2. Approve this address to spend impersonated account tokens.
        SGX.approve(address(vault), deposit+deposit);
         
        // 3. Impersonate user
        vault.createVault(deposit);
        
        ( , , balance, ) = vault.getVaultInfo(address(user));
        hevm.stopPrank();

        hevm.warp(block.timestamp + 1 days);

        // Change the reward rate.
        vault.setInterestRate(2e17);

        hevm.warp(block.timestamp + 1 days);

        hevm.startPrank(address(user));
        vault.depositInVault(deposit);
    }

    function testClaimRewardsWithChange() public {
        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;
        uint256 balance2;

        // 1. Mint token to account.
        SGX.mint(msg.sender, amount);
        uint256 balanceBefore = SGX.balanceOf(msg.sender);

        hevm.startPrank(msg.sender);
        // 2. Approve this address to spend impersonated account tokens.
        SGX.approve(address(vault), type(uint256).max);
         
        // 3. Impersonate user
        vault.createVault(deposit);
        
        ( , , balance, ) = vault.getVaultInfo(msg.sender);
        hevm.stopPrank();

        hevm.warp(block.timestamp + 1 days);

        // Change the reward rate.
        vault.setInterestRate(2e17);

        hevm.warp(block.timestamp + 1 days);

        hevm.startPrank(msg.sender);
        SGX.approve(address(lockup), type(uint256).max);
        
        vault.claimRewards(msg.sender);

        hevm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                              TEST-FAIL
    //////////////////////////////////////////////////////////////*/

    function testFailCreateVaultAlreadyHasOne() public {
        ERC20User user = new ERC20User(SGX);
        uint256 amount = 200e18;
 
        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        // 2. Approve vault to spend impersonated account tokens.
        user.approve(address(vault), amount);

        // 3. Create vault. 
        hevm.startPrank(address(user));
        vault.createVault(amount);

        // 4. Try to create vault again.
        vault.createVault(amount);

        hevm.stopPrank();
    }
    function testFailCreateVaultAmountTooSmall() public {
        ERC20User user = new ERC20User(SGX);
        uint256 amount = 1e16;
 
        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        // 2. Approve vault to spend impersonated account tokens.
        hevm.startPrank(address(user));
        user.approve(address(vault), amount);

        // 3. Create vault. 
        vault.createVault(amount);

        hevm.stopPrank();
    }
    function testFailCreateVaultNotEnoughFunds() public {
        ERC20User user = new ERC20User(SGX);
        uint256 amount = 2e18;
 
         hevm.startPrank(address(user));
        // 1. Approve vault to spend impersonated account tokens.
        user.approve(address(vault), amount);

        // 2. Try to create vault. Fails because user doesn't have enough tokens.
        vault.createVault(amount);

        hevm.stopPrank();
    }

    function testFailDepositInVaultDoesntHaveVault() public {
        ERC20User user = new ERC20User(SGX);

        uint256 amount = 10e18;
        uint256 deposit = 1e18;

        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        hevm.startPrank(address(user));
        // 2. Approve this address to spend impersonated account tokens.
        SGX.approve(address(vault), deposit+deposit);

        vault.depositInVault(deposit); 

        hevm.stopPrank();
    }

    function testFailDepositInVaultNotEnoughFunds() public {
        ERC20User user = new ERC20User(SGX);

        uint256 deposit = 1e18;

        // 1. Mint token to account.
        SGX.mint(address(user), deposit);

        hevm.startPrank(address(user));
        // 2. Approve this address to spend impersonated account tokens.
        SGX.approve(address(vault), deposit+deposit);

        vault.createVault(deposit);

        vault.depositInVault(deposit); 
        
        hevm.stopPrank();
    }

    function testFailLiquidateVaultNotUser() public {
        ERC20User user = new ERC20User(SGX);
        
        uint256 amount = 20e18;
 
        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        hevm.startPrank(address(user), address(user));
        // 2. Approve this address to spend impersonated account tokens.
        user.approve(address(vault), amount);

        // 3. Impersonate user. 
        vault.createVault(amount);
        hevm.stopPrank();

        vault.liquidateVault(address(user));
    }

    function testFailLiquidateVaultDoesntHaveVault() public {
        ERC20User user = new ERC20User(SGX);
        
        uint256 amount = 20e18;
 
        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        hevm.startPrank(address(user), address(user));
        // 2. Approve this address to spend impersonated account tokens.
        user.approve(address(vault), amount);

        vault.liquidateVault(address(user));
        
        hevm.stopPrank();
    }

    function testFailClaimRewardsNotUser() public {
        ERC20User user = new ERC20User(SGX);

        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;
        uint256 deposit = 1e18;

        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user), address(user));
        SGX.approve(address(vault), amount);
         
        vault.createVault(deposit);

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 10% rewards.

        // Approve
        SGX.approve(address(lockup), amount);

        hevm.stopPrank();
        vault.claimRewards(address(user));
    }

    function testFailClaimRewardsDoesntHaveVault() public {
        ERC20User user = new ERC20User(SGX);

        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;

        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user), address(user));
        SGX.approve(address(vault), amount);
        SGX.approve(address(lockup), amount);

        vault.claimRewards(address(user));

        hevm.stopPrank();
    }

    function testFailClaimRewardsToEarlyToClaim() public {
        ERC20User user = new ERC20User(SGX);

        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;
        uint256 deposit = 1e18;

        // 1. Mint token to account.
        SGX.mint(address(user), amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user), address(user));
        SGX.approve(address(vault), amount);
         
        vault.createVault(deposit);

        // Approve
        SGX.approve(address(lockup), amount);

        vault.claimRewards(address(user));
        hevm.stopPrank();
    }
}
