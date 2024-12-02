// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    using SafeERC20 for IERC20;

    LiveRoulette public liro;

    mapping(string name => Library.Limit limit) public limits;
    mapping(uint256 bitmap => string name) private payouts;

    event LimitChanged(string indexed limit, uint256 min, uint256 max);
    event BetPlaced(address indexed bet, uint256 round);

    modifier onlyLiro() {
        // check if the caller is the LiveRoulette contract
        require(msg.sender == address(liro), "LT01");
        _;
    }

    constructor(address _liro) Ownable(msg.sender) {
        liro = LiveRoulette(_liro);
        setUpLimits();
        setUpPayouts();
        setUpRows();
        setUpCorners();
        setUpSplits();
        setUpGroups();
    }

    function setLimit(string memory _name, uint256 _min, uint256 _max) public onlyOwner {
        Library.Limit storage _limit = limits[_name];
        limits[_name] = Library.Limit(_min, _max, _limit.payout);
        emit LimitChanged(_name, _min, _max);
    }

    function placeBet(bytes memory data) external virtual returns (address, uint256);

    /**
     * New implementation of possible win calculating:
     * just check payout for every combination of bets
     *
     * @param _bitmaps - array of bets
     * @return maxPossible - maximum possible win
     * @return totalAmount - total amount of bets
     */
    function getPossibleWin(
        Library.Bet[] memory _bitmaps
    )
        public
        view
        returns (uint256 maxPossible, uint256 totalAmount)
    {
        uint256 count = _bitmaps.length;
        for (uint256 k = 0; k < count; k++) {
            Library.Bet memory _bitmap = _bitmaps[k];
            uint256 amount = _bitmap.amount;
            uint256 bitmap = _bitmap.bitmap;
            (uint256 _payout, uint256 _min, uint256 _max) = getBitMapPayout(bitmap);
            require(amount >= _min, "LT02");
            require(amount <= _max, "LT03");
            totalAmount += amount;
            maxPossible += amount * _payout + amount;
        }
    }

    function setUpLimits() internal {
        limits["STRAIGHT"] = Library.Limit(10_000 ether, 150_000 ether, 35);
        limits["TOP-LINE"] = Library.Limit(10_000 ether, 650_000 ether, 8);
        limits["LOW-ZERO"] = Library.Limit(10_000 ether, 500_000 ether, 11);
        limits["HIGH-ZERO"] = Library.Limit(10_000 ether, 500_000 ether, 11);
        limits["BASIC"] = Library.Limit(10_000 ether, 3_000_000 ether, 1);
        limits["DOZEN"] = Library.Limit(15_000 ether, 2_000_000 ether, 2);
        limits["COLUMN"] = Library.Limit(15_000 ether, 2_000_000 ether, 2);
        limits["CORNER"] = Library.Limit(10_000 ether, 650_000 ether, 8);
        limits["ROW"] = Library.Limit(10_000 ether, 500_000 ether, 11);
        limits["SPLIT"] = Library.Limit(10_000 ether, 330_000 ether, 17);
        limits["GROUP"] = Library.Limit(10_000 ether, 330_000 ether, 5);
    }

    function setUpPayouts() internal {
        payouts[15] = "TOP-LINE";
        payouts[7] = "LOW-ZERO";
        payouts[13] = "HIGH-ZERO";
        payouts[524_286] = "BASIC";
        payouts[137_438_429_184] = "BASIC";
        payouts[91_625_968_980] = "BASIC";
        payouts[45_812_984_490] = "BASIC";
        payouts[91_447_186_090] = "BASIC";
        payouts[45_991_767_380] = "BASIC";
        payouts[8190] = "DOZEN";
        payouts[33_546_240] = "DOZEN";
        payouts[137_405_399_040] = "DOZEN";
        payouts[78_536_544_840] = "COLUMN";
        payouts[39_268_272_420] = "COLUMN";
        payouts[19_634_136_210] = "COLUMN";
    }

    function getBitMapPayout(uint256 bitmap) public view returns (uint256, uint256, uint256) {
        // return invalid bitmap
        require(bitmap != 0, "LT04");
        // get payout name
        string memory name = payouts[bitmap];
        // check for straight 0,1,2,3...36
        name = bitmap & (bitmap - 1) == 0 ? "STRAIGHT" : name;
        // get limit
        Library.Limit memory limit = limits[name];
        // revert if limit is not set
        require(limit.payout > 0, "LT04");
        // return limit
        return (limit.payout, limit.min, limit.max);
    }

    function setUpGroups() internal {
        uint256[11] memory groups = [
            126, // 1,2,3,4,5,6
            1008, // 4,5,6,7,8,9
            8064, // 7,8,9,10,11,12
            64_512, // 10,11,12,13,14,15
            516_096, // 13,14,15,16,17,18
            4_128_768, // 16,17,18,19,20,21
            33_030_144, // 19,20,21,22,23,24
            264_241_152, // 22,23,24,25,26,27
            2_113_929_216, // 25,26,27,28,29,30
            16_911_433_728, // 28,29,30,31,32,33
            uint256(135_291_469_824) // 31,32,33,34,35,36
        ];
        for (uint256 i = 0; i < groups.length; i++) {
            payouts[groups[i]] = "GROUP";
        }
    }

    function setUpRows() internal {
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
            payouts[rows[i]] = "ROW";
        }
    }

    function setUpCorners() internal {
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
            payouts[corners[i]] = "CORNER";
        }
    }

    function setUpSplits() internal {
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
            payouts[splits[i]] = "SPLIT";
        }
    }
}
