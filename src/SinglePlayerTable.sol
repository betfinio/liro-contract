// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

import { Library } from "./Library.sol";
import { Table } from "./Table.sol";
import { LiroBet } from "./LiroBet.sol";

/**
 * Error Codes:
 * SP01: Bet is not pending
 * SP02: Possible win is not allowed
 * SP03: Invalid refund period
 */
contract SinglePlayerTable is Table {
    uint256 public constant REFUND_PERIOD = 1 days;
    mapping(address bet => uint256 possibleWin) public betPossibleWin;

    constructor(address _liro) Table(_liro) { }

    function placeBet(bytes memory data) external override onlyLiro returns (address, uint256) {
        // decode the data
        (Library.Bet[] memory _bitmaps,,, address _player) =
            abi.decode(data, (Library.Bet[], address, uint256, address));
        // validate limits of each bet
        validateLimits(_bitmaps);
        // calculate possible win
        (uint256 possibleWin,) = getPossibleWin(_bitmaps);
        // calculate amount
        uint256 amount = Library.getBitmapsAmount(_bitmaps);
        // create bet
        LiroBet bet = new LiroBet(_player, amount, address(liro), address(this), 0);
        // set bet bitmap
        bet.setBets(_bitmaps);
        // store the bet
        betPossibleWin[address(bet)] = possibleWin;
        // get allowed to win
        uint256 allowedToWin = liro.token().balanceOf(liro.getStaking()) * 5 / 100;
        // check if the possible win is allowed
        require(allowedToWin >= possibleWin, "SP02");
        // return bet address and possible win
        return (address(bet), possibleWin);
    }

    function refund(address _bet) external {
        LiroBet bet = LiroBet(_bet);
        // check if the bet is pending
        require(bet.getStatus() == 1, "SP01");
        // check if the refund period is over
        require(block.timestamp - bet.getCreated() > REFUND_PERIOD, "SP03");
        // set the status
        bet.refund();
        // transfer possible win back to staking
        liro.token().transfer(address(liro.staking()), betPossibleWin[_bet]);
        // transfer intial bet amount back to player
        liro.token().transferFrom(address(liro), bet.getPlayer(), bet.getAmount());
    }

    function result(address _bet, uint256 win) external onlyLiro {
        LiroBet bet = LiroBet(_bet);
        // check if the bet is pending
        require(bet.getStatus() == 1, "SP01");

        // extract bitmaps
        (uint256[] memory amounts, uint256[] memory bitmaps) = bet.getBets();
        // calculate the result
        uint256 winAmount = 0;
        for (uint256 i = 0; i < bitmaps.length; i++) {
            uint256 bitmap = bitmaps[i];
            if (bitmap & (2 ** win) > 0) {
                (uint256 payout,,) = getBitMapPayout(bitmap);
                winAmount += amounts[i] * payout + amounts[i];
            }
        }
        // set the win number
        bet.setWinNumber(win);
        if (winAmount > 0) {
            // set the result
            bet.setResult(winAmount);
            // transfer the win amount
            liro.token().transfer(bet.getPlayer(), winAmount);
            // transfer rest to staking
            uint256 rest = betPossibleWin[_bet] - winAmount;
            if (rest > 0) {
                liro.token().transfer(address(liro.staking()), rest);
            }
        } else {
            // set the result
            bet.setResult(0);
        }
        // transfer initial bet amount to staking
        liro.token().transferFrom(address(liro), address(liro.getStaking()), bet.getAmount());
    }
}
