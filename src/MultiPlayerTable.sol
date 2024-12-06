// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Library } from "./Library.sol";
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
 * MP08: Invalid max bets
 */

contract MultiPlayerTable is Table {
    uint256 private constant REFUND_PERIOD = 1 days;
    uint256 private MAX_BETS = 50;
    uint256 public immutable interval;
    IERC20 private token;

    mapping(uint256 round => uint256 bank) private roundBank;
    mapping(uint256 round => LiroBet[] bets) private roundBets;
    mapping(uint256 round => uint256 win) private roundReserved;
    mapping(uint256 round => uint256 spinned) private roundSpinned;
    // 0 - not exists, 1 - created, 2 - requested, 3 - finished, 4 - refunded
    mapping(uint256 round => uint256 status) public roundStatus;

    event MaxBetsChanged(uint256 indexed max);

    constructor(address _liro, uint256 _interval) Table(_liro) {
        interval = _interval;
        token = IERC20(liro.token());
    }

    function getCurrentRound() public view returns (uint256) {
        return block.timestamp / interval;
    }

    function placeBet(bytes memory data) external override onlyLiro returns (address, uint256) {
        // decode the data
        (Library.Bet[] memory _bitmaps, address _table, uint256 _round, address _player) =
            abi.decode(data, (Library.Bet[], address, uint256, address));
        // check table
        require(_table == address(this), "MP02");
        // validate round
        require(_round == getCurrentRound(), "MP01");
        // check max bets
        require(roundBets[_round].length < MAX_BETS, "MP07");
        // calculate possibleWin and total amount of all bitmaps
        (uint256 possibleWin, uint256 totalAmount) = getPossibleWin(_bitmaps);
        // increase the bank
        roundBank[_round] += totalAmount;
        // create bet
        LiroBet bet = new LiroBet(_player, totalAmount, address(liro), _table, _round);
        // set bet bitmap
        bet.setBets(_bitmaps);
        // add bet to the round
        roundBets[_round].push(bet);
        // get allowed to win
        uint256 allowedToWin = (liro.token().balanceOf(liro.getStaking()) + roundReserved[_round]) * 5 / 100;
        // check if the possible win is allowed
        require(allowedToWin >= possibleWin, "MP03");
        // update round status if needed
        roundStatus[_round] = roundStatus[_round] == 0 ? 1 : roundStatus[_round];
        // update reserved funds
        roundReserved[_round] += possibleWin;
        // emit event
        emit BetPlaced(address(bet), _round);
        // return the bet address
        return (address(bet), possibleWin);
    }

    function spin(uint256 _round) external onlyLiro returns (bytes memory) {
        // check if round is older than the current round
        require(_round < getCurrentRound(), "MP01");
        // check if round status is 1
        require(roundStatus[_round] == 1, "MP04");
        // check if the bank is above the maximum limit
        require(liro.token().balanceOf(address(this)) >= roundReserved[_round], "MP05"); // should not happen
        // update round status
        roundStatus[_round] = 2;
        // update round spinned
        roundSpinned[_round] = block.timestamp;
        // return spin encoded data
        return abi.encode(false, address(this), _round);
    }

    function result(uint256 _round, uint256 _winNumber) external onlyLiro {
        // check round status
        require(roundStatus[_round] == 2, "MP04");
        // upate round status
        roundStatus[_round] = 3;
        // calculate token amount sent to players
        uint256 sent = 0;
        // get amount reserved for the round
        uint256 reserved = roundReserved[_round];
        // iterate over bets
        for (uint256 i = 0; i < roundBets[_round].length; i++) {
            // get bet
            LiroBet bet = roundBets[_round][i];
            // get bet bitmaps
            (uint256[] memory amounts, uint256[] memory bitmaps) = bet.getBets();
            // calculate win amount
            uint256 winAmount = 0;
            // iterate over all bitmaps
            for (uint256 j = 0; j < amounts.length; j++) {
                // get bitmap
                uint256 bitmap = bitmaps[j];
                // check if bitmap is winning
                if (bitmap & (2 ** _winNumber) > 0) {
                    // get payout for bitmap
                    (uint256 payout,,) = getBitMapPayout(bitmap);
                    // calculate win amount
                    winAmount += amounts[j] * payout + amounts[j];
                }
            }
            // transfer the win amount
            if (winAmount > 0) {
                // transfer win amount to player
                token.transfer(bet.getPlayer(), winAmount);
                // set the result
                bet.setResult(winAmount);
                // increase sent amount
                sent += winAmount;
            }
            // set the win number
            bet.setWinNumber(_winNumber);
            // emit event
            emit BetEnded(address(bet), _round, _winNumber, winAmount);
        }
        // check if sent amount is less than reserved
        if (sent < reserved) {
            // calculate how much is left
            uint256 rest = reserved - sent;
            // transfer the rest to the staking
            token.transfer(address(liro.getStaking()), rest);
        }
        // transfer bet amount to staking
        token.transferFrom(address(liro), address(liro.getStaking()), roundBank[_round]);
    }

    function refund(uint256 round) external onlyLiro {
        uint256 status = roundStatus[round];
        // refund if:
        if (status == 1) {
            // - REFUND_PERIOD has passed after the round end and round not yet spinned
            require(block.timestamp - (round + 1) * interval > REFUND_PERIOD, "MP06");
        } else if (status == 2) {
            // - REFUND_PERIOD has passed after the round spinned
            require(block.timestamp - roundSpinned[round] > REFUND_PERIOD, "MP06");
        } else {
            revert("MP04");
        }
        // set the round status to 4
        roundStatus[round] = 4;
        // iterate over bets
        for (uint256 i = 0; i < roundBets[round].length; i++) {
            // get bet
            LiroBet bet = roundBets[round][i];
            // get bet amount
            uint256 amount = bet.getAmount();
            // transfer the amount back to the player
            token.transferFrom(address(liro), bet.getPlayer(), amount);
            // set the result
            bet.refund();
        }
        token.transfer(address(liro.getStaking()), roundReserved[round]);
    }

    function getRoundBank(uint256 _round) external view returns (uint256) {
        return roundBank[_round];
    }

    function setMaxBets(uint256 _max) external onlyLiro {
        require(_max >= 10 && _max <= 100, "MP08");
        MAX_BETS = _max;
    }
}
