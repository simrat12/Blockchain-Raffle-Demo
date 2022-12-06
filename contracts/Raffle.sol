// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../Interfaces/VRFCoordinatorV2Interface.sol";
import "./VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "./ShitToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Raffle is Ownable, VRFConsumerBaseV2, AutomationCompatible {
    using SafeMath for uint256;

    mapping(bytes32 => mapping(address => bool)) public roles;
    bytes32 private constant ADMIN = keccak256(abi.encodePacked("ADMIN"));
    bytes32 private constant USER = keccak256(abi.encodePacked("USER"));


    enum RaffleState {
        Open,
        Closed
    }

    receive() external payable {

    }

    event WinnerChosen(address winner);
    event EnteredRaffle(address entrant);
    event RequestedRaffleWinner(uint256 Winner);
    event RaffleEnter(address entree);
    event WinnerPicked(address winner);
    uint256 private immutable i_entranceFee;
    uint256 private Max_entry;
    uint256 private s_lastTimeStamp;
    uint256 private i_interval;
    address private s_recentWinner;
    address payable[] private s_players;
    IERC20 public ShittyToken;
    IERC20 public WETH;
    RaffleState public s_raffleState;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 public ChosenTimePeriod;
    mapping(address => uint256) numberOfTickets;
    address[] investors;


    struct winnerDetails {
      bool winOrNot;
      uint256 amount;
      uint256 startSchedules;
      uint256 amountWithdrawn;
    }

    mapping(address => winnerDetails) public winnerInfo;
    uint256 public vestedTokenAllocation = 0;

    error Raffle__TransferFailed();
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();
    error Entry_too_high();
 

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        uint256 _maxEntry,
        address _shitToken
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        Max_entry = _maxEntry;
        ShittyToken = IERC20(_shitToken);
        WETH = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);
    }


    /* The admin functions below allow the owner of the smart contract to 
      allow any address to access the admin functions of the lottery, namely
      to set/revoke admins, initialise a winners' vesting period, change the
      entry fee and end the lottery.
    */

    function setAdmin(address _newAdmin) public onlyOwner {
      roles[ADMIN][_newAdmin] = true;
    }

    function revokeAdmin(address _oldAdmin) public onlyOwner {
      roles[ADMIN][_oldAdmin] = false;
    }

    modifier onlyAdmin(address _caller) {
      require(roles[ADMIN][_caller] == true, "You are not the admin!");
      _;
    }

    /* This function sets the winners' vesting period time (in seconds)
    */

    function initialiseWinnersVesting(uint256 _timePeriod) public onlyAdmin(msg.sender) {
      require(_timePeriod > 0, "Invalid entry!");
      ChosenTimePeriod = _timePeriod;
    }

    /* Helper function to change one of the parameters required for the Chainlink VRF co-ordinator
    */

    function changeAutomationInterval(uint256 _newInterval) public onlyOwner {
      i_interval = _newInterval;
    }

    /* The end lottery function calls the Chainlink VRF co-ordinator to request a random number
    */

    function endLottery() external onlyAdmin(msg.sender) {
        s_raffleState = RaffleState.Closed;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
        i_gasLane,
        i_subscriptionId,
        REQUEST_CONFIRMATIONS,
        i_callbackGasLimit,
        NUM_WORDS);

        emit RequestedRaffleWinner(requestId);
    }

    
    /* Internal end lottery function below, called by Chainlink keepers at regular intervals to 
    end the lottery. This is used if we choose to use Chaninlink keeper automation rather then
    manually end the lottery
    */

    function _endLottery() internal {
        s_raffleState = RaffleState.Closed;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
        i_gasLane,
        i_subscriptionId,
        REQUEST_CONFIRMATIONS,
        i_callbackGasLimit,
        NUM_WORDS);

        emit RequestedRaffleWinner(requestId);
    }

    /* Changes the entry fee needed to enter the lottery 
    */

    function changeMaxEntry(uint256 newFee) external onlyAdmin(msg.sender) {
        Max_entry = newFee;
    }

    /* Another helper function to change the gas limit for thr Chainlink VRF co-ordinator
    in case there are issues with network congestion
    */

    function changeChainlinkGasLimit(uint32 _newLimit) public onlyOwner {
      i_callbackGasLimit = _newLimit;
    }


    /* Checks if a user has already entered into the lottery
    */

    function exists1(address _addy) public view returns (bool) {
      for (uint i=0; i<investors.length; i++) {
        if (investors[i] == _addy) {
          return true;
        }
        return false;
      }
    }

    /* This is called every time the lottery is ended, to reset all the ticket balances of
    all lottery entrees back to 0
    */

    function _resetTicketEntry() internal {
      for (uint i=0; i<investors.length; i++) {
        numberOfTickets[investors[i]] = 0;
      }
    }

    /* Where a user can enter into a lottery with the required ERC-20 token
    */

    function enterRaffleInToken(uint256 _amount) public {
        if (_amount > 200) {
            revert Entry_too_high();
        }
        ShittyToken.approve(address(this), 10000); // needs to be max value and/or need a more efficient way to do this rather then calling approve everytime
        ShittyToken.transferFrom(msg.sender, address(this), _amount);

        for (uint i=0; i < _amount; i++) {
          s_players.push(payable(msg.sender));
        }

        if (!exists1(msg.sender)) {
          investors.push(msg.sender);
        }

        numberOfTickets[msg.sender] += _amount;

        emit RaffleEnter(msg.sender);
    }

    /* Returns the number of tickets that any address currently holds
    */

    function viewNumberOfTickets(address _address) public view returns (uint256){
      return numberOfTickets[_address];
    }


    /* This is called by the Chainlink VRF co-ordinator everytime the lottery is ended,
    here we use a random number to find a winner and then update the winner's winnings'
    balance with the current holdings of the smart contract. If the user is already a winner,
    their winners' balance is simply updated. The ticket numbers for each user and the array
    of addresses whom entered the lottery is re-initialised to 0.
    */

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        // s_players size 10
        // randomNumber 202
        // 202 % 10 ? what's doesn't divide evenly into 202?
        // 20 * 10 = 200
        // 2
        // 202 % 10 = 2
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        uint256 address_balance = ShittyToken.balanceOf(address(this)) - vestedTokenAllocation;
        if (winnerInfo[s_recentWinner].winOrNot == true) {
          uint256 amountBefore = winnerInfo[s_recentWinner].amount;
          winnerInfo[s_recentWinner].amount = amountBefore + address_balance;
        } else {
          winnerDetails memory details = winnerDetails(true, address_balance, block.timestamp, 0);
          winnerInfo[s_recentWinner] = details;
        }  
        vestedTokenAllocation += address_balance;
        _resetTicketEntry();
        delete(investors);
        emit WinnerPicked(recentWinner);
        s_raffleState = RaffleState.Open;
    }

    /* This allows a user towithdraw their current winnings based on the given vesting period
    */

    function withdraw2(uint256 _amount) public {
      require(winnerInfo[msg.sender].winOrNot == true, "You are not a winner, you are a loser!");
      require(winnerInfo[msg.sender].amount >= _amount, "This exceeds your allocated winnings!");
      uint256 duration = ChosenTimePeriod;
      uint256 endDateVesting = winnerInfo[msg.sender].startSchedules + duration;
      if (block.timestamp > endDateVesting) {
        ShittyToken.transferFrom(address(this), msg.sender, _amount);  
        winnerInfo[msg.sender].amountWithdrawn += _amount; 
        vestedTokenAllocation -= _amount;
      } else {
        uint256 rewardsPerSecond = winnerInfo[msg.sender].amount.div(duration);
        uint256 vestingTimeElapsed = block.timestamp - winnerInfo[msg.sender].startSchedules;
        uint256 allocatedRewards = vestingTimeElapsed.mul(rewardsPerSecond);
        if (_amount <= allocatedRewards) {
          ShittyToken.transferFrom(address(this), msg.sender, _amount);
          winnerInfo[msg.sender].amountWithdrawn += _amount;  
          vestedTokenAllocation -= _amount;
        } else {
          revert("Insufficient funds!");
        }
      }
    }

    /* Shows a lottery winning user how many tokens they can withdraw
    */

    function viewWinnings(address _account) public view returns (uint256) {  
      require(winnerInfo[_account].winOrNot == true, "You are not a winner, you are a loser!");
      uint256 duration = ChosenTimePeriod;
      uint256 rewardsPerSecond = winnerInfo[_account].amount.div(duration);  // change to _account
      uint256 vestingTimeElapsed = block.timestamp - winnerInfo[_account].startSchedules;
      uint256 allocatedRewards = vestingTimeElapsed.mul(rewardsPerSecond);
      uint256 remainingRewards = allocatedRewards - winnerInfo[_account].amountWithdrawn;
      return remainingRewards;
    }

    /* Internal function called by the Chainlink keepers for automation, should we choose
    to use automation instead to manually ending the lottery.
    */

   function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = (block.timestamp - s_lastTimeStamp) > i_interval;
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if ((block.timestamp - s_lastTimeStamp) > i_interval) {
            s_lastTimeStamp = block.timestamp;
            _endLottery();
        }
        // We don't use the performData in this example. The performData is generated by the Automation Node's call to your checkUpkeep function
    }

}