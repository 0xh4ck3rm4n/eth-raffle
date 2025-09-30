//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig, ContractConstants} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {CreateSubscription} from "../../script/Interactions.s.sol";
import {VRFCoordinatorV2_5Mock} from
    "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract TestRaffle is ContractConstants, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    CreateSubscription public createSubscription;

    address public PLAYER = makeAddr("PLAYER");

    uint256 public STARTING_BALANCE = 10e18;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        keyLane = config.keyLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        createSubscription = new CreateSubscription();

        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testInitialRaffleStateIsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__InsufficientEntranceFee.selector);
        raffle.enterRaffle();
    }

    function testRaffleBalanceIncreasesByEntranceFee() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        raffle.enterRaffle{value: entranceFee}();
        assertEq(address(raffle).balance, entranceFee);
    }

    function testPlayerGetsAddedtoArray() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function testRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleRevertsWhenCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Assert
        vm.expectRevert(Raffle.Raffle__RaffleIsNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /////////////////////////////////
    //    CHECK UP KEEP            //
    ////////////////////////////////

    function testCheckUpKeepReturnsFalseWithNoPlayer() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool response,) = raffle.checkUpkeep("");
        assert(response == false);
    }

    function testCheckUpKeepReturnsFalseIfTimeNotPassed() public {
        //entering the raffle
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        (bool response,) = raffle.checkUpkeep("");
        assert(response == false);
    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        (bool response,) = raffle.checkUpkeep("");
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(response == false);
    }

    /////////////////////////////////
    //    PERFORM UP KEEP         //
    ////////////////////////////////

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpKeepRunsIfCheckUpKeepIsTrue() public raffleEntered {
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertsWhenCheckUpKeepIsFalse() public {
        uint256 contractBalance = 0;
        uint256 numberOfPlayer = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, contractBalance, numberOfPlayer, rState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpKeepShouldUpdateState() public raffleEntered {
        raffle.performUpkeep("");
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function testRaffleEmitsRequestId() public raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        assert(uint256(requestId) > 0);
    }

    /////////////////////////////////
    //    FULFILL WORDS REQUEST    //
    ////////////////////////////////

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsRunsAfterPerformUpKeep(uint256 someRandomId) public raffleEntered skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(someRandomId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndEmits() public raffleEntered skipFork {
        address expectedWinner = address(1);
        uint256 additionEntrees = 3;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i < startingIndex + additionEntrees; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Gets RequestId from logs
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerBalance = recentWinner.balance;
        uint256 prize = entranceFee * (additionEntrees + 1);
        uint256 leftPlayers = raffle.getNumberOfPlayers();

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == prize + startingBalance);
        assert(endingTimeStamp > startingTimeStamp);
        assert(leftPlayers == 0);
    }

    function testGetEntranceFeeReturnsGood() public view {
        assertEq(raffle.getEntranceFee(), entranceFee);
    }

    function testGetPlayersReturnsAPlayer() public raffleEntered {
        assert(raffle.getPlayer(0) == address(PLAYER));
    }
}
