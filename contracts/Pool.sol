// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./management.sol";
contract SavingsPool {
    event PoolStarted(uint poolid, address _poolOwner, uint maxParticipants, uint contributions);
    event JoinedPool(uint poolid, address _joiner);
    event UserClaim(uint poolId, uint turnId, address _address, uint amountClaimed );
    event UserContributed();
   
    ManagementContract mgmt;
    address public owner;
    uint public poolCounter;
   

    //Struct storing the pool Details 
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

   //Struct storing the turn details within a pool
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
 
    constructor(address _mgmt) {
        require(_mgmt != address(0),"Invalid Contract Address");

        mgmt = ManagementContract(_mgmt);
        owner = msg.sender;
    }

//function allows for users to create pools
function createPool(address _tokenAddress, uint _maxParticipants, uint _contributionAmt,uint _durationPerTurn, bool _isRestricted) external {
    require(_tokenAddress!=address(0), "Invalid token");
    require (_maxParticipants!= 0,"Pool Needs a Valid number of Participants");
    require (_contributionAmt!= 0, "Enter a valid Contribution Amount");
    require (_durationPerTurn!= 0, "Enter a valid Duration");

    uint poolID = ++poolCounter;
    uint contributionInEth = _contributionAmt*10**18;
    //Owner must send deposit equivalent to 2 contributions
    IERC20 token  = IERC20(_tokenAddress);
    uint deposit = _calculateDeposit(contributionInEth);

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


//Function to join a Savings Pool
function joinPool(uint _id) external {
    //Check that the pool is not full
    uint maxPPL = pool[_id].maxParticipants;
    require(_checkParticipantCount(_id)!= maxPPL, "Pool Filled");

    //check if the address joining is blacklisted
    require(!mgmt.isBlacklisted(msg.sender), "You are blacklisted from the pool for defaulting");

    PoolDetails storage _joinpool =pool[_id];
    uint deposit = _calculateDeposit(_joinpool.contributionPerParticipant);
    address tknAddress = _joinpool.token;

//If the pool is restricted, Only addresses that are Friendlies of the owner can join the pool
    if(_joinpool.isRestrictedPool){
        address pOwner = _joinpool.owner;
        bool status = mgmt._checkStatus(pOwner,msg.sender);
        require(status == true, "You are not allowed in this pool");
    }

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

//External Function that allows a user to contribute to the pool
function contributeToPool(uint _poolID)  external {
    require(_isParticipant(_poolID,msg.sender), "Not a participant in this pool");
    
    uint _amount = pool[_poolID].contributionPerParticipant;

    uint turnId = pool[_poolID].currentTurn;

    require(turn[_poolID][turnId].hasContributed[msg.sender] == false, "User has already contributed to this turn");

    _contribute(_poolID, turnId, _amount); 

    _updateTurn(_poolID);
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
         emit UserClaim(_poolID,currentTurn,msg.sender, bal );

    // If the claimant is the last recipient, set the pool to not active
    if (currentTurn == pool[_poolID].participants.length) {
        pool[_poolID].isActive = false;
        // Return deposits to participants
        _returnDeposits(_poolID);
    }
   
    _updateTurn(_poolID);
}



//Owner can destroy the Pool, ONLY IF the Pool is not yet active
//function here



//In the case where the pool is closed or ended, deposits are returned



//We check the number of participants in so many functions, so we have it as an internal function
function _checkParticipantCount(uint _id) public view returns (uint) {
    uint count  = pool[_id].participants.length;

    return count;
}

function _isParticipant(uint _poolID, address _address) public view returns(bool){
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
function _updateTurn(uint _poolId) internal {

     PoolDetails storage thisPool = pool[_poolId];
     address []  memory _addresses = thisPool.participants;
     uint participantNo = _addresses.length;
     uint turnId =  thisPool.currentTurn;
     if(turn[_poolId][turnId].endTime < block.timestamp){
    for (uint i = 0; i < participantNo;) {
        address current = _addresses[i];

        //use deposit if they have the deposits
        if(!turn[_poolId][turnId].hasContributed[current] && 
        depositAmounts[_poolId][current]>= thisPool.contributionPerParticipant ){
            _useDeposit(_poolId, turnId, current);
        }else if(!turn[_poolId][turnId].hasContributed[current] && 
        depositAmounts[_poolId][current] < thisPool.contributionPerParticipant){
            //If both deposits are used, address is blacklisted from participating again
            mgmt.blacklistAddress(current);
        }
    }
    thisPool.currentTurn++;
     _setTurnDetails(_poolId);
     }

}
function _useDeposit(uint _poolId,uint _turnId, address _address) internal{
//A deposit is used as the contribution amount
    uint _contributionAmt = pool[_poolId].contributionPerParticipant;
    depositAmounts[_poolId][_address]-=_contributionAmt;
    turn[_poolId][_turnId].turnBal+=_contributionAmt;
    
}


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

function _calculateDeposit(uint _amount) internal pure returns (uint){
        return _amount*2;
}

}