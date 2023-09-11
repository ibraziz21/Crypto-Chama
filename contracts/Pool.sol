// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract SavingsPool {
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
   uint poolCounter;


   struct PoolDetails {
    address owner;
    address token;
    uint maxParticipants;
    uint contributionPerParticipant;
    uint durationPerTurn;
    uint startTime;
    uint currentTurn;
    address [] participants;
    mapping (address => bool) hasReceived;
    bool isActive;
    bool isRestrictedPool;
   }
   struct TurnDetails {
        uint turnBal;
        uint endTime;
        address currentClaimant;
        bool active;
        bool claimable;
        mapping (address => uint) turnContributions;
        mapping (address => bool) hasContributed;
   }
    //poolID => Turn ID => TurnDetails
   mapping (uint =>mapping(uint => TurnDetails)) public turn;

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

    uint poolID = ++poolCounter;
    //Owner must send deposit equivalent to 2 contributions
    IERC20 token  = IERC20(_tokenAddress);
    uint deposit = _calculateDeposit(_contributionAmt);

    if(token.balanceOf(msg.sender)<deposit) revert("Not Enough Tokens For the Deposit");
    if (token.allowance(msg.sender, address(this)) < deposit) {
        require(token.approve(address(this), deposit), "Token approval failed");
    }
    token.transferFrom(msg.sender, address(this),deposit);
    depositAmounts[poolID][msg.sender] = deposit;

    PoolDetails storage startPool = pool[poolID];
    startPool.owner = msg.sender;
    startPool.contributionPerParticipant = _contributionAmt *10**18;
    startPool.maxParticipants = _maxParticipants;
    startPool.durationPerTurn = _durationPerTurn;
    startPool.token = _tokenAddress;
    startPool.participants.push(msg.sender);
    startPool.isRestrictedPool = _isRestricted;
    startPool.isActive = false;
    startPool.currentTurn = 0;

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
        _joinpool.currentTurn++;
        _setTurnDetails(_id);

    }

    emit JoinedPool(_id, msg.sender);    
}

function contributeToPool(uint _poolID, uint _amount)  external {
    require(_isParticipant(_poolID,msg.sender), "Not a participant in this pool");
    require(_amount == pool[_poolID].contributionPerParticipant,"Wrong Amount");
    uint turnId = pool[_poolID].currentTurn;

    require(turn[_poolID][turnId].hasContributed[msg.sender] == false, "User has already contributed to this turn");

    _contribute(_poolID, turnId, _amount); 


}
function claimTurn(uint _poolID) external {
    // Check that the msg sender is part of the pool
    require(_isParticipant(_poolID, msg.sender), "Not a participant in this pool");

    // Get the current turn in the pool
    uint currentTurn = pool[_poolID].currentTurn;

    // Check if the beneficiary of the turn is the msg sender
    address beneficiary = turn[_poolID][currentTurn].currentClaimant;
    require(beneficiary == msg.sender, "It's not your turn to claim");

    // Check if there is a balance deposit, and refill it
    uint deposit = depositAmounts[_poolID][msg.sender];
    uint contributionAmt = pool[_poolID].contributionPerParticipant;
    uint expectedDep = contributionAmt*2;
    uint bal;
   
    if(deposit<expectedDep){
    // Refill the deposit with the claimant's amount
    bal = expectedDep-deposit;
    depositAmounts[_poolID][msg.sender] += bal;
    turn[_poolID][currentTurn].turnBal -= bal;
    }

    // Send remaining tokens to msg sender
    address tokenAddress = pool[_poolID].token;
    IERC20 token = IERC20(tokenAddress);
    uint remainingTokens = turn[_poolID][currentTurn].turnBal;

    // Transfer remaining tokens to the claimant
    if (remainingTokens > 0) {
        token.transfer(msg.sender, remainingTokens);
    }

    // Mark the turn as claimed
    turn[_poolID][currentTurn].active = false;

    // If the claimant is the last recipient, set the pool to not active
    if (currentTurn == pool[_poolID].participants.length) {
        pool[_poolID].isActive = false;
        // Return deposits to participants
        _returnDeposits(_poolID);
    }
}



//Owner can destroy the Pool, ONLY IF the Pool is not yet active
//function here


//internal functions
function _contribute( uint _poolId,uint _turnId,uint _amount) internal {
    address tknAddress  = pool[_poolId].token;
    IERC20 token  = IERC20(tknAddress);
    if(token.balanceOf(msg.sender)<_amount) revert("Not Enough Tokens For the Deposit");
    if (token.allowance(msg.sender, address(this)) < _amount) {
        require(token.approve(address(this), _amount), "Token approval failed");
    }
    token.transferFrom(msg.sender, address(this),_amount);

    turn[_poolId][_turnId].turnBal+=_amount;
    turn[_poolId][_turnId].turnContributions[msg.sender]=_amount;
    turn[_poolId][_turnId].hasContributed[msg.sender] = true;
}

function _setTurnDetails(uint _poolId) internal {
     //set the address to receive, endtime and activity
     PoolDetails storage thisPool = pool[_poolId];
     uint turnId = thisPool.currentTurn ;
     uint timePerTurn = thisPool.durationPerTurn;
     address turnBenefactor = thisPool.participants[turnId-1];

     TurnDetails storage thisTurn = turn[_poolId][turnId];
     thisTurn.currentClaimant = turnBenefactor;
     thisTurn.endTime = block.timestamp+timePerTurn;
     thisTurn.active = true;


}
function _useDeposit(uint _poolId,uint _turnId, address _address) internal{
//A deposit is used as the contribution amount
    uint _contributionAmt = pool[_poolId].contributionPerParticipant;
    depositAmounts[_poolId][_address]-=_contributionAmt;
    turn[_poolId][_turnId].turnBal+=_contributionAmt;
    
}


//In the case where the pool is closed or ended, deposits are returned
function _returnDeposits(uint _poolID) internal {
    uint _recipients = _checkParticipantCount(_poolID);
    address tkn = pool[_poolID].token;
    IERC20 token  = IERC20(tkn);

    for(uint i = 0; i < _recipients-1;){
        address receiver = pool[_poolID].participants[i];
        uint depositBal = depositAmounts[_poolID][receiver];
        if(depositBal!=0){
        token.transferFrom(address(this), receiver, depositBal);
        }
    unchecked {
        i++;
        }
    }
}


//We check the number of participants in so many functions, so we have it as an internal function
function _checkParticipantCount(uint _id) public view returns (uint) {
    uint count  = pool[_id].participants.length;

    return count;
}

function _isParticipant(uint _poolID, address _address) internal view returns(bool){
    PoolDetails storage _pooldetails = pool[_poolID];
    uint participants = _checkParticipantCount(_poolID);

    for(uint i = 0; i<participants;){
        address participant = _pooldetails.participants[i];
        if(participant == _address){
            return true;
        } unchecked {
            i++;
        }

    }
    return false;
}

function _calculateDeposit(uint _amount) internal pure returns (uint){
        return _amount*2;
}

}