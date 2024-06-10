// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract usdTousdc {
    uint256 public usdValue;
    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Sepolia Testnet
     * Aggregator: USDC/USD
     * Address: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
     */

    constructor() {
        priceFeed = AggregatorV3Interface(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E);
    }

    function inputUSD(uint256 _usdValue) public {
        usdValue = _usdValue;
    }

    function getLatestPrice() public view returns (uint256) {
        (
            , 
            int price,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function convertusdTousdc() public view returns (uint256) {
        uint256 price = getLatestPrice();
        // Price feed returns 8 decimal, therefore 10^8
        uint256 usdcValue = (usdValue * 10**8) / price;
        return usdcValue;
    }
}
