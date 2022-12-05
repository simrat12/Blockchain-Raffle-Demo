require("@nomicfoundation/hardhat-toolbox");
// import { HardhatUserConfig, task } from "hardhat/config";
require("@nomiclabs/hardhat-etherscan");
// require("@nomiclabs/hardhat-waffle");
require("@nomicfoundation/hardhat-chai-matchers");
require("@typechain/hardhat");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2/sG47YlSxJTbOZ4OKOncgBEJC6O35LzOe",
      accounts: ["e50091f32f0ba1158ca556e83b611a7d0e7b6b4bcd14280049f302495312ec75"],
      chainId: 5,
      saveDeployments: true,
    },
  },
  etherscan: {
    apiKey: {
      goerli: "MY65SQDZKVVA5YZBAYKAQVWSCG6FRKSFTJ"
    }
  },

  solidity: "0.8.17",
  compilers: [
    {
      version: "0.5.5",
    },
    {
      version: "0.6.0",
    },
    {
      version: "0.8.0"
    },
    {
      version: "0.8.4"
    },
    {
      version: "0.7.6"
    }
  ],  
};
