// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

interface IVaultFactory {

    function createVault(uint256 amount) external returns(bool);

    function depositInVault(address user, uint256 amount) external;

    function vaultExists(address user) external view returns(bool);

    function getMinVaultDeposit() external view returns (uint256);
}