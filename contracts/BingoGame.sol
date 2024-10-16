// SPDX-License-Identifier : MIT

pragma solidity ^0.8.8;
import { IERC20 } from "contracts/Interface/IERC20.sol";
error NotAdminError();
error error_drawsNotStarted();
error error_winnerIsDrawing();
error erorr__entryFee();
error error__exceedLimitPlayersInOneGame();
error error__inGameAlready();
error error__gameStarted();
error error__gameWinnerDrawed();
error error__notInGameOrClaimedRewards();
error error__gameWinnerNotDrawed();
import "hardhat/console.sol";

contract Bingo {
    /// @notice Represents game stage for each player in each game round
    enum gameStage{
        BETTING,
        DRAWING,
        DRAWNED
    }

    /// @notice Represents a player in the game
    struct player{
        gameStage stage;
        uint256[25] gameBoard;
        mapping(uint256 => uint256) gameBoardMatches;
    }

    struct gameround {
        bool drawing;
        bool winnerAnnounced;
        uint256 startTime;
        uint256 bingo;
        address[] winner ;
        address[] playersArray;
        uint256[24] winningNumbers;
        mapping(address => player) players;
    }

    uint256 public currentGameRound;
    address public admin;
    uint256 public joinDuration = 180;
    uint256 public turnDuration = 180;
    address public BingoToken;
    uint256 public EntryFee = 1000000000000000000;
    bool public returnBet ;
    uint256 public maxPlayers = 4;

    mapping(uint256 => gameround) public gameRoundsData;

    event GameCreated(address indexed creator, uint256 indexed round, uint256 time);
    event PlayerJoined(address indexed player, uint256 indexed round);
    event GameDrawn(uint256 indexed round, uint256 playersCount, uint256[24] winningNumbers, uint256 bingoRound);
    event PrizeClaimed(address indexed player, uint256 amount);

    modifier onlyadmin(){
        if(msg.sender != admin) revert NotAdminError();
        _;
    }

 /// @notice Only allowing one player to draw the winning numbers with time limit
    modifier drawingWinnerCheck(uint256 _gameRound){
        if(block.timestamp < gameRoundsData[_gameRound].startTime + joinDuration + turnDuration) 
        revert error_drawsNotStarted(); 
        if(gameRoundsData[_gameRound].drawing) revert error_winnerIsDrawing();
        gameRoundsData[_gameRound].drawing = true;
        _;
        gameRoundsData[_gameRound].drawing = false;
    }

/// @notice Deploying Bingo Token first before deploying this contract
    constructor(address _bingoTokenAddress){
        BingoToken = _bingoTokenAddress;
        admin = msg.sender;
    }

    /// @notice player start a new with game board generated
    function createGameWithEntryFee() public{
        /// @notice Send Bingo Token to this contract, and check transaction success
        if (
            IERC20(BingoToken).transferFrom(
                msg.sender,
                address(this),
                EntryFee
            ) != true
        ) revert erorr__entryFee();
        /// @notice Make a new game round
        unchecked {
            ++currentGameRound;
        }
        /// @notice Save game round Id into this function
        uint256 gameRoundnow = currentGameRound;
        /// @notice Save game round start time
        gameRoundsData[gameRoundnow].startTime = block.timestamp;
        /// @notice Generating player game board for this game round
        generatePlayerBoard(msg.sender, gameRoundnow);
        emit GameCreated(msg.sender, gameRoundnow, block.timestamp);
    }

    /// @notice Players join current game and generate their game board
    /// @param _gameRoundToJoin the round of game id
    function joinCurrentGameWithEntry(uint256 _gameRoundToJoin) public {
         /// @notice With 2 lines above being said, limit no more than 4 players in a game to limit out of gas problem
        if (gameRoundsData[_gameRoundToJoin].playersArray.length + 1 > maxPlayers)
            revert error__exceedLimitPlayersInOneGame();
        (
            gameStage stageOfPlayer,
            uint256 roundStartedTimeWithDuration
        ) = getRoundDetails(_gameRoundToJoin, msg.sender);
        /// @notice Player can join multiple game at the same time, but not in the same round
        if (stageOfPlayer != gameStage.BETTING) revert error__inGameAlready();
        /// @notice Players can not join the game after join duration
        if (block.timestamp > roundStartedTimeWithDuration)
            revert error__gameStarted();
        /// @notice Send Bingo Token to this contract, and check transaction success
        if (
            IERC20(BingoToken).transferFrom(
                msg.sender,
                address(this),
                EntryFee
            ) != true
        ) revert erorr__entryFee();
        /// @notice Generating player game board for this game round
        getPlayerGameBoard(msg.sender, _gameRoundToJoin);

    }

    /// @notice Players draw winner of this game round or claim prize
    /// @dev if one game is drawed, other players in this round
    /// @param _gameRound the round of game id that player joined
    function drawWinner(uint256 _gameRound) public drawingWinnerCheck(_gameRound) {
        /// @notice Read bet amount to use for this function at beginning to save gas
        /// @notice If winner is announced then distribute the prize to the caller
        /// @dev This only be true when second time this function is called
        if (gameRoundsData[_gameRound].winnerAnnounced == true)
            revert error__gameWinnerDrawed();
        /// @notice Draw winner or winners, if two players achieved bingo in the same round, they will split the prize poll
        /// @dev Drawing winner spend unbelievable gas amount, using a automation keeper to call this function could wave gas for player in real cases
        /// @notice Read players's addresses to use for this function at beginning of drawing process to save gas
        address[] memory playersArrays = gameRoundsData[_gameRound].playersArray;
        /// @notice Init winningNumbers array now for event params
        uint256[24] memory winningNumbers;
        /// @notice if there are more than one player in the game, then drawing start
        if (playersArrays.length > 1) {
            uint256 BingoIndex = 24;
            /// @notice Call `gameGenerateNumber` to generate winning numbers
            /// @dev Will generate 24 winning numbers for players for full experience of Bingo game
            winningNumbers = generateWinningNumbers(_gameRound);
            /// @notice i: i is representing players index in this game round, loop from first player to the last player
            /// @notice j: j is representing players first bingo index in this game round
            /// @dev j: if there is a first bingo in any players game board, we set j + 1 for the loop limit to save gas
            /// @notice k: k is representing players game board number index, loop from 0 - 24
            uint256 i;
            uint256 j;
            uint256 k;
            do {
                j = 0;
                do {
                    k = 0;
                    uint256[25] memory playerGameBoard = getPlayerGameBoard(
                        playersArrays[i],
                        _gameRound
                    );
                    do {
                        /// @notice If winning number and one of the player game board matches, set the players game board matches mapping to be 1
                        if (winningNumbers[j] == playerGameBoard[k]) {
                            gameRoundsData[_gameRound]
                                .players[playersArrays[i]]
                                .gameBoardMatches[k] = 1;
                        }
                        /// @notice Skip center number
                        if (k == 11) {
                            unchecked {
                                ++k;
                            }
                        }
                        unchecked {
                            ++k;
                        }
                        /// @notice When checking more than 5 numbers, check if this is a bingo or not
                        if (k > 4) {
                            /// @notice If bingo is true
                            if (isWinningBoard(_gameRound, playersArrays[i])) {
                                /// @notice set j to be bingo round + 1 to let other player check till this round to see if there are more than one winner in this game
                                if (j == BingoIndex - 1) {
                                    gameRoundsData[_gameRound].winner.push(
                                        playersArrays[i]
                                    );
                                } else {
                                    /// @notice If new bingo round is less than the first one, clean winner array and save this new winner
                                    gameRoundsData[_gameRound]
                                        .winner = new address[](0);
                                    gameRoundsData[_gameRound].winner.push(
                                        playersArrays[i]
                                    );
                                }
                                unchecked {
                                    BingoIndex = j + 1;
                                }
                                /// @notice Save bingo round number into contract
                                gameRoundsData[_gameRound].bingo = j;
                                console.log(
                                    "First Bingo in round",
                                    j,
                                    "for player address",
                                    playersArrays[i]
                                );
                                break;
                            }
                        }
                    } while (k < 25);
                    unchecked {
                        ++j;
                    }
                } while (j < BingoIndex);
                unchecked {
                    ++i;
                }
            } while (i < playersArrays.length);
            i = 0;
            /// @notice Winner wins the pot of entry fees, transferred on win
            do {
                (bool a, uint256 b) = checkWinner(_gameRound, playersArrays[i]);
                if (a) {
                    IERC20(BingoToken).transfer(playersArrays[i], b);
                    gameRoundsData[_gameRound]
                        .players[playersArrays[i]]
                        .stage = gameStage.DRAWNED;
                    emit PrizeClaimed(playersArrays[i], b);
                }
                unchecked {
                    ++i;
                }
            } while (i < playersArrays.length);
        }
        gameRoundsData[_gameRound].winnerAnnounced = true;
        emit GameDrawn(
            _gameRound,
            playersArrays.length,
            winningNumbers,
            gameRoundsData[_gameRound].bingo
        );
    }

    /// @notice Players claim prize if retrun bet is true or there is only one player in this game round
    /// @dev Normally player dont need to call this function, in case of draw function error
    /// @dev If return bet is true, player needs to call this function to get the token back
    /// @param _gameRound the round of game id that player joined
    function claimPrize(uint256 _gameRound) public drawingWinnerCheck(_gameRound) {
         /// @notice Cheak if stage of player in this is DRAWING to let them draw or claim
        if (
            gameRoundsData[_gameRound].players[msg.sender].stage !=
            gameStage.DRAWING
        ) revert error__notInGameOrClaimedRewards();
        /// @notice Read bet amount to use for this function at beginning to save gas
        uint256 betAmount = EntryFee;
        uint256 prizeToSend;
        /// @notice If winner is announced then distribute the prize to the caller
        /// @dev This only be true when second time this function is called
        if (gameRoundsData[_gameRound].winnerAnnounced == false)
            revert error__gameWinnerNotDrawed();
        /// @notice If there is one of more bingo achieved, check the prize and send to the winner
        if (gameRoundsData[_gameRound].bingo > 0) {
            prizeToSend = checkPrize(_gameRound, msg.sender);
            if (prizeToSend > 0) {
                IERC20(BingoToken).transfer(msg.sender, prizeToSend);
            }
            /// @dev Choosing by admin about sending back players bet fees, becuase house needs token as funds to balance out automation keepers gas spend, I chose not to send back token as house revenue
        } else if (
            gameRoundsData[_gameRound].playersArray.length <= 1 || returnBet
        ) {
            /// @notice If there one player in a game refund Bingo Token player bet
            /// @notice If there no bingo achieved, refund Bingo Token player bet
            IERC20(BingoToken).transfer(msg.sender, betAmount);
        }
        gameRoundsData[_gameRound].players[msg.sender].stage = gameStage.DRAWNED;
        emit PrizeClaimed(msg.sender, prizeToSend);
    }

    /// @notice Player generating game board when creating or joinning a game
    /// @dev `joinCurrentGameWithBet` & `startNewGameWithBet` will call this internal function
    /// @param _player player's address
    /// @param _gameRound the round of game id
    function generatePlayerBoard(address _player, uint256 _gameRound) internal{
        /// @notice Change player's stage of this game round to DRAWING
        gameRoundsData[_gameRound].players[_player].stage = gameStage.DRAWING;
        /// @notice Save player's address to game round player array
        gameRoundsData[_gameRound].playersArray.push(_player);
        uint256 i;
        /// @notice Make a memory array for generating game board numbers in this function
        /// @dev Saving more gas compares to directly save numbers into contract each time
        uint256[25] memory array;
        /// @dev Generate random number, but could be replaced by on-chain services provider, such as Chainlink
        bytes32 blockHashPrevious = blockhash(block.number - 1);
        uint256 seed = uint256(blockHashPrevious);
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(seed, msg.sender))
        );
        /// @dev Use do while and unchecked{} to save gas.
        do {
            /// @notice Check if the random number bigger than 256
            
            randomNumber = (randomNumber >> 8 > 0)
                ? (randomNumber >> 8) % 256
                : (uint256(keccak256(abi.encodePacked(seed, msg.sender, i)))) %
                    256;
            /// @notice Save random number into memory array
            array[i] = randomNumber;
            /// @notice No need to save the center game borad number
            if (i == 12) {
                unchecked {
                    ++i;
                }
            }
            unchecked {
                ++i;
            }
        } while (i < 25);
        /// @notice Save generated number into player game board
        gameRoundsData[_gameRound].players[_player].gameBoard = array;
        /// @notice Set player game board matches array[12] become matched
        gameRoundsData[_gameRound].players[_player].gameBoardMatches[12] = 1;
        emit PlayerJoined(msg.sender, _gameRound);
 
    }

   /// @notice Game generating winning number of this game round
    /// @dev `drawWinnerOrClaimPrize` will call this internal function
    /// @param _gameRound the round of game id
    function generateWinningNumbers(uint256 _gameRound) internal returns(uint256[24] memory) {
        /// @notice Make a memory array for generating game board numbers in this function
        /// @dev Saving more gas compares to directly save numbers into contract each time
        /// @dev Choose 24 winning numbers between 0 - 255 is enough for a bingo to be true, and it is also be able to make player gameboard match all bingos
        /// @dev Worst case of nobody has a bingo for five players are about 28000000 gas within 0 - 255 as numbers that this contract generated for bingo game with 24 winning numbers generated
        /// @dev We could definetly choose more to make every game has a Bingo if we insist
        uint256[24] memory array;
        uint256 i;
        /// @dev Generate random number, but could be replaced by on-chain services provider, such as Chainlink
        bytes32 blockHashPrevious = blockhash(block.number - 1);
        uint256 seed = uint256(blockHashPrevious);
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(seed, msg.sender))
        );
        /// @dev Use do while and unchecked{} to save gas.
        do {
            /// @notice Check if the random number bigger than 256
            randomNumber = (randomNumber >> 8 > 0)
                ? (randomNumber >> 8) % 256
                : (uint256(keccak256(abi.encodePacked(seed, msg.sender, i)))) %
                    256;
            /// @notice Save random number into memory array
            array[i] = randomNumber;
            unchecked {
                ++i;
            }
        } while (i < 24);
        /// @notice Save winning numbers into contract
        gameRoundsData[_gameRound].winningNumbers = array;
        return (array);
    }

    /// @notice get player stage of this round and timestamp right after join duration ends
    /// @dev `joinCurrentGameWithBet` will call this internal function
    /// @param _gameRound the round of game id
    /// @param _player player address of this round of game
     function getRoundDetails(
        uint256 _gameRound,
        address _player
    ) internal view returns (gameStage, uint256) {
        return (
            gameRoundsData[_gameRound].players[_player].stage,
            gameRoundsData[_gameRound].startTime + joinDuration
        );
    }

    /// @notice Get players addresses array of this round
    /// @dev This function is for frontend to get the players addresses in each round
    /// @param _gameRound the round of game id
     function getPlayerArray(
        uint256 _gameRound
    ) public view returns (address[] memory) {
        return (gameRoundsData[_gameRound].playersArray);
    }


       /// @notice Get the Bingo result of this round of game and winning numbers
    /// @param _gameRound the round of game id
    function getBingoRoundResult(
        uint256 _gameRound
    ) public view returns (bool, uint256[24] memory) {
        return (
            gameRoundsData[_gameRound].bingo > 0,
            gameRoundsData[_gameRound].winningNumbers
        );
    }

        /// @notice Get player game board numbers in a uint256 array
    /// @param _gameRound the round of game id
    /// @param _player player address of this round of game
       function getPlayerGameBoard(
        address _player,
        uint256 _gameRound
    ) public view returns (uint256[25] memory) {
        return (gameRoundsData[_gameRound].players[_player].gameBoard);
    }
        

    /// @notice Check prize for the player of this game round
    /// @dev `claimPrize` and `checkWinner` will call this internal function
    /// @param _gameRound the round of game id
    /// @param _player player address of this round of game
     function checkPrize(
        uint256 _gameRound,
        address _player
    ) internal view returns (uint256 winningPrize) {
         address[] memory winnners = gameRoundsData[_gameRound].winner;
        uint256 i;
        uint256 n;
        do {
            if (winnners[i] == _player) {
                unchecked {
                    n++;
                }
            }
            unchecked {
                ++i;
            }
        } while (i < winnners.length);
        /// @notice If there is more than one winnier, n will be equal to 1 and times betAmountForBINGO times numbers of players divided by winners number
        return ((n *
            (EntryFee *
                (gameRoundsData[_gameRound].playersArray.length))) /
            (winnners.length));
    }

    /// @notice Check if player is the the winner of this game round, and returns bool with winning prize to claim
    /// @param _gameRound the round of game id
    /// @param _player player address of this round of game
     function checkWinner(
        uint256 _gameRound,
        address _player
    ) public view returns (bool, uint256) {
        address[] memory winnners = gameRoundsData[_gameRound].winner;
        uint256 i;
        if (winnners.length > 0) {
            do {
                if (winnners[i] == _player) {
                    uint256 prize = checkPrize(_gameRound, _player);
                    return (true, prize);
                }
                unchecked {
                    ++i;
                }
            } while (i < winnners.length);
            return (false, 0);
        } else {
            return (false, 0);
        }
    }

     /// @notice Check if player game board matches and return bool
    /// @dev `drawWinnerOrClaimPrize` will call this internal function
    /// @param _gameRound the round of game id
    /// @param _player player address of this round of game
    function isWinningBoard(uint256 _gameRound,address _player) internal view returns (bool){
         uint256 i;
        if (
            /// @notice BINGO in [1,0,0,0,0]
            /// @notice          [0,1,0,0,0]
            /// @notice          [0,0,1,0,0]
            /// @notice          [0,0,0,1,0]
            /// @notice          [0,0,0,0,1]
            (gameRoundsData[_gameRound].players[_player].gameBoardMatches[0] == 1 &&
                gameRoundsData[_gameRound].players[_player].gameBoardMatches[6] ==
                1 &&
                gameRoundsData[_gameRound].players[_player].gameBoardMatches[18] ==
                1 &&
                gameRoundsData[_gameRound].players[_player].gameBoardMatches[24] ==
                1) ||
            /// @notice BINGO in [0,0,0,0,1]
            /// @notice          [0,0,0,1,0]
            /// @notice          [0,0,1,0,0]
            /// @notice          [0,1,0,0,0]
            /// @notice          [1,0,0,0,0]
            (gameRoundsData[_gameRound].players[_player].gameBoardMatches[4] == 1 &&
                gameRoundsData[_gameRound].players[_player].gameBoardMatches[8] ==
                1 &&
                gameRoundsData[_gameRound].players[_player].gameBoardMatches[16] ==
                1 &&
                gameRoundsData[_gameRound].players[_player].gameBoardMatches[20] ==
                1)
        ) {
            return (true);
        }
        do {
            if (
                /// @notice BINGO in [1,1,1,1,1] ↓
                /// @notice          [0,0,0,0,0] ↓
                /// @notice          [0,0,0,0,0] ↓
                /// @notice          [0,0,0,0,0] ↓
                /// @notice          [0,0,0,0,0] ↓
                (gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                    i * 5 + 0
                ] ==
                    1 &&
                    gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                        i * 5 + 1
                    ] ==
                    1 &&
                    gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                        i * 5 + 2
                    ] ==
                    1 &&
                    gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                        i * 5 + 3
                    ] ==
                    1 &&
                    gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                        i * 5 + 4
                    ] ==
                    1) ||
                /// @notice           → → → → →
                /// @notice BINGO in [1,0,0,0,0]
                /// @notice          [1,0,0,0,0]
                /// @notice          [1,0,0,0,0]
                /// @notice          [1,0,0,0,0]
                /// @notice          [1,0,0,0,0]
                (gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                    0 + i
                ] ==
                    1 &&
                    gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                        5 + i
                    ] ==
                    1 &&
                    gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                        10 + i
                    ] ==
                    1 &&
                    gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                        15 + i
                    ] ==
                    1 &&
                    gameRoundsData[_gameRound].players[_player].gameBoardMatches[
                        20 + i
                    ] ==
                    1)
            ) {
                return (true);
            }
            unchecked {
                ++i;
            }
        } while (i < 5);

        return (false);
    }

        function setJoinDuration(uint256 _joinDuration) public onlyadmin {
        joinDuration = _joinDuration;
    }

    function setConfigTurnDuration(uint256 _turnDuration) public onlyadmin {
        turnDuration = _turnDuration;
    }

    function setConfigEntryFee(
        uint256 _entryFee
    ) public onlyadmin {
        EntryFee = _entryFee;
    }

    function setConfigRefundEntryFee(bool _returnBet) public onlyadmin {
        returnBet = _returnBet;
    }

    function setConfigMaxPlayer(uint256 _maxPlayers) public onlyadmin {
        maxPlayers = _maxPlayers;
    }

    /// @dev this function helps people who accidentally transfer ERC20 token to our contract, and also withdraw Bingo Token as revenue
    function withdrawToken(
        address _erc20ContractAddress,
        uint256 _amount,
        address _to
    ) external onlyadmin {
        IERC20(_erc20ContractAddress).approve(address(this), _amount);
        bool callSuccess = IERC20(_erc20ContractAddress).transferFrom(
            address(this),
            _to,
            _amount
        );
        require(callSuccess, "Transfer failed");
    }



}