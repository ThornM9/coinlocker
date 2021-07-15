// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PriceFeedInterface.sol";

contract CoinLocker is Ownable {
  struct Deposit {
    address depositor;
    address tokenAddress;
    uint id;
    uint lockedAt;
    uint lockDays;
    bool redeemed;
    uint lockUntilPrice;
    uint amount;
    PriceFeedInterface priceFeed;
  }
  uint nextId = 1;

  mapping(address => uint[]) private userDeposits;
  mapping(uint => Deposit) private idToDeposit;

  function getPrice(uint id) public view returns (uint) {
    Deposit memory deposit = idToDeposit[id];
    (,int price,,,) = deposit.priceFeed.latestRoundData();
    return uint(price);
  }

  function createDeposit(address _priceFeedAddress, address _tokenAddress, uint _amount, uint _lockDays, uint _lockUntilPrice) external payable {
    require(_amount > 0 || _tokenAddress == address(0x0), "Token amount must be greater than 0");
    require(!(_tokenAddress != address(0x0) && msg.value > 0), "Invalid deposit");
    Deposit memory deposit = Deposit({
      depositor: msg.sender,
      tokenAddress: _tokenAddress,
      id: nextId,
      lockedAt: block.timestamp,
      lockDays: _lockDays,
      redeemed: false,
      lockUntilPrice: _lockUntilPrice,
      amount: _amount,
      priceFeed: PriceFeedInterface(_priceFeedAddress)
    });
    
    if (_tokenAddress == address(0x0)) {
      // accept eth as a deposit if token address set to 0
      require(msg.value > 0, "ETH deposit required");
      deposit.amount = msg.value;
    } else {
      // else accept erc20 deposit
      ERC20 token = ERC20(_tokenAddress);
      token.transferFrom(msg.sender, address(this), _amount);
    }
    // check price feed works
    deposit.priceFeed.latestRoundData();

    userDeposits[msg.sender].push(deposit.id);
    idToDeposit[nextId] = deposit;
    nextId++;
  }

  function getDeposit(uint id) external view returns (Deposit memory) {
    return idToDeposit[id];
  }

  function getUserDeposits(address user) external view returns (uint[] memory) {
    return userDeposits[user];
  }

  function canRedeemDeposit(uint id) public view returns (bool) {
    Deposit memory deposit = idToDeposit[id];
    if (deposit.lockedAt + (deposit.lockDays * 1 days) > block.timestamp) { return false; }
    if (getPrice(id) <= deposit.lockUntilPrice) { return false; }

    return true;
  }

  function _redeem(Deposit storage deposit) internal {
    deposit.redeemed = true; // prevent re-entrancy attack by redeeming before sending
    if (deposit.tokenAddress == address(0x0)) {
      payable(deposit.depositor).transfer(deposit.amount);
    } else {
      ERC20 token = ERC20(deposit.tokenAddress);
      token.transfer(deposit.depositor, deposit.amount);
    }
  }

  function redeemDeposit(uint id) external {
    Deposit storage deposit = idToDeposit[id];
    require(msg.sender == deposit.depositor, "Only the depositor can redeem their deposit");
    require(canRedeemDeposit(id), "Deposit cannot be redeemed yet");
    require(!deposit.redeemed, "Deposit has already been redeemed");

    _redeem(deposit);
  }

  function forceRedeem(uint id) external onlyOwner {
    // if a deposit gets stuck for some reason, the owner can redeem the deposit to the depositors address
    Deposit storage deposit = idToDeposit[id];
    _redeem(deposit);
  }
}