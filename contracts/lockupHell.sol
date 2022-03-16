// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ExtendedIERC20} from "./interfaces/ExtendedIERC20.sol";

/// @title Lockup Hell.
/// @author Subgenix Research.
/// @notice This contract is used to lock users rewards for a specific amount of time.
/// @dev This contract is called from the vaultFactory to lock users rewards.
contract LockUpHell is Ownable, ReentrancyGuard {

    // <--------------------------------------------------------> //
    // <------------------------ EVENTS ------------------------> //
    // <--------------------------------------------------------> // 

    /// @notice Emitted when user rewards are locked.
    /// @param user address, Owner of the rewards that are being locked up.
    /// @param shortLockupRewards uint256, short lockup period.
    /// @param longLockupRewards uint256, long lockup period.
    event RewardsLocked(address indexed user, uint256 shortLockupRewards, uint256 longLockupRewards);
    
    /// @notice Emitted when short lockup rewards are unlocked.
    /// @param user address, Owner of the rewards that are being unlocked.
    /// @param shortRewards uint256, amount of rewards unlocked.
    event UnlockShortLockup(address indexed user, uint256 shortRewards);
    
    /// @notice Emitted when long lockup rewards are unlocked.
    /// @param user address, Owner of the rewards that are being unlocked.
    /// @param longRewards uint256, amount of rewards unlocked.
    event UnlockLongLockup(address indexed user, uint256 longRewards);

    /// @notice Emitted when the owner of the contrct changes the shorter lockup time period.
    /// @param value uint32, the new value of the shorter lockup time period.
    event ShortLockupTimeChanged(uint32 value);

    /// @notice Emitted when the owner of the contrct changes the longer lockup time period.
    /// @param value uint32, the new value of the longer lockup time period.
    event LongLockupTimeChanged(uint32 value);

    /// @notice Emitted when the owner of the contract changes the % of the rewards that are
    ///         going to be locked up for a shorter period of time.
    /// @param percentage uint256, the new percentage (in thousands) of rewards that will be
    ///         locked up for a shorter period of time from now on.
    event ShortPercentageChanged(uint256 percentage);

    /// @notice Emitted when the owner of the contract changes the % of the rewards that are
    ///         going to be locked up for a longer period of time.
    /// @param percentage uint256, the new percentage (in thousands) of rewards that will be
    ///         locked up for a longer period of time from now on.
    event LongPercentageChanged(uint256 percentage);

    /// @notice Emitted when the owner changes the address of the vaultFactory variable.
    /// @param vaultAddress address, the new vault factory address.
    event VaultFactoryUpdated(address vaultAddress);

    // <--------------------------------------------------------> //
    // <----------------------- STRUCTS ------------------------> //
    // <--------------------------------------------------------> // 

    /// @notice Global rates defined by the owner of the contract.
    struct Rates {
        uint32 shortLockupTime;  // Shorter lockup period, i.e 07 days.
        uint32 longLockupTime;   // Longer lockup period, i.e 18 days.
        uint256 shortPercentage; // % of rewards locked up with a shorter period, defined in thousands i.e 18e16 = 18%.
        uint256 longPercentage;  // % of rewards locked up with a longer period, defined in thousands i.e. 12e16 = 12%.
    } 

    /// @notice Information about each `Lockup` the user has.
    struct Lockup {
        bool longRewardsCollected;    // True if user collected long rewards, false otherwise.
        bool shortRewardsCollected;   // True if user collected short rewards, false otherwise.
        uint32 longLockupUnlockDate;  // Time (in Unit time stamp) in the future when long lockup rewards will be unlocked.
        uint32 shortLockupUnlockDate; // Time (in Unit time stamp) in the future when short lockup rewards will be unlocked.
        uint256 longRewards;          // The amount of rewards available to the user after longLockupUnlockDate.
        uint256 shortRewards;         // The amount of rewards available to the user after shortLockupUnlockDate.
    }

    // <--------------------------------------------------------> //
    // <------------------- GLOBAL VARIABLES -------------------> //
    // <--------------------------------------------------------> // 
    
    /// @notice A mapping for each user's lockup i.e. `usersLockup[msg.sender][index]`
    ///         where the `index` refers to which lockup the user wants to look at.
    mapping(address => mapping(uint32 => Lockup)) public usersLockup;

    /// @notice A mapping for the total locked from each user.
    mapping(address => uint256) public usersTotalLocked;
    
    /// @notice A mapping to check the total of `lockup's` each user has. It can be seen like this:
    ///         `usersLockup[msg.sender][index]` where `index` <= `usersLockupLength[msg.sender]`.
    ///         Since the length of total lockups is the index of the last time the user claimed and
    ///         locked up his rewards. The index of the first lockup will be 1, not 0.
    mapping(address => uint32) public usersLockupLength;

    /// @notice Subgenix offical token, minted as a reward after each lockup.
    address public immutable sgx;

    // vaultFactory contract address.
    address public vaultFactory;

    // only the vaultFactory address can access function with this modifier.
    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Not vault Factory.");
        _;
    }

    /// @notice Global rates.
    Rates public rates;
    
    constructor(address SGXAddress) {
        require(SGXAddress != address(0), "Can not be zero address");
        sgx = SGXAddress;
    }

    // <--------------------------------------------------------> //
    // <------------------ EXTERNAL FUNCTIONS ------------------> //
    // <--------------------------------------------------------> // 

    /// @notice Every time a user claim's his rewards, a portion of them are locked for a specific time period
    ///         in this contract.
    /// @dev    Function called from the `VaultFactory` contract to lock users rewards. We use the 'nonReentrant' modifier
    ///         from the `ReentrancyGuard` made by openZeppelin as an extra layer of protection against Reentrancy Attacks.
    /// @param user address, The user who's rewards are being locked.
    /// @param shortLockupRewards uint256, amount of rewards that are going to be locked up for a shorter period of time.
    /// @param longLockupRewards uint256, amount of rewards that are going to be locked up for a longer period of time.
    function lockupRewards(
        address user,
        uint256 shortLockupRewards, 
        uint256 longLockupRewards
    ) external nonReentrant onlyVaultFactory {

        // first it checks how many `lockups` the user has, then it sets
        // the next index to be 'length+1' and finally it updates the 
        // usersLockupLength to be 'length+1'.
        uint32 userLockups = usersLockupLength[user];
        uint32 index = userLockups+1;
        usersLockupLength[user] = index;

        // Add the total value of lockup rewards to the users mapping.
        usersTotalLocked[user] += (shortLockupRewards + longLockupRewards);

        // Creates a new Lockup and add it to the new index location
        // of the usersLockup mapping.
        usersLockup[user][index] = Lockup({
                longRewardsCollected: false,
                shortRewardsCollected: false,
                longLockupUnlockDate: uint32(block.timestamp) + rates.longLockupTime,
                shortLockupUnlockDate: uint32(block.timestamp) + rates.shortLockupTime,
                longRewards: longLockupRewards,
                shortRewards: shortLockupRewards
            });

        emit RewardsLocked(user, shortLockupRewards, longLockupRewards); 

        // Transfer the rewards that are going to be locked up from the user to this
        // contract. They are placed in the end of the function after all the internal
        // work and state changes are done to avoid Reentrancy Attacks.
        bool success = ExtendedIERC20(sgx).transferFrom(user, address(this), shortLockupRewards);
        require(success, "Failed to transfer SGX to lockupHell.");
        
        success = ExtendedIERC20(sgx).transferFrom(user, address(this), longLockupRewards);
        require(success, "Failed to transfer SGX to lockupHell.");
    }

    /// @notice After the shorter lockup period is over, user can claim his rewards using this function.
    /// @dev Function called from the UI to allow user to claim his rewards. We use the 'nonReentrant' modifier
    ///      from the `ReentrancyGuard` made by openZeppelin as an extra layer of protection against Reentrancy Attacks.
    /// @param user address, the user who is claiming rewards. 
    /// @param index uint32, the index of the `lockup` the user is refering to.
    function claimShortLockup(address user, uint32 index) external nonReentrant {
        // There are 3 requirements that must be true before the user can claim his
        // short lockup rewards:
        //
        // 1. The index of the 'lockup' the user is refering to must be a valid one.
        // 2. The `shortRewardsCollected` variable from the 'lockup' must be false, proving
        //    the user didn't collect his rewards yet.
        // 3. The block.timestamp must be greater than the short lockup period proposed
        //    when the rewards were first locked.
        //
        // If all three are true, the user can safely colect their short lockup rewards.
        require(usersLockupLength[user] >= index, "Index invalid");
        require(!usersLockup[user][index].shortRewardsCollected, "Already claimed.");
        //require(block.timestamp > usersLockup[user][index].shortLockupUnlockDate, "Too early to claim.");
        require(msg.sender == user, "You can only claim your own rewards.");

        // Make a temporary copy of the user `lockup` and get the short lockup rewards amount.
        Lockup memory temp = usersLockup[user][index];
        uint256 amount = temp.shortRewards;
        
        // Updates status of the shortRewardsCollected to true,
        // and changes the shortRewards to be collected to zero.
        temp.shortRewardsCollected = true;
        temp.shortRewards = 0;

        // Updates the users lockup with the one that was
        // temporarily created.
        usersLockup[user][index] = temp;

        // Takes the amount being transfered out of users total locked mapping.
        usersTotalLocked[user] -= amount;

        emit UnlockShortLockup(user, amount);

        // Transfer the short rewards amount to user.
        bool success = ExtendedIERC20(sgx).transfer(user, amount);
        require(success, "Failed to trasfer SGX to user.");
    
    }

    /// @notice After the longer lockup period is over, user can claim his rewards using this function.
    /// @dev Function called from the UI to allow user to claim his rewards. We use the 'nonReentrant' modifier
    ///      from the `ReentrancyGuard` made by openZeppelin as an extra layer of protection against Reentrancy Attacks.
    /// @param user address, the user who is claiming rewards.
    /// @param index uint32, he index of the `lockup` the user is refering to.
    function claimLongLockup(address user, uint32 index) external nonReentrant {
        // There are 3 requirements that must be true before the user can claim his
        // long lockup rewards:
        //
        // 1. The index of the 'lockup' the user is refering to must be a valid one.
        // 2. The `longRewardsCollected` variable from the 'lockup' must be false, proving
        //    the user didn't collect his rewards yet.
        // 3. The block.timestamp must be greater than the long lockup period proposed
        //    when the rewards were first locked.
        //
        // If all three are true, the user can safely colect their long lockup rewards.
        require(usersLockupLength[user] >= index, "Index invalid");
        require(!usersLockup[user][index].longRewardsCollected, "Already claimed.");
        //require(block.timestamp > usersLockup[user][index].longLockupUnlockDate, "Too early to claim.");
        require(msg.sender == user, "You can only claim your own rewards.");

        // Make a temporary copy of the user `lockup` and get the long lockup rewards amount.
        Lockup memory temp = usersLockup[user][index];
        uint256 amount = temp.longRewards;
        
        // Updates status of the longRewardsCollected to true,
        // and changes the longRewards to be collected to zero.
        temp.longRewardsCollected = true;
        temp.longRewards = 0;

        // Updates the users lockup with the one that was
        // temporarily created.
        usersLockup[user][index] = temp;

        // Takes the amount being transfered out of users total locked mapping.
        usersTotalLocked[user] -= amount;
        
        emit UnlockLongLockup(user, amount);

        // Transfer the long rewards amount to user.
        bool success = ExtendedIERC20(sgx).transfer(user, amount);
        require(success, "Error transfering SGX to user.");
    }

    // <--------------------------------------------------------> //
    // <-------------------- VIEW FUNCTIONS --------------------> //
    // <--------------------------------------------------------> // 

    /// @notice Allow the user to check how long `shortLockupTime` is set to.
    /// @return uint32, the value `shortLockupTime` is set to.
    function getShortLockupTime() external view returns(uint32) {
        return rates.shortLockupTime;
    }
    
    /// @notice Allow the user to check how long `longLockupTime` is set to.
    /// @return uint32, the value `longLockupTime` is set to.
    function getLongLockupTime() external view returns(uint32) { 
        return rates.longLockupTime;
    }

    /// @notice Allow the user to know what the `shortPercentage` variable is set to.
    /// @return uint32, the value the `shortPercentage` variable is set to in thousands i.e. 1200 = 12%.
    function getShortPercentage() external view returns(uint256) {
        return rates.shortPercentage;
    }

    /// @notice Allow the user to know what the `longPercentage` variable is set to.
    /// @return uint32, the value the `longPercentage` variable is set to in thousands i.e. 1800 = 12%.
    function getLongPercentage() external view returns(uint256) { 
        return rates.longPercentage;
    }

    // <--------------------------------------------------------> //
    // <---------------------- ONLY OWNER ----------------------> //
    // <--------------------------------------------------------> // 
    
    /// @notice Allows the owner of the contract to change the shorter lockup period all
    ///         users rewards are going to be locked up to.
    /// @dev Allows the owner of the contract to change the `shortLockupTime` value.
    function setShortLockupTime(uint32 value) external onlyOwner {
        rates.shortLockupTime = value;

        emit ShortLockupTimeChanged(value);
    }

    /// @notice Allows the owner of the contract to change the longer lockup period all
    ///         users rewards are going to be locked up to.    
    /// @dev Allows the owner of the contract to change the `longLockupTime` value.
    function setLongLockupTime(uint32 value) external onlyOwner { 
        rates.longLockupTime = value;

        emit LongLockupTimeChanged(value);
    }

    /// @notice Allows the owner of the contract change the % of the rewards that are
    ///         going to be locked up for a short period of time.
    /// @dev Allows the owner of the contract to change the `shortPercentage` value.    
    function setShortPercentage(uint256 percentage) external onlyOwner {
        rates.shortPercentage = percentage;

        emit ShortPercentageChanged(percentage);
    }

    /// @notice Allows the owner of the contract change the % of the rewards that are
    ///         going to be locked up for a long period of time.
    /// @dev Allows the owner of the contract to change the `long` value.
    function setLongPercentage(uint256 percentage) external onlyOwner { 
        rates.longPercentage = percentage;

        emit LongPercentageChanged(percentage);
    }

    /// @notice Updates the vaultFactory contract address.
    /// @param  vaultAddress address, vaultFactory contract address.
    function setVaultFactory(address vaultAddress) external onlyOwner {
        require(vaultAddress != address(0), "Can not be zero address");
        
        vaultFactory = vaultAddress;

        emit VaultFactoryUpdated(vaultAddress);
    }
}
