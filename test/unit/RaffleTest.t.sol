// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
 
 import {console} from "../../lib/forge-std/src/console.sol";
 import {Test} from "../../lib/forge-std/src/Test.sol";
 import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
 import {Raffle} from "../../src/Raffle.sol";
 import {HelperConfig} from "../../script/HelperConfig.s.sol";
 import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";   
import {CodeConstants} from "../../script/HelperConfig.s.sol";  

       contract RaffleTest is Test,CodeConstants {

            Raffle public raffle;
          HelperConfig public helperConfig;
    
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

   address public PLAYER= makeAddr("player");
   uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event Winnerpicked(address  indexed winner);
   
   modifier raffleIsEntered() {
     vm.prank(PLAYER);
      raffle.enterRaffle{value : entranceFee}();
      vm.warp(block.timestamp + interval+1); 
      vm.roll(block.number +1);
      _;
   }
   function setUp() external {
     DeployRaffle deployer = new DeployRaffle();
     (raffle,helperConfig)= deployer.deployContract();
     HelperConfig.NetworkConfig memory config = helperConfig.getConfig(); 
       
       entranceFee =config.entranceFee;
       interval=config.interval;
       vrfCoordinator= config.vrfCoordinator;
       gasLane =  config.gasLane;
         callbackGasLimit = config.callbackGasLimit;
         subscriptionId = config.subscriptionId;

         vm.deal(PLAYER,STARTING_PLAYER_BALANCE);
   }
  function testRaffleInitiatesInOpenState () public view {
       assert( raffle.getRaffleState() == Raffle.RaffleState.OPEN);
  }
  function testRaffleIsFunded ()public  {
    vm.prank(PLAYER);
    vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
    raffle.enterRaffle();

  }
  ///////////////////////////////////////////////////////////////////
 ////////////////////////////// /*EVENTS*///////////////////////////
 //////////////////////////////////////////////////////////////////

    function testRaffleEmitsEvent() public {
     vm.prank(PLAYER);
     vm.expectEmit(true,false,false,false,address(raffle));
     emit RaffleEntered(PLAYER);
     raffle.enterRaffle{value : entranceFee}(); 
    }
    ///////////////////////////////////////////////////////////////
    //////////////////*ENTER RAFFLE*//////////////////////////////
    //////////////////////////////////////////////////////////////
      
      
      function testRafflePlayersListUpdates() public {
     vm.prank(PLAYER);
     raffle.enterRaffle{value : entranceFee}();
    address playerRecorded = raffle.getPlayer(0);
    assert( playerRecorded == PLAYER);
    }
    function testRaffleNotAllowedToEnterWhileCalculating() public raffleIsEntered{
      
      raffle.performUpkeep("");
      vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
      vm.prank(PLAYER);
      raffle.enterRaffle{value : entranceFee}();

    }
    /*//////////////////////////////////////////////////
    //////////////////// CHECKUPKEEP ///////////////////                    
    //////////////////////////////////////////////////*/
    
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
      vm.warp(block.timestamp+interval+1);
      vm.roll(block.number + 1);
      (bool upkeepNeeded,) = raffle.checkUpkeep("");
      assert(!upkeepNeeded);
    }
    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public raffleIsEntered {
      
      raffle.performUpkeep("");
      (bool upkeepNeeded,) = raffle.checkUpkeep("");
      assert(!upkeepNeeded);

    }
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasPassed() public {
     vm.prank(PLAYER);
      raffle.enterRaffle{value:entranceFee}();
      (bool upkeepNeeded,) = raffle.checkUpkeep("");
       assert(!upkeepNeeded);
    }
    function testCheckUpkeepReturnsTrueIfParametersAreOk() public raffleIsEntered {
     
      
      (bool upkeepNeeded,) = raffle.checkUpkeep("");
       assert(upkeepNeeded);
    }
    /////////////////////////////////////////////////////////////
    //////////////////* PERFORM UPKEEP */////////////////////////
    //////////////////////////////////////////////////////////////


    function testPerformUpkeepOnlyRunsWhenCheckUpkeepIsTrue() public raffleIsEntered {
      //Arrange
    
      //Act+Assert
      raffle.performUpkeep("");
    }
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
       //Arrange
       uint256 currentBalance = 0;
       uint256 numPlayers = 0;
       Raffle.RaffleState rState = raffle.getRaffleState();
       /*  to fail revert: vm.prank(PLAYER);raffle.enterRaffle{value:entranceFee}();
      vm.warp(block.timestamp+interval+1);
      vm.roll(block.number + 1);|| modifier: raffleIsEntered */
        //Act+Assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector,
        currentBalance,numPlayers,rState));
        raffle.performUpkeep("");

      
    }
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleIsEntered {
     

      vm.recordLogs();
      raffle.performUpkeep("");
      Vm.Log[] memory entries = vm.getRecordedLogs();
      //  console.logBytes32(entries);
      bytes32 requestId = entries[1].topics[1];     //fails with 'array out of bounds' bytes32 requestId = entries[1].topics[1];
      
      Raffle.RaffleState raffleState = raffle.getRaffleState(); 
      assert(uint256(requestId) > 0);
      assert(uint256(raffleState) ==1);
// assert(entries.length > 0);
    } 

    /*/////////////////////////////////////////////////////////////////////////////
    /////////////////////    FULFILLRANDOMWORDS   ////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////*/ 

modifier skipForkTest(){
  if(block.chainid !=LOCAL_CHAIN_ID){
    return;
    _;}
  }
    function testFulfillRandomWordsIsCalledOnlyAfterPerformUpkeep(uint256 RandomRequestId) public raffleIsEntered {
          vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
          VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(RandomRequestId,address(raffle));

    }
    function testFulfillRandomWordsPickesWinnerResetsAndSendsMoney() public  raffleIsEntered skipForkTest {
      //Arrange
    
      uint256 additionalEntrants = 3;
      uint256 startingIndex = 1;
      address expectedWinner = address(1);

      for(uint256 i=startingIndex;i<=additionalEntrants;i++){
        address newPlayer = address(uint160 (i));
        hoax(newPlayer,1 ether);
        raffle.enterRaffle{value:entranceFee}();
      }
      uint256 startingTimeStamp = raffle.getLastTimestamp();
      uint256 winnerStartingBalance = expectedWinner.balance;
      //Act
      vm.recordLogs();
      raffle.performUpkeep("");
      Vm.Log[] memory entries = vm.getRecordedLogs();
      bytes32 requestId = entries[1].topics[1];
      //  console.log(requestId);
      VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
        uint256(requestId),address(raffle));
       
       //Assert
       address recentWinner = raffle.getRecentWinner();
       Raffle.RaffleState raffleState = raffle.getRaffleState();
       uint256 winnerBalance = recentWinner.balance;
       uint256 endingTimestamp = raffle.getLastTimestamp();
       uint256 prize = entranceFee*(additionalEntrants + 1);

      assert(recentWinner == expectedWinner);
      assert(uint256(raffleState)==0);
      assert(winnerBalance == winnerStartingBalance+prize);
      assert(endingTimestamp > startingTimeStamp);
    }

 } 