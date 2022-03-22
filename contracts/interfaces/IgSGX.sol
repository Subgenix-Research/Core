// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >= 0.8.4 < 0.9.0;

interface IgSGX {
    function deposit(address to, uint256 amount) external;

    function withdraw(uint256 share) external;
}