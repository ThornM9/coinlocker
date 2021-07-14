const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("ERC20Locker", function() {
  let coinlocker;
  let mockToken;
  let deployer;
  let notOwner;
  let mockPriceFeed;


  beforeEach(async() => {
    // deploy new contracts
    [deployer, notOwner] = await ethers.getSigners();

    const Coinlocker = await ethers.getContractFactory("ERC20Locker");
    coinlocker = await Coinlocker.deploy();

    const MockToken = await ethers.getContractFactory("MockToken");
    mockToken = await MockToken.deploy();

    const MockPriceFeed = await ethers.getContractFactory("MockPriceFeed");
    mockPriceFeed = await MockPriceFeed.deploy(1900);
  });

  async function createDeposit(amount, lockDays, lockUntilPrice) {
    await mockToken.approve(coinlocker.address, amount);
    // address _priceFeedAddress, address _tokenAddress, uint _amount, uint _lockDays, uint _lockUntilPrice
    let tx = await coinlocker.createDeposit(mockPriceFeed.address, mockToken.address, amount, lockDays, lockUntilPrice);
    await tx.wait();
  }

  describe("Creating Deposits", () => {
    it("Successfully creates", async () => {
      await createDeposit(500, 1, 2000);
      let deposits = await coinlocker.getUserDeposits(deployer.address);
      assert(deposits.length == 1);
    });

    it("Doesn't create deposit if 0 tokens sent", async () => {
      await mockToken.approve(coinlocker.address, 500);
      await expect(coinlocker.createDeposit(mockPriceFeed.address, mockToken.address, 0, 1, 2000)).to.be.revertedWith("Token amount must be greater than 0");
      let deposits = await coinlocker.getUserDeposits(deployer.address);
      assert(deposits.length == 0)
    })
  });

  describe("Redeeming deposits", () => {
    it("Successfully redeems correct deposit", async() => {
      await createDeposit(500, 0, 100);
      // check that the tokens have been removed from the depositor
      let deployerBalance = await mockToken.balanceOf(deployer.address);
      assert(deployerBalance.toNumber() == 500);

      // redeem the deposit
      let tx = await coinlocker.redeemDeposit(1);
      await tx.wait();

      // check deposit details
      let deposits = await coinlocker.getUserDeposits(deployer.address);
      assert(deposits.length == 1);
      let deposit = await coinlocker.getDeposit(deposits[0]);
      assert(deposit.redeemed);
      
      // check that the tokens have been returned to the depositor
      deployerBalance = await mockToken.balanceOf(deployer.address);
      assert(deployerBalance.toNumber() == 1000);
    })

    it("Can't redeem someone else's deposit", async() => {
      await createDeposit(500, 0, 100);
      await expect(coinlocker.connect(notOwner).redeemDeposit(1)).to.be.revertedWith("Only the depositor can redeem their deposit");
    })

    it("Can't redeem deposit that hasn't passed the time restriction", async() => {
      await createDeposit(500, 1, 100);
      await expect(coinlocker.redeemDeposit(1)).to.be.revertedWith("Deposit cannot be redeemed yet");
    })

    it("Can't redeem deposit that is below the required price", async() => {
      await createDeposit(500, 0, 2000);
      await expect(coinlocker.redeemDeposit(1)).to.be.revertedWith("Deposit cannot be redeemed yet");
    })
  })
})