// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Subgenix Token.
/// @author Subgenix Research.
/// @notice This is the offical token of the Subgenix network.
/// @dev optimized implementation of the ERC20 token standard from solmate.
contract Subgenix is ERC20, Ownable {

    /// @notice Emitted only when a manager is added or removed from the `managers` mapping.
    /// @param user address, Contract/User to be added/removed from the managers mapping.
    /// @param value bool, true to add permission, false to remove permission.
    event managerSet(address indexed user, bool value);

    /// @notice Mapping of allowed address.
    mapping(address => bool) public managers;

    modifier onlyManagers() {
        require(managers[msg.sender] == true, "Not manager.");
        _;
    }
    
    // <--------------------------------------------------------> //
    // <---------------------- CONSTRUCTOR ---------------------> //
    // <--------------------------------------------------------> // 

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) {
        managers[msg.sender] = true;
    }

    // <--------------------------------------------------------> //
    // <--------------------- ERC20  LOGIC ---------------------> //
    // <--------------------------------------------------------> // 

    /// @notice Implementation of the mint function from the ERC20.
    /// @dev See {ERC20 _mint}. Only managers can call it.
    function mint(address to, uint256 value) external onlyManagers {
        _mint(to, value);
    }
    
    /// @notice Implementation of the burn function from the ERC20.
    /// @dev See {ERC20 _burn}.
    function burn(address from, uint256 value) external {
        _burn(from, value); 
    }

    // <--------------------------------------------------------> //
    // <------------------- ONLY OWNER LOGIC -------------------> //
    // <--------------------------------------------------------> // 

    /// @notice Add/remove an address from having access to functions with 
    ///         the `onlyManagers` modifier.
    /// @param user address, Contract/User to be added/removed from the managers mapping.
    /// @param value bool, true to add permission, false to remove permission.
    function setManager(address user, bool value) external onlyOwner {
        managers[user] = value;

        emit managerSet(user, value);
    }
}
