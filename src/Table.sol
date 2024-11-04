// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BetInterface } from "./interfaces/BetInterface.sol";
import { Library } from "./Library.sol";
import { LiveRoulette } from "./LiveRoulette.sol";

/**
 * Error Codes:
 * LT01: Only the LiveRoulette contract can call this function
 * LT02: Bet amount is below the minimum limit
 * LT03: Bet amount is above the maximum limit
 */
abstract contract Table is Ownable {
    LiveRoulette public liro;

    mapping(string name => Library.Limit limit) public limits;

    modifier onlyLiro() {
        // check if the caller is the LiveRoulette contract
        require(msg.sender == address(liro), "LT01");
        _;
    }

    constructor(address _liro) Ownable(_msgSender()) {
        liro = LiveRoulette(_liro);
        setUpLimits();
    }

    function setUpLimits() internal {
        limits["STRAIGHT"] = Library.Limit(10_000 ether, 150_000 ether);
        limits["TOP-LINE"] = Library.Limit(10_000 ether, 650_000 ether);
        limits["LOW-ZERO"] = Library.Limit(10_000 ether, 500_000 ether);
        limits["HIGH-ZERO"] = Library.Limit(10_000 ether, 500_000 ether);
        limits["LOW"] = Library.Limit(20_000 ether, 3_000_000 ether);
        limits["HIGH"] = Library.Limit(20_000 ether, 3_000_000 ether);
        limits["EVEN"] = Library.Limit(20_000 ether, 3_000_000 ether);
        limits["ODD"] = Library.Limit(20_000 ether, 3_000_000 ether);
        limits["RED"] = Library.Limit(20_000 ether, 3_000_000 ether);
        limits["BLACK"] = Library.Limit(20_000 ether, 3_000_000 ether);
        limits["1-DOZEN"] = Library.Limit(15_000 ether, 2_000_000 ether);
        limits["2-DOZEN"] = Library.Limit(15_000 ether, 2_000_000 ether);
        limits["3-DOZEN"] = Library.Limit(15_000 ether, 2_000_000 ether);
        limits["1-COLUMN"] = Library.Limit(15_000 ether, 2_000_000 ether);
        limits["2-COLUMN"] = Library.Limit(15_000 ether, 2_000_000 ether);
        limits["3-COLUMN"] = Library.Limit(15_000 ether, 2_000_000 ether);
        limits["CORNER"] = Library.Limit(10_000 ether, 650_000 ether);
        limits["ROW"] = Library.Limit(10_000 ether, 500_000 ether);
        limits["SPLIT"] = Library.Limit(10_000 ether, 330_000 ether);
    }

    function setLimit(string memory _name, uint256 _min, uint256 _max) public onlyOwner {
        limits[_name] = Library.Limit(_min, _max);
    }

    function placeBet(bytes memory data) external virtual returns (address);

    function validateLimits(Library.Bet[] memory _bitmaps) public view {
        for (uint256 i = 0; i < _bitmaps.length; i++) {
            (uint256 _payout, uint256 _min, uint256 _max) = getBitMapPayout(_bitmaps[i].bitmap);
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

    function getBitMapPayout(uint256 bitmap) public view returns (uint256, uint256, uint256) {
        // return invalid bitmap
        if (bitmap == 0) {
            return (0, 0, 0);
        }
        // check for TOP LINE 0,1,2,3
        if (bitmap == 15) {
            return (8, limits["TOP-LINE"].min, limits["TOP-LINE"].max);
        }
        // check for LOW ZERO 0,1,2
        if (bitmap == 7) {
            return (11, limits["LOW-ZERO"].min, limits["LOW-ZERO"].max);
        }
        // check for HIGH ZERO 0,2,3
        if (bitmap == 13) {
            return (11, limits["HIGH-ZERO"].min, limits["HIGH-ZERO"].max);
        }
        // check for LOW 1-18
        if (bitmap == 524_286) {
            return (1, limits["LOW"].min, limits["LOW"].max);
        }
        // check for HIGH 19-36
        if (bitmap == 137_438_429_184) {
            return (1, limits["HIGH"].min, limits["HIGH"].max);
        }
        // check for EVEN
        if (bitmap == 91_625_968_980) {
            return (1, limits["EVEN"].min, limits["EVEN"].max);
        }
        // check for ODD
        if (bitmap == 45_812_984_490) {
            return (1, limits["ODD"].min, limits["ODD"].max);
        }
        // check for RED
        if (bitmap == 91_447_186_090) {
            return (1, limits["RED"].min, limits["RED"].max);
        }
        // check for BLACK
        if (bitmap == 45_991_767_380) {
            return (1, limits["BLACK"].min, limits["BLACK"].max);
        }
        // check for 1-dozen
        if (bitmap == 8190) {
            return (2, limits["1-DOZEN"].min, limits["1-DOZEN"].max);
        }
        // check for 2-dozen
        if (bitmap == 33_546_240) {
            return (2, limits["2-DOZEN"].min, limits["2-DOZEN"].max);
        }
        // check for 3-dozen
        if (bitmap == 137_405_399_040) {
            return (2, limits["3-DOZEN"].min, limits["3-DOZEN"].max);
        }
        // check for 1-column
        if (bitmap == 78_536_544_840) {
            return (2, limits["1-COLUMN"].min, limits["1-COLUMN"].max);
        }
        // check for 2-column
        if (bitmap == 39_268_272_420) {
            return (2, limits["2-COLUMN"].min, limits["2-COLUMN"].max);
        }
        // check for 3-column
        if (bitmap == 19_634_136_210) {
            return (2, limits["3-COLUMN"].min, limits["3-COLUMN"].max);
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
        return (0, 0, 0);
    }

    function isRow(uint256 bitmap) public pure returns (bool) {
        // check 1,2,3
        if (bitmap == 14) return true;
        // check 4,5,6
        if (bitmap == 112) return true;
        // check 7,8,9
        if (bitmap == 896) return true;
        // check 10,11,12
        if (bitmap == 7168) return true;
        // check 13,14,15
        if (bitmap == 57_344) return true;
        // check 16,17,18
        if (bitmap == 458_752) return true;
        // check 19,20,21
        if (bitmap == 3_670_016) return true;
        // check 22,23,24
        if (bitmap == 29_360_128) return true;
        // check 25,26,27
        if (bitmap == 234_881_024) return true;
        // check 28,29,30
        if (bitmap == 1_879_048_192) return true;
        // check 31,32,33
        if (bitmap == 15_032_385_536) return true;
        // check 34,35,36
        if (bitmap == 120_259_084_288) return true;
        return false;
    }

    function isCorner(uint256 bitmap) public pure returns (bool) {
        // check 1,2,4,5
        if (bitmap == 54) return true;
        // check 2,3,5,6
        if (bitmap == 108) return true;
        // check 4,5,7,8
        if (bitmap == 432) return true;
        // check 5,6,8,9
        if (bitmap == 864) return true;
        // check 7,8,10,11
        if (bitmap == 3456) return true;
        // check 8,9,11,12
        if (bitmap == 6912) return true;
        // check 10,11,13,14
        if (bitmap == 27_648) return true;
        // check 11,12,14,15
        if (bitmap == 55_296) return true;
        // check 13,14,16,17
        if (bitmap == 221_184) return true;
        // check 14,15,17,18
        if (bitmap == 442_368) return true;
        // check 16,17,19,20
        if (bitmap == 1_769_472) return true;
        // check 17,18,20,21
        if (bitmap == 3_538_944) return true;
        // check 19,20,22,23
        if (bitmap == 14_155_776) return true;
        // check 20,21,23,24
        if (bitmap == 28_311_552) return true;
        // check 22,23,25,26
        if (bitmap == 113_246_208) return true;
        // check 23,24,26,27
        if (bitmap == 226_492_416) return true;
        // check 25,26,28,29
        if (bitmap == 905_969_664) return true;
        // check 26,27,29,30
        if (bitmap == 1_811_939_328) return true;
        // check 28,29,31,32
        if (bitmap == 7_247_757_312) return true;
        // check 29,30,32,33
        if (bitmap == 14_495_514_624) return true;
        // check 31,32,34,35
        if (bitmap == 57_982_058_496) return true;
        // check 32,33,35,36
        if (bitmap == 115_964_116_992) return true;
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
