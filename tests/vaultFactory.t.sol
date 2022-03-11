// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Subgenix} from "../contracts/Subgenix.sol";
import {ERC20User} from "./utils/users/ERC20User.sol";
import {VaultFactory} from "../contracts/VaultFactory.sol";
import {LockUpHell} from "../contracts/lockupHell.sol";
import {FullMath} from "../contracts/utils/FullMath.sol";
import {Hevm} from "./utils/Hevm.sol";
import {gSGX} from "../contracts/gSGX.sol";


contract VaultFactoryTest is DSTest {
    Hevm hevm = Hevm(HEVM_ADDRESS);
    VaultFactory vault;
    LockUpHell lockup;
    Subgenix SGX;
    gSGX GSGX;
    address Treasury = address(0xBEEF);

    using FullMath for uint256;

    function setUp() public {
        SGX = new Subgenix("Subgenix Currency", "SGX", 18);
        
        lockup = new LockUpHell(address(SGX));
        
        GSGX = new gSGX(address(SGX));
        
        vault = new VaultFactory(
            address(SGX),      // Underlying token.
            address(GSGX),     // Governance token
            Treasury,          // Treasury address.
            address(lockup)    // Lockup contract.
        );

        lockup.setLongPercentage(18e16);    // Percentage to be locked up for 18 days, 1800 = 18%
        lockup.setShortPercentage(12e16);   // Percentage to be locked up for 07 days, 1200 = 12%
        lockup.setLongLockupTime(1555200); // 18 days in seconds
        lockup.setShortLockupTime(604800); // 07 days in seconds

        vault.setInterestRate(1e17);      // Daily rewards, 1e17 = 10%
        vault.setBurnPercent(2e16);         // Percentage burned when claiming rewards, 200 = 2%.
        vault.setgSGXPercent(13e16);        // Percentage of rewards converted to gSGX
        vault.setgSGXDistributed(5e16);     // Percentage of rewards sent to the gSGX contract.
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
        assertEq(vault.MinVaultDeposit(), 1e18); 
        assertEq(vault.InterestRate(), 1e17);
    }
    
    function testCreateVault() public {
        ERC20User user = new ERC20User(SGX);
        uint256 amount = 200e18;
        uint256 lastClaimTime;
        uint256 pendingRewards;
        uint256 balance;
        VaultFactory.VaultLeague league;
        
        assertEq(vault.TotalNetworkVaults(), 0);
 
        // 1. Mint token to account.
        SGX.mint(address(user), amount);
        uint256 balanceBefore = SGX.balanceOf(address(user));
        assertEq(balanceBefore, amount);

        // 2. Approve this address to spend impersonated account tokens.
        user.approve(address(vault), amount);
         
        // 3. Impersonate user. 
        hevm.startPrank(address(user));
        vault.createVault(amount);

        (lastClaimTime, pendingRewards, balance, league) = vault.getVaultInfo(address(user));

        assertEq(vault.TotalNetworkVaults(), 1);
        assertEq(SGX.balanceOf(Treasury), amount);
        assertEq(balance, amount);
        assertEq(SGX.balanceOf(address(user)), balanceBefore - amount);

        hevm.stopPrank();
    }


    function testDepositInVault() public {
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

        uint256 currentBalance = balanceBefore - deposit;

        //hevm.warp(block.timestamp + 1 days);

        vault.depositInVault(deposit); 
        
        ( , , balance2, ) = vault.getVaultInfo(msg.sender);
        
        uint256 expectedRewards = 273972602739726;

        uint256 currentBalance2 = (currentBalance - deposit);

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


        //emit log_named_address("Sender: ", msg.sender);
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
        ( , , balance, ) = vault.getVaultInfo(msg.sender);

        uint256 userSGXBalance = amount - deposit;
        
       
        // *---- Jump in time and claim rewards ----* //

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 10% rewards.

        uint256 reward = 1e17; // 10%
        uint256 burnAmount = reward.mulDiv(vault.BurnPercent(), 1e18); 
        uint256 lockup7    = reward.mulDiv(lockup.getShortPercentage(), 1e18); 
        uint256 lockup18   = reward.mulDiv(lockup.getLongPercentage(), 1e18); 
        uint256 gSGXDistributed = reward.mulDiv(vault.GSGXDistributed(), 1e18);
        uint256 gSGXPercentage = reward.mulDiv(vault.GSGXPercent(), 1e18);

        reward -= burnAmount;
        reward -= lockup7;
        reward -= lockup18;
        reward -= gSGXDistributed;
        reward -= gSGXPercentage;

        uint256 result = (amount - deposit) + reward;
        
        // Approve
        hevm.prank(msg.sender);
        SGX.approve(address(lockup), type(uint256).max);

        hevm.prank(msg.sender);
        vault.claimRewards(msg.sender);
         
        //hevm.prank(msg.sender);
        //assertEq(SGX.balanceOf(msg.sender), result);
    }


    // TEST VIEW FUNCTIONS

    function testGetGSGXDominance() public {
        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;
        uint256 vesting;
        uint256 lastClaimTime;


        //emit log_named_address("Sender: ", msg.sender);
        // 1. Mint token to account.
        SGX.mint(msg.sender, amount);
        uint256 balanceBefore = SGX.balanceOf(msg.sender);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.prank(msg.sender);
        SGX.approve(address(vault), amount);
         
        // 3. Impersonate user. 
        hevm.prank(msg.sender);
        vault.createVault(deposit);


        hevm.warp(block.timestamp + 365 days); // Should receive 10% rewards.

        // Approve
        hevm.prank(msg.sender);
        SGX.approve(address(lockup), type(uint256).max);

        hevm.prank(msg.sender);
        vault.claimRewards(msg.sender);

        uint256 dominance = vault.getGSGXDominance();

        emit log_uint(dominance);
    }
}
