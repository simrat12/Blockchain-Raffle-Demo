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

// Now just need to chaeck time, open and close raffle every 30 days

// interface IUniswapV2Router {
//   function getAmountsOut(uint amountIn, address[] memory path)
//     external
//     view
//     returns (uint[] memory amounts);

//   function swapExactTokensForTokens(
//     uint amountIn,
//     uint amountOutMin,
//     address[] calldata path,
//     address to,
//     uint deadline
//   ) external returns (uint[] memory amounts);

//   function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
//     external
//     payable
//     returns (uint[] memory amounts);

//   function swapExactTokensForAVAX(
//     uint amountIn,
//     uint amountOutMin,
//     address[] calldata path,
//     address to,
//     uint deadline
//   ) external returns (uint[] memory amounts);

//   function swapExactAVAXForTokens(
//     uint amountOutMin,
//     address[] calldata path,
//     address to,
//     uint deadline
//   ) external payable returns (uint[] memory amounts);

//   function addLiquidity(
//     address tokenA,
//     address tokenB,
//     uint amountADesired,
//     uint amountBDesired,
//     uint amountAMin,
//     uint amountBMin,
//     address to,
//     uint deadline
//   )
//     external
//     returns (
//       uint amountA,
//       uint amountB,
//       uint liquidity
//     );

//   function removeLiquidity(
//     address tokenA,
//     address tokenB,
//     uint liquidity,
//     uint amountAMin,
//     uint amountBMin,
//     address to,
//     uint deadline
//   ) external returns (uint amountA, uint amountB);
// }

// interface IUniswapV2Pair {
//   function token0() external view returns (address);

//   function token1() external view returns (address);

//   function getReserves()
//     external
//     view
//     returns (
//       uint112 reserve0,
//       uint112 reserve1,
//       uint32 blockTimestampLast
//     );

//   function swap(
//     uint amount0Out,
//     uint amount1Out,
//     address to,
//     bytes calldata data
//   ) external;
// }

