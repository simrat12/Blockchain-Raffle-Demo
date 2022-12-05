const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
  
    const token = await hre.ethers.getContractFactory("ShitToken2");
    const token2 = await token.deploy();
    await token2.deployed();
  }
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });