// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {Subgenix} from "../src/Subgenix.sol";

contract SubgenixTest is DSTestPlus {
    Subgenix internal token;
    
    function setUp() public {
        token = new Subgenix("Subgenix Currency", "SGX", 18);
        token.setManager(address(this), true);
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
        hevm.assume(amount != 0);
        hevm.assume(amount < token.balanceOf(address(this)));

        hevm.prank(address(this));
        token.mint(from, amount);

        assertEq(token.totalSupply(), (6_000_000e18 + amount));
        assertEq(token.balanceOf(from), amount);
    }

    function testBurn(
        address from,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        hevm.assume(burnAmount < mintAmount);
        hevm.assume(mintAmount != 0 && burnAmount != 0);
        hevm.assume(mintAmount < token.balanceOf(address(this)));

        hevm.prank(address(this));
        token.mint(from, mintAmount);

        hevm.prank(from);
        token.burn(burnAmount);

        assertEq(token.totalSupply(), (6_000_000e18 + mintAmount) - burnAmount);
        assertEq(token.balanceOf(from), mintAmount - burnAmount);
    }

    function testBurnFrom(address user, uint256 burnAmount) public {
        uint256 initSupply = token.balanceOf(address(this));
        hevm.assume(burnAmount != 0);
        hevm.assume(burnAmount < initSupply);

        hevm.prank(address(this));
        token.approve(user, burnAmount);

        hevm.prank(user);
        token.burnFrom(address(this), burnAmount);

        assertEq(token.totalSupply(), initSupply - burnAmount);
        assertEq(token.balanceOf(address(this)), initSupply - burnAmount);
    }

    function testTransfer(address from, uint256 amount) public {
        hevm.assume(from != address(this));
        hevm.assume(amount != 0);
        hevm.assume(amount < token.balanceOf(address(this)));
        
        hevm.prank(address(this));
        token.mint(address(this), amount);

        assertTrue(token.transfer(from, amount));
        assertEq(token.totalSupply(), (6_000_000e18 + amount));

        assertEq(token.balanceOf(address(this)), 6_000_000e18);
        assertEq(token.balanceOf(from), amount);
    }

    function testTransferFrom(address to, uint256 amount) public {
        uint256 initSupply = token.balanceOf(address(this));
        hevm.assume(amount != 0);
        hevm.assume(amount < initSupply);

        hevm.prank(address(this));
        token.approve(to, amount);

        hevm.prank(to);
        token.transferFrom(address(this), to, amount);

        assertEq(token.balanceOf(address(this)), initSupply - amount);
        assertEq(token.allowance(address(this), to), 0);
        assertEq(token.balanceOf(to), amount);
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
        hevm.assume(burnAmount > mintAmount);

        hevm.prank(address(this));
        token.mint(to, mintAmount);

        hevm.prank(to);
        token.burn(burnAmount);
    }

    function testFailTransferInsufficientBalance(address to, uint256 sendAmount) public {
        hevm.assume(sendAmount > token.balanceOf(address(this)));
        token.transfer(to, sendAmount);
    }

    function testFailTransferFromInsufficientAllowance(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        hevm.assume(amount > approval);

        address from = address(0xABCD);

        hevm.prank(address(this));
        token.mint(from, amount);

        hevm.prank(from);
        token.approve(address(this), approval);

        token.transferFrom(from, to, amount);
    }

    function testFailTransferFromInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        hevm.assume(sendAmount > mintAmount);

        address from = address(0xABCD);

        hevm.prank(address(this));
        token.mint(from, mintAmount);

        hevm.prank(from);
        token.approve(address(this), sendAmount);
    
        token.transferFrom(from, to, sendAmount);
    }

    function testFailSetManagerNotOwner(address user) public {
        hevm.assume(user != address(this));

        hevm.prank(user);
        token.setManager(user, true);
    }

    function testFailTransferWhenPaused(address user, address to) public {
        token.pauseContract(true);

        hevm.assume(user != address(this));
        
        token.mint(address(user), 1e18);

        hevm.prank(address(user));
        token.transfer(to, 1e18);
    }

    function testFailTransferFromWhenPaused(address from, address to) public {
        token.pauseContract(true);

        hevm.assume(from != address(this));

        token.mint(from, 1e18);

        hevm.startPrank(from);
        token.approve(address(this), 1e18);
        token.transferFrom(from, to, 1e18);

        hevm.stopPrank();
    }

}