// interface IUniswapV2Factory {
//   function getPair(address token0, address token1) external view returns (address);
// }

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
    // address private constant GOERLI_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    uint256 public ChosenTimePeriod;
    mapping(address => uint256) numberOfTickets;

    // struct VestingBreakdown {
    //   uint256 chosenPeriod;
    //   uint256 timeFrame;
    // }

    struct winnerDetails {
      bool winOrNot;
      uint256 amount;
      uint256 startSchedules;
      uint256 amountWithdrawn;
    }

    // mapping(bool => VestingBreakdown) public VestingOptions;
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

    function initialiseWinnersVesting(uint256 _timePeriod) public onlyAdmin(msg.sender) {
      require(_timePeriod > 0, "Invalid entry!");
      ChosenTimePeriod = _timePeriod;
    }

    function changeAutomationInterval(uint256 _newInterval) public onlyAdmin(msg.sender) {
      i_interval = _newInterval;
    }

    // function getAmountOutMin(
    // address _tokenIn,
    // address _tokenOut,
    // uint _amountIn,
    // address ROUTER
    // ) internal view returns (uint) {
    //     address[] memory path;
    //     path = new address[](2);
    //     path[0] = _tokenIn;
    //     path[1] = _tokenOut;

    //     uint[] memory amountOutMins = IUniswapV2Router(ROUTER).getAmountsOut(_amountIn, path);
    //     return amountOutMins[path.length - 1];
    // }

    // function _swap(  
    // address _tokenIn,
    // address _tokenOut,
    // uint _amountIn
    // ) internal {
    //     address ROUTER = GOERLI_ROUTER;

    //     uint _amountOutMin = getAmountOutMin(_tokenIn, _tokenOut, _amountIn, ROUTER);

    //     WETH.approve(ROUTER, _amountIn);

    //     address[] memory path;
    //     path = new address[](2);
    //     path[0] = _tokenIn;
    //     path[1] = _tokenOut;
    

    //     IUniswapV2Router(ROUTER).swapETHForExactTokens(
    //         _amountOutMin,
    //         path,
    //         address(this),
    //         block.timestamp
    //     );
    // }


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

    function changeInterval(uint256 _newInterval) external onlyOwner {
        i_interval = _newInterval;
    } 

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

    function changeMaxEntry(uint256 newFee) external onlyAdmin(msg.sender) {
        Max_entry = newFee;
    }

    function changeChainlinkGasLimit(uint32 _newLimit) public onlyOwner {
      i_callbackGasLimit = _newLimit;
    }

    // function enterRaffle() public payable {
    //     // require(msg.value >= i_entranceFee, "Not enough value sent");
    //     // require(s_raffleState == RaffleState.OPEN, "Raffle is not open");
    //     if (msg.value < i_entranceFee) {
    //         revert Raffle__SendMoreToEnterRaffle();
    //     }
    //     if (s_raffleState != RaffleState.Open) {
    //         revert Raffle__RaffleNotOpen();
    //     }

    //     if (msg.value > Max_entry) {
    //         revert Entry_too_high();
    //     }

    //     s_players.push(payable(msg.sender));
    //     // Emit an event when we update a dynamic array or mapping
    //     // Named events with the function name reversed

    //     _swap(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6, 0x9f4c8362694225B428BE3C8B89c02Fe7b685Ad59, msg.value);

    //     emit RaffleEnter(msg.sender);
    // }

    function enterRaffleInToken(uint256 _amount) public {
        if (_amount > 200) {
            revert Entry_too_high();
        }
        ShittyToken.approve(address(this), 10000); // needs to be max value
        ShittyToken.transferFrom(msg.sender, address(this), _amount);

        for (uint i=0; i < _amount; i++) {
          s_players.push(payable(msg.sender));
        }

        numberOfTickets[msg.sender] += _amount;

        emit RaffleEnter(msg.sender);
    }

    function viewNumberOfTickets(address _address) public view returns (uint256){
      return numberOfTickets[_address];
    }


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
        winnerDetails memory details = winnerDetails(true, address_balance, block.timestamp, 0);
        winnerInfo[s_recentWinner] = details;  // maybe ensure that they are not already a winner
        vestedTokenAllocation += address_balance;
        emit WinnerPicked(recentWinner);
        s_raffleState = RaffleState.Open;
    }

    // function withdrawWinnings(uint256 _amount) public {
    //   require(winnerInfo[msg.sender].winOrNot == true, "You are not a winner, you are a loser!");
    //   require(winnerInfo[msg.sender].amount >= _amount, "This exceeds your allocated winnings!");
    //   uint256 hourlyAllow = winnerInfo[msg.sender].amount.div(VestingOptions[true].chosenPeriod);
    //   uint256 remainingTime = block.timestamp - winnerInfo[msg.sender].startSchedules;
    //   uint256 remainingTimeInHours = remainingTime.div(VestingOptions[true].timeFrame);
    //   uint256 totalAllowed = remainingTimeInHours.mul(hourlyAllow);
    //   if (totalAllowed >= _amount) {
    //     ShittyToken.transferFrom(address(this), msg.sender, _amount);
    //     vestedTokenAllocation -= _amount;
    //     winnerInfo[msg.sender].amount -= _amount;
    //   } else {
    //     revert("Insufficient Funds!");
    //   }
    // }

    function withdraw2(uint256 _amount) public {
      require(winnerInfo[msg.sender].winOrNot == true, "You are not a winner, you are a loser!");
      require(winnerInfo[msg.sender].amount >= _amount, "This exceeds your allocated winnings!");
      uint256 duration = ChosenTimePeriod;
      uint256 endDateVesting = winnerInfo[msg.sender].startSchedules + duration;
      if (block.timestamp > endDateVesting) {
        ShittyToken.transferFrom(address(this), msg.sender, _amount);  //update withdrawl mapping
        winnerInfo[msg.sender].amountWithdrawn += _amount; //decrement vestedTokenAllocation
        vestedTokenAllocation -= _amount;
      } else {
        uint256 rewardsPerSecond = winnerInfo[msg.sender].amount.div(duration);
        uint256 vestingTimeElapsed = block.timestamp - winnerInfo[msg.sender].startSchedules;
        uint256 allocatedRewards = vestingTimeElapsed.mul(rewardsPerSecond);
        if (_amount <= allocatedRewards) {
          ShittyToken.transferFrom(address(this), msg.sender, _amount);
          winnerInfo[msg.sender].amountWithdrawn += _amount;  //decrement vestedTokenAllocation
          vestedTokenAllocation -= _amount;
        } else {
          revert("Insufficient funds!");
        }
      }
    }

    function viewWinnings(address _account) public view returns (uint256) {  // use _address as argument
      require(winnerInfo[_account].winOrNot == true, "You are not a winner, you are a loser!");
      uint256 duration = ChosenTimePeriod;
      uint256 rewardsPerSecond = winnerInfo[_account].amount.div(duration);  // change to _account
      uint256 vestingTimeElapsed = block.timestamp - winnerInfo[_account].startSchedules;
      uint256 allocatedRewards = vestingTimeElapsed.mul(rewardsPerSecond);
      uint256 remainingRewards = allocatedRewards - winnerInfo[_account].amountWithdrawn;
      return remainingRewards;
    }

    // function viewRemainingWinnings() public view returns (uint256) {
    //   require(winnerInfo[msg.sender].winOrNot == true, "You are not a winner, you are a loser!");
    //   uint256 amount = winnerInfo[msg.sender].amount;
    //   uint256 remainingTime = block.timestamp - winnerInfo[msg.sender].startSchedules;
    //   uint256 dailyAllow = amount.div(remainingTime).mul(VestingOptions[true].timeFrame);
    //   return dailyAllow;
    // }

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