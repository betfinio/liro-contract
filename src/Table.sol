// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Library } from "./Library.sol";
import { LiveRoulette } from "./LiveRoulette.sol";

/**
 * Error Codes:
 * LT01: Only the LiveRoulette contract can call this function
 * LT02: Bet amount is below the minimum limit
 * LT03: Bet amount is above the maximum limit
 * LT04: Invalid bitmap
 */
abstract contract Table is Ownable {
    LiveRoulette public liro;

    mapping(string name => Library.Limit limit) public limits;
    mapping(uint256 bitmap => string name) public payouts;

    modifier onlyLiro() {
        // check if the caller is the LiveRoulette contract
        require(msg.sender == address(liro), "LT01");
        _;
    }

    constructor(address _liro) Ownable(_msgSender()) {
        liro = LiveRoulette(_liro);
        setUpLimits();
        setUpPayouts();
    }

    function setLimit(string memory _name, uint256 _min, uint256 _max, uint256 _payout) public onlyOwner {
        limits[_name] = Library.Limit(_min, _max, _payout);
    }

    function placeBet(bytes memory data) external virtual returns (address, uint256);

    function validateLimits(Library.Bet[] memory _bitmaps) public view {
        for (uint256 i = 0; i < _bitmaps.length; i++) {
            (, uint256 _min, uint256 _max) = getBitMapPayout(_bitmaps[i].bitmap);
            require(_bitmaps[i].amount >= _min, "LT02");
            require(_bitmaps[i].amount <= _max, "LT03");
        }
    }

    function getPossibleWin(Library.Bet[] memory _bitmaps) public view returns (uint256, uint256) {
        uint256 maxPossible = 0;
        uint256 winNumber = 42;
        uint256 count = _bitmaps.length;
        for (uint256 i = 0; i <= 36; i++) {
            uint256 possible = 0;
            for (uint256 k = 0; k < count; k++) {
                uint256 amount = _bitmaps[k].amount;
                uint256 bitmap = _bitmaps[k].bitmap;
                (uint256 payout,,) = getBitMapPayout(bitmap);
                if (bitmap & (2 ** i) > 0) {
                    possible += amount * payout + amount;
                }
                if (possible > maxPossible) {
                    maxPossible = possible;
                    winNumber = i;
                }
            }
        }
        return (maxPossible, winNumber);
    }

    function setUpLimits() internal {
        limits["STRAIGHT"] = Library.Limit(10_000 ether, 150_000 ether, 35);
        limits["TOP-LINE"] = Library.Limit(10_000 ether, 650_000 ether, 8);
        limits["LOW-ZERO"] = Library.Limit(10_000 ether, 500_000 ether, 11);
        limits["HIGH-ZERO"] = Library.Limit(10_000 ether, 500_000 ether, 11);
        limits["LOW"] = Library.Limit(10_000 ether, 3_000_000 ether, 1);
        limits["HIGH"] = Library.Limit(10_000 ether, 3_000_000 ether, 1);
        limits["EVEN"] = Library.Limit(10_000 ether, 3_000_000 ether, 1);
        limits["ODD"] = Library.Limit(10_000 ether, 3_000_000 ether, 1);
        limits["RED"] = Library.Limit(10_000 ether, 3_000_000 ether, 1);
        limits["BLACK"] = Library.Limit(10_000 ether, 3_000_000 ether, 1);
        limits["1-DOZEN"] = Library.Limit(15_000 ether, 2_000_000 ether, 2);
        limits["2-DOZEN"] = Library.Limit(15_000 ether, 2_000_000 ether, 2);
        limits["3-DOZEN"] = Library.Limit(15_000 ether, 2_000_000 ether, 2);
        limits["1-COLUMN"] = Library.Limit(15_000 ether, 2_000_000 ether, 2);
        limits["2-COLUMN"] = Library.Limit(15_000 ether, 2_000_000 ether, 2);
        limits["3-COLUMN"] = Library.Limit(15_000 ether, 2_000_000 ether, 2);
        limits["CORNER"] = Library.Limit(10_000 ether, 650_000 ether, 8);
        limits["ROW"] = Library.Limit(10_000 ether, 500_000 ether, 11);
        limits["SPLIT"] = Library.Limit(10_000 ether, 330_000 ether, 17);
    }

    function setUpPayouts() internal {
        payouts[15] = "TOP-LINE";
        payouts[7] = "LOW-ZERO";
        payouts[13] = "HIGH-ZERO";
        payouts[524_286] = "LOW";
        payouts[137_438_429_184] = "HIGH";
        payouts[91_625_968_980] = "EVEN";
        payouts[45_812_984_490] = "ODD";
        payouts[91_447_186_090] = "RED";
        payouts[45_991_767_380] = "BLACK";
        payouts[8190] = "1-DOZEN";
        payouts[33_546_240] = "2-DOZEN";
        payouts[137_405_399_040] = "3-DOZEN";
        payouts[78_536_544_840] = "1-COLUMN";
        payouts[39_268_272_420] = "2-COLUMN";
        payouts[19_634_136_210] = "3-COLUMN";
    }

    function getBitMapPayout(uint256 bitmap) public view returns (uint256, uint256, uint256) {
        // return invalid bitmap
        if (bitmap == 0) {
            revert("LT04");
        }
        // check for straight 0,1,2,3...36
        if (bitmap & (bitmap - 1) == 0) {
            return (35, limits["STRAIGHT"].min, limits["STRAIGHT"].max);
        }
        // check for corner
        if (isCorner(bitmap)) {
            return (8, limits["CORNER"].min, limits["CORNER"].max);
        }
        // check for row
        if (isRow(bitmap)) {
            return (11, limits["ROW"].min, limits["ROW"].max);
        }
        // check for split
        if (isSplit(bitmap)) {
            return (17, limits["SPLIT"].min, limits["SPLIT"].max);
        }
        // get limit
        string memory name = payouts[bitmap];
        require(limits[name].payout > 0, "LT04");
        return (limits[name].payout, limits[name].min, limits[name].max);
    }

    function isRow(uint256 bitmap) public pure returns (bool) {
        uint256[12] memory rows = [
            14, // 1,2,3
            112, // 4,5,6
            896, // 7,8,9
            7168, // 10,11,12
            57_344, // 13,14,15
            458_752, // 16,17,18
            3_670_016, // 19,20,21
            29_360_128, // 22,23,24
            234_881_024, // 25,26,27
            1_879_048_192, // 28,29,30
            15_032_385_536, // 31,32,33
            uint256(120_259_084_288) // 34,35,36
        ];
        for (uint256 i = 0; i < rows.length; i++) {
            if (bitmap == rows[i]) return true;
        }
        return false;
    }

    function isCorner(uint256 bitmap) public pure returns (bool) {
        uint256[22] memory corners = [
            54, // 1,2,4,5
            108, // 2,3,5,6
            432, // 4,5,7,8
            864, // 5,6,8,9
            3456, // 7,8,10,11
            6912, // 8,9,11,12
            27_648, // 10,11,13,14
            55_296, // 11,12,14,15
            221_184, // 13,14,16,17
            442_368, // 14,15,17,18
            1_769_472, // 16,17,19,20
            3_538_944, // 17,18,20,21
            14_155_776, // 19,20,22,23
            28_311_552, // 20,21,23,24
            113_246_208, // 22,23,25,26
            226_492_416, // 23,24,26,27
            905_969_664, // 25,26,28,29
            1_811_939_328, // 26,27,29,30
            7_247_757_312, // 28,29,31,32
            14_495_514_624, // 29,30,32,33
            57_982_058_496, // 31,32,34,35
            uint256(115_964_116_992) // 32,33,35,36
        ];
        for (uint256 i = 0; i < corners.length; i++) {
            if (bitmap == corners[i]) return true;
        }
        return false;
    }

    function isSplit(uint256 bitmap) public pure returns (bool) {
        uint256[60] memory splits = [
            3,
            5,
            9,
            6,
            12,
            18,
            36,
            48,
            72,
            96,
            144,
            288,
            384,
            576,
            768,
            1152,
            2304,
            3072,
            4608,
            6144,
            9216,
            18_432,
            24_576,
            36_864,
            49_152,
            73_728,
            147_456,
            196_608,
            294_912,
            393_216,
            589_824,
            1_179_648,
            1_572_864,
            2_359_296,
            3_145_728,
            4_718_592,
            9_437_184,
            12_582_912,
            18_874_368,
            25_165_824,
            37_748_736,
            75_497_472,
            100_663_296,
            150_994_944,
            201_326_592,
            301_989_888,
            603_979_776,
            805_306_368,
            1_207_959_552,
            1_610_612_736,
            2_415_919_104,
            4_831_838_208,
            6_442_450_944,
            9_663_676_416,
            12_884_901_888,
            19_327_352_832,
            38_654_705_664,
            51_539_607_552,
            77_309_411_328,
            uint256(103_079_215_104)
        ];
        for (uint256 i = 0; i < splits.length; i++) {
            if (bitmap == splits[i]) return true;
        }
        return false;
    }
}
