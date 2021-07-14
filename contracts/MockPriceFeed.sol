// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "./PriceFeedInterface.sol";

contract MockPriceFeed is PriceFeedInterface {
    int256 public mockedPrice;

    constructor(int256 _mockedPrice) {
        mockedPrice = _mockedPrice;
    }

    function latestRoundData() external view override returns (uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound) {
        return (100, mockedPrice, 100, 100, 100);
    }
}