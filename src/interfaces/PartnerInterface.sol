// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface PartnerInterface {
    function placeBet(address game, uint256 totalAmount, bytes calldata data) external returns (address);
    function stake(address staking, uint256 amount) external;
}
