// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

/**
 * Error Codes:
 * LB01: Invalid amount
 */
library Library {
    struct Bet {
        uint256 amount;
        uint256 bitmap;
    }

    struct Limit {
        uint256 min;
        uint256 max;
        uint256 payout;
    }

    function getBitmapsAmount(Bet[] memory _bets) internal pure returns (uint256 amount) {
        for (uint256 i = 0; i < _bets.length; i++) {
            // amount shoud bew greater than 0
            require(_bets[i].amount > 0, "LB01");
            amount += _bets[i].amount;
        }
    }
}
