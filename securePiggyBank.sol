// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SecurePiggyBank
 * @dev A secure implementation of a piggy bank contract with proper access controls
 */
contract SecurePiggyBank {
    address public owner;
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;
    
    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Allows users to deposit ETH into their individual account
     */
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @dev Allows users to withdraw only their own deposited funds
     */
    function withdraw() public {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        // Checks-Effects-Interactions pattern to prevent reentrancy
        deposits[msg.sender] = 0;
        totalDeposits -= amount;
        
        emit Withdrawal(msg.sender, amount);
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Owner-only function to withdraw all funds (emergency function)
     */
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        totalDeposits = 0;
        
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Transfer ownership to a new address
     */
    function transferOwnership(address newOwner) public onlyOwner validAddress(newOwner) {
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @dev Get the deposit balance for a specific address
     */
    function getBalance(address depositor) public view returns (uint256) {
        return deposits[depositor];
    }
    
    /**
     * @dev Get the contract's total balance
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title VulnerablePiggyBank
 * @dev The original vulnerable contract for demonstration purposes
 */
contract VulnerablePiggyBank {
    address public owner;
    
    constructor() { 
        owner = msg.sender; 
    }
    
    function deposit() public payable {}
    
    // VULNERABILITY: Anyone can withdraw all funds!
    function withdraw() public { 
        payable(msg.sender).transfer(address(this).balance); 
    }
    
    function attack() public {
        // This function demonstrates how anyone can drain the contract
        withdraw(); // Calls the vulnerable withdraw function
    }
}

/**
 * @title AttackContract
 * @dev Contract to demonstrate the attack on VulnerablePiggyBank
 */
contract AttackContract {
    VulnerablePiggyBank public target;
    address public attacker;
    
    constructor(address _target) {
        target = VulnerablePiggyBank(_target);
        attacker = msg.sender;
    }
    
    /**
     * @dev Attack function that exploits the vulnerable withdraw function
     */
    function attack() public {
        require(msg.sender == attacker, "Only attacker can call this");
        
        // Call the vulnerable withdraw function to steal all funds
        target.withdraw();
    }
    
    /**
     * @dev Function to receive stolen ETH
     */
    receive() external payable {
        // Funds received from the vulnerable contract
    }
    
    /**
     * @dev Withdraw stolen funds to attacker
     */
    function withdrawStolen() public {
        require(msg.sender == attacker, "Only attacker can withdraw");
        payable(attacker).transfer(address(this).balance);
    }
}

/**
 * @title TestScenario
 * @dev Contract to demonstrate the attack scenario
 */
contract TestScenario {
    VulnerablePiggyBank public vulnerableContract;
    AttackContract public attackContract;
    SecurePiggyBank public secureContract;
    
    constructor() {
        vulnerableContract = new VulnerablePiggyBank();
        attackContract = new AttackContract(address(vulnerableContract));
        secureContract = new SecurePiggyBank();
    }
    
    /**
     * @dev Simulate the attack scenario
     */
    function simulateAttack() public payable {
        require(msg.value >= 2 ether, "Need at least 2 ETH for simulation");
        
        // Step 1: Deposit some funds to the vulnerable contract
        vulnerableContract.deposit{value: 1 ether}();
        
        // Step 2: Execute the attack
        attackContract.attack();
        
        // The vulnerable contract should now be drained
        assert(address(vulnerableContract).balance == 0);
    }
}