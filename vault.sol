// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

contract SmartWallet {
    struct Asset {
        uint balance;
        mapping(address => uint) allowance;
    }

    mapping(address => bool) public guardians;
    address public owner;
    uint public balanceReceived;
    mapping(address => Asset) public assets;
    mapping(address => mapping(uint => bool)) public withdrawalRequests;
    uint public withdrawalDelay = 3 days; // 3 days time-lock for withdrawals
    bool public emergencyStop;

    event Deposit(address indexed sender, uint amount);
    event WithdrawalRequested(address indexed requester, uint amount);
    event WithdrawalApproved(address indexed requester, uint amount);
    event WithdrawalExecuted(address indexed receiver, uint amount);
    event AllowanceSet(address indexed spender, uint amount);
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EmergencyStop(bool isActive);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyGuardian() {
        require(guardians[msg.sender], "Not a guardian");
        _;
    }

    modifier notEmergencyStopped() {
        require(!emergencyStop, "Contract is in emergency stop");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    function deposit() public payable notEmergencyStopped {
        balanceReceived += msg.value;
        assets[address(0)].balance += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function withdrawAll() public onlyOwner notEmergencyStopped {
        uint totalBalance = getContractBalance();
        require(totalBalance > 0, "No funds available for withdrawal");

        payable(msg.sender).transfer(totalBalance);
        emit WithdrawalExecuted(msg.sender, totalBalance);
    }

    function withdrawToAddress(address payable _to) public onlyOwner notEmergencyStopped {
        uint totalBalance = getContractBalance();
        require(totalBalance > 0, "No funds available for withdrawal");

        _to.transfer(totalBalance);
        emit WithdrawalExecuted(_to, totalBalance);
    }

    function setAllowance(address _asset, address _spender, uint _amount) public onlyOwner {
        assets[_asset].allowance[_spender] = _amount;
        emit AllowanceSet(_spender, _amount);
    }

    function addGuardian(address _guardian) public onlyOwner {
        guardians[_guardian] = true;
        emit GuardianAdded(_guardian);
    }

    function removeGuardian(address _guardian) public onlyOwner {
        guardians[_guardian] = false;
        emit GuardianRemoved(_guardian);
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function requestWithdrawal(uint _amount) public onlyOwner notEmergencyStopped {
        require(_amount <= getContractBalance(), "Insufficient funds for withdrawal");
        uint requestId = block.timestamp; // Use timestamp as a unique request ID
        withdrawalRequests[msg.sender][requestId] = true;
        emit WithdrawalRequested(msg.sender, _amount);
    }

    function approveWithdrawal(address _requester, uint _requestId) public onlyGuardian notEmergencyStopped {
        require(withdrawalRequests[_requester][_requestId], "Withdrawal request not found");
        require(block.timestamp >= _requestId + withdrawalDelay, "Withdrawal time-lock not expired");

        uint amount = getContractBalance();
        _requester.transfer(amount);
        withdrawalRequests[_requester][_requestId] = false;
        emit WithdrawalApproved(_requester, amount);
    }

    function emergencyStopContract() public onlyOwner {
        emergencyStop = true;
        emit EmergencyStop(true);
    }

    function resumeContract() public onlyOwner {
        emergencyStop = false;
        emit EmergencyStop(false);
    }

    // Add more features as needed...
}
