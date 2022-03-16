// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

interface ILockupHell {
    
    function lockupRewards(
        address user, 
        uint256 shortLockupRewards, 
        uint256 longLockupRewards
    ) external;

    function claimShortLokcup(address user, uint32 index) external;

    function claimLongLockup(address user, uint32 index) external;

    function getShortLockupTime() external view returns(uint32);

    function getLongLockupTime() external view returns(uint32);

    function getShortPercentage() external view returns(uint256);
 
    function getLongPercentage() external view returns(uint256);
}