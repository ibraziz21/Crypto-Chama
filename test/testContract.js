
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SavingsPool",function () {
  
let SavingsPool, poolToken,owner, user1, user2, user3
  beforeEach(async function () {
    
  
     [owner, user1, user2, user3] = await ethers.getSigners();

    const token = await ethers.getContractFactory("poolToken");
     poolToken = await token.deploy();

    const SP = await ethers.getContractFactory("SavingsPool")
     SavingsPool = await SP.deploy();
  })
  it("should create a new pool", async function () {
    const maxParticipants = 5;
    const contributionAmt = ethers.parseEther("1");
    const durationPerTurn = 3600; // 1 hour
    const isRestricted = false;
    const savingsPool = await SavingsPool.getAddress();
    const tokenAddress = await poolToken.getAddress();
    const AllowanceAmt = contributionAmt*BigInt(10)
    console.log("Everythin Good")
  
    // Approve and transfer PoolToken to users
    await poolToken.connect(owner).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user1).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user2).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user3).approve(savingsPool, AllowanceAmt);
    console.log("Everythin Approved")
    // Create a new pool
    await expect(SavingsPool.connect(owner).createPool(tokenAddress, maxParticipants, contributionAmt, durationPerTurn, isRestricted))
      .to.emit(savingsPool, "PoolStarted")
      .withArgs(1, owner.address, maxParticipants, contributionAmt);
  
    // Verify pool details
    const poolDetails = await savingsPool.pool(1);
    expect(poolDetails.owner).to.equal(owner.address);
    expect(poolDetails.maxParticipants).to.equal(maxParticipants);
    expect(poolDetails.contributionPerParticipant).to.equal(contributionAmt);
    expect(poolDetails.durationPerTurn).to.equal(durationPerTurn);
    expect(poolDetails.token).to.equal(poolToken.address);
    expect(poolDetails.participants).to.have.lengthOf(1); // Owner is a participant
    expect(poolDetails.isRestrictedPool).to.equal(isRestricted);
    expect(poolDetails.isActive).to.equal(false);
    expect(poolDetails.currentTurn).to.equal(0);
  });
  
   
 
  })
