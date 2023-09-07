// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Name {
    event PoolStarted(uint poolid, address _poolOwner, uint maxParticipants, uint contributions);
    event JoinedPool(uint poolid, address _joiner);
    /* What can users do in this contract?
    - Users can Create a saving pool
        - Owner of the pool sets the rules, including the tokens used, maximum participants
          amount contributed per round, Open or closed pool
        - The Pool has a bool isActive to set the pool to start, and a timestamp once the pool is started to begin      
        - User can set a list of addresses that can participate in their pools
        - User can set a start Date, if the threshold of participants is met, the Pool automatically starts. If Not, Pool Users get their Deposits back and pool is destroyed

    -Users joining Pools
        - Users are checked that they are not blacklisted for defaulting
        - Users are checked if their address is allowed to participate by the owner (If Closed Pool)
        - User pays deposit equivalent to 2 turns contribution
        - User gets added to the pool, notified on frontend when pool starts

    -Contributions
        - User Gets notified when turn starts
        - Users have a set time to make contribution, else the one deposit amount is added to the turn.
        - If user contributes after, amount is set to be the deposit 
        - If user does not contribute by that time, User is halted from the pool, blacklisted and second deposit taken to compensate fellow participants

    -Claim turn
        -Check if it is user's turn to claim
        -Check that the user is not halted
        -User Claims available funds from turn
        -Mark as received.
        -If User is last recepient, set Pool to not active, return Deposits to Participants


    */
   uint counter;

   struct PoolDetails {
    address owner;
    address token;
    uint maxParticipants;
    uint contributionPerParticipant;
    uint durationPerTurn;
    address [] participants;
    mapping (address => bool) hasReceived;
    bool isActive;
    uint startTime;
    bool isRestrictedPool;

   }

   mapping (uint => PoolDetails) public pool;

//This Stores the deposit amounts of each user in the pool
   mapping (uint => mapping(address=> uint)) public depositAmounts;

    constructor() {
        
    }

function createPool(address _tokenAddress, uint _maxParticipants, uint _contributionAmt,uint _durationPerTurn, bool _isRestricted) external {
    require(_tokenAddress!=address(0), "Invalid token");
    require (_maxParticipants!= 0,"Pool Needs a Valid number of Participants");
    require (_contributionAmt!= 0, "Enter a valid Contribution Amount");
    require (_durationPerTurn!= 0, "Enter a valid Duration");

    uint poolID = ++counter;
    //Owner must send deposit equivalent to 2 contributions
    IERC20 token  = IERC20(_tokenAddress);
    uint deposit = _calculateDeposit(_contributionAmt);

    if(token.balanceOf(msg.sender)<deposit) revert("Not Enough Tokens For the Deposit");
    if (token.allowance(msg.sender, address(this)) < deposit) {
        require(token.approve(address(this), deposit), "Token approval failed");
    }
    token.transferFrom(msg.sender, address(this),deposit);
    depositAmounts[counter][msg.sender] = deposit;

    PoolDetails storage startPool = pool[poolID];
    startPool.owner = msg.sender;
    startPool.contributionPerParticipant = _contributionAmt *10**18;
    startPool.maxParticipants = _maxParticipants;
    startPool.durationPerTurn = _durationPerTurn;
    startPool.token = _tokenAddress;
    startPool.participants.push(msg.sender);
    startPool.isRestrictedPool = _isRestricted;
    startPool.isActive = false;

    emit PoolStarted(poolID, msg.sender, _maxParticipants, _contributionAmt);
}

function joinPool(uint _id) external {
    //Check that the pool is not full
    uint maxPPL = pool[_id].maxParticipants;
    require(_checkParticipantCount(_id)!= maxPPL, "Pool Filled");

    PoolDetails storage _joinpool =pool[_id];
    uint deposit = _calculateDeposit(_joinpool.contributionPerParticipant);
    address tknAddress = _joinpool.token;

    IERC20 token = IERC20(tknAddress);
    
    //Send the deposit
    if(token.balanceOf(msg.sender)<deposit) revert("Not Enough Tokens For the Deposit");
    if (token.allowance(msg.sender, address(this)) < deposit) {
        require(token.approve(address(this), deposit), "Token approval failed");
    }
    token.transferFrom(msg.sender, address(this),deposit);
    depositAmounts[_id][msg.sender] = deposit;


    //Once  Deposit is sent, add address to the array of participants
    _joinpool.participants.push(msg.sender);
    
    //Check if with this addition, pool is full. Start Pool if it is.
    if(_joinpool.participants.length == maxPPL){
        _joinpool.isActive = true;
        _joinpool.startTime =block.timestamp;
    }

    emit JoinedPool(_id, msg.sender);    
}

//Owner can destroy the Pool, ONLY IF the Pool is not yet active
//function here

function _checkParticipantCount(uint _id) public view returns (uint) {
    uint count  = pool[_id].participants.length;

    return count;
}

function _calculateDeposit(uint _amount) internal pure returns (uint){
        return _amount*2;
}

}