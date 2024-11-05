// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BetInterface } from "./interfaces/BetInterface.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Library } from "./Library.sol";
import { console } from "forge-std/src/console.sol";
import { Table } from "./Table.sol";
import { LiroBet } from "./LiroBet.sol";
/**
 * Error Codes:
 * MP01: Invalid round
 * MP02: Invalid table
 * MP03: Bank is above the maximum limit
 * MP04: Round is not in required status
 * MP05: Insufficient balance to start a round
 * MP06: Round is not refundable
 * MP07: Maximum bets reached
 */

contract MultiPlayerTable is Table {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_BETS = 100;

    uint256 public immutable interval;

    mapping(uint256 round => uint256 bank) public roundBank;
    mapping(uint256 round => LiroBet[] bets) public roundBets;
    mapping(uint256 round => Library.Bet[] bitmaps) public roundBitmaps;
    mapping(uint256 round => uint256 win) public roundPossibleWin;
    // 0 - not exists, 1 - created, 2 - requested, 3 - finished, 4 - refunded
    mapping(uint256 round => uint256 status) public roundStatus;

    constructor(address _liro, uint256 _interval) Table(_liro) {
        interval = _interval;
    }

    function getCurrentRound() public view returns (uint256) {
        return block.timestamp / interval;
    }

    function placeBet(bytes memory data) external override onlyLiro returns (address, int256) {
        // decode the data
        (Library.Bet[] memory _bitmaps, address _table, uint256 _round, address _player) =
            abi.decode(data, (Library.Bet[], address, uint256, address));

        // check table
        require(_table == address(this), "MP02");
        // validate round
        require(_round == getCurrentRound(), "MP01");
        // check max bets
        require(roundBets[_round].length < MAX_BETS, "MP07");
        // validate limits of each bet
        validateLimits(_bitmaps);
        // increase the bank
        uint256 amount = Library.getBitmapsAmount(_bitmaps);
        roundBank[_round] += amount;
        // create bet
        LiroBet bet = new LiroBet(_player, amount, address(liro), _table, _round);
        // set bet bitmap
        bet.setBets(_bitmaps);
        // add bet to the round
        roundBets[_round].push(bet);
        // add bitmap to the round
        for (uint256 i = 0; i < _bitmaps.length; i++) {
            roundBitmaps[_round].push(_bitmaps[i]);
        }
        // calculate possibleWin
        (uint256 maxPossibleWin,) = getPossibleWin(roundBitmaps[_round]);
        // check if the possibleWin is above the maximum limit
        require(maxPossibleWin <= liro.getMaxWinBank(), "MP03");
        // update round status if needed
        if (roundStatus[_round] == 0) {
            roundStatus[_round] = 1;
        }
        int256 diff = int256(maxPossibleWin - roundPossibleWin[_round]);
        roundPossibleWin[_round] = maxPossibleWin;
        // return the bet address
        return (address(bet), diff);
    }

    function spin(uint256 _round) external override returns (bytes memory) {
        // check if round is older than the current round
        require(_round < getCurrentRound(), "MP01");
        // check if round status is 1
        require(roundStatus[_round] == 1, "MP04");
        // check if the bank is above the maximum limit
        require(liro.token().balanceOf(address(this)) >= roundPossibleWin[_round], "MP05"); // should not happen
        roundStatus[_round] = 2;
        return abi.encode(false, address(this), _round);
    }

    function result(uint256 _round, uint256 _winNumber) external onlyLiro {
        // check round status
        require(roundStatus[_round] == 2, "MP04");
        // save token for gas optimization
        address token = address(liro.token());
        // calculate token amount sent to players
        uint256 sent = 0;
        // iterate over bets
        for (uint256 i = 0; i < roundBets[_round].length; i++) {
            // get bet
            LiroBet bet = roundBets[_round][i];
            // get bet bitmaps
            (uint256[] memory amounts, uint256[] memory bitmaps) = bet.getBets();
            // calculate win amount
            uint256 winAmount = 0;
            for (uint256 j = 0; j < amounts.length; j++) {
                uint256 bitmap = bitmaps[j];
                if (bitmap & (2 ** _winNumber) > 0) {
                    (uint256 payout,,) = getBitMapPayout(bitmap);
                    winAmount += amounts[j] * payout + amounts[j];
                }
            }
            // transfer the win amount
            if (winAmount > 0) {
                IERC20(token).transfer(bet.getPlayer(), winAmount);
                sent += winAmount;
            }
            // set the result
            if (winAmount > 0) {
                bet.setResult(winAmount);
            }
            bet.setWinNumber(_winNumber);
        }
        if (sent < roundPossibleWin[_round]) {
            // transfer the rest to the staking
            uint256 rest = roundPossibleWin[_round] - sent;
            IERC20(token).transfer(address(liro.getStaking()), rest);
        }
        // transfer bet amount to staking
        IERC20(token).transferFrom(address(liro), address(liro.getStaking()), roundBank[_round]);
        roundStatus[_round] = 3;
    }

    function refund(uint256 round, address) external override onlyLiro {
        // refund only if number was not generated after 1 days after the round start
        require(block.timestamp > (round + 1) * interval + 1 days, "MP06");
        // check the round status
        require(roundStatus[round] >= 1 && roundStatus[round] < 3, "MP04"); // status 1 - created, 2 - requested
        // iterate over bets
        for (uint256 i = 0; i < roundBets[round].length; i++) {
            // get bet
            LiroBet bet = roundBets[round][i];
            // get bet amount
            uint256 amount = bet.getAmount();
            // transfer the amount back to the player
            IERC20(address(liro.token())).transferFrom(address(liro), bet.getPlayer(), amount);
            // set the result
            bet.refund();
        }
        IERC20(address(liro.token())).transfer(address(liro.getStaking()), roundPossibleWin[round]);
        // set the round status to 4
        roundStatus[round] = 4;
    }

    function getRoundBank(uint256 _round) external view returns (uint256) {
        return roundBank[_round];
    }
}
