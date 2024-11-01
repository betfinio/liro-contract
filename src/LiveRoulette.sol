// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { GameInterface } from "./interfaces/GameInterface.sol";
import { StakingInterface } from "./interfaces/StakingInterface.sol";
import { LiroBet } from "./LiroBet.sol";
import { GelatoVRFConsumerBase } from "@gelato/contracts/GelatoVRFConsumerBase.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * Errors:
 * LR01: Invalid player
 * LR02: Invalid amount
 * LR03: Table already exists
 * LR04: Invalid table id
 * LR05: Invalid interval
 * LR06: Round mismatch
 */
contract LiveRoulette is GameInterface, GelatoVRFConsumerBase {
    using SafeERC20 for IERC20;

    struct Table {
        uint256 id;
        uint256 interval;
    }

    uint256 private immutable created;
    address private immutable operator;
    StakingInterface public staking;

    mapping(uint256 id => Table table) public tables;

    constructor(address _staking, address __operator) GelatoVRFConsumerBase() {
        created = block.timestamp;
        staking = StakingInterface(_staking);
        operator = __operator;
        tables[0] = Table(0, 0); // table for single players
    }

    function placeBet(address, uint256 amount, bytes calldata data) external override returns (address betAddress) {
        (uint256 _amount, uint256 _table, uint256 _round, address _player) =
            abi.decode(data, (uint256, uint256, uint256, address));
        require(_amount == amount, "LR02");
        require(_table == tables[_table].id, "LR04");
        require(_round == getCurrentRound(_table), "LR06");
        LiroBet bet = new LiroBet(_player, amount, address(this));
        return address(bet);
    }

    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory extraData) internal override {
        require(block.timestamp > 1); // todo
    }

    function _operator() internal view override returns (address) {
        return operator;
    }

    function createTable(uint256 id, uint256 interval) external {
        require(interval > 0, "LR05");
        require(id > 0, "LR04");
        require(tables[id].id == 0, "LR03");
        tables[id] = Table(id, interval);
    }

    function getCurrentRound(uint256 _table) public view returns (uint256 round) {
        return block.timestamp / tables[_table].interval;
    }

    function getTableInterval(uint256 id) external view returns (uint256 interval) {
        return tables[id].interval;
    }

    function getAddress() external view override returns (address gameAddress) {
        return address(this);
    }

    function getVersion() external view override returns (uint256 version) {
        return created;
    }

    function getFeeType() external pure override returns (uint256 feeType) {
        return 0;
    }

    function getStaking() external view override returns (address) {
        return address(staking);
    }
}
