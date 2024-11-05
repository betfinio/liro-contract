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
import { DynamicStaking } from "./DynamicStaking.sol";

contract LiveRouletteTest is Test {
    address public alice = address(1);
    address public bob = address(2);

    LiveRoulette public game;
    Token public token;
    DynamicStaking staking;
    address operator = address(999);
    address core = address(777);

    MultiPlayerTable public table;

    function setUp() public virtual {
        token = new Token(address(this));
        staking = new DynamicStaking(address(token));
        staking.grantRole(staking.TIMELOCK(), address(this));
        vm.mockCall(core, abi.encodeWithSelector(CoreInterface.token.selector), abi.encode(token));
        game = new LiveRoulette(address(staking), core, operator, address(this));
        staking.addGame(address(game));
        table = MultiPlayerTable(game.createTable(5 minutes));
        token.transfer(address(staking), 1_000_000_000 ether);
        vm.warp(1_730_419_200); // 2024-11-01 00:00:00
    }

    function test() public virtual {
        assertEq(address(game.staking()), address(staking));
        assertEq(address(game.core()), core);
        assertEq(address(game.token()), address(token));
        assertTrue(game.tables(address(table)));
    }

    function placeBet(address player, address _table, Library.Bet[] memory bets) internal {
        uint256 round = MultiPlayerTable(_table).getCurrentRound();
        bytes memory data = abi.encode(bets, _table, round, player);
        token.transfer(address(game), Library.getBitmapsAmount(bets));
        vm.prank(core);
        game.placeBet(player, Library.getBitmapsAmount(bets), data);
    }

    function placeSingleBet(address player, Library.Bet[] memory bets) internal {
        bytes memory data = abi.encode(bets, address(0), 0, player);
        token.transfer(address(game), Library.getBitmapsAmount(bets));
        vm.prank(core);
        game.placeBet(player, Library.getBitmapsAmount(bets), data);
    }

    function testPlaceBet_multi_one_number_win() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 8192; // number 13

        placeBet(alice, address(table), bets);

        assertEq(table.getRoundBank(round), 10_000 ether);
        assertEq(token.balanceOf(address(table)), 360_000 ether);
        assertEq(token.balanceOf(address(game)), 10_000 ether);

        vm.warp(block.timestamp + 1 days);
        game.spin(address(table), round);

        assertEq(table.roundStatus(round), 2);
        bytes memory extraData = abi.encode(false, address(table), round);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_567_413), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(table)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 360_000 ether);
    }

    function testPlaceBet_multi_two_color_win() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 91_447_186_090; // red

        placeBet(alice, address(table), bets);

        assertEq(table.getRoundBank(round), 10_000 ether);
        assertEq(token.balanceOf(address(table)), 20_000 ether);
        assertEq(token.balanceOf(address(game)), 10_000 ether);

        bets[0].bitmap = 45_991_767_380; // black
        placeBet(bob, address(table), bets);

        assertEq(table.getRoundBank(round), 20_000 ether);
        assertEq(token.balanceOf(address(table)), 20_000 ether);
        assertEq(token.balanceOf(address(game)), 20_000 ether);

        vm.warp(block.timestamp + 1 days);
        game.spin(address(table), round);

        assertEq(table.roundStatus(round), 2);
        bytes memory extraData = abi.encode(false, address(table), round);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_567_413), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(table)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 0 ether);
        assertEq(token.balanceOf(address(bob)), 20_000 ether);
    }

    function testPlaceBet_multi_two_number_win() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 8192; // number 13

        placeBet(alice, address(table), bets);

        assertEq(table.getRoundBank(round), 10_000 ether);
        assertEq(token.balanceOf(address(table)), 360_000 ether);
        assertEq(token.balanceOf(address(game)), 10_000 ether);

        bets[0].bitmap = 91_447_186_090; // red
        placeBet(bob, address(table), bets);

        assertEq(table.getRoundBank(round), 20_000 ether);
        assertEq(token.balanceOf(address(table)), 360_000 ether);
        assertEq(token.balanceOf(address(game)), 20_000 ether);

        vm.warp(block.timestamp + 1 days);
        game.spin(address(table), round);

        assertEq(table.roundStatus(round), 2);
        bytes memory extraData = abi.encode(false, address(table), round);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_567_413), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(table)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 360_000 ether);
        assertEq(token.balanceOf(address(bob)), 0 ether);
    }

    function testPlaceBet_multi_two_both_win() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 8192; // number 13

        placeBet(alice, address(table), bets);

        assertEq(table.getRoundBank(round), 10_000 ether);
        assertEq(token.balanceOf(address(table)), 360_000 ether);
        assertEq(token.balanceOf(address(game)), 10_000 ether);

        bets[0].bitmap = 45_991_767_380; // red
        placeBet(bob, address(table), bets);

        assertEq(table.getRoundBank(round), 20_000 ether);
        assertEq(token.balanceOf(address(table)), 380_000 ether);
        assertEq(token.balanceOf(address(game)), 20_000 ether);

        vm.warp(block.timestamp + 1 days);
        game.spin(address(table), round);

        assertEq(table.roundStatus(round), 2);
        bytes memory extraData = abi.encode(false, address(table), round);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_567_413), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(table)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 360_000 ether);
        assertEq(token.balanceOf(address(bob)), 20_000 ether);
    }

    function testPlaceBet_multi_one_loose() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 2; // number 1

        placeBet(alice, address(table), bets);

        assertEq(table.getRoundBank(round), 10_000 ether);
        assertEq(token.balanceOf(address(table)), 360_000 ether);
        assertEq(token.balanceOf(address(game)), 10_000 ether);

        vm.warp(block.timestamp + 1 days);
        game.spin(address(table), round);

        assertEq(table.roundStatus(round), 2);
        bytes memory extraData = abi.encode(false, address(table), round);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_567_413), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(table)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 0 ether);
        assertEq(token.balanceOf(address(game)), 0 ether);
        assertEq(token.balanceOf(address(staking)), 1_000_010_000 ether);
    }

    function testPlaceBet_multi_sameTable_multipleRound() public {
        for (uint256 i = 1; i <= 36; i++) {
            Library.Bet[] memory bets = new Library.Bet[](1);
            bets[0].amount = 10_000 ether;
            bets[0].bitmap = 2 ** i; // number i
            vm.warp(block.timestamp + 5 minutes);
            placeBet(address(uint160(i)), address(table), bets);
            assertEq(table.getRoundBank(MultiPlayerTable(table).getCurrentRound()), 10_000 ether);
        }
        assertEq(token.balanceOf(address(table)), 12_960_000 ether);
        assertEq(token.balanceOf(address(game)), 360_000 ether);
    }

    function testPlaceBet_multi_36_win() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        for (uint256 i = 1; i <= 36; i++) {
            Library.Bet[] memory bets = new Library.Bet[](1);
            bets[0].amount = 10_000 ether;
            bets[0].bitmap = 2 ** i; // number i
            placeBet(address(uint160(i)), address(table), bets);
        }

        assertEq(table.getRoundBank(round), 360_000 ether);
        assertEq(token.balanceOf(address(table)), 360_000 ether);
        assertEq(token.balanceOf(address(game)), 360_000 ether);

        vm.warp(block.timestamp + 1 days);
        game.spin(address(table), round);

        assertEq(table.roundStatus(round), 2);
        bytes memory extraData = abi.encode(false, address(table), round);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_567_413), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(table)), 0 ether);
        for (uint256 i = 1; i <= 36; i++) {
            if (i == 13) {
                assertEq(token.balanceOf(address(uint160(i))), 360_000 ether);
            } else {
                assertEq(token.balanceOf(address(uint160(i))), 0 ether);
            }
        }
    }

    function testPlaceBet_multi_one_allNumbers() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        Library.Bet[] memory bets = new Library.Bet[](37);
        for (uint256 i = 0; i <= 36; i++) {
            bets[i].amount = 10_000 ether;
            bets[i].bitmap = 2 ** i; // number i
        }
        placeBet(alice, address(table), bets);

        assertEq(table.getRoundBank(round), 370_000 ether);
        assertEq(token.balanceOf(address(table)), 360_000 ether);
        assertEq(token.balanceOf(address(game)), 370_000 ether);

        vm.warp(block.timestamp + 1 days);
        game.spin(address(table), round);

        assertEq(table.roundStatus(round), 2);
        bytes memory extraData = abi.encode(false, address(table), round);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_567_413), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(table)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 360_000 ether);
        assertEq(token.balanceOf(address(staking)), 1_000_010_000 ether);

        // refund will fail
        vm.expectRevert(bytes("MP06"));
        game.refund(address(table), round);
    }

    function testPlaceBet_multi_refund() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        Library.Bet[] memory bets = new Library.Bet[](37);
        for (uint256 i = 0; i <= 36; i++) {
            bets[i].amount = 10_000 ether;
            bets[i].bitmap = 2 ** i; // number i
        }
        placeBet(alice, address(table), bets);

        assertEq(table.getRoundBank(round), 370_000 ether);
        assertEq(token.balanceOf(address(table)), 360_000 ether);
        assertEq(token.balanceOf(address(game)), 370_000 ether);

        vm.warp(block.timestamp + 1 days);
    }
}
