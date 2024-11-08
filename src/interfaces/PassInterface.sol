// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface PassInterface {
    function mint(address member, address inviter, address parent) external;

    function balanceOf(address) external view returns (uint256);
}
