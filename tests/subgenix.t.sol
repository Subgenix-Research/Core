// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Subgenix} from "../contracts/Subgenix.sol";
import {ERC20User} from "./utils/users/ERC20User.sol";

contract SubgenixTest is DSTestPlus {
    Subgenix token;

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    
    function setUp() public {
        token = new Subgenix("Subgenix Currency", "SGX", 18);
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
        token.mint(address(0xBEEF), 1e18);

        assertEq(token.totalSupply(), 1e18);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testBurn() public {
        token.mint(address(0xBEEF), 1e18);
        
        hevm.prank(address(0xBEEF));
        token.burn(0.9e18);

        assertEq(token.totalSupply(), 1e18 - 0.9e18);
        assertEq(token.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testApprove() public {
        assertTrue(token.approve(address(0xBEEF), 1e18));

        assertEq(token.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testTransfer() public {
        token.mint(address(this), 1e18);

        assertTrue(token.transfer(address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFrom() public {
        ERC20User from = new ERC20User(token);

        token.mint(address(from), 1e18);

        from.approve(address(this), 1e18);

        assertTrue(token.transferFrom(address(from), address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.allowance(address(from), address(this)), 0);

        assertEq(token.balanceOf(address(from)), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testInfiniteApproveTransferFrom() public {
        ERC20User from = new ERC20User(token);

        token.mint(address(from), 1e18);

        from.approve(address(this), type(uint256).max);

        assertTrue(token.transferFrom(address(from), address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), 1e18);

        assertEq(token.allowance(address(from), address(this)), type(uint256).max);

        assertEq(token.balanceOf(address(from)), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(token.PERMIT_TYPEHASH(), owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(token.allowance(owner, address(0xCAFE)), 1e18);
        assertEq(token.nonces(owner), 1);
    }

    function testSetManager() public {
        ERC20User owner = new ERC20User(token);

        token.setManager(address(owner), true);

        assertTrue(token.managers(address(owner)));
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

    function testApprove(address to, uint256 amount) public {
        assertTrue(token.approve(to, amount));

        assertEq(token.allowance(address(this), to), amount);
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

    function testPermit(
        uint248 privKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        uint256 privateKey = privKey;
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline, v, r, s);

        assertEq(token.allowance(owner, to), amount);
        assertEq(token.nonces(owner), 1);
    }

    function testSetManager(address owner) public {

        token.setManager(address(owner), true);

        assertTrue(token.managers(address(owner)));
    }

    /*///////////////////////////////////////////////////////////////
                              TEST-FAIL
    //////////////////////////////////////////////////////////////*/

    function testFailTransferInsufficientBalance() public {
        token.mint(address(this), 0.9e18);
        token.transfer(address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientAllowance() public {
        ERC20User from = new ERC20User(token);

        token.mint(address(from), 1e18);
        from.approve(address(this), 0.9e18);
        token.transferFrom(address(from), address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientBalance() public {
        ERC20User from = new ERC20User(token);

        token.mint(address(from), 0.9e18);
        from.approve(address(this), 1e18);
        token.transferFrom(address(from), address(0xBEEF), 1e18);
    }


    function testFailSetManagerNotOwner() public {
        ERC20User user = new ERC20User(token);

        hevm.prank(address(user));
        token.setManager(address(user), true);
    }

    function testFailPermitBadNonce() public {
        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 1, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testFailPermitBadDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp + 1, v, r, s);
    }

    function testFailPermitPastDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp - 1))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp - 1, v, r, s);
    }

    function testFailPermitReplay() public {
        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        token.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

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

    function testFailPermitBadNonce(
        uint256 privateKey,
        address to,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) public {
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;
        if (nonce == 0) nonce = 1;

        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, nonce, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline, v, r, s);
    }

    function testFailPermitBadDeadline(
        uint256 privateKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline + 1, v, r, s);
    }

    function testFailPermitPastDeadline(
        uint256 privateKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        deadline = bound(deadline, 0, block.timestamp - 1);
        if (privateKey == 0) privateKey = 1;

        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline, v, r, s);
    }

    function testFailPermitReplay(
        uint256 privateKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = hevm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        token.permit(owner, to, amount, deadline, v, r, s);
        token.permit(owner, to, amount, deadline, v, r, s);
    }

    function testFailSetManagerNotOwner(address user) public {

        hevm.prank(user);
        token.setManager(user, true);
    }

}