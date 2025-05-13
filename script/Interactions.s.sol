// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {CodeConstants} from "./HelperConfig.s.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256 subscriptionId, address) {
        HelperConfig helperConfig = new HelperConfig();
        
        address account = helperConfig.getConfig().account;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
       (uint256 subId, )= createSubscription(vrfCoordinator,account);
        return (subId, vrfCoordinator) ;
    }

    function createSubscription(address vrfCoordinator,address account) public returns (uint256, address) {
        // console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        // console.log("Your subscription Id is: ", subId);
        // console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return (subId, vrfCoordinator);
     }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
        HelperConfig helperConfig = new HelperConfig();

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, account); 
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {  //
        // console.log("Adding consumer contract: ", contractToAddToVrf);
        // console.log("Using vrfCoordinator: ", vrfCoordinator);
        // console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(account);   
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

contract FundSubscription is CodeConstants, Script {
    uint256 public constant FUND_AMOUNT = 3 ether;
        HelperConfig helperConfig = new HelperConfig();

    function fundSubscriptionUsingConfig() public {
        // HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address linkToken = helperConfig.getConfig().link;
         address account = helperConfig.getConfig().account;

// //         if (subId == 0) {  
// //             CreateSubscription createSub = new CreateSubscription();
// //             (uint256 updatedSubId, address updatedVRFv2) = createSub.run();
// //             subId = updatedSubId;
// //             vrfCoordinatorV2_5 = updatedVRFv2;
// //             console.log("New SubId Created! ", subId, "VRF Address: ", vrfCoordinatorV2_5);
// //         }

        fundSubscription(vrfCoordinator, subscriptionId, linkToken,account);
    }

    function fundSubscription(address vrfCoordinator, 
    uint256 subscriptionId, address linkToken,address account) public {
        // console.log("Funding subscription: ", subscriptionId);
        // console.log("Using vrfCoordinator: ", vrfCoordinator);
        // console.log("On ChainID: ", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator)
            .fundSubscription(subscriptionId,FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            // console.log(LinkToken(link).balanceOf(msg.sender));
            // console.log(msg.sender);
            // console.log(LinkToken(link).balanceOf(address(this)));
            // console.log(address(this));
            vm.startBroadcast(account);
            LinkToken(linkToken)
            .transferAndCall(vrfCoordinator,FUND_AMOUNT, 
            abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig(); 
    }
}
