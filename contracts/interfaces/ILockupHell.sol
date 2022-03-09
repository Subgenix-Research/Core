// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;


interface ILockupHell {
    function lockupRewards(address user, uint256 shortLockup, uint256 longLockup) external;
    function getShortPercentage() external view returns(uint256); 
    function getLongPercentage() external view returns(uint256);
}