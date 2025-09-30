// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/test.sol";
import {CreateSubscription, FundSubscription} from "../../script/Interactions.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract InteractionsTest is Test {
    HelperConfig helperConfig;
    CreateSubscription createSubscription;
    FundSubscription fundSubscription;
    DeployRaffle deployRaffle;
    Raffle raffle;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    address account;

    function setUp() external {
        deployRaffle = new DeployRaffle();
        (, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        keyLane = config.keyLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        helperConfig = new HelperConfig();
    }

    function testCreateSubscriptionReturnsSubId() public {
        (uint256 subId,) = createSubscription.createSubscriptionUsingConfig();
        assert(subId > 0);
    }

    function testGetConfigByChainIdRevertsWithWrongChainId() public {
        uint256 wrongChainId = 4224;
        vm.expectRevert(HelperConfig.HelperConfig__InvalidChainId.selector);
        helperConfig.getConfigByChainId(wrongChainId);
    }

    function testGetOrCreateAnvilConfigRunsGood() public {
        helperConfig.getConfig().vrfCoordinator = address(0);
        helperConfig.getOrCreateAnvilConfig();
        assert(helperConfig.getConfig().vrfCoordinator != address(0));
        assert(helperConfig.getConfig().link != address(0));
        assert(helperConfig.getConfig().entranceFee == entranceFee);
        assert(helperConfig.getConfig().interval == interval);
        assert(helperConfig.getConfig().callbackGasLimit == callbackGasLimit);
    }
}
