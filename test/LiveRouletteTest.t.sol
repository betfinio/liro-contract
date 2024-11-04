// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { CoreInterface } from "src/interfaces/CoreInterface.sol";
import { PartnerInterface } from "src/interfaces/PartnerInterface.sol";
import { StakingInterface } from "src/interfaces/StakingInterface.sol";
import { PassInterface } from "src/interfaces/PassInterface.sol";
import { Token } from "src/Token.sol";
import { LiveRoulette } from "src/LiveRoulette.sol";
import { LiroBet } from "src/LiroBet.sol";
import { Library } from "src/Library.sol";
import { MultiPlayerTable } from "src/MultiPlayerTable.sol";

contract LiveRouletteTest is Test {
    address public alice = address(1);
    address public bob = address(2);

    LiveRoulette public game;
    Token public token;
    address staking = address(888);
    address operator = address(999);
    address core = address(777);

    MultiPlayerTable public table;

    function setUp() public virtual {
        token = new Token(address(this));
        vm.mockCall(core, abi.encodeWithSelector(CoreInterface.token.selector), abi.encode(token));
        game = new LiveRoulette(staking, core, operator, address(this));
        table = MultiPlayerTable(game.createTable(5 minutes));
        token.transfer(alice, 1_000_000 ether);
        token.transfer(bob, 1_000_000 ether);
        token.transfer(staking, 7_200_000 ether);
        vm.warp(1_730_419_200); // 2024-11-01 00:00:00
    }

    function test() public virtual {
        assertEq(address(game.staking()), staking);
        assertEq(address(game.core()), core);
        assertEq(address(game.token()), address(token));
        assertTrue(game.tables(address(table)));
    }

    function placeBet(address player, address _table, Library.Bet[] memory bets) internal {
        uint256 round = MultiPlayerTable(_table).getCurrentRound();
        bytes memory data = abi.encode(bets, _table, round, player);
        vm.prank(core);
        game.placeBet(player, Library.getBitmapsAmount(bets), data);
    }

    function testPlaceBet_multi_number() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 2; // number 1
        placeBet(alice, address(table), bets);
        assertEq(table.getRoundBank(round), 10_000 ether);
    }
}
