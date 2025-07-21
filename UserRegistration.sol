// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title UserProfileManager
 * @dev A smart contract for managing user profiles with registration and update functionality
 */
contract UserProfileManager {
    
    // User struct to store profile information
    struct User {
        string name;
        uint256 age;
        string email;
        bool isRegistered;
        uint256 registrationTimestamp;
    }
    
    // State variables
    mapping(address => User) private users;
    address[] private registeredAddresses;
    uint256 public totalRegisteredUsers;
    
    // Events
    event UserRegistered(address indexed userAddress, string name, uint256 timestamp);
    event ProfileUpdated(address indexed userAddress, string name, uint256 age, string email);
    
    // Modifiers
    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "User not registered");
        _;
    }
    
    modifier notAlreadyRegistered() {
        require(!users[msg.sender].isRegistered, "User already registered");
        _;
    }
    
    modifier validAge(uint256 _age) {
        require(_age > 0 && _age <= 150, "Invalid age: must be between 1 and 150");
        _;
    }
    
    modifier validName(string memory _name) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_name).length <= 50, "Name too long: maximum 50 characters");
        _;
    }
    
    modifier validEmail(string memory _email) {
        require(bytes(_email).length > 0, "Email cannot be empty");
        require(bytes(_email).length <= 100, "Email too long: maximum 100 characters");
        _;
    }
    
    /**
     * @dev Register a new user with profile information
     * @param _name User's name
     * @param _age User's age
     * @param _email User's email address
     */
    function register(
        string memory _name,
        uint256 _age,
        string memory _email
    ) public notAlreadyRegistered validName(_name) validAge(_age) validEmail(_email) {
        
        users[msg.sender] = User({
            name: _name,
            age: _age,
            email: _email,
            isRegistered: true,
            registrationTimestamp: block.timestamp
        });
        
        registeredAddresses.push(msg.sender);
        totalRegisteredUsers++;
        
        emit UserRegistered(msg.sender, _name, block.timestamp);
    }
    
    /**
     * @dev Update existing user profile information
     * @param _name New name (optional, pass empty string to keep current)
     * @param _age New age (pass 0 to keep current)
     * @param _email New email (optional, pass empty string to keep current)
     */
    function updateProfile(
        string memory _name,
        uint256 _age,
        string memory _email
    ) public onlyRegistered {
        
        User storage user = users[msg.sender];
        
        // Update name if provided
        if (bytes(_name).length > 0) {
            require(bytes(_name).length <= 50, "Name too long: maximum 50 characters");
            user.name = _name;
        }
        
        // Update age if provided and valid
        if (_age > 0) {
            require(_age <= 150, "Invalid age: must be 150 or less");
            user.age = _age;
        }
        
        // Update email if provided
        if (bytes(_email).length > 0) {
            require(bytes(_email).length <= 100, "Email too long: maximum 100 characters");
            user.email = _email;
        }
        
        emit ProfileUpdated(msg.sender, user.name, user.age, user.email);
    }
    
    /**
     * @dev Get profile information for the caller
     * @return name User's name
     * @return age User's age
     * @return email User's email
     * @return registrationTimestamp When the user registered
     */
    function getProfile() public view onlyRegistered returns (
        string memory name,
        uint256 age,
        string memory email,
        uint256 registrationTimestamp
    ) {
        User memory user = users[msg.sender];
        return (user.name, user.age, user.email, user.registrationTimestamp);
    }
    
    /**
     * @dev Get profile information for a specific address (public getter)
     * @param _userAddress Address of the user to query
     * @return name User's name
     * @return age User's age
     * @return email User's email
     * @return isRegister Whether the user is registered
     * @return registrationTimestamp When the user registered
     */
    function getUserProfile(address _userAddress) public view returns (
        string memory name,
        uint256 age,
        string memory email,
        bool isRegister,
        uint256 registrationTimestamp
    ) {
        User memory user = users[_userAddress];
        return (user.name, user.age, user.email, user.isRegistered, user.registrationTimestamp);
    }
    
    /**
     * @dev Check if a user is registered
     * @param _userAddress Address to check
     * @return bool True if user is registered
     */
    function isUserRegistered(address _userAddress) public view returns (bool) {
        return users[_userAddress].isRegistered;
    }
    
    /**
     * @dev Check if the caller is registered
     * @return bool True if caller is registered
     */
    function isRegistered() public view returns (bool) {
        return users[msg.sender].isRegistered;
    }
    
    /**
     * @dev Get all registered user addresses (for admin purposes)
     * @return address[] Array of all registered addresses
     */
    function getAllRegisteredUsers() public view returns (address[] memory) {
        return registeredAddresses;
    }
    
    /**
     * @dev Get registration timestamp for a specific user
     * @param _userAddress Address of the user
     * @return uint256 Registration timestamp
     */
    function getRegistrationTimestamp(address _userAddress) public view returns (uint256) {
        require(users[_userAddress].isRegistered, "User not registered");
        return users[_userAddress].registrationTimestamp;
    }
}