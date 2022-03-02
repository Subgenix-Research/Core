// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract ERC20User {
    ERC20 token;

    constructor(ERC20 _token) {
        token = _token;
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        return token.approve(spender, amount);
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        return token.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        return token.transferFrom(from, to, amount);
    }

}
