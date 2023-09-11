
const { expect, use } = require("chai");
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
    const contributionAmt = 1;
    const durationPerTurn = 3600; // 1 hour
    const isRestricted = false;
    const savingsPool = await SavingsPool.getAddress();
    const tokenAddress = await poolToken.getAddress();
    const AllowanceAmt = ethers.parseEther("1000")
    // Approve and transfer PoolToken to users
    await poolToken.connect(owner).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user1).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user2).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user3).approve(savingsPool, AllowanceAmt);
    // Create a new pool
    expect( await SavingsPool.connect(owner).createPool(tokenAddress, maxParticipants, contributionAmt, durationPerTurn, isRestricted))
      .to.emit(SavingsPool, "PoolStarted")
      .withArgs(1, owner.address, maxParticipants, contributionAmt);

      
  
    // Verify pool details
    const poolDetails = await SavingsPool.pool(1);
    expect(poolDetails.owner).to.equal(owner.address);
    expect(poolDetails.maxParticipants).to.equal(maxParticipants);
    expect(poolDetails.contributionPerParticipant).to.equal(ethers.parseEther("1"));
    expect(poolDetails.durationPerTurn).to.equal(durationPerTurn);
    expect(poolDetails.token).to.equal(tokenAddress);
    //expect(poolDetails.participants).to.have.lengthOf(1); // Owner is a participant
    expect(poolDetails.isRestrictedPool).to.equal(isRestricted);
    expect(poolDetails.isActive).to.equal(false);
    expect(poolDetails.currentTurn).to.equal(0);
  });
  
  it("Users should be able to join pools", async function(){
    const maxParticipants = 5;
    const contributionAmt = 1;
    const durationPerTurn = 3600; // 1 hour
    const isRestricted = false;
    const savingsPool = await SavingsPool.getAddress();
    const tokenAddress = await poolToken.getAddress();
    const AllowanceAmt = ethers.parseEther("1000")
    // Approve and transfer PoolToken to users
    await poolToken.connect(owner).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user1).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user2).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user3).approve(savingsPool, AllowanceAmt);


    await poolToken.connect(owner).transfer(user1.address, ethers.parseEther("10"))
    // Create a new pool
    expect( await SavingsPool.connect(owner).createPool(tokenAddress, maxParticipants, contributionAmt, durationPerTurn, isRestricted))
      .to.emit(SavingsPool, "PoolStarted")
      .withArgs(1, owner.address, maxParticipants, contributionAmt);

    await SavingsPool.connect(user1).joinPool(1);

    expect(await SavingsPool._checkParticipantCount(1)).to.equal(2);
  
  })
  it("Check that the deposits are correctly stored pointing to their owners", async function () {
    const maxParticipants = 5;
    const contributionAmt = 1;
    const durationPerTurn = 3600; // 1 hour
    const isRestricted = false;
    const savingsPool = await SavingsPool.getAddress();
    const tokenAddress = await poolToken.getAddress();
    const AllowanceAmt = ethers.parseEther("1000")
    // Approve and transfer PoolToken to users
    await poolToken.connect(owner).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user1).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user2).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user3).approve(savingsPool, AllowanceAmt);


    await poolToken.connect(owner).transfer(user1.address, ethers.parseEther("10"))
    // Create a new pool
    expect( await SavingsPool.connect(owner).createPool(tokenAddress, maxParticipants, contributionAmt, durationPerTurn, isRestricted))
      .to.emit(SavingsPool, "PoolStarted")
      .withArgs(1, owner.address, maxParticipants, contributionAmt);

    await SavingsPool.connect(user1).joinPool(1);

    expect(await SavingsPool.depositAmounts(1, owner.address)).to.equal(ethers.parseEther('2'))
    expect(await SavingsPool.connect(user1).depositAmounts(1, user1.address)).to.equal(ethers.parseEther('2'))
    
  })
   it("If max participants reached, pool should automatically be started", async function(){
    const maxParticipants = 3;
    const contributionAmt = 1;
    const durationPerTurn = 3600; // 1 hour
    const isRestricted = false;
    const savingsPool = await SavingsPool.getAddress();
    const tokenAddress = await poolToken.getAddress();
    const AllowanceAmt = ethers.parseEther("1000")
    // Approve and transfer PoolToken to users
    await poolToken.connect(owner).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user1).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user2).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user3).approve(savingsPool, AllowanceAmt);


    await poolToken.connect(owner).transfer(user1.address, ethers.parseEther("10"))
    await poolToken.connect(owner).transfer(user2.address, ethers.parseEther("10"))

    // Create a new pool
    expect( await SavingsPool.connect(owner).createPool(tokenAddress, maxParticipants, contributionAmt, durationPerTurn, isRestricted))
      .to.emit(SavingsPool, "PoolStarted")
      .withArgs(1, owner.address, maxParticipants, contributionAmt);

    await SavingsPool.connect(user1).joinPool(1);
    await SavingsPool.connect(user2).joinPool(1);

    expect((await SavingsPool.pool(1)).isActive).to.equal(true);
    expect((await SavingsPool.pool(1)).currentTurn).to.equal(1)

   })
   it("Once a pool is started, users can contribute once", async function(){
    const maxParticipants = 3;
    const contributionAmt = 1;
    const durationPerTurn = 3600; // 1 hour
    const isRestricted = false;
    const savingsPool = await SavingsPool.getAddress();
    const tokenAddress = await poolToken.getAddress();
    const AllowanceAmt = ethers.parseEther("1000")
    // Approve and transfer PoolToken to users
    await poolToken.connect(owner).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user1).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user2).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user3).approve(savingsPool, AllowanceAmt);


    await poolToken.connect(owner).transfer(user1.address, ethers.parseEther("10"))
    await poolToken.connect(owner).transfer(user2.address, ethers.parseEther("10"))

    // Create a new pool
    expect( await SavingsPool.connect(owner).createPool(tokenAddress, maxParticipants, contributionAmt, durationPerTurn, isRestricted))
      .to.emit(SavingsPool, "PoolStarted")
      .withArgs(1, owner.address, maxParticipants, contributionAmt);

    await SavingsPool.connect(user1).joinPool(1);
    await SavingsPool.connect(user2).joinPool(1);

    await SavingsPool.connect(owner).contributeToPool(1);
    const turnDetails = await SavingsPool.turn(1, 1);

    expect(await turnDetails.turnBal).to.equal(ethers.parseEther('1'))
    
    
   // expect(await turnDetails.hasContributed[owner.address]).to.equal(true);

 
  })
  it("User should be able to claim the tokens if they are the beneficiary, and everyone has contributed", async function(){
    const maxParticipants = 3;
    const contributionAmt = 1;
    const durationPerTurn = 3600; // 1 hour
    const isRestricted = false;
    const savingsPool = await SavingsPool.getAddress();
    const tokenAddress = await poolToken.getAddress();
    const AllowanceAmt = ethers.parseEther("1000")
    // Approve and transfer PoolToken to users
    await poolToken.connect(owner).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user1).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user2).approve(savingsPool, AllowanceAmt);
    await poolToken.connect(user3).approve(savingsPool, AllowanceAmt);


    await poolToken.connect(owner).transfer(user1.address, ethers.parseEther("10"))
    await poolToken.connect(owner).transfer(user2.address, ethers.parseEther("10"))

    // Create a new pool
    expect( await SavingsPool.connect(owner).createPool(tokenAddress, maxParticipants, contributionAmt, durationPerTurn, isRestricted))
      .to.emit(SavingsPool, "PoolStarted")
      .withArgs(1, owner.address, maxParticipants, contributionAmt);

    await SavingsPool.connect(user1).joinPool(1);
    await SavingsPool.connect(user2).joinPool(1);

    await SavingsPool.connect(owner).contributeToPool(1);
    await SavingsPool.connect(user1).contributeToPool(1);
    await SavingsPool.connect(user2).contributeToPool(1);

    const initBalance = await poolToken.balanceOf(owner.address)

    await SavingsPool.connect(owner).claimTurn(1)

    const newBal = await poolToken.balanceOf(owner.address)

    expect(newBal - initBalance).to.equal(ethers.parseEther('3'))
    
  

    

    
    
    

  })
})
