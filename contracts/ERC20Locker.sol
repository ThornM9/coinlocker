pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface PriceFeedInterface {
    function latestRoundData() external view returns (uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound);
}

contract ERC20Locker is Ownable {
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

  mapping(address => Deposit[]) private userDeposits;
  mapping(uint => Deposit) private idToDeposit;

  function getPrice(uint id) public view returns (uint) {
    Deposit memory deposit = idToDeposit[id];
    (,int price,,,) = deposit.priceFeed.latestRoundData();
    return uint(price);
  }

  function createDeposit(address _priceFeedAddress, address _tokenAddress, uint _amount, uint _lockDays, uint _lockUntilPrice) external {
    ERC20 token = ERC20(_tokenAddress);
    token.transferFrom(msg.sender, address(this), _amount);
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
    userDeposits[msg.sender].push(deposit);
    idToDeposit[nextId] = deposit;
    nextId++;
  }

  function getDeposit(uint id) external view returns (Deposit memory) {
    return idToDeposit[id];
  }

  function getUserDeposits(address user) external view returns (Deposit[] memory) {
    return userDeposits[user];
  }

  function canRedeemDeposit(uint id) public view returns (bool) {
    Deposit memory deposit = idToDeposit[id];
    if (deposit.lockedAt + deposit.lockDays <= block.timestamp) { return false; }
    if (getPrice(id) <= deposit.lockUntilPrice) { return false; }

    return true;
  }

  function _redeem(Deposit storage deposit) internal {
    deposit.redeemed = true; // prevent re-entrancy attack by redeeming before sending
    ERC20 token = ERC20(deposit.tokenAddress);
    token.transfer(deposit.depositor, deposit.amount);
  }

  function redeemDeposit(uint id) external {
    Deposit storage deposit = idToDeposit[id];
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