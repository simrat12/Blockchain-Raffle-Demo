const { expect } = require("chai");
// const { it } = require("node:test");
const { time, loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("Raffle", function () {
  async function deploy () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const VRF = await ethers.getContractFactory("VRFCoordinatorV2Mock");
    const vrf = await VRF.deploy(10,10);
    const Mock = await ethers.getContractFactory("ShitToken2");
    const mock = await Mock.deploy();
    await mock.deployed();
    const Raffle = await ethers.getContractFactory("Raffle");
    const raffle = await Raffle.deploy(vrf.address, 588, "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15", 10, 10, 500000, 500, mock.address);
    await raffle.deployed();

    return {owner, addr1, addr2, vrf, mock, raffle}
  };

  it("check if raffle works", async function () {
    const { raffle, addr1, addr2, owner, mock } = await loadFixture(deploy);
    await raffle.connect(owner).setAdmin(owner.address);
    await mock.connect(owner).transfer(addr1.address, 10);
    await mock.connect(owner).transfer(addr2.address, 10);

    await mock.connect(addr1).approve(raffle.address, 10);
    await mock.connect(addr2).approve(raffle.address, 10);

    await raffle.connect(addr1).enterRaffleInToken(10);
    await raffle.connect(addr2).enterRaffleInToken(10);
    await expect(raffle.connect(owner).endLottery()).to.be.reverted;
  })

  it("max fee should be reverted", async function () {
    const { raffle, addr1, addr2, owner, mock } = await loadFixture(deploy);
    await raffle.connect(owner).setAdmin(owner.address);
    await mock.connect(owner).transfer(addr1.address, 10);
    await mock.connect(owner).transfer(addr2.address, 10);

    await mock.connect(addr1).approve(raffle.address, 10);
    await mock.connect(addr2).approve(raffle.address, 10);

    await raffle.connect(addr1).enterRaffleInToken(10);
    await raffle.connect(owner).changeMaxEntry(1000);
    await expect(raffle.connect(addr2).enterRaffleInToken(1001)).to.be.reverted;
  })

  it("change admin", async function () {
    const { raffle, addr1, addr2, owner } = await loadFixture(deploy);
    await raffle.connect(owner).setAdmin(addr1.address);
    await raffle.connect(addr1).changeMaxEntry(1000);
  })

  it("Should revert as not admin", async function () {
    const { raffle, addr1, addr2, owner } = await loadFixture(deploy);
    await expect(raffle.connect(addr1).initialiseWinnersVesting(10000)).to.be.reverted;
  })

  it("Should accept admin", async function () {
    const { raffle, addr1, addr2, owner } = await loadFixture(deploy);
    await raffle.connect(owner).setAdmin(addr1.address);
    await raffle.connect(addr1).initialiseWinnersVesting(10000);
  })

});
