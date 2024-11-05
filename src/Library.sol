// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

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
            amount += _bets[i].amount;
        }
    }
}
