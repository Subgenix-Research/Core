// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 < 0.9.0;

interface IgSGX {
    function deposit(address _to, uint256 _amount) external;

    function withdraw(uint256 _amount) external;
}