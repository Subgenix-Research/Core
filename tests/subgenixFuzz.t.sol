// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../contracts/Subgenix.sol";
import {ERC20User} from "@rari-capital/solmate/src/test/utils/users/ERC20User.sol";


contract SubgenixTest is DSTestPlus {
    Subgenix internal token;
    
    function setUp() public {
        token = new Subgenix("Subgenix Currency", "SGX", 18);
    }
    
    /*///////////////////////////////////////////////////////////////
                              FUZZ-TESTING
    //////////////////////////////////////////////////////////////*/

    function testMetaData(
        string calldata name,
        string calldata symbol,
        uint8 decimals
    ) public {
        Subgenix tokenMeta = new Subgenix(name, symbol, decimals);
        assertEq(tokenMeta.name(), name);
        assertEq(tokenMeta.symbol(), symbol);
        assertEq(tokenMeta.decimals(), decimals);
    }
    
    function testMint(address from, uint256 amount) public {
        token.mint(from, amount);

        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(from), amount);
    }

    function testBurn(
        address from,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        burnAmount = bound(burnAmount, 0, mintAmount);

        token.mint(from, mintAmount);

        hevm.prank(from);
        token.burn(burnAmount);

        assertEq(token.totalSupply(), mintAmount - burnAmount);
        assertEq(token.balanceOf(from), mintAmount - burnAmount);
    }

    function testTransfer(address from, uint256 amount) public {
        token.mint(address(this), amount);

        assertTrue(token.transfer(from, amount));
        assertEq(token.totalSupply(), amount);

        if (address(this) == from) {
            assertEq(token.balanceOf(address(this)), amount);
        } else {
            assertEq(token.balanceOf(address(this)), 0);
            assertEq(token.balanceOf(from), amount);
        }
    }

    function testTransferFrom(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        amount = bound(amount, 0, approval);

        ERC20User from = new ERC20User(token);

        token.mint(address(from), amount);

        from.approve(address(this), approval);

        assertTrue(token.transferFrom(address(from), to, amount));
        assertEq(token.totalSupply(), amount);

        uint256 app = address(from) == address(this) || approval == type(uint256).max ? approval : approval - amount;
        assertEq(token.allowance(address(from), address(this)), app);

        if (address(from) == to) {
            assertEq(token.balanceOf(address(from)), amount);
        } else {
            assertEq(token.balanceOf(address(from)), 0);
            assertEq(token.balanceOf(to), amount);
        }
    }

    function testSetManager(address owner) public {

        token.setManager(address(owner), true);

        assertTrue(token.managers(address(owner)));
    }

    /*///////////////////////////////////////////////////////////////
                              TEST-FAIL
    //////////////////////////////////////////////////////////////*/

    function testFailBurnInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

        token.mint(to, mintAmount);

        hevm.prank(to);
        token.burn(burnAmount);
    }

    function testFailTransferInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        token.mint(address(this), mintAmount);
        token.transfer(to, sendAmount);
    }

    function testFailTransferFromInsufficientAllowance(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        amount = bound(amount, approval + 1, type(uint256).max);

        ERC20User from = new ERC20User(token);

        token.mint(address(from), amount);
        from.approve(address(this), approval);
        token.transferFrom(address(from), to, amount);
    }

    function testFailTransferFromInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        ERC20User from = new ERC20User(token);

        token.mint(address(from), mintAmount);
        from.approve(address(this), sendAmount);
        token.transferFrom(address(from), to, sendAmount);
    }

    function testFailSetManagerNotOwner(address user) public {
        hevm.assume(user != token.owner());

        hevm.prank(user);
        token.setManager(user, true);
    }

    function testFailTransferWhenPaused(address user, address to) public {
        token.pauseContract(true);

        hevm.assume(user != token.owner());
        
        token.mint(address(user), 1e18);

        hevm.prank(address(user));
        token.transfer(to, 1e18);
    }

    function testFailTransferFromWhenPaused(address from, address to) public {
        token.pauseContract(true);

        hevm.assume(from != token.owner());

        token.mint(from, 1e18);

        hevm.startPrank(from);
        token.approve(address(this), 1e18);
        token.transferFrom(from, to, 1e18);

        hevm.stopPrank();
    }

}
