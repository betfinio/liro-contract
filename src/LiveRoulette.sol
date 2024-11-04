// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { GameInterface } from "./interfaces/GameInterface.sol";
import { StakingInterface } from "./interfaces/StakingInterface.sol";
import { LiroBet } from "./LiroBet.sol";
import { GelatoVRFConsumerBase } from "@gelato/contracts/GelatoVRFConsumerBase.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CoreInterface } from "./interfaces/CoreInterface.sol";
import { Token } from "./Token.sol";
import { Table } from "./Table.sol";
import { Library } from "./Library.sol";
import { SinglePlayerTable } from "./SinglePlayerTable.sol";
import { MultiPlayerTable } from "./MultiPlayerTable.sol";

/**
 * Errors:
 * LR01: Invalid calles
 * LR02: Invalid amount
 * LR03: Table do not exists
 * LR04: Invalid table id
 * LR05: Invalid interval
 * LR06: Round mismatch
 */
contract LiveRoulette is GameInterface, GelatoVRFConsumerBase, AccessControl {
    using SafeERC20 for IERC20;

    uint256 private immutable created;
    address private immutable operator;
    StakingInterface public immutable staking;
    CoreInterface public immutable core;
    Token public immutable token;
    SinglePlayerTable public immutable singlePlayerTable;

    mapping(address table => bool exists) public tables;

    constructor(address _staking, address _core, address __operator, address _admin) GelatoVRFConsumerBase() {
        created = block.timestamp;
        staking = StakingInterface(_staking);
        operator = __operator;
        core = CoreInterface(_core);
        token = Token(core.token());
        singlePlayerTable = new SinglePlayerTable(address(this));
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function setLimit(
        address table,
        string calldata limit,
        uint256 min,
        uint256 max
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        Table(table).setLimit(limit, min, max);
    }

    function placeBet(address, uint256 amount, bytes calldata data) external override returns (address betAddress) {
        // check if the caller is the core contract
        require(_msgSender() == address(core), "LR01");
        // decode the data
        (Library.Bet[] memory _bitmaps, address _table, uint256 _round, address _player) =
            abi.decode(data, (Library.Bet[], address, uint256, address));
        // get total amount of bets
        uint256 _amount = Library.getBitmapsAmount(_bitmaps);
        // check if the amount is correct
        require(_amount == amount, "LR02");
        // check if single player - table and round are 0
        if (_table == address(0) && _round == 0) {
            return singlePlayerTable.placeBet(data);
        }
        // check if table exists
        require(tables[_table], "LR03");
        // get the table
        MultiPlayerTable table = MultiPlayerTable(_table);
        // place and return bet
        return table.placeBet(data);
    }

    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory extraData) internal override {
        require(block.timestamp > 1); // todo
    }

    function _operator() internal view override returns (address) {
        return operator;
    }

    function createTable(uint256 interval) external returns (address) {
        require(interval > 0, "LR05");
        MultiPlayerTable table = new MultiPlayerTable(address(this), interval);
        tables[address(table)] = true;
        return address(table);
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

    function getMaxWinBank() external view returns (uint256) {
        return IERC20(token).balanceOf(address(staking)) * 5 / 100; // 5% of staking balance
    }
}
