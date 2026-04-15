// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {kUSD} from "../src/kUSD.sol";

/// @dev A minimal ERC-20 token used to test the rescueERC20 function.
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1_000_000e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract kUSDTest is Test {
    kUSD public token;

    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");
    address public blacklister = makeAddr("blacklister");
    address public masterMinter = makeAddr("masterMinter");
    address public minter = makeAddr("minter");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        token = new kUSD(owner, pauser, blacklister, masterMinter);
    }

    // ═══════════════════════════════════════════════
    //  Deployment & metadata
    // ═══════════════════════════════════════════════

    function test_metadata() public view {
        assertEq(token.name(), "kUSD");
        assertEq(token.symbol(), "kUSD");
        assertEq(token.decimals(), 6);
        assertEq(token.totalSupply(), 0);
    }

    function test_initialRoles() public view {
        assertEq(token.owner(), owner);
        assertEq(token.pauser(), pauser);
        assertEq(token.blacklister(), blacklister);
        assertEq(token.masterMinter(), masterMinter);
    }

    function test_constructor_revertsOnZeroAddress() public {
        vm.expectRevert(kUSD.ZeroAddress.selector);
        new kUSD(address(0), pauser, blacklister, masterMinter);

        vm.expectRevert(kUSD.ZeroAddress.selector);
        new kUSD(owner, address(0), blacklister, masterMinter);

        vm.expectRevert(kUSD.ZeroAddress.selector);
        new kUSD(owner, pauser, address(0), masterMinter);

        vm.expectRevert(kUSD.ZeroAddress.selector);
        new kUSD(owner, pauser, blacklister, address(0));
    }

    // ═══════════════════════════════════════════════
    //  Minting
    // ═══════════════════════════════════════════════

    function _configureMinter(address _minter, uint256 allowance) internal {
        vm.prank(masterMinter);
        token.configureMinter(_minter, allowance);
    }

    function test_configureMinter() public {
        _configureMinter(minter, 1_000e6);
        assertTrue(token.isMinter(minter));
        assertEq(token.minterAllowance(minter), 1_000e6);
    }

    function test_configureMinter_onlyMasterMinter() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotMinter.selector);
        token.configureMinter(minter, 1_000e6);
    }

    function test_configureMinter_revertsZeroAddress() public {
        vm.prank(masterMinter);
        vm.expectRevert(kUSD.ZeroAddress.selector);
        token.configureMinter(address(0), 1_000e6);
    }

    function test_mint() public {
        _configureMinter(minter, 1_000e6);

        vm.prank(minter);
        token.mint(alice, 500e6);

        assertEq(token.balanceOf(alice), 500e6);
        assertEq(token.totalSupply(), 500e6);
        assertEq(token.minterAllowance(minter), 500e6);
    }

    function test_mint_revertsWhenNotMinter() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotMinter.selector);
        token.mint(bob, 100e6);
    }

    function test_mint_revertsZeroAmount() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(minter);
        vm.expectRevert(kUSD.ZeroAmount.selector);
        token.mint(alice, 0);
    }

    function test_mint_revertsZeroAddress() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(minter);
        vm.expectRevert(kUSD.ZeroAddress.selector);
        token.mint(address(0), 100e6);
    }

    function test_mint_revertsExceedsAllowance() public {
        _configureMinter(minter, 100e6);
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(kUSD.MintAllowanceExceeded.selector, 200e6, 100e6));
        token.mint(alice, 200e6);
    }

    function test_mint_revertsWhenPaused() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(pauser);
        token.pause();

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.mint(alice, 100e6);
    }

    function test_mint_revertsWhenMinterBlacklisted() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(blacklister);
        token.blacklist(minter);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(kUSD.Blacklisted.selector, minter));
        token.mint(alice, 100e6);
    }

    function test_mint_revertsWhenRecipientBlacklisted() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(blacklister);
        token.blacklist(alice);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(kUSD.Blacklisted.selector, alice));
        token.mint(alice, 100e6);
    }

    // ═══════════════════════════════════════════════
    //  Burning
    // ═══════════════════════════════════════════════

    function test_burn() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(minter);
        token.mint(minter, 500e6);

        vm.prank(minter);
        token.burn(200e6);

        assertEq(token.balanceOf(minter), 300e6);
        assertEq(token.totalSupply(), 300e6);
    }

    function test_burn_revertsNotMinter() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotMinter.selector);
        token.burn(100e6);
    }

    function test_burn_revertsZeroAmount() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(minter);
        vm.expectRevert(kUSD.ZeroAmount.selector);
        token.burn(0);
    }

    function test_burn_revertsExceedsBalance() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(minter);
        token.mint(minter, 100e6);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(kUSD.BurnAmountExceedsBalance.selector, 200e6, 100e6));
        token.burn(200e6);
    }

    function test_burn_revertsWhenPaused() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(minter);
        token.mint(minter, 500e6);

        vm.prank(pauser);
        token.pause();

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.burn(100e6);
    }

    function test_burn_revertsWhenBlacklisted() public {
        _configureMinter(minter, 1_000e6);
        vm.prank(minter);
        token.mint(minter, 500e6);

        vm.prank(blacklister);
        token.blacklist(minter);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(kUSD.Blacklisted.selector, minter));
        token.burn(100e6);
    }

    // ═══════════════════════════════════════════════
    //  Remove minter
    // ═══════════════════════════════════════════════

    function test_removeMinter() public {
        _configureMinter(minter, 1_000e6);
        assertTrue(token.isMinter(minter));

        vm.prank(masterMinter);
        token.removeMinter(minter);

        assertFalse(token.isMinter(minter));
        assertEq(token.minterAllowance(minter), 0);
    }

    function test_removeMinter_onlyMasterMinter() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotMinter.selector);
        token.removeMinter(minter);
    }

    // ═══════════════════════════════════════════════
    //  Transfers
    // ═══════════════════════════════════════════════

    function _mintTo(address to, uint256 amount) internal {
        _configureMinter(minter, amount);
        vm.prank(minter);
        token.mint(to, amount);
    }

    function test_transfer() public {
        _mintTo(alice, 1_000e6);

        vm.prank(alice);
        token.transfer(bob, 300e6);

        assertEq(token.balanceOf(alice), 700e6);
        assertEq(token.balanceOf(bob), 300e6);
    }

    function test_transferFrom() public {
        _mintTo(alice, 1_000e6);

        vm.prank(alice);
        token.approve(charlie, 500e6);

        vm.prank(charlie);
        token.transferFrom(alice, bob, 300e6);

        assertEq(token.balanceOf(alice), 700e6);
        assertEq(token.balanceOf(bob), 300e6);
    }

    function test_transfer_revertsWhenPaused() public {
        _mintTo(alice, 1_000e6);

        vm.prank(pauser);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.transfer(bob, 100e6);
    }

    function test_transfer_revertsWhenSenderBlacklisted() public {
        _mintTo(alice, 1_000e6);

        vm.prank(blacklister);
        token.blacklist(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(kUSD.Blacklisted.selector, alice));
        token.transfer(bob, 100e6);
    }

    function test_transfer_revertsWhenRecipientBlacklisted() public {
        _mintTo(alice, 1_000e6);

        vm.prank(blacklister);
        token.blacklist(bob);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(kUSD.Blacklisted.selector, bob));
        token.transfer(bob, 100e6);
    }

    function test_transferFrom_revertsWhenSpenderBlacklisted() public {
        _mintTo(alice, 1_000e6);

        vm.prank(alice);
        token.approve(charlie, 500e6);

        vm.prank(blacklister);
        token.blacklist(charlie);

        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(kUSD.Blacklisted.selector, charlie));
        token.transferFrom(alice, bob, 100e6);
    }

    // ═══════════════════════════════════════════════
    //  Approve
    // ═══════════════════════════════════════════════

    function test_approve_revertsWhenPaused() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.approve(bob, 100e6);
    }

    function test_approve_revertsWhenOwnerBlacklisted() public {
        vm.prank(blacklister);
        token.blacklist(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(kUSD.Blacklisted.selector, alice));
        token.approve(bob, 100e6);
    }

    function test_approve_revertsWhenSpenderBlacklisted() public {
        vm.prank(blacklister);
        token.blacklist(bob);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(kUSD.Blacklisted.selector, bob));
        token.approve(bob, 100e6);
    }

    // ═══════════════════════════════════════════════
    //  Pause / Unpause
    // ═══════════════════════════════════════════════

    function test_pause_unpause() public {
        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused());

        vm.prank(pauser);
        token.unpause();
        assertFalse(token.paused());
    }

    function test_pause_onlyPauser() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotPauser.selector);
        token.pause();
    }

    function test_unpause_onlyPauser() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(kUSD.NotPauser.selector);
        token.unpause();
    }

    function test_configureMinter_revertsWhenPaused() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(masterMinter);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.configureMinter(minter, 1_000e6);
    }

    // ═══════════════════════════════════════════════
    //  Blacklisting
    // ═══════════════════════════════════════════════

    function test_blacklist_unblacklist() public {
        vm.prank(blacklister);
        token.blacklist(alice);
        assertTrue(token.isBlacklisted(alice));

        vm.prank(blacklister);
        token.unblacklist(alice);
        assertFalse(token.isBlacklisted(alice));
    }

    function test_blacklist_onlyBlacklister() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotBlacklister.selector);
        token.blacklist(bob);
    }

    function test_unblacklist_onlyBlacklister() public {
        vm.prank(blacklister);
        token.blacklist(alice);

        vm.prank(bob);
        vm.expectRevert(kUSD.NotBlacklister.selector);
        token.unblacklist(alice);
    }

    function test_blacklist_revertsZeroAddress() public {
        vm.prank(blacklister);
        vm.expectRevert(kUSD.ZeroAddress.selector);
        token.blacklist(address(0));
    }

    function test_unblacklist_revertsIfNotBlacklisted() public {
        vm.prank(blacklister);
        vm.expectRevert(abi.encodeWithSelector(kUSD.NotBlacklistedAccount.selector, alice));
        token.unblacklist(alice);
    }

    // ═══════════════════════════════════════════════
    //  Role updates (owner-only)
    // ═══════════════════════════════════════════════

    function test_updatePauser() public {
        vm.prank(owner);
        token.updatePauser(alice);
        assertEq(token.pauser(), alice);
    }

    function test_updatePauser_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotOwner.selector);
        token.updatePauser(bob);
    }

    function test_updatePauser_revertsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(kUSD.ZeroAddress.selector);
        token.updatePauser(address(0));
    }

    function test_updateBlacklister() public {
        vm.prank(owner);
        token.updateBlacklister(alice);
        assertEq(token.blacklister(), alice);
    }

    function test_updateBlacklister_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotOwner.selector);
        token.updateBlacklister(bob);
    }

    function test_updateBlacklister_revertsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(kUSD.ZeroAddress.selector);
        token.updateBlacklister(address(0));
    }

    function test_updateMasterMinter() public {
        vm.prank(owner);
        token.updateMasterMinter(alice);
        assertEq(token.masterMinter(), alice);
    }

    function test_updateMasterMinter_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotOwner.selector);
        token.updateMasterMinter(bob);
    }

    function test_updateMasterMinter_revertsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(kUSD.ZeroAddress.selector);
        token.updateMasterMinter(address(0));
    }

    // ═══════════════════════════════════════════════
    //  Ownership (two-step)
    // ═══════════════════════════════════════════════

    function test_twoStepOwnershipTransfer() public {
        vm.prank(owner);
        token.transferOwnership(alice);
        assertEq(token.pendingOwner(), alice);
        assertEq(token.owner(), owner); // still old owner

        vm.prank(alice);
        token.acceptOwnership();
        assertEq(token.owner(), alice);
        assertEq(token.pendingOwner(), address(0));
    }

    function test_transferOwnership_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NotOwner.selector);
        token.transferOwnership(bob);
    }

    function test_transferOwnership_revertsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(kUSD.ZeroAddress.selector);
        token.transferOwnership(address(0));
    }

    function test_acceptOwnership_revertsNoPending() public {
        vm.prank(alice);
        vm.expectRevert(kUSD.NoPendingOwner.selector);
        token.acceptOwnership();
    }

    function test_acceptOwnership_revertsNotPending() public {
        vm.prank(owner);
        token.transferOwnership(alice);

        vm.prank(bob);
        vm.expectRevert(kUSD.NotPendingOwner.selector);
        token.acceptOwnership();
    }

    // ═══════════════════════════════════════════════
    //  Rescue ERC-20
    // ═══════════════════════════════════════════════

    function test_rescueERC20() public {
        MockERC20 mock = new MockERC20();
        uint256 amount = 100e18;
        mock.mint(address(token), amount);

        vm.prank(owner);
        token.rescueERC20(IERC20(address(mock)), alice, amount);
        assertEq(mock.balanceOf(alice), amount);
    }

    function test_rescueERC20_onlyOwner() public {
        MockERC20 mock = new MockERC20();
        vm.prank(alice);
        vm.expectRevert(kUSD.NotOwner.selector);
        token.rescueERC20(IERC20(address(mock)), alice, 1);
    }

    function test_rescueERC20_revertsZeroAddress() public {
        MockERC20 mock = new MockERC20();
        vm.prank(owner);
        vm.expectRevert(kUSD.ZeroAddress.selector);
        token.rescueERC20(IERC20(address(mock)), address(0), 1);
    }

    // ═══════════════════════════════════════════════
    //  EIP-2612 Permit
    // ═══════════════════════════════════════════════

    function test_permit() public {
        uint256 alicePrivKey = 0xA11CE;
        address aliceAddr = vm.addr(alicePrivKey);

        _mintTo(aliceAddr, 1_000e6);

        uint256 nonce = token.nonces(aliceAddr);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 value = 500e6;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        aliceAddr,
                        bob,
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivKey, digest);

        token.permit(aliceAddr, bob, value, deadline, v, r, s);
        assertEq(token.allowance(aliceAddr, bob), value);
    }

    // ═══════════════════════════════════════════════
    //  Fuzz tests
    // ═══════════════════════════════════════════════

    function testFuzz_mintAndTransfer(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1, type(uint128).max);
        transferAmount = bound(transferAmount, 1, mintAmount);

        _configureMinter(minter, mintAmount);
        vm.prank(minter);
        token.mint(alice, mintAmount);

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
    }

    function testFuzz_mintAndBurn(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 1, type(uint128).max);
        burnAmount = bound(burnAmount, 1, mintAmount);

        _configureMinter(minter, mintAmount);
        vm.prank(minter);
        token.mint(minter, mintAmount);

        vm.prank(minter);
        token.burn(burnAmount);

        assertEq(token.balanceOf(minter), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }
}
