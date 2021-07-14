const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("EthLocker", function() {
  let coinlocker;
  let deployer;

  beforeEach(async() => {
    const Coinlocker = await ethers.getContractFactory("EthLocker");
    coinlocker = await Coinlocker.deploy();

    [deployer] = await ethers.getSigners();
  });

  describe("Creating Deposits", () => {
    it("Successfully creates", async () => {
      let overrides = {
        value: ethers.utils.parseEther("1.0"),
      };
      let tx = await coinlocker.createDeposit(1, 2000, overrides);
      await tx.wait();
      let deposits = await coinlocker.getUserDeposits(deployer.address);
      assert(deposits.length == 1)
    });

    it("Doesn't create deposit if 0 ETH sent", async () => {
      let overrides = {
        value: 0,
      };
      await expect(coinlocker.createDeposit(1, 2000, overrides)).to.be.revertedWith("There was no ETH sent with this transaction to lock");
      let deposits = await coinlocker.getUserDeposits(deployer.address);
      assert(deposits.length == 0)
    })
    
  })
})