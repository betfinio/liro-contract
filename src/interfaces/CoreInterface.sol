// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface CoreInterface {
    function isStaking(address _staking) external view returns (bool);
    function fee() external view returns (uint256);
    function token() external view returns (address);

    function addGame(address _game) external;
}
