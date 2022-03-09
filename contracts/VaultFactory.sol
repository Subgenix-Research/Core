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
    
    /*///////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable SGX;        // Official Subgenix Network token.
    IgSGX public immutable gSGX;        // Subgenix Governance token.
    address public immutable Treasury;  // Subgenix Treasury.
    address public immutable Lockup;    // LockUpHell contract.

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
                         VAULTS CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    
    // Vault's info.
    struct Vault {
        bool exists;            // vault exists.
        uint256 lastClaimTime;  // Last claim.
        uint256 pendingRewards; // All pending rewards.
        uint256 balance;        // Total Deposited in the vault. 
    }
    
    /// @notice mapping of all users vaults.
    mapping(address => Vault) public UsersVault;
    
    /// @notice Emitted when a vault is created.
    /// @param user address, owner of the vault.
    event VaultCreated(address indexed user);

    /// @notice Emitted when user successfully deposit in his vault.
    /// @param user address, user that initiated the deposit.
    /// @param amount uint256, amount that was deposited in the vault.
    event SuccessfullyDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when a vault is liquidated.
    /// @param user address, owner of the vault that was liquidated.
    event VaultLiquidated(address indexed user);
    
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
    uint256 public MinVaultDeposit;
    
    /// @notice Percentage burned when claiming rewards.
    uint256 public BurnPercent;

    /// @notice Percetage of SGX balance user will have after when liquidating vault.
    uint256 public LiquidateVaultPercent;

    /// @notice Percentage of the reward converted to gSGX.
    uint256 public GSGXPercent;

    /// @notice Percentage of the reward sent to the gSGX contract.
    uint256 public GSGXDistributed;

    /// @notice Used to boost users SGX. 
    /// @dev Multiplies users SGX (amount * networkBoost) when
    ///      depositing/creating a vault.
    uint8 public NetworkBoost;

    /// @notice Updates the burn percentage.
    /// @param percentage uint256, the new burn percentage.
    function setBurnPercent(uint256 percentage) external onlyOwner {
        BurnPercent = percentage;
        emit burnPercentUpdated(percentage);
    }

    /// @notice Updates the minimum required to deposit in the vault.
    /// @param minDeposit uint256, the new minimum deposit required.
    function setMinVaultDeposit(uint256 minDeposit) external onlyOwner {
        MinVaultDeposit = minDeposit;
        emit minVaultDepositUpdated(minDeposit);
    }

    /// @notice Updates the network boost.
    /// @param boost uint8, the new network boost.
    function setNetworkBoost(uint8 boost) external onlyOwner {
        require(boost >= 1, "Network Boost can't be < 1.");
        NetworkBoost = boost;
        emit networkBoostUpdated(boost);
    }

    /// @notice Updates the percentage of rewards coverted to gSGX
    ///         when claiming rewards.
    /// @param percentage uint256, the new percentage.
    function setgSGXPercent(uint256 percentage) external onlyOwner {
        GSGXPercent = percentage;
    }

    /// @notice Updates the percentage of the total amount in the vault 
    ///         user will receive in SGX when liquidating the vualt.
    /// @param  percentage uint256, the new percentage.
    function setLiquidateVaultPercent(uint256 percentage) external onlyOwner {
        LiquidateVaultPercent = percentage;
    }

    /// @notice Updates the percentage of the rewards that will be 
    ///         converted to gSGX and sent to the gSGX contract.
    /// @param percentage uint256, the new percentage.
    function setgSGXDistributed(uint256 percentage) external onlyOwner {
        GSGXDistributed = percentage;
    }
    
    /*///////////////////////////////////////////////////////////////
                        VAULTS FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a vault for the user.
    /// @param amount uint256, amount that will be deposited in the vault.
    function createVault(uint256 amount) external returns(bool) {
        require(UsersVault[msg.sender].exists == false, "User already has a Vault.");
        require(amount >= MinVaultDeposit, "Amount is too small.");

        uint256 amountBoosted = amount * NetworkBoost;
        
        UsersVault[msg.sender] = Vault({
            exists: true,
            lastClaimTime: block.timestamp,
            pendingRewards: 0,
            balance: amountBoosted
        });

        TotalNetworkVaults += 1;
        TotalSGXDeposited += amount;

        SGX.transferFrom(msg.sender, address(this), amount);
        SGX.approve(Treasury, amount);
        SGX.transfer(Treasury, amount);

        emit VaultCreated(msg.sender);
        return true;
    }

    /// @notice Deposits `amount` of SGX in the vault.
    /// @param amount uint256, amount that will be deposited in the vault.
    function depositInVault(uint256 amount) external {
        require(amount >= MinVaultDeposit, "Amount is too small.");
        Vault memory userVault = UsersVault[msg.sender];
        
        require(userVault.exists == true, "You don't have a vault.");

        uint256 amountBoosted = amount * NetworkBoost;

        uint256 timeElapsed = block.timestamp - userVault.lastClaimTime;

        uint256 rewardsPercent = (timeElapsed * InterestRate) / baseTime;

        uint256 interest = (userVault.balance * rewardsPercent) / scale;

        // Update user's vault info
        userVault.lastClaimTime = block.timestamp;
        userVault.pendingRewards += interest;
        userVault.balance += amountBoosted;

        UsersVault[msg.sender] = userVault;

        TotalSGXDeposited += amount;

        // User needs to approve this contract to spend `token`.
        SGX.transferFrom(msg.sender, address(this), amount);
        SGX.approve(Treasury, amount);
        SGX.transfer(Treasury, amount);

        emit SuccessfullyDeposited(msg.sender, amountBoosted); 
    }

    /// @notice Deletes user's vault.
    function liquidateVault(address user) external {
        require(msg.sender == user, "You can only liquidate your own vault.");
        Vault memory userVault = UsersVault[user];
        require(userVault.exists == true, "You don't have a vault.");

        // 1. Claim all available rewards.
        uint256 timeElapsed = block.timestamp - userVault.lastClaimTime;

        uint256 rewardsPercent = (timeElapsed * InterestRate) / baseTime;

        uint256 claimableRewards = ((userVault.balance * rewardsPercent) / scale) + userVault.pendingRewards;

        distributeRewards(claimableRewards,  user);

        // Calculate liquidateVaultPercent of user's vault balance.
        uint256 sgxPercent = (userVault.balance * LiquidateVaultPercent) / scale;

        // Delete user vault.
        userVault.exists = false;
        userVault.lastClaimTime = block.timestamp;
        userVault.pendingRewards = 0;
        userVault.balance = 0;

        UsersVault[user] = userVault;

        ProtocolDebt += sgxPercent;
        TotalNetworkVaults -= 1;

        SGX.mint(user, sgxPercent);

        emit VaultLiquidated(user);
    }

    /*///////////////////////////////////////////////////////////////
                         REWARDS CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Emmited when the reward percentage is updated.
    /// @param reward uint256, the new reward percentage.
    event interestRateUpdated(uint256 reward);

    // The interestRate is represented as following:
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
    uint256 public InterestRate;

    /// @notice the level of reward granularity, WAD
    uint256 public constant scale = 1e18;

    /// @notice Base time used to calculate rewards.
    uint32 public constant baseTime = 365 days;

    /// @notice Updates the reward percentage distributed per `baseTime`
    /// @param _reward uint256, the new reward percentage.
    function setInterestRate(uint256 _reward) external onlyOwner {
        InterestRate = _reward;
        emit interestRateUpdated(_reward);
    }

    /*///////////////////////////////////////////////////////////////
                        REWARDS FUNCTIONALITY 
    //////////////////////////////////////////////////////////////*/

    /// @notice Claims the available rewards from user's vault.
    /// @param user address, who we are claiming rewards of.
    function claimRewards(address user) public {
        require(msg.sender == user, "You can only claim your own rewards.");
        Vault memory userVault = UsersVault[user];
        require(userVault.exists == true, "You don't have a vault.");

        uint256 timeElapsed = block.timestamp - userVault.lastClaimTime;

        //require(timeElapsed >= 24 hours, "To early to claim rewards.");

        uint256 rewardsPercent = (timeElapsed * InterestRate) / baseTime;

        uint256 claimableRewards = ((userVault.balance * rewardsPercent) / scale) + userVault.pendingRewards;

        // Update user's vault info
        userVault.lastClaimTime = block.timestamp;
        userVault.pendingRewards = 0;
        UsersVault[msg.sender] = userVault;

        distributeRewards(claimableRewards, user);
    }
    
    /// @notice Distributes the claimable rewards to the user, obeying
    ///         protocol rules.
    /// @param claimableRewards uint256, the total amount of rewards the user is claiming.
    /// @param user address, who we are distributing rewards to.
    function distributeRewards(uint256 claimableRewards, address user) private {

        uint256 mintAmount = claimableRewards;

        (uint256 burnAmount, 
         uint256 shortLockup, 
         uint256 longLockup,
         uint256 gSGXPercent,
         uint256 gSGXToContract) = calculateDistribution(claimableRewards); 
        
        claimableRewards -= burnAmount;

        claimableRewards -= gSGXPercent;

        claimableRewards -= gSGXToContract;

        SGX.mint(address(this), mintAmount);

        SGX.burn(address(this), burnAmount); // Burn token

        // Convert to gSGX and send to ser.
        SGX.approve(address(gSGX), gSGXPercent);
        gSGX.deposit(gSGXPercent);

        // send to gSGX Contract
        SGX.transfer(address(gSGX), gSGXToContract);

        // TODO Change this.

        SGX.transfer(user, claimableRewards); // Transfer token to users.
        
        ILockupHell(Lockup).lockupRewards(user, shortLockup, longLockup); // Lockup tokens
    }

    /// @notice Calculate the final value of the percentage based on the rewards amount.
    ///         eg. If rewards = 100 then 10% of it = 10.
    /// @param rewards uint256, the amount all the percentages are being calculated on top off.
    function calculateDistribution(uint256 rewards) internal view returns (
    uint256 burnAmount, 
    uint256 shortLockup, 
    uint256 longLockup,
    uint256 gSGXPercent,
    uint256 gSGXToContract
    ) {

        burnAmount = calculatePercentage(rewards, BurnPercent);
        shortLockup = calculatePercentage(rewards, ILockupHell(Lockup).getShortPercentage());
        longLockup = calculatePercentage(rewards, ILockupHell(Lockup).getLongPercentage());
        gSGXPercent = calculatePercentage(rewards, GSGXPercent);
        gSGXToContract = calculatePercentage(rewards, GSGXDistributed);
    } 

    /// @notice Calculates X's percentage based on rewards amount.
    ///         E.g. x = 1e17, y = 2e16, scale = 1e18
    ///              if scale == 100%, then x == 10% and y == 2%
    ///              Then the question is, what is 2% of 1e17?
    ///
    ///              ((1e17 * 2e16) / 1e18) --> (2e33 / 1e18) --> 2e15
    ///
    ///              This is what we are doing in this formula.
    /// TODO: FIX possible phantom overflow.
    /// @dev We are performing a mulDiv operation, rounding down.
    /// @param x uint256, the rewards.
    /// @param y uint256, the percentage being calculated.
    /// @return z uint256, the final value x based on the percetage y.
    function calculatePercentage(
        uint256 x, 
        uint256 y
    ) public pure returns (uint256 z) {
        
        z = (x * y) / scale;
    }

    /// @notice Checks how much reward the User can get if he claim rewards.
    /// @param user address, who we are checking the pending rewards.
    /// @return immediateRewards uint256, rewards the user will immediately receive.
    /// @return burnAmount       uint256, the amount of rewards that will be burned.
    /// @return shortLockup      uint256, the amount of rewards that will be locked up for a short period.
    /// @return longLockup       uint256, the amount of rewards that will be locked up for a long period.
    /// @return gSGXPercent      uint256, the amount of gSGX the user will receive.
    /// @return gSGXToContract   uint256, the amount of gSGX sent to the gSGX contract.
    function viewPendingRewards(address user) external view returns(uint256, uint256, uint256, uint256, uint256, uint256) {
        Vault memory userVault = UsersVault[user];
        require(userVault.exists == true, "You don't have a vault.");

        uint256 timeElapsed = block.timestamp - userVault.lastClaimTime;

        uint256 rewardsPercent = (timeElapsed * InterestRate) / baseTime;

        uint256 immediateRewards = ((userVault.balance * rewardsPercent) / scale) + userVault.pendingRewards;

        (uint256 burnAmount,
         uint256 shortLockup,
         uint256 longLockup,
         uint256 gSGXPercent,
         uint256 gSGXToContract) = calculateDistribution(immediateRewards);

        // Amount burned.
        immediateRewards -= burnAmount;

        // Amount converted to gSGX and sent to user.
        immediateRewards -= gSGXPercent; 

        // Amount sent to gSGX contract.
        immediateRewards -= gSGXToContract;

        // Amount to be locked up for a short period.
        immediateRewards -= shortLockup;

        // Amount to be locked up for a long period.
        immediateRewards -= longLockup;

        // The final result of the immediateRewards is what the user will recieve in his wallet.

        return (immediateRewards, burnAmount, shortLockup, longLockup, gSGXPercent, gSGXToContract);
    }

    /*///////////////////////////////////////////////////////////////
                        PROTOCOL FUNCTIONALITY 
    //////////////////////////////////////////////////////////////*/

    /// @notice Total vaults created.
    uint256 public TotalNetworkVaults;

    /// @notice Total SGX in the Protocol
    uint256 public TotalSGXDeposited;
    
    /// @notice Total protocol debt from vaults liquidated.
    uint256 public ProtocolDebt;

    /// @notice Emitted when protocol debt is repaid.
    /// @param amount uint256, amount of debt that was repaid.
    event debtReaid(uint256 amount);

    /// @notice Repay the debt created by liquidated vauts.
    /// @param amount uint256, the amount of debt being repaid.
    function repayDebt(uint256 amount) external onlyOwner {
        require(amount <= ProtocolDebt, "Amount too big.");

        ProtocolDebt -= amount;

        // Treasury needs to give permission to this contract.
        SGX.burn(address(this), amount);

        emit debtReaid(amount);
    }


    /*///////////////////////////////////////////////////////////////
                           VIEW FUNCTIONALITY 
    //////////////////////////////////////////////////////////////*/


    /// @notice Get user's vault info.
    /// @param user address, user we are checking the vault.
    function getVaultInfo(address user) public view returns(uint256 lastClaimTime, uint256 pendingRewards, uint256 balance) {
        require(UsersVault[user].exists == true, "Vault doens't exist.");

        lastClaimTime  = UsersVault[user].lastClaimTime;
        pendingRewards = UsersVault[user].pendingRewards;
        balance        = UsersVault[user].balance;
    }

    /// @notice Check if vault exists.
    /// @param user address, User we are checking the vault.
    function vaultExists(address user) external view returns(bool) {
        return UsersVault[user].exists;
    }

    function canClaimRewards(address user) external view returns(bool) {
        require(UsersVault[user].exists == true, "Vault doens't exist.");

        uint256 lastClaimTime = UsersVault[user].lastClaimTime;

        if ((block.timestamp - lastClaimTime) >= 24 hours) { return true; }

        return false; 
    }

    /// @notice Get the SGX token address.
    function getSGXAddress() external view returns (address) {
        return address(SGX);
    }

    /// @notice Get the gSGX token address.
    function getGSGXAddress() external view returns (address) {
        return address(gSGX);
    }

    function getGSGXDominance() external view returns (uint256) {
        require(SGX.totalSupply() > 0, "not enough SGX.");

        return (SGX.balanceOf(address(gSGX)) * scale) / SGX.totalSupply();
    }
}