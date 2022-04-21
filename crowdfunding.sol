// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.9.0;

contract CrowdFunding {
    mapping(address => uint256) public contributors;
    address public admin;
    uint256 public numberOfContributors;
    uint256 public minimumContribution;
    uint256 public deadline; // Timestamp
    uint256 public goal;
    uint256 public raisedAmount;

    // Spending Request
    struct Request {
        string description;
        address payable recipient;
        uint256 value;
        bool completed;
        uint256 numberOfVoters;
        mapping(address => bool) voters;
    }

    /*
    Mapping of spending requests
    The key is the spending request number (index) - starts from zero
    The value is a Request struct
    */
    mapping(uint256 => Request) public requests;
    uint256 public requestNumber;

    // Events to emit, must be captured by a javascript callback
    event ContributeEvent(address _sender, uint256 _value);
    event CreateRequestEvent(
        string _description,
        address _recipient,
        uint256 _value
    );
    event MakePaymentEvent(address _recipient, uint256 _value);

    constructor(uint256 _goal, uint256 _deadline) {
        goal = _goal;
        deadline = block.timestamp + _deadline;
        minimumContribution = 100 wei;
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    function contribute() public payable {
        require(block.timestamp < deadline, "Deadline has passed");
        require(
            msg.value >= minimumContribution,
            "Minimum Contribution not met"
        );

        // Incrementing the number of contributors the first time when someone sends ETH to the contract
        if (contributors[msg.sender] == 0) {
            numberOfContributors++;
        }

        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;

        emit ContributeEvent(msg.sender, msg.value);
    }

    receive() external payable {
        contribute();
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // A contributor can get a refund if goal was not reached within the deadline
    function getRefund() public {
        require(block.timestamp > deadline, "Deadline has not passed");
        require(raisedAmount < goal, "The goal was met");
        require(contributors[msg.sender] > 0);

        address payable recipient = payable(msg.sender);
        uint256 value = contributors[msg.sender];

        recipient.transfer(value);
        contributors[msg.sender] = 0;
    }

    function createRequest(
        string memory _description,
        address payable _recipient,
        uint256 _value
    ) public onlyAdmin {
        // requestNumber starts from zero
        Request storage newRequest = requests[requestNumber];
        requestNumber++;

        newRequest.description = _description;
        newRequest.recipient = _recipient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.numberOfVoters = 0;

        emit CreateRequestEvent(_description, _recipient, _value);
    }

    function voteRequest(uint256 _requestNumber) public {
        require(
            contributors[msg.sender] > 0,
            "You must be a contributor to vote"
        );
        Request storage thisRequest = requests[_requestNumber];
        require(
            thisRequest.voters[msg.sender] == false,
            "You have already voted"
        );

        thisRequest.voters[msg.sender] = true;
        thisRequest.numberOfVoters++;
    }

    function makePayment(uint256 _requestNumber) public onlyAdmin {
        require(raisedAmount >= goal);
        Request storage thisRequest = requests[_requestNumber];

        require(
            thisRequest.completed == false,
            "The request has been completed"
        );
        require(thisRequest.numberOfVoters > numberOfContributors / 2); // More than 50% of contributors must vote for a request
        thisRequest.recipient.transfer(thisRequest.value);
        thisRequest.completed = true;

        emit MakePaymentEvent(thisRequest.recipient, thisRequest.value);
    }
}
