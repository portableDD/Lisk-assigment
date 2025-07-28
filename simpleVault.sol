// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SafeMath Library
 * @dev Library for safe mathematical operations
 */
library SafeMath {
    /**
     * @dev Adds two numbers, throws on overflow
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Subtracts two numbers, throws on underflow
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction underflow");
        return a - b;
    }

    /**
     * @dev Multiplies two numbers, throws on overflow
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Integer division, truncates the quotient
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}

/**
 * @title VaultBase
 * @dev Base contract that defines the vault structure and shared logic
 */
contract VaultBase {
    using SafeMath for uint256;

    // State variables
    mapping(address => uint256) public balances;
    uint256 public totalDeposits;
    address public owner;

    // Events
    event Deposit(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawal(address indexed user, uint256 amount, uint256 newBalance);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "VaultBase: caller is not the owner");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "VaultBase: amount must be greater than 0");
        _;
    }

    /**
     * @dev Constructor sets the contract deployer as owner
     */
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    /**
     * @dev Returns the balance of a specific user
     * @param user The address to query
     * @return The balance of the user
     */
    function getBalance(address user) public view returns (uint256) {
        return balances[user];
    }

    /**
     * @dev Returns the total contract balance
     * @return The total Ether stored in the contract
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Transfer ownership to a new address
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "VaultBase: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Internal function to update user balance and total deposits
     * @param user The user's address
     * @param amount The amount to add
     */
    function _addToBalance(address user, uint256 amount) internal {
        balances[user] = balances[user].add(amount);
        totalDeposits = totalDeposits.add(amount);
    }

    /**
     * @dev Internal function to subtract from user balance and total deposits
     * @param user The user's address
     * @param amount The amount to subtract
     */
    function _subtractFromBalance(address user, uint256 amount) internal {
        balances[user] = balances[user].sub(amount);
        totalDeposits = totalDeposits.sub(amount);
    }
}

/**
 * @title VaultManager
 * @dev Derived contract that implements deposit and withdraw functionality
 */
contract VaultManager is VaultBase {
    using SafeMath for uint256;

    // Additional state variables for the manager
    bool public depositsEnabled;
    bool public withdrawalsEnabled;
    uint256 public maxDepositAmount;
    uint256 public minDepositAmount;

    // Additional events
    event DepositsToggled(bool enabled);
    event WithdrawalsToggled(bool enabled);
    event DepositLimitsUpdated(uint256 minAmount, uint256 maxAmount);

    /**
     * @dev Constructor initializes the vault manager
     */
    constructor() VaultBase() {
        depositsEnabled = true;
        withdrawalsEnabled = true;
        maxDepositAmount = 100 ether; // Default max deposit
        minDepositAmount = 0.001 ether; // Default min deposit
    }

    /**
     * @dev Modifier to check if deposits are enabled
     */
    modifier whenDepositsEnabled() {
        require(depositsEnabled, "VaultManager: deposits are currently disabled");
        _;
    }

    /**
     * @dev Modifier to check if withdrawals are enabled
     */
    modifier whenWithdrawalsEnabled() {
        require(withdrawalsEnabled, "VaultManager: withdrawals are currently disabled");
        _;
    }

    /**
     * @dev Allows users to deposit Ether into the vault
     */
    function deposit() 
        external 
        payable 
        validAmount(msg.value) 
        whenDepositsEnabled 
    {
        require(msg.value >= minDepositAmount, "VaultManager: deposit amount too small");
        require(msg.value <= maxDepositAmount, "VaultManager: deposit amount too large");

        _addToBalance(msg.sender, msg.value);
        
        emit Deposit(msg.sender, msg.value, balances[msg.sender]);
    }

    /**
     * @dev Allows users to withdraw their deposited Ether
     * @param amount The amount to withdraw
     */
    function withdraw(uint256 amount) 
        external 
        validAmount(amount) 
        whenWithdrawalsEnabled 
    {
        require(balances[msg.sender] >= amount, "VaultManager: insufficient balance");
        require(address(this).balance >= amount, "VaultManager: insufficient contract balance");

        _subtractFromBalance(msg.sender, amount);
        
        // Use call for safer Ether transfer
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "VaultManager: withdrawal failed");
        
        emit Withdrawal(msg.sender, amount, balances[msg.sender]);
    }

    /**
     * @dev Withdraw all deposited Ether for the caller
     */
    function withdrawAll() external whenWithdrawalsEnabled {
        uint256 userBalance = balances[msg.sender];
        require(userBalance > 0, "VaultManager: no balance to withdraw");
        require(address(this).balance >= userBalance, "VaultManager: insufficient contract balance");

        _subtractFromBalance(msg.sender, userBalance);
        
        (bool success, ) = payable(msg.sender).call{value: userBalance}("");
        require(success, "VaultManager: withdrawal failed");
        
        emit Withdrawal(msg.sender, userBalance, 0);
    }

    /**
     * @dev Emergency withdrawal function for owner only
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "VaultManager: insufficient contract balance");
        
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "VaultManager: emergency withdrawal failed");
    }

    /**
     * @dev Toggle deposit functionality
     * @param enabled Whether deposits should be enabled
     */
    function toggleDeposits(bool enabled) external onlyOwner {
        depositsEnabled = enabled;
        emit DepositsToggled(enabled);
    }

    /**
     * @dev Toggle withdrawal functionality
     * @param enabled Whether withdrawals should be enabled
     */
    function toggleWithdrawals(bool enabled) external onlyOwner {
        withdrawalsEnabled = enabled;
        emit WithdrawalsToggled(enabled);
    }

    /**
     * @dev Update deposit limits
     * @param minAmount Minimum deposit amount
     * @param maxAmount Maximum deposit amount
     */
    function updateDepositLimits(uint256 minAmount, uint256 maxAmount) external onlyOwner {
        require(minAmount <= maxAmount, "VaultManager: min amount cannot exceed max amount");
        minDepositAmount = minAmount;
        maxDepositAmount = maxAmount;
        emit DepositLimitsUpdated(minAmount, maxAmount);
    }

    /**
     * @dev Get user's deposit information
     * @param user The user's address
     * @return balance The user's current balance
     * @return canWithdraw Whether the user can withdraw
     */
    function getUserInfo(address user) external view returns (uint256 balance, bool canWithdraw) {
        balance = balances[user];
        canWithdraw = withdrawalsEnabled && balance > 0;
    }

    /**
     * @dev Get vault statistics
     * @return contractBalance Total Ether in contract
     * @return totalDeposited Total amount ever deposited
     */
    function getVaultStats() external view returns (uint256 contractBalance, uint256 totalDeposited) {
        contractBalance = address(this).balance;
        totalDeposited = totalDeposits;
    }
}