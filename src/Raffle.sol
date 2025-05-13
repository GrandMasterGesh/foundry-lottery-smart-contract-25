// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations,enum
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import {console} from "../lib/forge-std/src/console.sol";
import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
// import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";


contract Raffle is VRFConsumerBaseV2Plus{

error  Raffle__NotEnoughEthSent();
error Raffle__TransferFailed();
error Raffle__RaffleNotOpen();
error Raffle__UpkeepNotNeeded(uint256 balance,uint256 rafffleState,uint256 playerslength);

enum RaffleState {OPEN,CALCULATING}

// uint16 private immutable i_requestConfirmations;
uint256 private immutable i_subscriptionId;
bytes32 private immutable i_keyHash;
uint32 private immutable i_callbackGasLimit;
uint256 private immutable i_entranceFee;
uint256 private immutable i_interval;


uint16 constant REQUEST_CONFIRMATIONS = 3;
uint16 constant NUM_WORDS = 1;
address payable[] private s_players;
uint256  private s_lastTimestamp;
address payable private s_recentWinner;
RaffleState private s_raffleState;
// CEI: Checks Effects Interactions
// Checks
//___________________________________________

// Effects (Internal contract state)
event RaffleEntered(address indexed player);
event Winnerpicked(address  indexed winner);
event RequestedRaffleWinner (uint256 indexed requestId );
//uint16 requestConfirmations,
constructor ( 
    uint256 entranceFee,
    uint256 interval,
    address vrfCoordinator,
  bytes32 gasLane,
  uint256 subscriptionId,
    uint32 callbackGasLimit

)
VRFConsumerBaseV2Plus (vrfCoordinator){
    i_keyHash = gasLane;
    i_interval = interval;//duration in sec 
    i_subscriptionId = subscriptionId;
    i_entranceFee = entranceFee;
      i_callbackGasLimit =callbackGasLimit;  
       s_lastTimestamp = block.timestamp;
       s_raffleState = RaffleState.OPEN;
      
    //    i_requestConfirmations = requestConfirmations;
      
      
       
}
// Interactions (External contract interactions) 
function enterRaffle() external payable {
   
// require(msg.value >= i_entranceFee,"Not enough ETH");
if(msg.value < i_entranceFee){  
    revert Raffle__NotEnoughEthSent();}
// require(msg.value >= i_entranceFee , Raffle_NotEnoughETH());
if(s_raffleState != RaffleState.OPEN){
    revert Raffle__RaffleNotOpen();
}
s_players.push(payable (msg.sender));
 console.log('Hello Lucky');
emit RaffleEntered(msg.sender);
}
function checkUpkeep(bytes memory /*calldata*/)public 
view returns(bool upkeepNeeded,bytes memory /*performData*/){
bool timeHasPassed = ((block.timestamp-s_lastTimestamp)>= i_interval);
bool isOpen = s_raffleState==RaffleState.OPEN;
bool hasBalance = address(this).balance > 0;
bool hasPlayers = s_players.length > 0;
if(timeHasPassed&&isOpen&&hasBalance&&hasPlayers){
    upkeepNeeded=true;}
    return (upkeepNeeded,""); 
    }
function performUpkeep(bytes calldata /* performData */ ) external payable {
    (bool upkeepNeeded, ) = checkUpkeep("");
    if(!upkeepNeeded) {
        revert Raffle__UpkeepNotNeeded(address(this).balance,s_players.length, uint256 (s_raffleState));
    }
if((block.timestamp-s_lastTimestamp)< i_interval){
    revert();
}

s_raffleState = RaffleState.CALCULATING;// sets the Rafflestate[]to RaffleState[1]
 
 VRFV2PlusClient.RandomWordsRequest  memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

/* */ uint256 requestId = s_vrfCoordinator.requestRandomWords(request); 
     emit RequestedRaffleWinner(requestId); //Cycle closed     
}
 function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal virtual override {
// function response to req
uint256 indexOfWinner = randomWords[0]% s_players.length;
address payable winner = s_players[indexOfWinner];
s_recentWinner = winner;
s_players = new address payable[](0);

s_raffleState = RaffleState.OPEN;
s_lastTimestamp = block.timestamp;
emit Winnerpicked(s_recentWinner);
(bool success,) = winner.call{value:address(this).balance} ("");
if(!success){
    revert Raffle__TransferFailed();
}

 }

function getEntranceFee()external view returns(uint256){
    return i_entranceFee;
}
function getRaffleState() external view returns(RaffleState)  {
  return s_raffleState;
}
function getPlayer(uint256 indexOfPlayer) external view  returns(address){
    return s_players[indexOfPlayer];

}
function getLastTimestamp() external view returns (uint256) {
  return s_lastTimestamp;
}
function getRecentWinner() external view returns(address) {
    return s_recentWinner;
}
}