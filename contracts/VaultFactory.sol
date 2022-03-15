// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ExtendedIERC20} from "./interfaces/ExtendedIERC20.sol";
import {IJoeRouter02} from "./interfaces/IJoeRouter02.sol";
import {ILockupHell} from "./interfaces/ILockupHell.sol";
import {FullMath} from "./utils/FullMath.sol";
import {IgSGX} from "./interfaces/IgSGX.sol";

/// @title Subgenix Vault Factory.
/// @author Subgenix Research.
/// @notice The VaultFactory contract creates and manages user's vaults.
contract VaultFactory is Ownable, ReentrancyGuard {

    using FullMath for uint256;
    
    // <--------------------------------------------------------> //
    // <----------------------- METADATA -----------------------> //
    // <--------------------------------------------------------> // 

    // Trader Joe Router.
    IJoeRouter02 private joeRouter = IJoeRouter02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
    // WAVAX token address.
    address constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    ExtendedIERC20 public immutable SGX; // Official Subgenix Network token.
    IgSGX public immutable gSGX;         // Subgenix Governance token.
    address public immutable Treasury;   // Subgenix Treasury.
    address public immutable Research;   // Subgenix Research.
    address public immutable Lockup;     // LockUpHell contract.

    constructor(
        address _SGX,
        address _gSGX,
        address _treasury,
        address _research,
        address _lockup
    ) {
        require(_treasury != address(0), "Can not be zero address.");
        require(_research != address(0), "Can not be zero address");
        require(_lockup != address(0), "Can not be zero address");

        SGX = ExtendedIERC20(_SGX);
        gSGX = IgSGX(_gSGX);
        Treasury = _treasury;
        Research = _research;
        Lockup = _lockup;
    }

    // <--------------------------------------------------------> //
    // <----------------- VAULTS CONFIGURATION -----------------> //
    // <--------------------------------------------------------> // 
    
    // Vault Leagues.
    enum VaultLeague {
        league0, // Avalanche Defender
        league1, // Subnet Soldier
        league2, // Network Warrior
        league3, // Consensus Master
        league4  // Royal Validator
    }

    // Vault's info.
    struct Vault {
        bool exists;            // vault exists.
        uint256 lastClaimTime;  // Last claim.
        uint256 pendingRewards; // All pending rewards.
        uint256 balance;        // Total Deposited in the vault.
        uint256 interestLength; // Last interestRates length.
        VaultLeague league;     // Vault league.
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
    event BurnPercentUpdated(uint256 percentage);
    
    /// @notice Emitted when the minimum deposit required is updated.
    /// @param minDeposit uint256, the new minimum deposit.
    event MinVaultDepositUpdated(uint256 minDeposit);

    /// @notice Emitted when the network boost is updated.
    /// @param newBoost uint8, the new network boost.
    event NetworkBoostUpdated(uint8 newBoost);

    /// @notice Emitted when the gSGXPercent is updated.
    /// @param percentage uint256, the new gSGXPercent.
    event GSGXPercentUpdated(uint256 percentage);

    /// @notice Emitted when the liquidateVaultPercent is updated.
    /// @param percentage uint256, the new liquidateVaultPercent.
    event LiquidateVaultPercentUpdated(uint256 percentage);

    /// @notice Emitted when the gSGXDistributed is updated.
    /// @param percentage uint256, the new gSGXDistributed.
    event GSGXDistributedUpdated(uint256 percentage);

    /// @notice Emmited when the rewardsWaitTime is updated.
    /// @param time uint256, the re rewardsWaitTime.
    event RewardsWaitTimeUpdated(uint256 time);

    /// @notice Emitted when the treasurySwap is updated.
    /// @param allow bool, the new treasurySwap.
    event TreasurySwapUpdated(bool allow);
    
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

    /// @notice Time you have to wait to colect rewards again.
    uint256 public rewardsWaitTime;

    /// @notice Used to boost users SGX.
    /// @dev Multiplies users SGX (amount * networkBoost) when
    ///      depositing/creating a vault.
    uint8 public NetworkBoost;

    // Indicates if swaps are happening or not.
    bool allowTreasurySwap;

    /// @notice Updates the burn percentage.
    /// @param percentage uint256, the new burn percentage.
    function setBurnPercent(uint256 percentage) external onlyOwner {
        BurnPercent = percentage;
        emit BurnPercentUpdated(percentage);
    }

    /// @notice Updates the minimum required to deposit in the vault.
    /// @param minDeposit uint256, the new minimum deposit required.
    function setMinVaultDeposit(uint256 minDeposit) external onlyOwner {
        MinVaultDeposit = minDeposit;
        emit MinVaultDepositUpdated(minDeposit);
    }

    /// @notice Updates the network boost.
    /// @param boost uint8, the new network boost.
    function setNetworkBoost(uint8 boost) external onlyOwner {
        require(boost >= 1, "Network Boost can't be < 1.");
        NetworkBoost = boost;
        emit NetworkBoostUpdated(boost);
    }

    /// @notice Updates the percentage of rewards coverted to gSGX
    ///         when claiming rewards.
    /// @param percentage uint256, the new percentage.
    function setgSGXPercent(uint256 percentage) external onlyOwner {
        GSGXPercent = percentage;

        emit GSGXPercentUpdated(percentage);
    }

    /// @notice Updates the percentage of the total amount in the vault 
    ///         user will receive in SGX when liquidating the vualt.
    /// @param  percentage uint256, the new percentage.
    function setLiquidateVaultPercent(uint256 percentage) external onlyOwner {
        LiquidateVaultPercent = percentage;

        emit LiquidateVaultPercentUpdated(percentage);
    }

    /// @notice Updates the percentage of the rewards that will be 
    ///         converted to gSGX and sent to the gSGX contract.
    /// @param percentage uint256, the new percentage.
    function setgSGXDistributed(uint256 percentage) external onlyOwner {
        GSGXDistributed = percentage;

        emit GSGXDistributedUpdated(percentage);
    }

    /// @notice Updates the time user will have to wait to claim rewards
    ///         again.
    /// @param time uint256, the new wait time.
    function setRewardsWaitTime(uint256 time) external onlyOwner {
        rewardsWaitTime = time;

        emit RewardsWaitTimeUpdated(time);
    }

    /// @notice Updates the treasury swap status.
    /// @param allow bool, true to activate swap, false otherwise.
    function setTreasurySwap(bool allow) external onlyOwner {
        allowTreasurySwap = allow;

        emit TreasurySwapUpdated(allow);
    }

    // <--------------------------------------------------------> //
    // <----------------- VAULTS FUNCTIONALITY -----------------> //
    // <--------------------------------------------------------> // 

    /// @notice Creates a vault for the user.
    /// @param amount uint256, amount that will be deposited in the vault.
    function createVault(uint256 amount) external nonReentrant returns(bool) {
        require(!UsersVault[msg.sender].exists, "User already has a Vault.");
        require(amount >= MinVaultDeposit, "Amount is too small.");

        uint256 amountBoosted = amount * NetworkBoost;

        VaultLeague tempLeague = getVaultLeague(amountBoosted);

        UsersVault[msg.sender] = Vault({
            exists: true,
            lastClaimTime: block.timestamp,
            pendingRewards: 0,
            balance: amountBoosted,
            interestLength: PastInterestRates.length,
            league: tempLeague
        });

        TotalNetworkVaults += 1;

        uint256 swapAmount = 0;

        emit VaultCreated(msg.sender);

        bool success = SGX.transferFrom(msg.sender, address(this), amount);
        require(success, "Failed to transfer SGX to vault.");

        if (allowTreasurySwap) {
            // Swaps 66% of the amount deposit to AVAX.
            swapAmount = amount.mulDiv(66e16, scale);
            swapSGXforAVAX(swapAmount);
        }

        success = SGX.approve(Treasury, amount - swapAmount);
        require(success, "Failed to approve Treasury.");
        success = SGX.transfer(Treasury, amount - swapAmount);
        require(success, "Failed to transfer SGX to Treasury.");

        return true;
    }

    /// @notice Deposits `amount` of SGX in the vault.
    /// @param amount uint256, amount that will be deposited in the vault.
    function depositInVault(uint256 amount) external nonReentrant {
        Vault memory userVault = UsersVault[msg.sender];
        
        require(userVault.exists, "You don't have a vault.");

        uint256 amountBoosted = amount * NetworkBoost;

        uint256 totalBalance = userVault.balance + amountBoosted;

        VaultLeague tempLeague = getVaultLeague(totalBalance);
        uint256 timeElapsed;
        uint256 rewardsPercent;
        uint256 interest = 0;

        // Make the check if interest rate length is still the same.
        if (PastInterestRates.length != userVault.interestLength) {
            (interest, 
             userVault.interestLength, 
             userVault.lastClaimTime) = getPastInterestRates(userVault.interestLength, userVault.lastClaimTime, userVault.balance);
        }

        timeElapsed = block.timestamp - userVault.lastClaimTime;

        rewardsPercent = (timeElapsed).mulDiv(InterestRate, baseTime);

        interest += (userVault.balance).mulDiv(rewardsPercent, scale);


        // Update user's vault info
        userVault.lastClaimTime = block.timestamp;
        userVault.pendingRewards += interest;
        userVault.balance = totalBalance;
        userVault.league = tempLeague;

        UsersVault[msg.sender] = userVault;

        emit SuccessfullyDeposited(msg.sender, amountBoosted); 

        // User needs to approve this contract to spend `token`.
        bool success = SGX.transferFrom(msg.sender, address(this), amount);
        require(success, "Failed to transfer SGX to vault.");

        uint256 swapAmount = 0;

        if (allowTreasurySwap) {
            // Swaps 16% of the amount deposit to AVAX.
            swapAmount = amount.mulDiv(16e16, scale);
            swapSGXforAVAX(swapAmount);
        }

        success = SGX.approve(Treasury, amount - swapAmount);
        require(success, "Failed to approve Treasury.");
        success = SGX.transfer(Treasury, amount - swapAmount);
        require(success, "Failed to transfer SGX to Treasury.");
    }

    /// @notice Deletes user's vault.
    /// @param user address, the user we are deliting the vault.
    function liquidateVault(address user) external nonReentrant {
        require(msg.sender == user, "You can only liquidate your own vault.");
        require(UsersVault[user].exists, "You don't have a vault.");

        // 1. Claim all available rewards.
        uint256 timeElapsed = block.timestamp - UsersVault[user].lastClaimTime;

        uint256 rewardsPercent = (timeElapsed).mulDiv(InterestRate, baseTime);

        uint256 claimableRewards = (UsersVault[user].balance).mulDiv(rewardsPercent, scale) + UsersVault[user].pendingRewards;

        // Calculate liquidateVaultPercent of user's vault balance.
        uint256 sgxPercent = (UsersVault[user].balance).mulDiv(LiquidateVaultPercent, scale);

        // Delete user vault.
        delete UsersVault[user];

        ProtocolDebt += sgxPercent;
        TotalNetworkVaults -= 1;

        emit VaultLiquidated(user);

        distributeRewards(claimableRewards,  user);

        SGX.mint(user, sgxPercent);
    }

    /// @notice Calculates the total interest generated based
    ///         on past interest rates.
    /// @param _userInterestLength uint256, the last interest length updated in users vault.
    /// @param _userLastClaimTime uint256,  the last time user claimed his rewards.
    /// @param _userBalance uint256,        user balance in the vault.
    /// @return interest uint256,           the total interest accumalted.
    /// @return interestLength uint256,     the updated version of users interest length.
    /// @return lastClaimTime uint256,      the updated version of users last claim time.
    function getPastInterestRates(
        uint256 _userInterestLength, 
        uint256 _userLastClaimTime,
        uint256 _userBalance
        ) internal view returns(uint256 interest, uint256 interestLength, uint256 lastClaimTime) {
        
        interestLength = _userInterestLength;
        lastClaimTime = _userLastClaimTime;
        uint256 timeElapsed;
        uint256 rewardsPercent;

        for (uint i = interestLength; i < PastInterestRates.length; i++) {
            
            timeElapsed = TimeWhenChanged[i] - lastClaimTime;
            rewardsPercent = (timeElapsed).mulDiv(PastInterestRates[i], baseTime);
            
            interest += (_userBalance).mulDiv(rewardsPercent, scale);
            
            lastClaimTime = TimeWhenChanged[i];
            interestLength += 1;
        }
    }

    /// @notice Gets the league user is part of depending on the balance in his vault.
    /// @param balance uint256, the balance in user's vault.
    /// @return tempLeague VaultLeague, the league user is part of.
    function getVaultLeague(uint256 balance) internal pure returns(VaultLeague tempLeague) {
        if (balance <= 2_000e18) {
            tempLeague = VaultLeague.league0;
        } else if (balance >= 2_001e18 &&  balance <= 5_000e18) {
            tempLeague = VaultLeague.league1;
        } else if (balance >= 5_001e18 &&  balance <= 20_000e18) {
            tempLeague = VaultLeague.league2;
        } else if (balance >= 20_001e18 &&  balance <= 100_000e18) {
            tempLeague = VaultLeague.league3;
        } else {
            tempLeague = VaultLeague.league4;
        }
    }

    /// @notice swaps SGX for AVAX on traderJoe. The Subgenix Network will use the SGX
    ///         in the treasury to make investments in subnets, and at a certain point the
    ///         team would have to sell its SGX tokens to make the investments. To avoid
    ///         big dumps in the price of the token we decided to make a partial sell of the
    ///         SGX everytime some SGX goes to the treasury, this will help the team have
    ///         AVAX ready to make the investments and will save the community from seeing
    ///         massive dumps in the price of the token.
    /// @param swapAmount uint256, the amount of SGX we are making the swap.
    function swapSGXforAVAX(uint256 swapAmount) private onlyOwner {

        address[] memory path;
        path = new address[](2);
        path[0] = address(SGX);
        path[1] = WAVAX;

        uint256 toTreasury = swapAmount.mulDiv(75e16, scale);
        uint256 toResearch = swapAmount - toTreasury;

        bool success = SGX.approve(address(joeRouter), swapAmount);
        require(success, "Failed to approve joeRouter.");
        
        joeRouter.swapExactTokensForAVAX(toTreasury, 0, path, Treasury, block.timestamp);
        joeRouter.swapExactTokensForAVAX(toResearch, 0, path, Research, block.timestamp);
    }

    // <--------------------------------------------------------> //
    // <---------------- REWARDS  CONFIGURATION ----------------> //
    // <--------------------------------------------------------> // 

    /// @notice Emmited when the reward percentage is updated.
    /// @param reward uint256, the new reward percentage.
    event InterestRateUpdated(uint256 reward);

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

    uint256[] PastInterestRates; // Past interest rates.
    uint256[] TimeWhenChanged;   // Last time the interest rate was valid.

    /// @notice the level of reward granularity, WAD
    uint256 public constant scale = 1e18;

    /// @notice Base time used to calculate rewards.
    uint32 public constant baseTime = 365 days;

    /// @notice Updates the reward percentage distributed per `baseTime`
    /// @param _reward uint256, the new reward percentage.
    function setInterestRate(uint256 _reward) external onlyOwner {

        if (InterestRate != 0) {
            PastInterestRates.push(InterestRate);
            TimeWhenChanged.push(block.timestamp);
        }
        InterestRate = _reward;

        emit InterestRateUpdated(_reward);
    }

    // <--------------------------------------------------------> //
    // <---------------- REWARDS  FUNCTIONALITY ----------------> //
    // <--------------------------------------------------------> // 

    /// @notice Claims the available rewards from user's vault.
    /// @param user address, who we are claiming rewards of.
    function claimRewards(address user) public nonReentrant {
        Vault memory userVault = UsersVault[user];

        require(msg.sender == user, "You can only claim your own rewards.");
        require(userVault.exists, "You don't have a vault.");
        require((block.timestamp - userVault.lastClaimTime) >= rewardsWaitTime, "To early to claim rewards.");

        uint256 timeElapsed;
        uint256 rewardsPercent;
        uint256 claimableRewards = 0;

        // Make the check if interest rate length is still the same.
        if (PastInterestRates.length != userVault.interestLength) {
            (claimableRewards, 
             userVault.interestLength, 
             userVault.lastClaimTime) = getPastInterestRates(userVault.interestLength, userVault.lastClaimTime, userVault.balance);
        }

        timeElapsed = block.timestamp - userVault.lastClaimTime;

        rewardsPercent = timeElapsed.mulDiv(InterestRate, baseTime);

        claimableRewards += userVault.balance.mulDiv(rewardsPercent, scale) + userVault.pendingRewards;

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

        // Convert to gSGX and send to user.
        bool success = SGX.approve(address(gSGX), gSGXPercent);
        require(success, "Failed to approve gSGX contract to spend SGX.");
        gSGX.deposit(user, gSGXPercent);

        // send to gSGX Contracts
        success = SGX.transfer(address(gSGX), gSGXToContract);
        require(success, "Failed to send SGX to gSGX contract.");

        // TODO Change this.

        success = SGX.transfer(user, claimableRewards); // Transfer token to users.
        require(success, "Failed to send SGX to user.");
        
        ILockupHell(Lockup).lockupRewards(user, shortLockup, longLockup); // Lockup tokens
    }

    /// @notice Calculate the final value of the percentage based on the rewards amount.
    ///         eg. If rewards = 100 then 10% of it = 10.
    /// @param rewards uint256, the amount all the percentages are being calculated on top off.
    /// @return burnAmount uint256,     the amount being burned.
    /// @return shortLockup uint256,    the amount being locked for a shorter period of time.
    /// @return longLockup uint256,     the amount being locked for a longer period of time.
    /// @return gSGXPercent uint256,    the amount being converted to gSGX.
    /// @return gSGXToContract uint256, the amount being sent to the gSGX contract.
    function calculateDistribution(uint256 rewards) internal view returns (
    uint256 burnAmount, 
    uint256 shortLockup, 
    uint256 longLockup,
    uint256 gSGXPercent,
    uint256 gSGXToContract
    ) {

        burnAmount = rewards.mulDiv(BurnPercent, scale);
        shortLockup = rewards.mulDiv(ILockupHell(Lockup).getShortPercentage(), scale);
        longLockup = rewards.mulDiv(ILockupHell(Lockup).getLongPercentage(), scale);
        gSGXPercent = rewards.mulDiv(GSGXPercent, scale);
        gSGXToContract = rewards.mulDiv(GSGXDistributed, scale);
    } 


    /// @notice Checks how much reward the User can get if he claim rewards.
    /// @param user address, who we are checking the pending rewards.
    /// @return pendingRewards uint256, rewards that user can claim at any time.
    /// @return shortLockup uint256, the rewards being locked for a shorter period of time.
    /// @return longLockup uint256, the rewards being locked for a longer period of time.
    function viewPendingRewards(address user) external view returns(uint256, uint256, uint256) {
        require(UsersVault[user].exists, "You don't have a vault.");

        uint256 interestLength = UsersVault[user].interestLength;

        uint256 balance = UsersVault[user].balance;

        uint256 timeElapsed;

        uint256 rewardsPercent;

        uint256 pendingRewards = 0;

        uint256 lastClaimTime = UsersVault[user].lastClaimTime;

        // Make the check if interest rate length is still the same.
        if (PastInterestRates.length != interestLength) {
            (pendingRewards, 
              , 
             lastClaimTime) = getPastInterestRates(interestLength, lastClaimTime, balance);
        }

        timeElapsed = block.timestamp - lastClaimTime;

        rewardsPercent = timeElapsed.mulDiv(InterestRate, baseTime);

        pendingRewards += balance.mulDiv(rewardsPercent, scale) + UsersVault[user].pendingRewards;

        (uint256 burnAmount,
         uint256 shortLockup,
         uint256 longLockup,
         uint256 gSGXPercent,
         uint256 gSGXToContract) = calculateDistribution(pendingRewards);

        // Amount burned.
        pendingRewards -= burnAmount;

        // Amount converted to gSGX and sent to user.
        pendingRewards -= gSGXPercent; 

        // Amount sent to gSGX contract.
        pendingRewards -= gSGXToContract;

        pendingRewards -= shortLockup;

        pendingRewards -= longLockup;

        return (pendingRewards, shortLockup, longLockup);
    }

    // <--------------------------------------------------------> //
    // <---------------- PROTOCOL FUNCTIONALITY ----------------> //
    // <--------------------------------------------------------> // 

    /// @notice Total vaults created.
    uint256 public TotalNetworkVaults;
    
    /// @notice Total protocol debt from vaults liquidated.
    uint256 public ProtocolDebt;

    /// @notice Emitted when protocol debt is repaid.
    /// @param amount uint256, amount of debt that was repaid.
    event DebtReaid(uint256 amount);

    /// @notice Repay the debt created by liquidated vauts.
    /// @param amount uint256, the amount of debt being repaid.
    function repayDebt(uint256 amount) external onlyOwner {
        require(amount <= ProtocolDebt, "Amount too big.");

        ProtocolDebt -= amount;

        emit DebtReaid(amount);

        // Treasury needs to give permission to this contract.
        SGX.burn(address(this), amount);
    }

    // <--------------------------------------------------------> //
    // <------------------ VIEW FUNCTIONALITY ------------------> //
    // <--------------------------------------------------------> // 

    /// @notice Get user's vault info.
    /// @param user address, user we are checking the vault.
    /// @param lastClaimTime uint256,  last time user claimed rewards.
    /// @param pendingRewards uint256, rewards user didn't collected yet.
    /// @param balance uint256,        user's vault balance.
    /// @param league VaultLeague,     league user's vault is part of.
    function getVaultInfo(address user) external view returns(
        uint256 lastClaimTime, 
        uint256 pendingRewards, 
        uint256 balance, 
        VaultLeague league
        ) {
        require(UsersVault[user].exists, "Vault doens't exist.");

        lastClaimTime  = UsersVault[user].lastClaimTime;
        pendingRewards = UsersVault[user].pendingRewards;
        balance        = UsersVault[user].balance;
        league         = UsersVault[user].league;
    }

    /// @notice Gets the balance in user's vault.
    /// @param user address, the user we are checking the balance of.
    /// @return The balance of the user.
    function getUserBalance(address user) external view returns (uint256) {
        return UsersVault[user].balance;
    }

    /// @notice Gets the league user's vault is part of.
    /// @param user address, the user we are checking the league of.
    /// @return The user's vault league.
    function getUserLeague(address user) external view returns (VaultLeague) {
        return UsersVault[user].league;
    }

    /// @notice Check if vault exists.
    /// @param user address, User we are checking the vault.
    /// @return True if vault exists, false otherwise.
    function vaultExists(address user) external view returns(bool) {
        return UsersVault[user].exists;
    }

    /// @notice Checks if user can claim rewards or not.
    /// @param user address, the user we are checking if he can claim rewards or not.
    /// @return True if user can claim rewards, false otherwise.
    function canClaimRewards(address user) external view returns(bool) {
        require(UsersVault[user].exists, "Vault doens't exist.");

        uint256 lastClaimTime = UsersVault[user].lastClaimTime;

        if ((block.timestamp - lastClaimTime) >= rewardsWaitTime) { return true; }

        return false;
    }

    /// @notice Gets the percentage of SGX being hold in the gSGX contract.
    /// @return The percentage of SGX being hold in the gSGX contract.
    function getGSGXDominance() external view returns (uint256) {
        require(SGX.totalSupply() > 0, "not enough SGX.");

        return SGX.balanceOf(address(gSGX)).mulDiv(scale, SGX.totalSupply());
    }
}