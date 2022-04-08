// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../src/Subgenix.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {LockupHell} from "../src/lockupHell.sol";
import {GovernanceSGX} from "../src/Governancesgx.sol";
import {MockWAVAX} from "./utils/mocks/MockWAVAX.sol";
import {Helper} from "./utils/Helper.sol";


contract VaultFactoryTest is DSTestPlus {
    VaultFactory internal vault;
    LockupHell internal lockup;
    Subgenix internal sgx;
    MockWAVAX internal wavax;
    GovernanceSGX internal gSGX;
    address internal treasury = address(0xBEEF);
    address internal research = address(0xABCD);

    uint256 internal constant WAVAXCONVERSION = 7692307692307693;

    using Helper for uint256;

    function setUp() public {
        wavax = new MockWAVAX();

        sgx = new Subgenix("Subgenix Currency", "SGX", 18);
        sgx.setManager(address(this), true);
        
        lockup = new LockupHell(address(sgx));
        
        gSGX = new GovernanceSGX(address(sgx));
        
        vault = new VaultFactory(
            address(wavax),    // Wrapped wavax.
            address(sgx),      // Underlying token.
            address(gSGX),     // Governance token
            treasury,          // treasury address.
            research,          // research address.
            address(lockup)    // Lockup contract.
        );

        lockup.setVaultFactory(address(vault));

        vault.setInterestRate(7e18);                 // Daily rewards, 700e18 = 700%
        vault.setBurnPercent(2e16);                  // Percentage burned when claiming rewards, 200 = 2%.
        vault.setgSGXPercent(13e16);                 // Percentage of rewards converted to gSGX
        vault.setgSGXDistributed(5e16);              // Percentage of rewards sent to the gSGX contract.
        vault.setMinVaultDeposit(1e18);              // Minimum amount required to deposite in Vault.
        vault.setNetworkBoost(1e18);                 // SGX booster.
        vault.setRewardsWaitTime(24 hours);          // rewards wait time.
        vault.setLiquidateVaultPercent(15e16);       // 15% of the vault back to the user.
        vault.setAcceptedTokens(address(sgx), true); // Add sgx to the accepted tokens

        sgx.setManager(address(vault), true);

        hevm.stopPrank();
    }

    function testMetaData() public { 
        assertEq(vault.treasury(), treasury); 
        assertEq(vault.research(), research); 
        assertTrue(vault.acceptedTokens(address(wavax)));
    }

    // <--------------------------------------------------------> //
    // <--------------------- CREATE VAULT ---------------------> //
    // <--------------------------------------------------------> // 
    function testCreateVault(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000

        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        hevm.prank(address(this));
        sgx.transfer(user, mintAmount);

        // 2. Impersonate user and approve this address to 
        //    spend his tokens.
        hevm.startPrank(user);
        sgx.approve(address(vault), deposit);

        // 3. Create Vault.
        vault.createVault(address(sgx), deposit);

        (exists,
         lastClaimTime, 
          ,
         balance, 
         interestLength, 
         league) = vault.usersVault(user);

        assertTrue(exists);
        assertEq(lastClaimTime, block.timestamp);
        assertEq(balance, deposit);
        assertEq(interestLength, vault.getPastInterestRatesLength());
        assertTrue(league == vault.getVaultLeague(deposit));
        assertEq(vault.totalNetworkVaults(), 1);
        assertEq(sgx.balanceOf(treasury), deposit);
        //assertEq(sgx.balanceOf(user), balanceBefore - deposit);

        hevm.stopPrank();
    }

    function testCreateVaultWithWAVAX(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000

        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Set user balance to 10e18
        hevm.deal(user, deposit);

        hevm.startPrank(address(user));
        wavax.deposit{value: deposit}();
 
        uint256 balanceBefore = wavax.balanceOf(address(user));

        wavax.approve(address(vault), deposit);
        vault.createVault(address(wavax), deposit);

        (exists,
         lastClaimTime, 
          ,
         balance, 
         interestLength, 
         league) = vault.usersVault(address(user));

        assertTrue(exists);
        assertEq(lastClaimTime, block.timestamp);
        assertEq(balance, deposit.mulDivDown(WAVAXCONVERSION, 1e18));
        assertEq(interestLength, vault.getPastInterestRatesLength());
        assertTrue(league == vault.getVaultLeague(deposit));
        assertEq(vault.totalNetworkVaults(), 1);
        assertEq(wavax.balanceOf(treasury), deposit);
        assertEq(wavax.balanceOf(address(user)), balanceBefore - deposit);

        hevm.stopPrank();
    }

    function testCreateVaultInLiquidityPhase(address user, uint256 deposit) public {
        vault.setLiquidityAccumulationPhase(true);

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000

        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        hevm.prank(address(this));
        sgx.transfer(address(user), mintAmount);
        uint256 balanceBefore = sgx.balanceOf(address(user));

        // 2. Impersonate user and approve this address to 
        //    spend his tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), deposit);

        // 3. Create Vault.
        vault.createVault(address(sgx), deposit);

        (exists,
         lastClaimTime, 
          ,
         balance, 
         interestLength, 
         league) = vault.usersVault(address(user));

        assertTrue(exists);
        assertEq(lastClaimTime, block.timestamp);
        assertEq(balance, deposit);
        assertEq(interestLength, vault.getPastInterestRatesLength());
        assertTrue(league == vault.getVaultLeague(deposit));
        assertEq(vault.totalNetworkVaults(), 1);
        assertEq(sgx.balanceOf(address(vault)), deposit);
        assertEq(sgx.balanceOf(address(user)), balanceBefore - deposit);

        hevm.stopPrank();
    }

    function testCreateVaultInLiquidityPhaseWithWAVAX(address user, uint256 deposit) public {
        vault.setLiquidityAccumulationPhase(true);
        
        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000

        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Set user balance to 10e18
        hevm.deal(user, deposit);

        hevm.startPrank(address(user));
        wavax.deposit{value: deposit}();
 
        uint256 balanceBefore = wavax.balanceOf(address(user));

        wavax.approve(address(vault), deposit);
        vault.createVault(address(wavax), deposit);

        (exists,
         lastClaimTime, 
          ,
         balance, 
         interestLength, 
         league) = vault.usersVault(address(user));

        assertTrue(exists);
        assertEq(lastClaimTime, block.timestamp);
        assertEq(balance, deposit.mulDivDown(WAVAXCONVERSION, 1e18));
        assertEq(interestLength, vault.getPastInterestRatesLength());
        assertTrue(league == vault.getVaultLeague(deposit));
        assertEq(vault.totalNetworkVaults(), 1);
        assertEq(wavax.balanceOf(address(vault)), deposit);
        assertEq(wavax.balanceOf(address(user)), balanceBefore - deposit);

        hevm.stopPrank();
    }

    function testFailCreateVaultAlreadyHasOne(address user, uint256 deposit) public {
        
        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.transfer(address(user), 10e18);

        // 2. Approve vault to spend impersonated account tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), 10e18);

        // 3. Create vault. 
        vault.createVault(address(sgx), deposit);

        // 4. Try to create vault again.
        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();
    }
    function testFailCreateVaultAmountTooSmall(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit < vault.minVaultDeposit() && deposit < mintAmount);

 
        // 1. Mint token to account.
        sgx.transfer(address(user), 10e18);

        // 2. Approve vault to spend impersonated account tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), deposit);

        // 3. Create vault. 
        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();
    }

    function testFailCreateVaultTokenNotAccepted(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);
 
        // 1. Mint token to account.
        sgx.transfer(address(user), 10e18);

        // 2. Approve vault to spend impersonated account tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), 10e18);

        // 3. Create vault. 
        vault.createVault(address(0x00DEAD), deposit);

        hevm.stopPrank();
    }

    function testFailCreateVaultTransferFromUnderflow(address user, uint256 deposit) public {
        
        hevm.assume(deposit > vault.minVaultDeposit());
 
        hevm.startPrank(address(user));
        // 1. Approve vault to spend impersonated account tokens.
        sgx.approve(address(vault), deposit);

        // 2. Try to create vault. Fails because user doesn't have enough tokens.
        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();
    }

    function testFailCreateVaultStopInEmergency(address user, uint256 deposit) public {
        hevm.assume(deposit > vault.minVaultDeposit());

        vault.setCircuitBreaker(true);

        hevm.prank(address(user));
        vault.createVault(address(sgx), deposit);
    }








    // <--------------------------------------------------------> //
    // <--------------------- DEPOSIT VAULT --------------------> //
    // <--------------------------------------------------------> // 

    function testDepositInVault(address user, uint256 deposit) public {
        
        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < (mintAmount/2));
        
        uint256 firstBalance;
        uint256 lastClaimTime;
        uint256 secondBalance;
        VaultFactory.VaultLeague league;

        // 1. Mint token to account.
        hevm.prank(address(this));
        sgx.transfer(user, mintAmount);
        uint256 balanceBefore = sgx.balanceOf(user);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);
        vault.createVault(address(sgx), deposit);
        
        ( , , , firstBalance, , ) = vault.usersVault(user);

        uint256 currentBalance = balanceBefore - deposit;
        
        vault.depositInVault(address(sgx), deposit); 
        
        ( ,
         lastClaimTime, 
          ,
         secondBalance, 
          , 
         league) = vault.usersVault(address(user));

        uint256 currentsecondBalance = (currentBalance - deposit);

        assertEq(secondBalance, firstBalance+deposit);
        assertEq(sgx.balanceOf(address(user)), currentsecondBalance);
        assertEq(lastClaimTime, block.timestamp);
        assertTrue(league == vault.getVaultLeague(secondBalance));
        
        hevm.stopPrank();
    }

    function testDepositInVaultWithWAVAX(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < (mintAmount/2));

        uint256 firstBalance;
        uint256 lastClaimTime;
        uint256 secondBalance;
        VaultFactory.VaultLeague league;

        // 1. Set user balance to 10e18
        hevm.deal(user, mintAmount);

        hevm.startPrank(address(user));
        wavax.deposit{value: mintAmount}();
 
        uint256 balanceBefore = wavax.balanceOf(user);

        wavax.approve(address(vault), deposit + deposit);

        vault.createVault(address(wavax), deposit);
        
        ( , , , firstBalance, , ) = vault.usersVault(user);

        vault.depositInVault(address(wavax), deposit);

        ( ,
         lastClaimTime, 
          ,
         secondBalance, 
          , 
         league) = vault.usersVault(user);

        assertEq(secondBalance, (deposit.mulDivDown(WAVAXCONVERSION, 1e18)*2));
        assertEq(wavax.balanceOf(user), (balanceBefore - (deposit*2)));
        assertEq(lastClaimTime, block.timestamp);
        assertTrue(league == vault.getVaultLeague(secondBalance));
        
        hevm.stopPrank();
    }

    function testDepositInVaultWithInterestChange(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < (mintAmount/2));

        uint256 interestLength;

        // 1. Mint token to account.
        hevm.prank(address(this));
        sgx.transfer(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);
         
        // 3. Create vault.
        vault.createVault(address(sgx), deposit);
        
        ( , , , , interestLength, ) = vault.usersVault(user);

        assertEq(interestLength, 0);
        hevm.stopPrank();

        hevm.warp(block.timestamp + 1 days);

        // Change the reward rate.
        vault.setInterestRate(2e17);

        hevm.warp(block.timestamp + 1 days);

        hevm.startPrank(user);
        vault.depositInVault(address(sgx), deposit);

        ( , , , , interestLength, ) = vault.usersVault(user);
        assertEq(interestLength, 1);
    }

    function testFailDepositInVaultDoesntHaveVault(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.transfer(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.depositInVault(address(sgx), deposit); 

        hevm.stopPrank();
    }

    function testFailDepositInVaultAmountTooSmall(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit < vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.transfer(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.createVault(address(sgx), deposit);

        vault.depositInVault(address(sgx), deposit); 
        
        hevm.stopPrank();
    }


    function testFailDepositInVaultTokenNotAccepted(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.transfer(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.createVault(address(sgx), deposit);

        vault.depositInVault(address(0xABCD), deposit); 
        
        hevm.stopPrank();
    }

    function testFailDepositInVaultStopInEmergency(address user, uint256 deposit) public {
        
        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.transfer(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();

        vault.setCircuitBreaker(true);

        hevm.startPrank(user);
        vault.depositInVault(address(sgx), deposit); 
        
        hevm.stopPrank();
    }

    function testFailDepositInVaultTransferFromUnderflow(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.transfer(user, deposit);

        hevm.startPrank(user);
        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();
    }




    // <--------------------------------------------------------> //
    // <------------------- LIQUIDATE VAULT --------------------> //
    // <--------------------------------------------------------> //
    function testLiquidateVault(address user, uint256 deposit) public {
        
        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        uint256 balance;
        bool exists;
 
        // 1. Mint token to account.
        hevm.prank(address(this));
        sgx.transfer(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit);

        // 3. Create Vault.
        vault.createVault(address(sgx), deposit);
        
        (exists, , , balance, , ) = vault.usersVault(user);

        assertTrue(exists);
        assertEq(deposit, balance);

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 700% rewards.

        (uint256 reward,
         uint256 lockup7, 
         uint256 lockup18
        ) = vault.viewPendingRewards(user);

        uint256 percentageReceived = balance.mulDivDown(vault.liquidateVaultPercent(), 1e18);

        uint256 result = (mintAmount - deposit) + reward + percentageReceived;

        vault.liquidateVault(user);
        
        // Approve
        sgx.approve(address(lockup), lockup7+lockup18);

        (exists, , , , , ) = vault.usersVault(user);
        
        assertEq(sgx.balanceOf(address(user)), result);
        assertTrue(!exists);

        hevm.stopPrank();
    }

    function testFailLiquidateVaultNotUser(address user) public {
        vault.liquidateVault(user);
    }

    function testFailLiquidateVaultDoesntHaveVault(address user) public {

        hevm.prank(user);
        vault.liquidateVault(user);
    }







    // <--------------------------------------------------------> //
    // <--------------------- CLAIM REWARDS --------------------> //
    // <--------------------------------------------------------> // 

    function testClaimRewards(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);
        uint256 balance;

        // 1. Mint token to account.
        hevm.prank(address(this));
        sgx.transfer(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), type(uint256).max);
         
        // 3. Impersonate user
        vault.createVault(address(sgx), deposit);
        
        ( , , , balance, , ) = vault.usersVault(user);

        // *---- Jump in time and claim rewards ----* //

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 700% rewards.

        (uint256 reward,
         uint256 lockup7, 
         uint256 lockup18
        ) = vault.viewPendingRewards(user);
        
        uint256 result = (mintAmount - deposit) + reward;
        
        // Approve
        sgx.approve(address(lockup), lockup7+lockup18);
        
        vault.claimRewards(user);
        
        assertEq(sgx.balanceOf(user), result);
        hevm.stopPrank();
    }


    function testClaimRewardsWithChange(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);
        uint256 balance;

        // 1. Mint token to account.
        hevm.prank(address(this));
        sgx.transfer(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), type(uint256).max);
         
        // 3. Impersonate user
        vault.createVault(address(sgx), deposit);
        
        ( , , , balance, , ) = vault.usersVault(user);
        hevm.stopPrank();

        hevm.warp(block.timestamp + 1 days);

        // Change the reward rate.
        vault.setInterestRate(2e17);

        hevm.warp(block.timestamp + 1 days);

        hevm.startPrank(user);
        sgx.approve(address(lockup), type(uint256).max);
        
        vault.claimRewards(user);

        hevm.stopPrank();
    }


    function testFailClaimRewardsNotUser(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);
        hevm.assume(user != vault.owner());

        // 1. Mint token to account.
        sgx.transfer(user, mintAmount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(user);
        sgx.approve(address(vault),  deposit);
         
        vault.createVault(address(sgx), deposit);

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 10% rewards.

        hevm.stopPrank();

        vault.claimRewards(user);
    }

    function testFailClaimRewardsDoesntHaveVault(address user, uint256 deposit) public {

        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.transfer(user, mintAmount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(user);
        sgx.approve(address(vault), deposit);
        sgx.approve(address(lockup), deposit);

        vault.claimRewards(user);

        hevm.stopPrank();
    }

    function testFailClaimRewardsToEarlyToClaim(address user, uint256 deposit) public {

        // *---- Create and deposit in vault ----* //
        uint256 mintAmount = 6_000_000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.transfer(user, mintAmount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(user, user);
        sgx.approve(address(vault), deposit);
         
        vault.createVault(address(sgx), deposit);

        // Approve
        sgx.approve(address(lockup), deposit);
        vault.claimRewards(user);

        hevm.stopPrank();
    }
}