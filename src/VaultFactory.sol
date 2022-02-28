// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILockupHell} from "./interfaces/ILockupHell.sol";
import {IERC20} from "./interfaces/IERC20.sol";

/// @title Subgenix Vault Factory.
/// @author Subgenix Research.
/// @notice The VaultFactory contract creates and manages user's vaults.
contract VaultFactory is Ownable {

    event VaultCreated(address indexed user);
    event SuccessfullyDeposited(address indexed user, uint256 amount);

    // Info for Vault owner
    struct Vault {
        bool exists;
        uint32 lastClaimTime;     // Last claim.
        uint32 vesting;           // Seconds left to vest.
        uint256 claimableRewards; // SGX remaining to be paid.
        uint256 balance;          // Total Deposited in the vault. 
    }
    
    mapping(address => Vault) public UsersVault;
    
    // Metadata
    IERC20 public immutable SGX;        // Token given as payment for Vault.
    address public immutable Treasury;  // Subgenix Treasury.
    address public immutable Lockup;    // LockUpHell contract

    uint256 public totalVaultsCreated = 0;
    constructor(
        address _SGX,
        address _treasury,
        address _lockup
    ) {
        SGX = IERC20(_SGX);
        Treasury = _treasury;
        Lockup = _lockup;
    }
    
    /*///////////////////////////////////////////////////////////////
                         REWARDS CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Emmited when the reward percentage is updated.
    /// @param reward uint256, the new reward percentage.
    event rewardPercentUpdated(uint256 reward);

    // Rewards are represented as following (per `baseTime`):
    //   - 100% = 1e18
    //   -  10% = 1e17
    //   -   1% = 1e16
    //   - 0.1% = 1e15
    //   and so on..
    //
    // This allow us to have a really high level of granulatity,
    // and distributed really small amount of rewards with high
    // precision. 
    
    /// @notice reward Percentage (per `baseTime`) i.e. 1e17 = 10%/`baseTime`
    uint256 public rewardPercent;

    /// @notice the level of reward granularity 
    uint256 public constant reward_granularity = 1e18;

    /// @notice Base time used to calculate rewards.
    uint32 public constant baseTime = 365 days;

    /// @notice Updates the reward percentage distributed per `baseTime`
    /// @param _reward uint256, the new reward percentage.
    function setRewardPercent(uint256 _reward) external onlyOwner {
        rewardPercent = _reward;
        emit rewardPercentUpdated(_reward);
    }

    /*///////////////////////////////////////////////////////////////
                         VAULTS CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Emitted when the burn percentage is updated.
    /// @param percentage uint256, the new burn percentage.
    event burnPercentUpdated(uint256 percentage);
    
    /// @notice Emitted when the minimum deposit required is updated.
    /// @param minDeposit uint256, the new minimum deposit.
    event minVaultDepositUpdated(uint256 minDeposit);
    
    /// @notice The minimum amount to deposit in the vault.
    uint256 public minVaultDeposit;
    
    /// @notice Percentage burned when claiming rewards.
    uint256 public burnPercent;

    /// @notice Function used to update the burn percentage.
    /// @param percentage uint256, the new burn percentage.
    function setBurnPercent(uint256 percentage) external onlyOwner {
        burnPercent = percentage;
        emit burnPercentUpdated(percentage);
    }

    /// @notice Function used by the owner to update the minimum amount
    ///         required to deposit in the vault.
    /// @param minDeposit uint256, the new minimum deposit required.
    function setMinVaultDeposit(uint256 minDeposit) external onlyOwner {
        minVaultDeposit = minDeposit;
        emit minVaultDepositUpdated(minDeposit);
    }
    
    /*///////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    function createVault(uint256 amount) external returns(bool) {
        require(UsersVault[msg.sender].exists == false, "User already has a Vault.");
        require(amount >= minVaultDeposit, "Amount is too small.");
        require(SGX.balanceOf(msg.sender) >= amount, "Not enough token in wallet.");

        SGX.transferFrom(msg.sender, address(this), amount);
        SGX.approve(Treasury, amount);
        SGX.transfer(Treasury, amount);
        
        UsersVault[msg.sender] = Vault({
            exists: true,
            lastClaimTime: uint32(block.timestamp),
            vesting: baseTime,
            claimableRewards: payoutFor(amount),
            balance: amount
        });

        totalVaultsCreated += 1;
        emit VaultCreated(msg.sender);
        return true;
    }

    function depositInVault(address user, uint256 amount) external {
        require(msg.sender == user, "You can only deposit in your own vault.");
        require(amount >= minVaultDeposit, "Amount is too small.");
        require(SGX.balanceOf(user) >= amount, "Not enough token in wallet.");
        
        // User needs to approve this contract to spend `token`.
        SGX.transferFrom(user, address(this), amount);
        SGX.approve(Treasury, amount);
        SGX.transfer(Treasury, amount);

        // Claim current rewards and reset lastClaimTime         
        if (percentVestedFor(user) >= reward_granularity) { 
            // Fully Vested
            claimRewards(user);
        } else { // Not fully vested
            // Calculate amount of SGX available for claim by user.
            uint256 claimableRewards = pendingRewardsFor(user);
            if (claimableRewards != 0) {
                Vault memory userVault = UsersVault[user];
                
                distributeRewards(claimableRewards, user);

                // Update user's vault info
                userVault.lastClaimTime = uint32(block.timestamp);
                userVault.vesting -= uint32(block.timestamp) - uint32(userVault.lastClaimTime);
                userVault.claimableRewards -= claimableRewards;

                UsersVault[user] = userVault; 
            }
        }
        
        // Add amount to users vault & update claimable rewards
        UsersVault[user].balance += amount;
        UsersVault[user].claimableRewards += payoutFor(amount);

        emit SuccessfullyDeposited(msg.sender, amount); 
    }
    
    /*///////////////////////////////////////////////////////////////
                         PUBLIC FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    function claimRewards(address user) public {
        require(msg.sender == user, "You can only claim your own rewards.");
        require(percentVestedFor(msg.sender) >= reward_granularity, "Too early to claim rewards.");
        
        Vault memory userVault = UsersVault[msg.sender];
        // Pay user everything due
        uint256 claimableRewards = userVault.claimableRewards;

        distributeRewards(claimableRewards, user);

        // Reset vesting period & User info.
        userVault.lastClaimTime = uint32(block.timestamp);
        userVault.vesting = baseTime;
        userVault.claimableRewards = 0;

        UsersVault[msg.sender] = userVault;
    }
    
    /*///////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS 
    //////////////////////////////////////////////////////////////*/
    function distributeRewards(uint256 claimableRewards, address user) private {
        require(msg.sender == user, "You can only distribute your own rewards.");
        SGX.mint(address(this), claimableRewards);

        (uint256 burnAmount, uint256 shortLockup, uint256 longLockup) = updateDistribution(claimableRewards); 
        
        claimableRewards -= burnAmount;

        SGX.burn(address(this), burnAmount); // Burn token

        SGX.transfer(msg.sender, claimableRewards); // Transfer token to users.
        
        ILockupHell(Lockup).lockupRewards(msg.sender, shortLockup, longLockup); // Lockup tokens

        // Require a successfull lockup
    }
    

    /*///////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    function updateDistribution(uint256 rewards) internal view returns (
    uint256 burnAmount, 
    uint256 shortLockup, 
    uint256 longLockup
    ) {
        // Burned amount
        burnAmount = calculatePercentage(rewards, burnPercent);
        shortLockup = calculatePercentage(rewards, ILockupHell(Lockup).getShortPercentage());
        longLockup = calculatePercentage(rewards, ILockupHell(Lockup).getLongPercentage());
    } 

    /// @notice Updates the amount that is being burned when claiming rewards
    /// @param amount New BurnPercentage amount
    function updateBurnPercentage(uint256 amount) internal onlyOwner {   
        burnPercent = amount;
         
        emit burnPercentUpdated(amount);
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    function calculatePercentage(
        uint256 rewards, 
        uint256 variable
    ) public pure returns (uint256 percentage) {
        percentage = (rewards * variable) / reward_granularity; 
    }

    /// @notice Calculate how far into the baseTime the depositor is
    /// @param user address
    /// @return percentVested_ uint256
    function percentVestedFor(address user) public view returns (uint256 percentVested_) {
        Vault memory userVault = UsersVault[user];

        uint32 secondsSinceLast = uint32(block.timestamp) - userVault.lastClaimTime;
        uint32 vesting = userVault.vesting;

        if (vesting > 0) {
            percentVested_ = (secondsSinceLast * reward_granularity) / vesting;
        } else {
            percentVested_ = 0;
        }
    }

    /// @notice Calculate amount of SGX available for claim by depositor
    /// @param user address
    /// @return pendingRewards_ uint256
    function pendingRewardsFor(address user) public view returns (uint256 pendingRewards_) {
        uint256 percentVested = percentVestedFor(user);
        uint256 rewards = UsersVault[user].claimableRewards;

        if (percentVested >= reward_granularity) {
            pendingRewards_ = rewards;
        } else {
            pendingRewards_ = (rewards * percentVested) / reward_granularity;
        }
    }
    

    
    function getVaultInfo() public view returns(bool exists, uint32 lastClaimTime, uint32 vesting, uint256 claimableRewards, uint256 balance) {
        address user     = msg.sender;
        exists           = UsersVault[user].exists;
        lastClaimTime    = UsersVault[user].lastClaimTime;
        vesting          = UsersVault[user].vesting;
        claimableRewards = UsersVault[user].claimableRewards;
        balance          = UsersVault[user].balance;
    }

    /// @notice Calculate interest due.
    function payoutFor(uint256 value_) public view returns (uint256 value) {
        value = (value_ * rewardPercent) / reward_granularity;
    }

    function getSGXAddress() external view returns (address) {
        return address(SGX);
    }

    function getTreasuryAddress() external view returns (address) {
        return Treasury;
    }

    function getMinVaultDeposit() external view returns (uint256) {
        return minVaultDeposit;
    }

    function getVaultReward() external view returns (uint256) {
        return rewardPercent;
    }

    function getBurnPercentage() external view returns (uint256) {
        return burnPercent;
    }

    function vaultExists(address user) external view returns(bool) {
        return UsersVault[user].exists;
    }
}
