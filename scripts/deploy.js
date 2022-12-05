// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  const args = ["0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D", "5407", "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15", "600", "100000000", "800000", "10000000000000000000", "0x198244C498340dD151B5A0bB7f0d40893270a085"]
  const Raffle = await hre.ethers.getContractFactory("Raffle");
  const raffle = await Raffle.deploy(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
  await raffle.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

