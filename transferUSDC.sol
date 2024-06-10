// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract USDCPayment {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC Token Contract Address

    event PaymentSent(address indexed recipient, uint256 amount);

    function sendUSDC(address payable recipient, uint256 amount) external {
        require(amount <= USDC.balanceOf(msg.sender), "Insufficient balance");

        USDC.transferFrom(msg.sender, recipient, amount);
        emit PaymentSent(recipient, amount);
    }
}
