// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILockupHell} from "./interfaces/ILockupHell.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IgSGX} from "./interfaces/IgSGX.sol";

/// @title Subgenix Vault Factory.
/// @author Subgenix Research.
/// @notice The VaultFactory contract creates and manages user's vaults.
contract VaultFactory is Ownable {

    event VaultCreated(address indexed user);
    event SuccessfullyDeposited(address indexed user, uint256 amount);

    // Info for Vault owner
    struct Vault {
        bool exists;
        uint256 lastClaimTime; // Last claim.
        uint256 balance;      // Total Deposited in the vault. 
    }
    
    mapping(address => Vault) public UsersVault;
    
    // Metadata
    IERC20 public immutable SGX;        // Token given as payment for Vault.
    IgSGX public immutable gSGX;        // Governance token.
    address public immutable Treasury;  // Subgenix Treasury.
    address public immutable Lockup;    // LockUpHell contract.

    uint256 public totalNetworkVaults = 0;
    constructor(
        address _SGX,
        address _gSGX,
        address _treasury,
        address _lockup
    ) {
        SGX = IERC20(_SGX);
        gSGX = IgSGX(_gSGX);
        Treasury = _treasury;
        Lockup = _lockup;
    }
    
    /*///////////////////////////////////////////////////////////////
                         REWARDS CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Emmited when the reward percentage is updated.
    /// @param reward uint256, the new reward percentage.
    event interestRateUpdated(uint256 reward);

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
    
    /// @notice Interest rate (per `baseTime`) i.e. 1e17 = 10% / `baseTime`
    uint256 public interestRate;

    /// @notice the level of reward granularity 
    uint256 public constant reward_granularity = 1e18;

    /// @notice Base time used to calculate rewards.
    uint32 public constant baseTime = 365 days;

    /// @notice Updates the reward percentage distributed per `baseTime`
    /// @param _reward uint256, the new reward percentage.
    function setInterestRate(uint256 _reward) external onlyOwner {
        interestRate = _reward;
        emit interestRateUpdated(_reward);
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

    /// @notice Emitted when the network boost is updated.
    /// @param newBoost uint8, the new network boost.
    event networkBoostUpdated(uint8 newBoost);
    
    /// @notice The minimum amount to deposit in the vault.
    uint256 public minVaultDeposit;
    
    /// @notice Percentage burned when claiming rewards.
    uint256 public burnPercent;

    /// @notice Percentage of the reward converted to gSGX.
    uint256 public gSGXPercent;

    /// @notice Percentage of the reward sent to the gSGX contract.
    uint256 public gSGXDistributed;

    /// @notice Used to boost users SGX. 
    /// @dev Multiplies users SGX (amount * networkBoost) when
    ///      depositing/creating a vault.
    uint8 public networkBoost;

    /// @notice Function used by the owner to update the burn percentage.
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

    /// @notice Function used by the owner to update the network boost.
    /// @param boost uint8, the new network boost.
    function setNetworkBoost(uint8 boost) external onlyOwner {
        require(boost >= 1, "Network Boost can't be < 1.");
        networkBoost = boost;
        emit networkBoostUpdated(boost);
    }

    /// @notice Function used by the owner to update the percentage of
    ///         gSGX converted when claiming rewards.
    /// @param percentage uint256, the new percentage.
    function setgSGXPercent(uint256 percentage) external onlyOwner {
        gSGXPercent = percentage;
    }

    /// @notice Function used by the owner to update the percentage of
    ///         the rewards that will be converted to gSGX and sent to the
    ///         gSGX contract.
    /// @param percentage uint256, the new percentage.
    function setgSGXDistributed(uint256 percentage) external onlyOwner {
        gSGXDistributed = percentage;
    }
    
    /*///////////////////////////////////////////////////////////////
                        VAULTS FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function createVault(uint256 amount) external returns(bool) {
        require(UsersVault[msg.sender].exists == false, "User already has a Vault.");
        require(amount >= minVaultDeposit, "Amount is too small.");

        uint256 amountBoosted = amount * networkBoost;
        
        UsersVault[msg.sender] = Vault({
            exists: true,
            lastClaimTime: block.timestamp,
            balance: amountBoosted
        });

        totalNetworkVaults += 1;

        SGX.transferFrom(msg.sender, address(this), amount);
        SGX.approve(Treasury, amount);
        SGX.transfer(Treasury, amount);

        emit VaultCreated(msg.sender);
        return true;
    }

    function depositInVault(uint256 amount) external {
        require(amount >= minVaultDeposit, "Amount is too small.");

        uint256 amountBoosted = amount * networkBoost;

        // Claim current rewards and reset lastClaimTime         
        claimRewards();
        
        // Add amount to users vault & update claimable rewards
        UsersVault[msg.sender].balance += amountBoosted;

        // User needs to approve this contract to spend `token`.
        SGX.transferFrom(msg.sender, address(this), amount);
        SGX.approve(Treasury, amount);
        SGX.transfer(Treasury, amount);

        emit SuccessfullyDeposited(msg.sender, amountBoosted); 
    }
    
    /*///////////////////////////////////////////////////////////////
                         PUBLIC FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    function claimRewards() public {
        Vault memory userVault = UsersVault[msg.sender];

        uint256 timeElapsed = block.timestamp - userVault.lastClaimTime;

        uint256 rewardsPercent = (timeElapsed * interestRate) / baseTime;

        uint256 interest = (userVault.balance * rewardsPercent) / reward_granularity;

        distributeRewards(interest, msg.sender);

        // Update user's vault info
        userVault.lastClaimTime = block.timestamp;
        UsersVault[msg.sender] = userVault;
    }
    
    /*///////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS 
    //////////////////////////////////////////////////////////////*/
    function distributeRewards(uint256 claimableRewards, address user) private {
        require(msg.sender == user, "You can only distribute your own rewards.");
        SGX.mint(address(this), claimableRewards);

        (uint256 burnAmount, 
         uint256 shortLockup, 
         uint256 longLockup,
         uint256 gSGXPercentage,
         uint256 gSGXPercentageDistribtued) = updateDistribution(claimableRewards); 
        
        claimableRewards -= burnAmount;

        claimableRewards -= gSGXPercentage;

        claimableRewards -= gSGXPercentageDistribtued;

        SGX.burn(address(this), burnAmount); // Burn token

        // 13% Convert to gSGX and send to ser.
        SGX.approve(address(gSGX), gSGXPercentage);
        gSGX.deposit(gSGXPercentage);

        // 05% sent to gSGX Contract
        SGX.transfer(address(gSGX), gSGXPercentageDistribtued);

        SGX.transfer(msg.sender, claimableRewards); // Transfer token to users.
        
        ILockupHell(Lockup).lockupRewards(msg.sender, shortLockup, longLockup); // Lockup tokens
    }
    

    /*///////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    function updateDistribution(uint256 rewards) internal view returns (
    uint256 burnAmount, 
    uint256 shortLockup, 
    uint256 longLockup,
    uint256 gSGXPercentage,
    uint256 gSGXPercentageDistribtued
    ) {
        burnAmount = calculatePercentage(rewards, burnPercent);
        shortLockup = calculatePercentage(rewards, ILockupHell(Lockup).getShortPercentage());
        longLockup = calculatePercentage(rewards, ILockupHell(Lockup).getLongPercentage());
        gSGXPercentage = calculatePercentage(rewards, gSGXPercent);
        gSGXPercentageDistribtued = calculatePercentage(rewards, gSGXDistributed);
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


    function getVaultInfo() public view returns(bool exists, uint256 lastClaimTime, uint256 balance) {
        address user      = msg.sender;
        exists           = UsersVault[user].exists;
        lastClaimTime    = UsersVault[user].lastClaimTime;
        balance          = UsersVault[user].balance;
    }

    function getTotalNetworkVaults() external view returns (uint256) {
        return totalNetworkVaults;
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

    function getInterestRate() external view returns (uint256) {
        return interestRate;
    }

    function getBurnPercentage() external view returns (uint256) {
        return burnPercent;
    }

    function getGSGXDistributed() external view returns (uint256) {
        return gSGXDistributed;
    }

    function getGSGXPercent() external view returns (uint256) {
        return gSGXPercent;
    }

    function vaultExists(address user) external view returns(bool) {
        return UsersVault[user].exists;
    }
}
