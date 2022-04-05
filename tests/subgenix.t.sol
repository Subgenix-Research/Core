// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.4 < 0.9.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../contracts/Subgenix.sol";
import {ERC20User} from "@rari-capital/solmate/src/test/utils/users/ERC20User.sol";


contract SubgenixTest is DSTestPlus {
    Subgenix internal token;
    
    function setUp() public {
        token = new Subgenix("Subgenix Currency", "SGX", 18);
        token.setManager(address(this), true);
    }

    /*///////////////////////////////////////////////////////////////
                              UNIT-TESTS 
    //////////////////////////////////////////////////////////////*/

    function testMetaData() public {
        assertEq(token.name(), "Subgenix Currency");
        assertEq(token.symbol(), "SGX");
        assertEq(token.decimals(), 18);
    }

    function testMint() public {
        hevm.prank(address(this));
        token.mint(address(0xBEEF), 1e18);

        assertEq(token.totalSupply(), 6_000_001e18);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testBurn() public {
        hevm.prank(address(this));
        token.mint(address(0xBEEF), 1e18);

        hevm.prank(address(0xBEEF));
        token.burn(0.9e18);

        assertEq(token.totalSupply(), 6_000_001e18 - 0.9e18);
        assertEq(token.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testBurnFrom() public {
        address from = address(this);

        hevm.prank(from);
        token.mint(address(0xBEEF), 1e18);

        hevm.prank(address(0xBEEF));
        token.approve(from, 1e18);

        hevm.prank(from);
        token.burnFrom(address(0xBEEF), 0.9e18);

        assertEq(token.totalSupply(), 6_000_001e18 - 0.9e18);
        assertEq(token.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testTransfer() public {
        hevm.prank(address(this));
        token.mint(address(this), 1e18);

        assertTrue(token.transfer(address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 6_000_001e18);

        assertEq(token.balanceOf(address(this)), 6_000_000e18);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        hevm.prank(address(this));
        token.mint(from, 1e18);

        hevm.prank(from);
        token.approve(address(this), 1e18);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 6_000_001e18);

        assertEq(token.allowance(from, address(this)), 0);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testSetManager() public {
        address owner = address(0xABCD);

        token.setManager(address(owner), true);

        assertTrue(token.managers(address(owner)));
    }
    
    /*///////////////////////////////////////////////////////////////
                              TEST-FAIL
    //////////////////////////////////////////////////////////////*/

    function testFailTransferInsufficientBalance() public {
        hevm.prank(address(0xABCD));
        token.transfer(address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientAllowance() public {
        ERC20User from = new ERC20User(token);

        hevm.prank(address(this));
        token.mint(address(from), 1e18);
        from.approve(address(this), 0.9e18);
        token.transferFrom(address(from), address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientBalance() public {
        ERC20User from = new ERC20User(token);

        hevm.prank(address(this));
        token.mint(address(from), 0.9e18);
        from.approve(address(this), 1e18);
        token.transferFrom(address(from), address(0xBEEF), 1e18);
    }


    function testFailSetManagerNotOwner() public {
        ERC20User user = new ERC20User(token);

        hevm.prank(address(user));
        token.setManager(address(user), true);
    }


    function testFailTransferWhenPaused() public {
        token.pauseContract(true);

        ERC20User user = new ERC20User(token);
        
        hevm.prank(address(this));
        token.mint(address(user), 1e18);

        hevm.prank(address(user));
        token.transfer(address(0xBEEF), 1e18);
    }

    function testFailTransferFromWhenPaused() public {
        token.pauseContract(true);

        ERC20User from = new ERC20User(token);
        
        hevm.prank(address(this));
        token.mint(address(from), 1e18);

        hevm.startPrank(address(from));
        token.approve(address(this), 1e18);
        token.transferFrom(address(from), address(0xBEEF), 1e18);

        hevm.stopPrank();
    }
}
