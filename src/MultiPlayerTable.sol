// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BetInterface } from "./interfaces/BetInterface.sol";
import { Library } from "./Library.sol";
import { console } from "forge-std/src/console.sol";
import { Table } from "./Table.sol";
import { LiroBet } from "./LiroBet.sol";
/**
 * Error Codes:
 * MP01: Invalid round
 * MP02: Invalid table
 * MP03: Bank is above the maximum limit
 */

contract MultiPlayerTable is Table {
    uint256 public immutable interval;

    mapping(uint256 round => uint256 bank) public roundBank;
    mapping(uint256 round => LiroBet[] bets) public roundBets;
    mapping(uint256 round => uint256 maxWin) public roundMaxWin;
    mapping(uint256 round => Library.Bet[] bitmaps) public roundBitmaps;

    constructor(address _liro, uint256 _interval) Table(_liro) {
        interval = _interval;
    }

    function getCurrentRound() public view returns (uint256) {
        return block.timestamp / interval;
    }

    function placeBet(bytes memory data) external override onlyLiro returns (address) {
        // decode the data
        (Library.Bet[] memory _bitmaps, address _table, uint256 _round, address _player) =
            abi.decode(data, (Library.Bet[], address, uint256, address));

        // check table
        require(_table == address(this), "MP02");
        // validate round
        require(_round == getCurrentRound(), "MP01");
        // validate limits of each bet
        validateLimits(_bitmaps);
        // increase the bank
        uint256 amount = Library.getBitmapsAmount(_bitmaps);
        roundBank[_round] += amount;
        // create bet
        LiroBet bet = new LiroBet(_player, amount, address(liro), _table, _round);
        bet.setBets(_bitmaps);
        // add bet to the round
        roundBets[_round].push(bet);
        // add bitmap to the round
        for (uint256 i = 0; i < _bitmaps.length; i++) {
            roundBitmaps[_round].push(_bitmaps[i]);
        }
        // update maxWin by current round
        roundMaxWin[_round] = liro.getMaxWinBank();
        // calculate possibleWin
        (uint256 totalPossibleWin,) = getPossibleWin(roundBitmaps[_round]);
        // check if the possibleWin is above the maximum limit
        require(totalPossibleWin <= roundMaxWin[_round], "MP03");
        return address(bet);
    }

    function getRoundBank(uint256 _round) public view returns (uint256) {
        return roundBank[_round];
    }
}
