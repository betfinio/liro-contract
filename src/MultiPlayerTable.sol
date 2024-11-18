// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

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
 */

contract MultiPlayerTable is Table {
    uint256 public constant REFUND_PERIOD = 1 days;

    uint256 public constant MAX_BETS = 100;

    uint256 public immutable interval;

    mapping(uint256 round => uint256 bank) public roundBank;
    mapping(uint256 round => LiroBet[] bets) public roundBets;
    mapping(uint256 round => Library.Bet[] bitmaps) public roundBitmaps;
    mapping(uint256 round => uint256 win) public roundPossibleWin;
    // 0 - not exists, 1 - created, 2 - requested, 3 - finished, 4 - refunded
    mapping(uint256 round => uint256 status) public roundStatus;
    mapping(uint256 round => uint256 spinned) public roundSpinned;

    constructor(address _liro, uint256 _interval) Table(_liro) {
        interval = _interval;
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
        // get allowed to win
        uint256 allowedToWin = (liro.token().balanceOf(liro.getStaking()) + roundPossibleWin[_round]) * 5 / 100;
        // check if the possible win is allowed
        require(allowedToWin >= maxPossibleWin, "MP03"); // update round status if needed
        if (roundStatus[_round] == 0) {
            roundStatus[_round] = 1;
        }
        uint256 diff = maxPossibleWin - roundPossibleWin[_round];
        roundPossibleWin[_round] = maxPossibleWin;
        // return the bet address
        return (address(bet), diff);
    }

    function spin(uint256 _round) external onlyLiro returns (bytes memory) {
        // check if round is older than the current round
        require(_round < getCurrentRound(), "MP01");
        // check if round status is 1
        require(roundStatus[_round] == 1, "MP04");
        // check if the bank is above the maximum limit
        require(liro.token().balanceOf(address(this)) >= roundPossibleWin[_round], "MP05"); // should not happen
        roundStatus[_round] = 2;
        roundSpinned[_round] = block.timestamp;
        return abi.encode(false, address(this), _round);
    }

    function result(uint256 _round, uint256 _winNumber) external onlyLiro {
        // check round status
        require(roundStatus[_round] == 2, "MP04");
        roundStatus[_round] = 3;
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
        }

        // check the round status
        require(status >= 1 && status < 3, "MP04"); // status 1 - created, 2 - requested\
        // set the round status to 4
        roundStatus[round] = 4;
        // get address token
        address token = address(liro.token());
        // iterate over bets
        for (uint256 i = 0; i < roundBets[round].length; i++) {
            // get bet
            LiroBet bet = roundBets[round][i];
            // get bet amount
            uint256 amount = bet.getAmount();
            // transfer the amount back to the player
            IERC20(token).transferFrom(address(liro), bet.getPlayer(), amount);
            // set the result
            bet.refund();
        }
        IERC20(token).transfer(address(liro.getStaking()), roundPossibleWin[round]);
    }

    function getRoundBank(uint256 _round) external view returns (uint256) {
        return roundBank[_round];
    }
}
