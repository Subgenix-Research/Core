// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../contracts/Subgenix.sol";
import {VaultFactory} from "../contracts/VaultFactory.sol";
import {LockupHell} from "../contracts/lockupHell.sol";
import {GovernanceSGX} from "../contracts/Governancesgx.sol";
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

    function testCreateVault() public {
        address user = address(0x0ABCD);
        uint256 deposit = 2e18;

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        sgx.mint(address(user), 10e18);
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
        assertEq(sgx.balanceOf(treasury), deposit);
        assertEq(sgx.balanceOf(address(user)), balanceBefore - deposit);

        hevm.stopPrank();
    }

    function testCreateVaultWithWAVAX() public {
        address user = address(0x0ABCD);
        uint256 deposit = 2e18;

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        wavax.mint(address(user), 10e18);
        uint256 balanceBefore = wavax.balanceOf(address(user));

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user));
        wavax.approve(address(vault), deposit);

        // 3. Impersonate user. 
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

    function testCreateVaultInLiquidityPhase() public {
        vault.setLiquidityAccumulationPhase(true);
        
        address user = address(0x0ABCD);
        uint256 deposit = 2e18;

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        sgx.mint(address(user), 10e18);
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

    function testCreateVaultInLiquidityPhaseWithWAVAX() public {
        vault.setLiquidityAccumulationPhase(true);
        
        address user = address(0x0ABCD);
        uint256 deposit = 2e18;

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        wavax.mint(address(user), 10e18);
        uint256 balanceBefore = wavax.balanceOf(address(user));

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user));
        wavax.approve(address(vault), deposit);

        // 3. Impersonate user. 
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

    function testFailCreateVaultAlreadyHasOne() public {
        address user = address(0x0ABCD);
        uint256 deposit = 2e18;
 
        // 1. Mint token to account.
        sgx.mint(address(user), 10e18);

        // 2. Approve vault to spend impersonated account tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), 10e18);

        // 3. Create vault. 
        vault.createVault(address(sgx), deposit);

        // 4. Try to create vault again.
        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();
    }
    function testFailCreateVaultAmountTooSmall() public {
        address user = address(0x0ABCD);
        uint256 deposit = 1e16;
 
        // 1. Mint token to account.
        sgx.mint(address(user), 10e18);

        // 2. Approve vault to spend impersonated account tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), deposit);

        // 3. Create vault. 
        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();
    }

    function testFailCreateVaultTokenNotAccepted() public {
        address user = address(0x0ABCD);
        uint256 deposit = 2e18;
 
        // 1. Mint token to account.
        sgx.mint(address(user), 10e18);

        // 2. Approve vault to spend impersonated account tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), 10e18);

        // 3. Create vault. 
        vault.createVault(address(0x00DEAD), deposit);

        hevm.stopPrank();
    }

    function testFailCreateVaultTransferFromUnderflow() public {
        address user = address(0x0ABCD);
        uint256 amount = 2e18;
 
        hevm.startPrank(address(user));
        // 1. Approve vault to spend impersonated account tokens.
        sgx.approve(address(vault), amount);

        // 2. Try to create vault. Fails because user doesn't have enough tokens.
        vault.createVault(address(sgx), amount);

        hevm.stopPrank();
    }

    function testFailCreateVaultStopInEmergency() public {
        address user = address(0x0ABCD);
        uint256 deposit = 2e18;

        vault.setCircuitBreaker(true);

        hevm.prank(address(user));
        vault.createVault(address(sgx), deposit);
    }

    function testCreateVault(address user, uint256 deposit) public {

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000

        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        sgx.mint(user, mintAmount);
        uint256 balanceBefore = sgx.balanceOf(user);

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
        assertEq(sgx.balanceOf(user), balanceBefore - deposit);

        hevm.stopPrank();
    }

    function testCreateVaultWithWAVAX(address user, uint256 deposit) public {

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000

        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        wavax.mint(address(user), mintAmount);
        uint256 balanceBefore = wavax.balanceOf(address(user));

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user));
        wavax.approve(address(vault), deposit);

        // 3. Impersonate user. 
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

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000

        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        sgx.mint(address(user), mintAmount);
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
        
        uint256 mintAmount = 100000000e18; // max suplly 100.000.000

        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        bool exists;
        uint256 lastClaimTime;
        uint256 balance;
        uint256 interestLength;
        VaultFactory.VaultLeague league;
 
        // 1. Mint token to account.
        wavax.mint(address(user), mintAmount);
        uint256 balanceBefore = wavax.balanceOf(address(user));

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user));
        wavax.approve(address(vault), deposit);

        // 3. Impersonate user. 
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
        
        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.mint(address(user), 10e18);

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

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit < vault.minVaultDeposit() && deposit < mintAmount);

 
        // 1. Mint token to account.
        sgx.mint(address(user), 10e18);

        // 2. Approve vault to spend impersonated account tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), deposit);

        // 3. Create vault. 
        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();
    }

    function testFailCreateVaultTokenNotAccepted(address user, uint256 deposit) public {

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);
 
        // 1. Mint token to account.
        sgx.mint(address(user), 10e18);

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

    function testDepositInVault() public {
        address user = address(0x0ABCD);

        uint256 mintAmount = 10e18;
        uint256 deposit = 2e18;
        uint256 firstBalance;

        uint256 lastClaimTime;
        uint256 secondBalance;
        VaultFactory.VaultLeague league;

        // 1. Mint token to account.
        sgx.mint(user, mintAmount);
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
         league) = vault.usersVault(user);

        uint256 currentsecondBalance = (currentBalance - deposit);

        assertEq(secondBalance, firstBalance+deposit);
        assertEq(sgx.balanceOf(user), currentsecondBalance);
        assertEq(lastClaimTime, block.timestamp);
        assertTrue(league == vault.getVaultLeague(secondBalance));
        
        hevm.stopPrank();
    }

    function testDepositInVaultWithWAVAX() public {
        address user = address(0x0ABCD);

        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 firstBalance;

        uint256 lastClaimTime;
        uint256 secondBalance;
        VaultFactory.VaultLeague league;

        // 1. Mint token to account.
        wavax.mint(user, amount);
        uint256 balanceBefore = wavax.balanceOf(user);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        wavax.approve(address(vault), deposit+deposit);

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

    function testFailDepositInVaultDoesntHaveVault() public {
        address user = address(0x0ABCD);

        uint256 amount = 10e18;
        uint256 deposit = 1e18;

        // 1. Mint token to account.
        sgx.mint(user, amount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.depositInVault(address(sgx), deposit); 

        hevm.stopPrank();
    }

    function testFailDepositInVaultAmountTooSmall() public {
        address user = address(0x0ABCD);

        uint256 deposit = 1e18;

        // 1. Mint token to account.
        sgx.mint(user, deposit);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.createVault(address(sgx), deposit);

        vault.depositInVault(address(sgx), deposit); 
        
        hevm.stopPrank();
    }

    function testFailDepositInVaultTokenNotAccepted() public {
        address user = address(0x0ABCD);

        uint256 deposit = 1e18;

        // 1. Mint token to account.
        sgx.mint(user, deposit);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.createVault(address(sgx), deposit);

        vault.depositInVault(address(0xABCD), deposit); 
        
        hevm.stopPrank();
    }

    function testFailDepositInVaultStopInEmergency() public {
        address user = address(0x0ABCD);

        uint256 deposit = 1e18;

        // 1. Mint token to account.
        sgx.mint(user, deposit);

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

    function testFailDepositInVaultTransferFromUnderflow() public {
        address user = address(0x0ABCD);

        uint256 deposit = 1e18;

        // 1. Mint token to account.
        sgx.mint(user, deposit);

        hevm.startPrank(user);
        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();
    }

    function testDepositInVault(address user, uint256 deposit) public {
        
        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < (mintAmount/2));
        
        uint256 firstBalance;
        uint256 lastClaimTime;
        uint256 secondBalance;
        VaultFactory.VaultLeague league;

        // 1. Mint token to account.
        sgx.mint(user, mintAmount);
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

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < (mintAmount/2));

        uint256 firstBalance;
        uint256 lastClaimTime;
        uint256 secondBalance;
        VaultFactory.VaultLeague league;

        // 1. Mint token to account.
        wavax.mint(user, mintAmount);
        uint256 balanceBefore = wavax.balanceOf(user);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
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

    function testFailDepositInVaultDoesntHaveVault(address user, uint256 deposit) public {

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.mint(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.depositInVault(address(sgx), deposit); 

        hevm.stopPrank();
    }

    function testFailDepositInVaultAmountTooSmall(address user, uint256 deposit) public {

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit < vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.mint(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.createVault(address(sgx), deposit);

        vault.depositInVault(address(sgx), deposit); 
        
        hevm.stopPrank();
    }

    function testFailDepositInVaultTokenNotAccepted(address user, uint256 deposit) public {

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.mint(user, mintAmount);

        hevm.startPrank(user);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.createVault(address(sgx), deposit);

        vault.depositInVault(address(0xABCD), deposit); 
        
        hevm.stopPrank();
    }

    function testFailDepositInVaultStopInEmergency(address user, uint256 deposit) public {
        
        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.mint(user, mintAmount);

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

        uint256 mintAmount = 100000000e18; // max suplly 100.000.000
        hevm.assume(deposit > vault.minVaultDeposit() && deposit < mintAmount);

        // 1. Mint token to account.
        sgx.mint(user, deposit);

        hevm.startPrank(user);
        vault.createVault(address(sgx), deposit);

        hevm.stopPrank();
    }































    // <--------------------------------------------------------> //
    // <------------------- LIQUIDATE VAULT --------------------> //
    // <--------------------------------------------------------> // 
    function testLiquidateVault() public {
        address user = address(0x0ABCD);
        uint256 amount = 10e18;
        uint256 balance;
        bool exists;
 
        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        hevm.startPrank(address(user), address(user));
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), amount);
        balance = sgx.balanceOf(address(user));

        // 3. Impersonate user. 
        vault.createVault(address(sgx), amount);
        balance = sgx.balanceOf(address(user));
        
        (exists, , , , , ) = vault.usersVault(address(user));

        assertTrue(exists);

        vault.liquidateVault(address(user));

        (exists, , , balance, , ) = vault.usersVault(address(user));
        balance = sgx.balanceOf(address(user));

        assertTrue(!exists);

        hevm.stopPrank();
    }

    function testClaimRewards() public {
        address user = address(0x0ABCD);

        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;

        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user), address(user));
        sgx.approve(address(vault), amount);
         
        vault.createVault(address(sgx), deposit);

        ( , , , balance, , ) = vault.usersVault(address(user));

        // *---- Jump in time and claim rewards ----* //

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 700% rewards.

        uint256 reward = 7e18; // 700%
        uint256 burnAmount = reward.mulDivDown(vault.burnPercent(), 1e18); 
        uint256 lockup7    = reward.mulDivDown(lockup.getShortPercentage(), 1e18); 
        uint256 lockup18   = reward.mulDivDown(lockup.getLongPercentage(), 1e18); 
        uint256 gSGXDistributed = reward.mulDivDown(vault.gSGXDistributed(), 1e18);
        uint256 gSGXPercentage = reward.mulDivDown(vault.gSGXPercent(), 1e18);

        reward -= burnAmount;
        reward -= lockup7;
        reward -= lockup18;
        reward -= gSGXDistributed;
        reward -= gSGXPercentage;
        
        uint256 result = (amount - deposit) + reward;
        
        // Approve
        sgx.approve(address(lockup), lockup7+lockup18);
        
        vault.claimRewards(address(user));
        
        assertEq(sgx.balanceOf(address(user)), result);
        hevm.stopPrank();
    }


    function testDepositInVaultWithInterestChange() public {
        address user = address(0x0ABCD);

        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;

        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        hevm.startPrank(address(user));
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);
         
        // 3. Impersonate user
        vault.createVault(address(sgx), deposit);
        
        ( , , , balance, , ) = vault.usersVault(address(user));
        hevm.stopPrank();

        hevm.warp(block.timestamp + 1 days);

        // Change the reward rate.
        vault.setInterestRate(2e17);

        hevm.warp(block.timestamp + 1 days);

        hevm.startPrank(address(user));
        vault.depositInVault(address(sgx), deposit);
    }

    function testClaimRewardsWithChange() public {
        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;

        // 1. Mint token to account.
        sgx.mint(msg.sender, amount);

        hevm.startPrank(msg.sender);
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), type(uint256).max);
         
        // 3. Impersonate user
        vault.createVault(address(sgx), deposit);
        
        ( , , , balance, , ) = vault.usersVault(msg.sender);
        hevm.stopPrank();

        hevm.warp(block.timestamp + 1 days);

        // Change the reward rate.
        vault.setInterestRate(2e17);

        hevm.warp(block.timestamp + 1 days);

        hevm.startPrank(msg.sender);
        sgx.approve(address(lockup), type(uint256).max);
        
        vault.claimRewards(msg.sender);

        hevm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                              TEST-FAIL
    //////////////////////////////////////////////////////////////*/


    function testFailLiquidateVaultNotUser() public {
        address user = address(0x0ABCD);
        
        uint256 amount = 20e18;
 
        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        hevm.startPrank(address(user), address(user));
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), amount);

        // 3. Impersonate user. 
        vault.createVault(address(sgx), amount);
        hevm.stopPrank();

        vault.liquidateVault(address(user));
    }

    function testFailLiquidateVaultDoesntHaveVault() public {
        address user = address(0x0ABCD);
        
        uint256 amount = 20e18;
 
        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        hevm.startPrank(address(user), address(user));
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), amount);

        vault.liquidateVault(address(user));
        
        hevm.stopPrank();
    }

    function testFailClaimRewardsNotUser() public {
        address user = address(0x0ABCD);

        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;
        uint256 deposit = 1e18;

        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user), address(user));
        sgx.approve(address(vault), amount);
         
        vault.createVault(address(sgx), deposit);

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 10% rewards.

        // Approve
        sgx.approve(address(lockup), amount);

        hevm.stopPrank();
        vault.claimRewards(address(user));
    }

    function testFailClaimRewardsDoesntHaveVault() public {
        address user = address(0x0ABCD);

        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;

        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user), address(user));
        sgx.approve(address(vault), amount);
        sgx.approve(address(lockup), amount);

        vault.claimRewards(address(user));

        hevm.stopPrank();
    }

    function testFailClaimRewardsToEarlyToClaim() public {
        address user = address(0x0ABCD);

        // *---- Create and deposit in vault ----* //
        uint256 amount = 10e18;
        uint256 deposit = 1e18;

        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user), address(user));
        sgx.approve(address(vault), amount);
         
        vault.createVault(address(sgx), deposit);

        // Approve
        sgx.approve(address(lockup), amount);

        vault.claimRewards(address(user));
        hevm.stopPrank();
    }
}
