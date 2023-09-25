// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.17;

contract ManagementContract {
    //In this smart contract, we will be having registrations and preferences set by users
    
    //Key Part of this is the blacklist, where defaulters are banned from participating
    //Another Key part is allowing a user to whitelist their friendlies to reduce chances of bad actors

    //Owner sets a DAO Panel to review and vote on whether an address can return to the pools
    struct BlacklistVote {
        address subject;
        uint8 votesFor;
        uint8 votesAgainst;
        mapping (address => bool) hasVoted;
    }

    address public owner;
    address[] public panel;
    mapping (address => bool) public isPanel;
    mapping (address => BlacklistVote) public blacklistedRedemption;
    mapping (address => bool) public isBlacklisted;
    mapping (address =>mapping(address => bool)) public userFriendlies;

    constructor() {
        owner = msg.sender;
    }

    function selectManagementVoter(address _address)  external 
     {
        require(msg.sender == owner, "Unauthorized");
        require(_address !=address(0), "Invalid Address");
        require(panel.length < 10, "Too many panelists");
        panel.push(_address);
        isPanel[_address] = true;

    }

    function setFriendly(address _address) external {
        require (_address != address(0), "Invalid Address");
        require(!userFriendlies[msg.sender][_address], "Already A Friendly");
        userFriendlies[msg.sender][_address] = true;
        
    }
    function setBatchFriendlies(address [] calldata _addresses) external {
        uint number = _addresses.length;
        for(uint i = 0; i< number;){
            address add = _addresses[i];
            require(add!=address(0), "One of the addresses is invalid");
            require(!userFriendlies[msg.sender][add], "One of the users is already a friendly");
            userFriendlies[msg.sender][add] =true;
        }
    }

    function blacklistAddress(address _address) private  {
        require(_address != address(0), "Invalid Address");
        require(!isBlacklisted[_address], "The address is already blacklisted");
        isBlacklisted[_address] = true;
    }

    function _checkStatus(address _owner, address _joiner ) public view returns(bool){
        require(_owner != address(0) && _joiner!= address(0), "Invalid Address");
        
        return userFriendlies[_owner][_joiner];
    }

    function reinstateBlacklistedUser(address _address, bool _vote) public {
        require(_address != address(0), "Invalid Address");
        require(isPanel[msg.sender], "Not Allowed to vote");
        BlacklistVote storage vote = blacklistedRedemption[_address];

        if(_vote == true){
            vote.votesFor++;
            vote.hasVoted[msg.sender] = true;
        }else {
            vote.votesAgainst++;
            vote.hasVoted[msg.sender] = true;
        }

        uint totalvotes = vote.votesFor + vote.votesAgainst;
        if(totalvotes == panel.length){
            if(((vote.votesFor/totalvotes)*100) > 60){
                //remove Address from blacklist
                isBlacklisted[_address] = false;
            }
        }
        
        
    }

}