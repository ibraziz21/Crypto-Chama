// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // const management = await ethers.deployContract("ManagementContract", {gasLimit: 0x200000})
  // const addr = await management.getAddress()
  // console.log("Management Contract Address ", addr)

  const pool = await ethers.deployContract("SavingsPool", ['0x035e9C0E58C649775407B468b724ab8796dCE575'],  {gasLimit: 0x300000});

  const sAddr = await pool.getAddress();
  console.log("Pool Contract CA:", sAddr);

  // const token = await ethers.deployContract("poolToken", {gasLimit: 0x200000})

  // const tAddr = await token.getAddress();
  // console.log("Governance Token: ", tAddr);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
