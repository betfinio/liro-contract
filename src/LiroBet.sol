// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { BetInterface } from "./interfaces/BetInterface.sol";
import { Library } from "./Library.sol";
/*
 * Errors:
 * LB01: Invalid bets length
 */

contract LiroBet is BetInterface, Ownable {
    uint256 private immutable created;
    address private immutable player;
    uint256 private immutable amount;
    address private immutable game;

    address private immutable table;
    uint256 private immutable round;

    // 1 - created
    // 2 - finished
    // 3 - refunded
    uint256 private status;
    uint256 private result;
    uint256 public winNumber = 42; // 0-36, 42 - undefined

    Library.Bet[] private bets;

    constructor(
        address _player,
        uint256 _amount,
        address _game,
        address _table,
        uint256 _round
    )
        Ownable(_msgSender())
    {
        player = _player;
        amount = _amount;
        status = 1;
        game = _game;
        created = block.timestamp;
        table = _table;
        round = _round;
    }

    function setBets(Library.Bet[] memory _bets) public onlyOwner {
        for (uint256 i = 0; i < _bets.length; i++) {
            bets.push(_bets[i]);
        }
        require(bets.length == _bets.length, "LB01");
    }

    function getBetsCount() public view returns (uint256) {
        return bets.length;
    }

    function getBet(uint256 index) public view returns (uint256, uint256) {
        return (bets[index].amount, bets[index].bitmap);
    }

    function getBets() public view returns (uint256[] memory amounts, uint256[] memory bitmaps) {
        uint256 count = bets.length;
        amounts = new uint256[](count);
        bitmaps = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            amounts[i] = bets[i].amount;
            bitmaps[i] = bets[i].bitmap;
        }
        return (amounts, bitmaps);
    }
    /**
     * @return player - address of player
     */

    function getPlayer() external view override returns (address) {
        return player;
    }

    /**
     * @return amount - amount of bet
     */
    function getAmount() external view override returns (uint256) {
        return amount;
    }

    /**
     * @return result - amount of payout
     */
    function getResult() external view override returns (uint256) {
        return result;
    }

    /**
     * @return status - status of bet
     */
    function getStatus() external view override returns (uint256) {
        return status;
    }

    /**
     * @return game - address of game
     */
    function getGame() external view override returns (address) {
        return game;
    }

    /**
     * @return timestamp - created timestamp of bet
     */
    function getCreated() external view override returns (uint256) {
        return created;
    }

    /**
     * @return data - all data at once (player, game, amount, result, status, created)
     */
    function getBetInfo() external view override returns (address, address, uint256, uint256, uint256, uint256) {
        return (player, game, amount, result, status, created);
    }

    function setResult(uint256 _result) external onlyOwner {
        result = _result;
    }

    function setStatus(uint256 _status) external onlyOwner {
        status = _status;
    }

    function setWinNumber(uint256 _winNumber) external onlyOwner {
        winNumber = _winNumber;
        status = 2;
    }

    function refund() external onlyOwner {
        status = 3;
        result = amount;
    }
}
