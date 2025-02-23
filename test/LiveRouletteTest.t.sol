// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { CoreInterface } from "src/interfaces/CoreInterface.sol";
import { Token } from "src/Token.sol";
import { LiveRoulette } from "src/LiveRoulette.sol";
import { Library } from "src/Library.sol";
import { MultiPlayerTable } from "src/MultiPlayerTable.sol";
import { DynamicStaking } from "./DynamicStaking.sol";
import { LiroBet } from "src/LiroBet.sol";
import { console } from "forge-std/src/console.sol";

contract LiveRouletteTest is Test {
    address public alice = address(1);
    address public bob = address(2);

    LiveRoulette public game;
    Token public token;
    DynamicStaking public staking;
    address public operator = address(999);
    address public core = address(777);

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
        assertEq(game.getAddress(), address(game));
        assertEq(game.getFeeType(), 1);
        assertTrue(game.tables(address(table)));
    }


    function placeSingleBet(address player, Library.Bet[] memory bets) internal returns (address) {
        bytes memory data = abi.encode(bets, address(0), 0, player);
        token.transfer(address(game), Library.getBitmapsAmount(bets));
        vm.prank(core);
        return game.placeBet(player, Library.getBitmapsAmount(bets), data);
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
        assertEq(token.balanceOf(address(table)), 40_000 ether);
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

        bets[0].bitmap = 45_991_767_380; // black
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
        assertEq(token.balanceOf(address(table)), 360_000 * 36 ether);
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
        assertEq(token.balanceOf(address(game)), 0 ether);
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
        assertEq(token.balanceOf(address(table)), 360_000 * 37 ether);
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
        assertEq(token.balanceOf(address(game)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 360_000 ether);
        assertEq(token.balanceOf(address(staking)), 1_000_010_000 ether);

        // refund will fail
        vm.expectRevert(bytes("MP04"));
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
        assertEq(token.balanceOf(address(table)), 360_000 * 37 ether);
        assertEq(token.balanceOf(address(game)), 370_000 ether);

        vm.warp(block.timestamp + 1 days + 6 minutes);

        game.refund(address(table), round);

        assertEq(token.balanceOf(address(table)), 0 ether);
        assertEq(token.balanceOf(address(game)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 370_000 ether);
        assertEq(token.balanceOf(address(staking)), 1_000_000_000 ether);
    }

    function testPlaceBet_single_number_win() public {
        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 8192; // number 13

        address bet = placeSingleBet(alice, bets);

        assertEq(token.balanceOf(address(game.singlePlayerTable())), 360_000 ether);
        assertEq(token.balanceOf(address(game)), 10_000 ether);

        bytes memory extraData = abi.encode(true, address(bet), 0);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_538_613), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(table)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 360_000 ether);
    }

    function testPlaceBet_single_color_win() public {
        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 45_991_767_380; // black

        address bet = placeSingleBet(alice, bets);

        assertEq(token.balanceOf(address(game.singlePlayerTable())), 20_000 ether);
        assertEq(token.balanceOf(address(game)), 10_000 ether);

        bytes memory extraData = abi.encode(true, address(bet), 0);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_538_613), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(game.singlePlayerTable())), 0 ether);
        assertEq(token.balanceOf(address(game)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 20_000 ether);
    }

    function testPlaceBet_single_multiBet_win() public {
        Library.Bet[] memory bets = new Library.Bet[](2);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 45_991_767_380; // black
        bets[1].amount = 10_000 ether;
        bets[1].bitmap = 91_447_186_090; // red

        address bet = placeSingleBet(alice, bets);

        assertEq(LiroBet(bet).getBetsCount(), 2);

        (uint256 b1a, uint256 b1b) = LiroBet(bet).getBet(0);
        assertEq(b1a, 10_000 ether);
        assertEq(b1b, 45_991_767_380);
        (uint256 b2a, uint256 b2b) = LiroBet(bet).getBet(1);
        assertEq(b2a, 10_000 ether);
        assertEq(b2b, 91_447_186_090);

        assertEq(token.balanceOf(address(game.singlePlayerTable())), 40_000 ether);
        assertEq(token.balanceOf(address(game)), 20_000 ether);

        bytes memory extraData = abi.encode(true, address(bet), 0);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_538_613), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(game.singlePlayerTable())), 0 ether);
        assertEq(token.balanceOf(address(game)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 20_000 ether);

        assertEq(LiroBet(bet).getResult(), 20_000 ether);
    }

    function testSetLimit() public {
        (uint256 min, uint256 max, uint256 payout) = table.limits("STRAIGHT");
        assertEq(min, 3_000 ether);
        assertEq(max, 150_000 ether);
        assertEq(payout, 35);
        // success
        game.setLimit(address(table), "STRAIGHT", 20_000 ether, 300_000 ether);

        (min, max, payout) = table.limits("STRAIGHT");
        assertEq(min, 20_000 ether);
        assertEq(max, 300_000 ether);
        assertEq(payout, 35);

        // fail
        vm.expectRevert();
        vm.prank(core);
        game.setLimit(address(table), "STRAIGHT", 10_000 ether, 150_000 ether);
    }

    function testPlaceBet_revert() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes("LR01"));
        game.placeBet(alice, 10_000 ether, "");

        vm.stopPrank();

        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 45_991_767_380; // black

        uint256 round = MultiPlayerTable(table).getCurrentRound();
        bytes memory data = abi.encode(bets, address(table), round, alice);
        token.transfer(address(game), Library.getBitmapsAmount(bets));
        vm.startPrank(core);
        vm.expectRevert(bytes("LR02"));
        game.placeBet(alice, 10_000, data); // fail
    }

    function testPlaceBet_invalidTable() public {
        Library.Bet[] memory bets = new Library.Bet[](1);
        bets[0].amount = 10_000 ether;
        bets[0].bitmap = 45_991_767_380; // black

        uint256 round = MultiPlayerTable(table).getCurrentRound();
        bytes memory data = abi.encode(bets, address(888), round, alice); // wrong table
        token.transfer(address(game), Library.getBitmapsAmount(bets));
        vm.startPrank(core);
        vm.expectRevert(bytes("LR03"));
        game.placeBet(alice, 10_000 ether, data); // fail
    }

    function testRefund_revert() public {
        vm.expectRevert(bytes("LR03"));
        game.refund(address(777), 0);
    }

    function testSpin_revert() public {
        vm.expectRevert(bytes("LR03"));
        game.spin(address(777), 0);
    }

    function testCreateTable_revert() public {
        vm.startPrank(alice);
        vm.expectRevert();
        game.createTable(0);

        vm.stopPrank();
        vm.expectRevert(bytes("LR05"));
        game.createTable(0);
    }

    function testPlaceBet_multipleTable_maxBitMaps() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        uint256 betNum = 37;
        Library.Bet[] memory bets = new Library.Bet[](betNum);

        for (uint256 i; i < betNum; i++) {
            bets[i].amount = 10_000 ether;
            bets[i].bitmap = 91_447_186_090; // red
        }

        assertEq(bets.length, betNum);
        console.log("alice plays %d bets", betNum);
        placeBet(alice, address(table), bets);

        assertEq(table.getRoundBank(round), 10_000 ether * betNum);
        assertEq(token.balanceOf(address(table)), 20_000 ether * betNum);
        assertEq(token.balanceOf(address(game)), 10_000 ether * betNum);

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
        //assertEq(token.balanceOf(address(bob)), 20_000 ether);
    }

    function testPlaceBet_multipleTable_maxBetCount() public {
        uint256 round = MultiPlayerTable(table).getCurrentRound();
        for (uint256 p = 0; p < 50; p++) {
            uint256 betNum = 37;
            Library.Bet[] memory bets = new Library.Bet[](betNum);
            for (uint256 i; i < betNum; i++) {
                bets[i].amount = 10_000 ether;
                bets[i].bitmap = 2 ** i; // straight
            }
            placeBet(alice, address(table), bets);
        }

        assertEq(table.getRoundBank(round), 10_000 ether * 37 * 50);
        assertEq(token.balanceOf(address(table)), 360_000 ether * 37 * 50);
        assertEq(token.balanceOf(address(game)), 10_000 ether * 37 * 50);

        vm.warp(block.timestamp + 1 days);
        game.spin(address(table), round);

        assertEq(table.roundStatus(round), 2);
        bytes memory extraData = abi.encode(false, address(table), round);
        bytes memory data = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(uint256(12_567_413), data);
        vm.prank(operator);
        game.fulfillRandomness(uint256(0), dataWithRound);
        assertEq(token.balanceOf(address(table)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 360_000 * 50 ether);
        assertEq(token.balanceOf(address(bob)), 0 ether);
    }

	function test_dos_placeBet_single_refund_ZeroPlayerNotCheck() public {
		Library.Bet[] memory bets = new Library.Bet[](1);
		bets[0].amount = 10_000 ether;
		bets[0].bitmap = 8192; // number 13

		address bet = placeSingleBet(address(0), bets);

		assertEq(token.balanceOf(address(game.singlePlayerTable())), 360_000 ether);
		assertEq(token.balanceOf(address(game)), 10_000 ether);

		vm.warp(block.timestamp + 1.1 days);

		game.refundSingleBet(bet);
	}

	function test_dos_placeBet_multi_refund_revert_ZeroPlayerNotCheck() public {
		uint256 round = MultiPlayerTable(table).getCurrentRound();
		Library.Bet[] memory bets = new Library.Bet[](37);
		for (uint256 i = 0; i <= 36; i++) {
			bets[i].amount = 10_000 ether;
			bets[i].bitmap = 2 ** i; // number i
		}
		placeBet(alice, address(table), bets);

		bets = new Library.Bet[](1);
		for (uint256 i = 0; i < 1; i++) {
			bets[i].amount = 10_000 ether;
			bets[i].bitmap = 2 ** i; // number i
		}

		placeBet(address(0), address(table), bets);

		vm.warp(block.timestamp + 1 days + 6 minutes);

		game.refund(address(table), round);
	}

	function test_dos_placeBet_single_number_win_revert() public {
		Library.Bet[] memory bets = new Library.Bet[](1);
		bets[0].amount = 10_000 ether;
		bets[0].bitmap = 8192; // number 13

		address bet = placeSingleBet(address(0), bets);

		bytes memory extraData = abi.encode(true, address(bet), 0);
		bytes memory data = abi.encode(uint256(0), extraData);
		bytes memory dataWithRound = abi.encode(uint256(12_538_613), data);
		vm.prank(operator);
		game.fulfillRandomness(uint256(0), dataWithRound);
	}

	function test_dos_placeBet_multi_one_number_win_revert() public {
		uint256 round = MultiPlayerTable(table).getCurrentRound();
		Library.Bet[] memory bets = new Library.Bet[](37);
		for (uint256 i = 0; i <= 36; i++) {
			bets[i].amount = 10_000 ether;
			bets[i].bitmap = 8192; // number i
		}
		placeBet(alice, address(table), bets);

		bets = new Library.Bet[](1);
		for (uint256 i = 0; i < 1; i++) {
			bets[i].amount = 10_000 ether;
			bets[i].bitmap = 8192; // number i
		}

		placeBet(address(0), address(table), bets);

		vm.warp(block.timestamp + 1 days);
		game.spin(address(table), round);

		assertEq(table.roundStatus(round), 2);
		bytes memory extraData = abi.encode(false, address(table), round);
		bytes memory data = abi.encode(uint256(0), extraData);
		bytes memory dataWithRound = abi.encode(uint256(12_567_413), data);
		vm.prank(operator);
		game.fulfillRandomness(uint256(0), dataWithRound);
	}

	function placeBet(address player, address _table, Library.Bet[] memory bets) internal {
		uint256 round = MultiPlayerTable(_table).getCurrentRound();
		bytes memory data = abi.encode(bets, _table, round, player);
		token.transfer(address(game), Library.getBitmapsAmount(bets));
		vm.prank(core);
		address bet = game.placeBet(player, Library.getBitmapsAmount(bets), data);
		assertEq(LiroBet(bet).getBetsCount(), bets.length);
		assertEq(LiroBet(bet).getGame(), address(game));
		assertEq(LiroBet(bet).getCreated(), block.timestamp);
		(address _p, address _g, uint256 _a, uint256 _r, uint256 _s, uint256 _c) = LiroBet(bet).getBetInfo();
		assertEq(_p, player);
		assertEq(_g, address(game));
		assertEq(_a, Library.getBitmapsAmount(bets));
		assertEq(_r, 0);
		assertEq(_s, 1);
		assertEq(_c, block.timestamp);
	}
}
