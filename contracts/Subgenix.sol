// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >= 0.8.4 < 0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

error Unauthorized();
error Paused();

/// @title Subgenix Token.
/// @author Subgenix Research.
/// @notice This is the offical token of the Subgenix network.
/// @dev optimized implementation of the ERC20 token standard from solmate.
contract Subgenix is ERC20, Ownable {

    /// @notice Emitted only when a manager is added or removed from the `managers` mapping.
    /// @param user address, Contract/User to be added/removed from the managers mapping.
    /// @param value bool, true to add permission, false to remove permission.
    event ManagerSet(address indexed user, bool value);

    event PauseContract(bool action);

    /// @notice Mapping of allowed address.
    mapping(address => bool) public managers;

    /// @notice Indicates if transactions are allowed or not.
    bool public paused;
    
    // <--------------------------------------------------------> //
    // <---------------------- CONSTRUCTOR ---------------------> //
    // <--------------------------------------------------------> // 

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) {

        //managers[msg.sender] = true;
        
        // Mint inital supply
        _mint(msg.sender, 6_000_000e18);
    }

    // <--------------------------------------------------------> //
    // <--------------------- ERC20  LOGIC ---------------------> //
    // <--------------------------------------------------------> // 

    /// @notice Implementation of the mint function from the ERC20.
    /// @dev See {ERC20 _mint}. Only managers can call it.
    function mint(address to, uint256 amount) external {
        if (!managers[msg.sender]) revert Unauthorized();
        _mint(to, amount);
    }
    
    /// @notice Implementation of the burn function from the ERC20.
    /// @dev See {ERC20 _burn}.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Burns `amount` tokens from `from`, deducting from the caller's
    ///         allowance. See {ERC20Burnable}.
    ///         `from` must approve caller to burn at least the `amount`.
    function burnFrom(address from, uint256 amount) external {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _burn(from, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (paused && !managers[msg.sender]) revert Paused();
        
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (paused && !managers[msg.sender]) revert Paused();

        return super.transferFrom(from, to, amount);
    }

    // <--------------------------------------------------------> //
    // <------------------- ONLY OWNER LOGIC -------------------> //
    // <--------------------------------------------------------> // 

    /// @notice Add/remove an address from having access to functions with 
    ///         the `onlyManagers` modifier.
    /// @param user address, Contract/User to be added/removed from the managers mapping.
    /// @param action bool, true to add permission, false to remove permission.
    function setManager(address user, bool action) external onlyOwner {
        managers[user] = action;

        emit ManagerSet(user, action);
    }

    function pauseContract(bool action) external onlyOwner {
        paused = action;
        emit PauseContract(paused);
    }
}
