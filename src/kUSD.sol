// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title kUSD
 * @notice A fiat-backed stablecoin modeled after USDC (Centre FiatToken).
 *
 * Key features mirroring USDC:
 *   - 6-decimal ERC-20 token
 *   - Role-based access control: owner, admin, pauser, blacklister, minters
 *   - Configurable minters with per-minter allowances
 *   - Address blacklisting (blocked addresses cannot send, receive, or approve)
 *   - Pausable (owner/pauser can freeze all transfers)
 *   - EIP-2612 gasless approvals (permit)
 *   - Rescuable (recover ERC-20 tokens accidentally sent to the contract)
 *   - Two-step ownership transfer
 */
contract kUSD is ERC20, ERC20Permit, Pausable {
    // ──────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────
    error NotOwner();
    error NotAdmin();
    error NotPauser();
    error NotBlacklister();
    error NotMinter();
    error ZeroAddress();
    error Blacklisted(address account);
    error NotBlacklistedAccount(address account);
    error MintAllowanceExceeded(uint256 requested, uint256 allowance);
    error BurnAmountExceedsBalance(uint256 amount, uint256 balance);
    error ZeroAmount();
    error NoPendingOwner();
    error NotPendingOwner();

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────
    event MinterConfigured(address indexed minter, uint256 minterAllowedAmount);
    event MinterRemoved(address indexed minter);
    event MasterMinterChanged(address indexed newMasterMinter);
    event AddressBlacklisted(address indexed account);
    event AddressUnblacklisted(address indexed account);
    event BlacklisterChanged(address indexed newBlacklister);
    event PauserChanged(address indexed newPauser);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────
    address private _owner;
    address private _pendingOwner;
    address public pauser;
    address public blacklister;
    address public masterMinter;

    mapping(address => bool) internal _blacklisted;
    mapping(address => bool) internal _minters;
    mapping(address => uint256) internal _minterAllowed;

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────
    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    modifier onlyPauser() {
        if (msg.sender != pauser) revert NotPauser();
        _;
    }

    modifier onlyBlacklister() {
        if (msg.sender != blacklister) revert NotBlacklister();
        _;
    }

    modifier onlyMasterMinter() {
        if (msg.sender != masterMinter) revert NotMinter();
        _;
    }

    modifier notBlacklisted(address account) {
        if (_blacklisted[account]) revert Blacklisted(account);
        _;
    }

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────
    constructor(
        address owner_,
        address pauser_,
        address blacklister_,
        address masterMinter_
    ) ERC20("kUSD", "kUSD") ERC20Permit("kUSD") {
        if (owner_ == address(0)) revert ZeroAddress();
        if (pauser_ == address(0)) revert ZeroAddress();
        if (blacklister_ == address(0)) revert ZeroAddress();
        if (masterMinter_ == address(0)) revert ZeroAddress();

        _owner = owner_;
        pauser = pauser_;
        blacklister = blacklister_;
        masterMinter = masterMinter_;

        emit OwnershipTransferred(address(0), owner_);
        emit PauserChanged(pauser_);
        emit BlacklisterChanged(blacklister_);
        emit MasterMinterChanged(masterMinter_);
    }

    // ──────────────────────────────────────────────
    //  ERC-20 Overrides (6 decimals like USDC)
    // ──────────────────────────────────────────────
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // ──────────────────────────────────────────────
    //  Ownership (two-step, mirrors USDC v2)
    // ──────────────────────────────────────────────
    function owner() public view returns (address) {
        return _owner;
    }

    function pendingOwner() public view returns (address) {
        return _pendingOwner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    function acceptOwnership() external {
        if (_pendingOwner == address(0)) revert NoPendingOwner();
        if (msg.sender != _pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }

    // ──────────────────────────────────────────────
    //  Pause
    // ──────────────────────────────────────────────
    function pause() external onlyPauser {
        _pause();
    }

    function unpause() external onlyPauser {
        _unpause();
    }

    function updatePauser(address newPauser) external onlyOwner {
        if (newPauser == address(0)) revert ZeroAddress();
        pauser = newPauser;
        emit PauserChanged(newPauser);
    }

    // ──────────────────────────────────────────────
    //  Blacklisting
    // ──────────────────────────────────────────────
    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }

    function blacklist(address account) external onlyBlacklister {
        if (account == address(0)) revert ZeroAddress();
        _blacklisted[account] = true;
        emit AddressBlacklisted(account);
    }

    function unblacklist(address account) external onlyBlacklister {
        if (!_blacklisted[account]) revert NotBlacklistedAccount(account);
        _blacklisted[account] = false;
        emit AddressUnblacklisted(account);
    }

    function updateBlacklister(address newBlacklister) external onlyOwner {
        if (newBlacklister == address(0)) revert ZeroAddress();
        blacklister = newBlacklister;
        emit BlacklisterChanged(newBlacklister);
    }

    // ──────────────────────────────────────────────
    //  Minting
    // ──────────────────────────────────────────────
    function isMinter(address account) external view returns (bool) {
        return _minters[account];
    }

    function minterAllowance(address minter) external view returns (uint256) {
        return _minterAllowed[minter];
    }

    function configureMinter(address minter, uint256 minterAllowedAmount)
        external
        onlyMasterMinter
        whenNotPaused
    {
        if (minter == address(0)) revert ZeroAddress();
        _minters[minter] = true;
        _minterAllowed[minter] = minterAllowedAmount;
        emit MinterConfigured(minter, minterAllowedAmount);
    }

    function removeMinter(address minter) external onlyMasterMinter {
        _minters[minter] = false;
        _minterAllowed[minter] = 0;
        emit MinterRemoved(minter);
    }

    function mint(address to, uint256 amount)
        external
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
    {
        if (!_minters[msg.sender]) revert NotMinter();
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        if (amount > _minterAllowed[msg.sender]) {
            revert MintAllowanceExceeded(amount, _minterAllowed[msg.sender]);
        }

        _minterAllowed[msg.sender] -= amount;
        _mint(to, amount);
    }

    function burn(uint256 amount)
        external
        whenNotPaused
        notBlacklisted(msg.sender)
    {
        if (!_minters[msg.sender]) revert NotMinter();
        if (amount == 0) revert ZeroAmount();

        uint256 balance = balanceOf(msg.sender);
        if (amount > balance) revert BurnAmountExceedsBalance(amount, balance);

        _burn(msg.sender, amount);
    }

    function updateMasterMinter(address newMasterMinter) external onlyOwner {
        if (newMasterMinter == address(0)) revert ZeroAddress();
        masterMinter = newMasterMinter;
        emit MasterMinterChanged(newMasterMinter);
    }

    // ──────────────────────────────────────────────
    //  Transfer hooks (enforce pause + blacklist)
    // ──────────────────────────────────────────────
    function _update(address from, address to, uint256 value)
        internal
        override
        whenNotPaused
    {
        // Minting (from == 0) and burning (to == 0) have their own guards,
        // but regular transfers must check both parties.
        if (from != address(0) && _blacklisted[from]) revert Blacklisted(from);
        if (to != address(0) && _blacklisted[to]) revert Blacklisted(to);
        super._update(from, to, value);
    }

    /**
     * @dev Override approve to prevent blacklisted accounts from approving
     *      or being approved, matching USDC behavior.
     */
    function approve(address spender, uint256 value)
        public
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(spender)
        returns (bool)
    {
        return super.approve(spender, value);
    }

    /**
     * @dev Override transferFrom to also check the spender (msg.sender)
     *      is not blacklisted, matching USDC behavior.
     */
    function transferFrom(address from, address to, uint256 value)
        public
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        returns (bool)
    {
        return super.transferFrom(from, to, value);
    }

    // ──────────────────────────────────────────────
    //  Rescue (recover accidentally sent ERC-20 tokens)
    // ──────────────────────────────────────────────
    function rescueERC20(IERC20 token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        token.transfer(to, amount);
        emit TokensRescued(address(token), to, amount);
    }
}
