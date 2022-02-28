// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IJoeRouter02} from "./interfaces/IJoeRouter02.sol";
import {IVaultFactory} from "./interfaces/IVaultFactory.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract Zapper is Ownable {

    address public SGX;
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    
    mapping (address => bool) public allowedReserves;
    
    IJoeRouter02 private joeRouter = IJoeRouter02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
    IVaultFactory public vaultFactory;

    constructor(address _SGX, address _vaultFactory) {
        SGX = _SGX;
        vaultFactory = IVaultFactory(_vaultFactory);

        allowedReserves[0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664] = true; // USDC.e
        allowedReserves[0x130966628846BFd36ff31a822705796e8cb8C18D] = true; // MIM
    }

    function swapAVAXforSGX(
        address _to,
        uint256 _amount
    ) external {
        require(msg.sender == _to, "Not user.");
        require(_amount >= vaultFactory.getMinVaultDeposit(), "Amount is too small.");
        require(IERC20(WAVAX).balanceOf(_to) >= _amount, "Not enough founds.");

        IERC20(WAVAX).transferFrom(_to, address(this), _amount);
        IERC20(WAVAX).approve(address(joeRouter), _amount);

        address[] memory path;
        path = new address[](2);
        path[0] = WAVAX;
        path[1] = SGX;

        joeRouter.swapExactAVAXForTokens{value: _amount}(0, path, _to, block.timestamp);

        require(IERC20(SGX).balanceOf(_to) >= _amount, "Error comunicating with router.");

        if(vaultFactory.vaultExists(_to)) {
            // Vault exists
            vaultFactory.depositInVault(_to, _amount);
        } else {
            // Vault doesn't exists.
            vaultFactory.createVault(_amount);
        }

        // Check if deposit/creation was done correctly.
    }

    function swapTokenforSGX(
        address _token,
        address _to,
        uint256 _amount
    ) external {
        require(msg.sender == _to, "Not user.");
        require(_amount >= vaultFactory.getMinVaultDeposit(), "Amount is too small.");
        require(allowedReserves[_token], "Token not allowed");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        IERC20(_token).approve(address(joeRouter), _amount);

        address[] memory path;
        path = new address[](3);
        path[0] = _token;
        path[1] = WAVAX;
        path[2] = SGX;

        joeRouter.swapExactAVAXForTokens{value: _amount}(0, path, _to, block.timestamp);

        require(IERC20(SGX).balanceOf(_to) >= _amount, "Error comunicating with router.");

        if(vaultFactory.vaultExists(_to)) {
            // Vault exists
            vaultFactory.depositInVault(_to, _amount);
        } else {
            // Vault doesn't exists.
            vaultFactory.createVault(_amount);
        }

        // Check if deposit/creation was done correctly.
    }

    function setReserve(address _token, bool value) external onlyOwner {
        allowedReserves[_token] = value;
    }

    /*///////////////////////////////////////////////////////////////
                          RECIEVE ETHER LOGIC
    //////////////////////////////////////////////////////////////*/
    
    /// @dev Required for the Zapper to receive unwrapped AVAX.
    receive() external payable {}

}
