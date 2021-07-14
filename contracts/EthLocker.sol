pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

interface PriceFeedInterface {
    function latestRoundData() external view returns (uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound);
}

contract EthLocker is Ownable {
  struct Deposit {
    address depositor;
    uint id;
    uint lockedAt;
    uint lockDays;
    bool redeemed;
    uint lockUntilPrice;
    uint amount;
  }
  uint nextId = 1;

  mapping(address => Deposit[]) private userDeposits;
  mapping(uint => Deposit) private idToDeposit;
  PriceFeedInterface private priceFeed;

  constructor() public {
    priceFeed = PriceFeedInterface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e); // ETH/USD price feed on rinkeby
  }

  function setPriceFeedAddress(address _priceFeedAddress) external onlyOwner {
    priceFeed = AggregatorV3Interface(_priceFeedAddress);
  }

  function getPrice() public view returns (uint) {
    (
        uint80 roundID, 
        int price,
        uint startedAt,
        uint timeStamp,
        uint80 answeredInRound
    ) = priceFeed.latestRoundData();
    return uint(price);
  }

  function createDeposit(uint _lockDays, uint _lockUntilPrice) external payable {
    require(msg.value > 0, "There was no ETH sent with this transaction to lock");
    Deposit deposit = Deposit({
      depositor: msg.sender,
      id: nextId,
      lockedAt: block.timestamp,
      lockDays: _lockDays,
      redeemed: false,
      lockUntilPrice: _lockUntilPrice,
      amount: msg.value
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
    Deposit deposit = idToDeposit[id];
    if (deposit.lockedAt + deposit.lockDays <= block.timestamp) { return false; }
    if (getPrice() <= deposit.lockUntilPrice) { return false; }

    return true;
  }

  function _redeem(Deposit deposit) internal {
    deposit.redeemed = true; // prevent re-entrancy attack by redeeming before sending
    payable(deposit.depositor).transfer(deposit.amount);
  }

  function redeemDeposit(uint id) external {
    Deposit deposit = idToDeposit[id];
    require(canRedeemDeposit(id), "Deposit cannot be redeemed yet");
    require(!deposit.redeemed, "Deposit has already been redeemed");

    _redeem(deposit);
  }

  function forceRedeem(uint id) external onlyOwner {
    // if a deposit gets stuck for some reason, the owner can redeem the deposit to the depositors address
    Deposit deposit = idToDeposit[id];
    _redeem(deposit);
  }
}