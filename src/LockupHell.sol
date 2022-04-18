// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.4;

import {ReentrancyGuard} from "@solmate/src/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Isgx} from "./interfaces/Isgx.sol";

error TooEarlyToClaim();
error AlreadyClaimed();
error Unauthorized();
error IndexInvalid();
error TransferFrom();
error Transfer();

/// @title Lockup Hell.
/// @author Subgenix Research.
/// @notice This contract is used to lock users rewards for a specific amount of time.
/// @dev This contract is called from the vaultFactory to lock users rewards.
contract LockupHell is Ownable, ReentrancyGuard {
    // <--------------------------------------------------------> //
    // <------------------------ EVENTS ------------------------> //
    // <--------------------------------------------------------> //

    /// @notice Emitted when user rewards are locked.
    /// @param user address, Owner of the rewards that are being locked up.
    /// @param shortLockupRewards uint256, short lockup period.
    /// @param longLockupRewards uint256, long lockup period.
    event RewardsLocked(
        address indexed user,
        uint256 shortLockupRewards,
        uint256 longLockupRewards
    );

    /// @notice Emitted when short lockup rewards are unlocked.
    /// @param user address, Owner of the rewards that are being unlocked.
    /// @param shortRewards uint256, amount of rewards unlocked.
    event UnlockShortLockup(address indexed user, uint256 shortRewards);

    /// @notice Emitted when long lockup rewards are unlocked.
    /// @param user address, Owner of the rewards that are being unlocked.
    /// @param longRewards uint256, amount of rewards unlocked.
    event UnlockLongLockup(address indexed user, uint256 longRewards);

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
        uint256 shortPercentage; // % of rewards locked up with a shorter period, defined in thousands i.e 18e16 = 18%.
        uint256 longPercentage; // % of rewards locked up with a longer period, defined in thousands i.e. 12e16 = 12%.
    }

    /// @notice Information about each `Lockup` the user has.
    struct Lockup {
        bool longRewardsCollected; // True if user collected long rewards, false otherwise.
        bool shortRewardsCollected; // True if user collected short rewards, false otherwise.
        uint32 longLockupUnlockDate; // Time (in Unit time stamp) when long lockup rewards will be unlocked.
        uint32 shortLockupUnlockDate; // Time (in Unit time stamp) when short lockup rewards will be unlocked.
        uint256 longRewards; // The amount of rewards available to the user after longLockupUnlockDate.
        uint256 shortRewards; // The amount of rewards available to the user after shortLockupUnlockDate.
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

    // Subgenix offical token, minted as a reward after each lockup.
    address internal immutable sgx;

    // vaultFactory contract address.
    address internal vaultFactory;

    // Global rates.
    Rates public rates;

    uint32 public shortLockupTime = 7 days; // Shorter lockup period.
    uint32 public longLockupTime = 18 days; // Longer lockup period.

    constructor(address sgxAddress) {
        sgx = sgxAddress;
    }

    // <--------------------------------------------------------> //
    // <------------------ EXTERNAL FUNCTIONS ------------------> //
    // <--------------------------------------------------------> //

    /// @notice Every time a user claim's his rewards, a portion of them are locked for a
    ///         specific time period in this contract.
    /// @dev    Function called from the `VaultFactory` contract to lock users rewards. We use
    ///         the 'nonReentrant' modifier from the `ReentrancyGuard` made by openZeppelin as
    ///         an extra layer of protection against Reentrancy Attacks.
    /// @param user address, The user who's rewards are being locked.
    /// @param shortLockupRewards uint256, amount of rewards that are going to be locked up for
    ///        a shorter period of time.
    /// @param longLockupRewards uint256, amount of rewards that are going to be locked up for
    ///        a longer period of time.
    function lockupRewards(
        address user,
        uint256 shortLockupRewards,
        uint256 longLockupRewards
    ) external nonReentrant {
        // only the vaultFactory address can access function.
        if (msg.sender != vaultFactory) revert Unauthorized();

        // first it checks how many `lockups` the user has and sets
        // the next index to be 'length+1' and finally it updates the
        // usersLockupLength to be 'length + 1'.
        uint32 index = usersLockupLength[user] + 1;
        usersLockupLength[user] = index;

        // The total amount being transfered.
        uint256 amount = (shortLockupRewards + longLockupRewards);

        // Add the total value of lockup rewards to the users mapping.
        usersTotalLocked[user] += amount;

        // Creates a new Lockup and add it to the new index location
        // of the usersLockup mapping.
        usersLockup[user][index] = Lockup({
            longRewardsCollected: false,
            shortRewardsCollected: false,
            longLockupUnlockDate: uint32(block.timestamp) + longLockupTime,
            shortLockupUnlockDate: uint32(block.timestamp) + shortLockupTime,
            longRewards: longLockupRewards,
            shortRewards: shortLockupRewards
        });

        // Transfer the rewards that are going to be locked up from the user to this contract.
        Isgx(sgx).transferFrom(address(vaultFactory), address(this), amount);

        emit RewardsLocked(user, shortLockupRewards, longLockupRewards);
    }

    /// @notice After the shorter lockup period is over, user can claim his rewards using this function.
    /// @dev Function called from the UI to allow user to claim his rewards.
    /// @param index uint32, the index of the `lockup` the user is refering to.
    function claimShortLockup(uint32 index) external nonReentrant {
        Lockup memory temp = usersLockup[msg.sender][index];

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
        if (usersLockupLength[msg.sender] < index) revert IndexInvalid();
        if (temp.shortRewardsCollected) revert AlreadyClaimed();
        if (block.timestamp <= temp.shortLockupUnlockDate)
            revert TooEarlyToClaim();

        // Make a temporary copy of the user `lockup` and get the short lockup rewards amount.
        uint256 amount = temp.shortRewards;

        // Updates status of the shortRewardsCollected to true,
        // and changes the shortRewards to be collected to zero.
        temp.shortRewardsCollected = true;
        temp.shortRewards = 0;

        // Updates the users lockup with the one that was
        // temporarily created.
        usersLockup[msg.sender][index] = temp;

        // Takes the amount being transfered out of users total locked mapping.
        usersTotalLocked[msg.sender] -= amount;

        // Transfer the short rewards amount to user.
        Isgx(sgx).transfer(msg.sender, amount);

        emit UnlockShortLockup(msg.sender, amount);
    }

    /// @notice After the longer lockup period is over, user can claim his rewards using this function.
    /// @dev Function called from the UI to allow user to claim his rewards. We use the 'nonReentrant' modifier
    ///      from the `ReentrancyGuard` made by openZeppelin as an extra layer of protection against Reentrancy Attacks.
    /// @param index uint32, he index of the `lockup` the user is refering to.
    function claimLongLockup(uint32 index) external nonReentrant {
        // Make a temporary copy of the user `lockup` and get the long lockup rewards amount.
        Lockup memory temp = usersLockup[msg.sender][index];

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
        if (usersLockupLength[msg.sender] < index) revert IndexInvalid();
        if (temp.shortRewardsCollected) revert AlreadyClaimed();
        if (block.timestamp <= temp.shortLockupUnlockDate)
            revert TooEarlyToClaim();

        uint256 amount = temp.longRewards;

        // Updates status of the longRewardsCollected to true,
        // and changes the longRewards to be collected to zero.
        temp.longRewardsCollected = true;
        temp.longRewards = 0;

        // Updates the users lockup with the one that was
        // temporarily created.
        usersLockup[msg.sender][index] = temp;

        // Takes the amount being transfered out of users total locked mapping.
        usersTotalLocked[msg.sender] -= amount;

        // Transfer the long rewards amount to user.
        Isgx(sgx).transfer(msg.sender, amount);

        emit UnlockLongLockup(msg.sender, amount);
    }

    // <--------------------------------------------------------> //
    // <-------------------- VIEW FUNCTIONS --------------------> //
    // <--------------------------------------------------------> //

    /// @notice Allow the user to know what the `shortPercentage` variable is set to.
    /// @return uint32, the value the `shortPercentage` variable is set to in thousands i.e. 1200 = 12%.
    function getShortPercentage() external view returns (uint256) {
        return rates.shortPercentage;
    }

    /// @notice Allow the user to know what the `longPercentage` variable is set to.
    /// @return uint32, the value the `longPercentage` variable is set to in thousands i.e. 1800 = 12%.
    function getLongPercentage() external view returns (uint256) {
        return rates.longPercentage;
    }

    // <--------------------------------------------------------> //
    // <---------------------- ONLY OWNER ----------------------> //
    // <--------------------------------------------------------> //

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
        vaultFactory = vaultAddress;
        emit VaultFactoryUpdated(vaultAddress);
    }
}
