// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BetInterface } from "./interfaces/BetInterface.sol";
import { Library } from "./Library.sol";
import { Table } from "./Table.sol";
import { console } from "forge-std/src/console.sol";

contract SinglePlayerTable is Table {
    constructor(address _liro) Table(_liro) { }

    function placeBet(bytes memory data) external view override onlyLiro returns (address, int256) {
        // decode the data
        (Library.Bet[] memory _bitmaps,,,) = abi.decode(data, (Library.Bet[], address, uint256, address));
        // validate limits of each bet
        validateLimits(_bitmaps);
        // calculate possible win
        (uint256 possibleWin,) = getPossibleWin(_bitmaps);
        uint256 amount = Library.getBitmapsAmount(_bitmaps);

        return (address(0), 0);
    }

    function result(address _bet, uint256 win) external { }

    function refund(uint256, address _bet) external override { }

    function spin(uint256 _round) external view override returns (bytes memory) {
        console.log("SinglePlayerTable.spin", _round);
        return abi.encode(true, address(0), 0);
    }
}
