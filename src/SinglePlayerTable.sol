// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BetInterface } from "./interfaces/BetInterface.sol";
import { Library } from "./Library.sol";
import { Table } from "./Table.sol";

contract SinglePlayerTable is Table {
    constructor(address _liro) Table(_liro) { }

    function placeBet(bytes memory data) external override onlyLiro returns (address) {
        // decode the data
        (Library.Bet[] memory _bitmaps, address _table, uint256 _round, address _player) =
            abi.decode(data, (Library.Bet[], address, uint256, address));
        // validate limits of each bet
        validateLimits(_bitmaps);

        return address(0);
    }
}
