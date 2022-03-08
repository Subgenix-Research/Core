// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Governance SGX.
/// @author Subgenix Research.
/// @notice This is the offical governance token of the Subgenix network. 
contract gSGX is ERC20, Ownable {

    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when user deposits their SGX for gSGX.
    /// @param user address, the user we are sending gSGX to.
    /// @param amount uint256, the amount of gSGX we are sending to the user.
    event Deposit(address indexed user, uint256 amount);

    /// @notice Emitted when user withdraw their initial SGX + rewards.
    /// @param user address, the user we are sending SGX to.
    /// @param amount uint256, the amount of SGX we are sending to the user.
    /// @param share uint256, the total gSGX shares that were burned.
    event Withdraw(address indexed user, uint256 amount, uint256 share);

    /// @notice Emitted when the penalty value is updated.
    /// @param newPenalty uint256, the new penalty value.
    event penaltySet(uint256 newPenalty);

    /// @notice Emitted when the withdraw ceil is updated.
    /// @param _ceil uint256, the new withdraw ceil value.
    event withdrawCeilSet(uint256 _ceil);

    /*///////////////////////////////////////////////////////////////
                            GLOBAL VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Subgenix Network offical token.
    IERC20 public immutable SGX;

    /// @notice The penalty for withdrawing early.
    uint256 public penalty;

    /// @notice The withdraw ceiling, manually updated by devs.
    uint256 public withdrawCeil;

    /// @notice The max penalty for withdrawing, 25%.
    uint256 public constant MAX_PENALTY = 2500;

    /// @notice The base multiplier.
    uint256 public constant BASE_VALUE = 10000;

    constructor(
        address _sgx
    ) ERC20("Governance SGX", "gSGX", 18) {
        SGX = IERC20(_sgx);
    }

    /*///////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS 
    ///////////////////////////////////////////////////////////////*/

    /// @notice Locks SGX and mints gSGX.
    /// @param _amount uint256, the amount of SGX that will be locked.
    function deposit(uint256 _amount) external {
        // Gets the amount of SGX locked in the contract
        uint256 totalSGX = sgxBalance();

        // Get the amount of gSGX in existence
        uint256 totalShares = totalSupply;

        // If no gSGX exists, mint it 1:1 to the amonut put in
        if (totalShares == 0 || totalSGX == 0) {
            _mint(msg.sender, _amount);
        } else {
            // Calculate and mint the amount of gSGX the SGX is worth.
            // The ratio will change overtime, as gSGX is burned/minted
            // and SGX deposited + gained from fees / withdrawn.
            uint256 value = (_amount * totalShares) / totalSGX;
            _mint(msg.sender, value);
        }

        // Lock the SGX in the contract
        SGX.transferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _amount);
    }

    /// @notice Unlocks the staked + gained SGX and burns gSGX.
    /// @param _share uint256, the amount of gSGX that will be burned from user.
    function withdraw(uint256 _share) external {

        // Gets the amount of SGX locked in the contract
        uint256 totalSGX = sgxBalance();

        // Get the amount of gSGX in existence
        uint256 totalShares = totalSupply;

        // Calculate the amount of gSGX the SGX is worth.
        uint256 amount = (_share * totalSGX) / totalShares;

        // Check with withdraw ceiling wasn't hit yet.
        require(withdrawCeil >= amount, "Amount hitting withdraw ceil.");

        withdrawCeil -= amount;
        
        // burn gSGX
        _burn(msg.sender, _share);

        uint256 fee = (amount * penalty) / BASE_VALUE;
        uint256 finalAmount = amount - fee;

        // Transfer user's SGX.
        SGX.transfer(msg.sender, finalAmount);

        emit Withdraw(msg.sender, finalAmount, _share);
    }

    /// @notice Change the early withdraw penalty value
    /// @param _penalty uint256, new penalty for early withdraw.
    function setPenalty(uint256 _penalty) external onlyOwner {
        require(_penalty <= MAX_PENALTY, "penalty is too high.");
        penalty = _penalty;
        emit penaltySet(_penalty);
    }

    /// @notice Updates the withdraw ceil value.
    /// @param _ceil uint256, the new withdraw ciel.
    function setWithdrawCeil(uint256 _ceil) external onlyOwner {
        withdrawCeil = _ceil;
        emit withdrawCeilSet(_ceil);
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS 
    ///////////////////////////////////////////////////////////////*/

    /// @notice Get the total amount of SGX locked in this contract.
    /// @return The amount of SGX locked in this contract.
    function sgxBalance() public view returns(uint256) {
        return SGX.balanceOf(address(this));
    }

    function gSGXBalance(address user) external view returns(uint256) {
        return balanceOf[user];
    }

}
