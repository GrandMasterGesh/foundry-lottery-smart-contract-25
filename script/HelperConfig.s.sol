// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Script, console2} from "../lib/forge-std/src/Script.sol";
 import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CodeConstants {
uint96 public MOCK_BASE_FEE = 0.25 ether;
uint96 public MOCK_GAS_PRICE_LINK = 1e9;
int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

     uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
        
        error HelperConfig__InvalidChainId();

      struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address link;
        address account;
        
    }
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor(){
networkConfigs[ETH_SEPOLIA_CHAIN_ID]= getSepoliaEthConfig();
 networkConfigs[LOCAL_CHAIN_ID] =  getOrCreateAnvilEthConfig();
    }
function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory){
   if (networkConfigs[chainId].vrfCoordinator !=address(0)){
   return networkConfigs[chainId];
   } else if(chainId == LOCAL_CHAIN_ID){
     return getOrCreateAnvilEthConfig();
     }
   else {
    revert HelperConfig__InvalidChainId();
   }
}
function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory){
    if(localNetworkConfig.vrfCoordinator != address(0)){
        return localNetworkConfig;
    }
    vm.startBroadcast();
    VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
        MOCK_BASE_FEE,MOCK_GAS_PRICE_LINK,MOCK_WEI_PER_UINT_LINK);
    LinkToken linkToken = new LinkToken();
    vm.stopBroadcast();

    localNetworkConfig = NetworkConfig({
        entranceFee:0.01 ether,
        interval :30,
           vrfCoordinator : address(vrfCoordinatorMock),
           gasLane : 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
           callbackGasLimit : 50000,
          subscriptionId:0,
          link: address(linkToken),
          account:0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
    });
    return localNetworkConfig;
}
function getConfig() public returns(NetworkConfig memory){
return getConfigByChainId(block.chainid);
}
    function getSepoliaEthConfig () public pure returns(NetworkConfig memory){
        return NetworkConfig({
            entranceFee : 0.01 ether,
            interval :30,
           vrfCoordinator : 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
           gasLane : 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
           callbackGasLimit : 50000,
            subscriptionId:76768446417862600354310449677495264146754097447136563967119704486089302417382,
        //   requestConfirmations : 3,
        //   numWords: 1
        link :0x779877A7B0D9E8603169DdbD7836e478b4624789,
        account : 0x35758f595452634bfB32eb32Ce40e3B5c322Aabb

        });
    }
}