const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("CoinLocker", function() {
  let coinlocker;
  let mockToken;
  let deployer;
  let notOwner;
  let mockPriceFeed;


  beforeEach(async() => {
    // deploy new contracts
    [deployer, notOwner] = await ethers.getSigners();

    const Coinlocker = await ethers.getContractFactory("CoinLocker");
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
    it("Successful deposit of ERC20", async () => {
      await createDeposit(500, 1, 2000);
      let deposits = await coinlocker.getUserDeposits(deployer.address);
      assert(deposits.length == 1);
    })

    it("Successful deposit of ETH", async () => {
      let overrides = {
        value: ethers.utils.parseEther("1.0"),
      };
      let tx = await coinlocker.createDeposit(mockPriceFeed.address, ethers.constants.AddressZero, 100, 1, 2000, overrides);
      await tx.wait();
      let deposits = await coinlocker.getUserDeposits(deployer.address);
      assert(deposits.length == 1)
    })

    it("Fails if 0 tokens sent", async () => {
      await mockToken.approve(coinlocker.address, 500);
      await expect(coinlocker.createDeposit(mockPriceFeed.address, mockToken.address, 0, 1, 2000)).to.be.revertedWith("Token amount must be greater than 0");
    })

    it("Fails if ETH sent and token address sent", async() => {
      let overrides = {
        value: ethers.utils.parseEther("1.0"),
      };
      await expect(coinlocker.createDeposit(mockPriceFeed.address, mockToken.address, 100, 1, 2000, overrides)).to.be.revertedWith("Invalid deposit");
    })

    it("Fails if 0 ETH sent", async() => {
      await expect(coinlocker.createDeposit(mockPriceFeed.address, ethers.constants.AddressZero, 100, 1, 2000)).to.be.revertedWith("ETH deposit required");
    })
  });

  describe("Redeeming deposits", () => {
    it("Successful redemption of ERC20", async() => {
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

    it("Successful redemption of ETH", async() => {
      let startBalance = await deployer.getBalance();
      // deposit eth
      let overrides = {
        value: ethers.utils.parseEther("1.0"),
      };
      let tx = await coinlocker.createDeposit(mockPriceFeed.address, ethers.constants.AddressZero, 100, 0, 1800, overrides);
      await tx.wait();

      // check that the amount of eth left in the account is roughly correct (gas fees make it impossible to do a direct equality check)
      assert(
        (await deployer.getBalance()).gt(startBalance.sub(ethers.utils.parseEther("1.1"))) && 
        (await deployer.getBalance()).lt(startBalance.sub(ethers.utils.parseEther("0.9"))))

      // redeem the deposit
      tx = await coinlocker.redeemDeposit(1);
      await tx.wait();

      // check deposit details
      let deposits = await coinlocker.getUserDeposits(deployer.address);
      assert(deposits.length == 1);
      let deposit = await coinlocker.getDeposit(deposits[0]);
      assert(deposit.redeemed);

      // check that eth has been returned to the depositor
      assert((await deployer.getBalance()).gt(startBalance.sub(ethers.utils.parseEther("0.1"))))
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