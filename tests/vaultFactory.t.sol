// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../contracts/Subgenix.sol";
import {VaultFactory} from "../contracts/VaultFactory.sol";
import {LockupHell} from "../contracts/lockupHell.sol";
import {GovernanceSGX} from "../contracts/Governancesgx.sol";
import {MockWAVAX} from "./utils/mocks/MockWAVAX.sol";


contract VaultFactoryTest is DSTestPlus {
    VaultFactory internal vault;
    LockupHell internal lockup;
    Subgenix internal sgx;
    MockWAVAX internal wavax;
    GovernanceSGX internal gSGX;
    address internal treasury = address(0xBEEF);
    address internal research = address(0xABCD);

    uint256 internal constant WAVAXCONVERSION = 7692307692307693;

    /// @dev    from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol)
    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        // solhint-disable-next-line
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

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

        lockup.setLongPercentage(18e16);    // Percentage to be locked up for 18 days, 1800 = 18%
        lockup.setShortPercentage(12e16);   // Percentage to be locked up for 07 days, 1200 = 12%
        lockup.setLongLockupTime(1555200);  // 18 days in seconds
        lockup.setShortLockupTime(604800);  // 07 days in seconds
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
        sgx.setManager(address(gSGX), true);
        sgx.setManager(address(lockup), true);
        sgx.pauseContract(true);

        hevm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/
    
    function testMetaData() public { 
        assertEq(vault.treasury(), treasury); 
        assertEq(vault.minVaultDeposit(), 1e18);
    }

    function testCreateVault() public {
        address user = address(0x0ABCD);
        uint256 amount = 200e18;
        uint256 balance;
 
        // 1. Mint token to account.
        sgx.mint(address(user), amount);
        uint256 balanceBefore = sgx.balanceOf(address(user));
        assertEq(balanceBefore, amount);

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), amount);

        // 3. Impersonate user. 
        vault.createVault(address(sgx), amount);

        ( , , balance, ) = vault.getVaultInfo(address(user));

        assertEq(vault.totalNetworkVaults(), 1);
        assertEq(sgx.balanceOf(treasury), amount);
        assertEq(balance, amount);
        assertEq(sgx.balanceOf(address(user)), balanceBefore - amount);

        hevm.stopPrank();
    }

    function testCreateVaultWithWAVAX() public {
        address user = address(0x0ABCD);
        uint256 amount = 10e18;
        uint256 balance;
 
        // 1. Mint token to account.
        wavax.mint(address(user), amount);
        uint256 balanceBefore = wavax.balanceOf(address(user));

        // 2. Approve this address to spend impersonated account tokens.
        hevm.startPrank(address(user));
        wavax.approve(address(vault), amount);

        // 3. Impersonate user. 
        vault.createVault(address(wavax), amount);

        ( , , balance, ) = vault.getVaultInfo(address(user));

        assertEq(vault.totalNetworkVaults(), 1);
        assertEq(wavax.balanceOf(treasury), amount);
        assertEq(balance, mulDivDown(amount, WAVAXCONVERSION, 1e18));
        assertEq(wavax.balanceOf(address(user)), balanceBefore - amount);

        hevm.stopPrank();
    }


    function testDepositInVault() public {
        address user = address(0x0ABCD);

        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;
        uint256 balance2;

        // 1. Mint token to account.
        sgx.mint(address(user), amount);
        uint256 balanceBefore = sgx.balanceOf(address(user));

        hevm.startPrank(address(user));
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.createVault(address(sgx), deposit);
        
        ( , , balance, ) = vault.getVaultInfo(address(user));

        uint256 currentBalance = balanceBefore - deposit;

        vault.depositInVault(address(sgx), deposit); 
        
        ( , , balance2, ) = vault.getVaultInfo(address(user));

        uint256 currentBalance2 = (currentBalance - deposit);

        assertEq(balance2, balance+deposit);
        assertEq(sgx.balanceOf(address(user)), currentBalance2);
        
        hevm.stopPrank();
    }

    function testDepositInVaultWithWAVAX() public {
        address user = address(0x0ABCD);

        uint256 amount = 10e18;
        uint256 deposit = 1e18;
        uint256 balance;
        uint256 balance2;

        // 1. Mint token to account.
        wavax.mint(address(user), amount);
        uint256 balanceBefore = wavax.balanceOf(address(user));

        hevm.startPrank(address(user));
        // 2. Approve this address to spend impersonated account tokens.
        wavax.approve(address(vault), deposit+deposit);

        vault.createVault(address(wavax), deposit);
        
        ( , , balance, ) = vault.getVaultInfo(address(user));

        vault.depositInVault(address(wavax), deposit);

        ( , , balance2, ) = vault.getVaultInfo(address(user));

        assertEq(balance2, (mulDivDown(deposit, WAVAXCONVERSION, 1e18)*2));
        assertEq(wavax.balanceOf(address(user)), (balanceBefore - (deposit*2)));
        
        hevm.stopPrank();
    }

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

        ( , , balance, ) = vault.getVaultInfo(address(user));

        // *---- Jump in time and claim rewards ----* //

        // Jump 1 day into the future
        hevm.warp(block.timestamp + 365 days); // Should receive 700% rewards.

        uint256 reward = 7e18; // 700%
        uint256 burnAmount = mulDivDown(reward, vault.burnPercent(), 1e18); 
        uint256 lockup7    = mulDivDown(reward, lockup.getShortPercentage(), 1e18); 
        uint256 lockup18   = mulDivDown(reward, lockup.getLongPercentage(), 1e18); 
        uint256 gSGXDistributed = mulDivDown(reward, vault.gSGXDistributed(), 1e18);
        uint256 gSGXPercentage = mulDivDown(reward, vault.gSGXPercent(), 1e18);

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
        
        ( , , balance, ) = vault.getVaultInfo(address(user));
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
        
        ( , , balance, ) = vault.getVaultInfo(msg.sender);
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

    function testFailCreateVaultAlreadyHasOne() public {
        address user = address(0x0ABCD);
        uint256 amount = 200e18;
 
        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        // 2. Approve vault to spend impersonated account tokens.
        sgx.approve(address(vault), amount);

        // 3. Create vault. 
        hevm.startPrank(address(user));
        vault.createVault(address(sgx), amount);

        // 4. Try to create vault again.
        vault.createVault(address(sgx), amount);

        hevm.stopPrank();
    }
    function testFailCreateVaultAmountTooSmall() public {
        address user = address(0x0ABCD);
        uint256 amount = 1e16;
 
        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        // 2. Approve vault to spend impersonated account tokens.
        hevm.startPrank(address(user));
        sgx.approve(address(vault), amount);

        // 3. Create vault. 
        vault.createVault(address(sgx), amount);

        hevm.stopPrank();
    }
    function testFailCreateVaultNotEnoughFunds() public {
        address user = address(0x0ABCD);
        uint256 amount = 2e18;
 
         hevm.startPrank(address(user));
        // 1. Approve vault to spend impersonated account tokens.
        sgx.approve(address(vault), amount);

        // 2. Try to create vault. Fails because user doesn't have enough tokens.
        vault.createVault(address(sgx), amount);

        hevm.stopPrank();
    }

    function testFailDepositInVaultDoesntHaveVault() public {
        address user = address(0x0ABCD);

        uint256 amount = 10e18;
        uint256 deposit = 1e18;

        // 1. Mint token to account.
        sgx.mint(address(user), amount);

        hevm.startPrank(address(user));
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.depositInVault(address(sgx), deposit); 

        hevm.stopPrank();
    }

    function testFailDepositInVaultNotEnoughFunds() public {
        address user = address(0x0ABCD);

        uint256 deposit = 1e18;

        // 1. Mint token to account.
        sgx.mint(address(user), deposit);

        hevm.startPrank(address(user));
        // 2. Approve this address to spend impersonated account tokens.
        sgx.approve(address(vault), deposit+deposit);

        vault.createVault(address(sgx), deposit);

        vault.depositInVault(address(sgx), deposit); 
        
        hevm.stopPrank();
    }

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
