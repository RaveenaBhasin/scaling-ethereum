// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// A contract to store the state of the game and the moves made by the players 
// for game of three card
contract AdminThreeCard  {
    IERC20 public immutable gameToken;
    constructor(address _gameTokenAddress) {
        gameToken = IERC20(_gameTokenAddress);
    }

    enum BetType { call, raise, boot, pack }  // If the player bets high or low
    enum GameStage { NotStarted, Started, Ended }  // If the player bets high or low

    uint public totalGames;

    mapping(uint => Game) public Games;

    event GameCreated(uint gameId, address playerAddress, uint amount);
    event EnteredAGame(uint gameId, address playerAddress, uint amount);
    event CardsSeen(uint[] cards, uint gameId, address playerAddress);
    event Scored(uint gameId, address playerAddress, uint score, address opponentAddress, uint opponentScore);


    // A move in the game
    struct Move {
        uint gameId;
        uint moveId;
        address playerAddress;
        BetType bet;
        uint amount;
        uint timestamp;
    }

    struct PlayerState {
        address playerAddress;
        bool registered;
        bool SeenOrNot;
        uint256[] cards;
    }

    struct Game {
        uint gameId;
        uint totalPlayers;
        mapping(address => PlayerState) players;
        address[2] allPlayerAddresses;
        uint potBalance;
        Move lastmove;
        GameStage currentGameStage;
        Result result;
    }

    struct Result {
        uint gameId;
        bool isMatchTied;
        address winner;
        address loser;
        uint totalWinamount;
    }

    function createNewGame(uint bootAmount) public {
        Game storage newGame = Games[totalGames];

        newGame.gameId = totalGames;
        uint256[] memory cards;
        newGame.players[msg.sender] = PlayerState(msg.sender, true, false, cards);
        newGame.potBalance = bootAmount;
        newGame.currentGameStage = GameStage.NotStarted;  
        newGame.totalPlayers = 1;  

        newGame.allPlayerAddresses[newGame.totalPlayers - 1] = msg.sender;


        gameToken.transferFrom(msg.sender, address(this), bootAmount);

        (uint card1, uint card2, uint card3) = dealCards();
        newGame.players[msg.sender].cards.push(card1);
        newGame.players[msg.sender].cards.push(card2);
        newGame.players[msg.sender].cards.push(card3);
        emit GameCreated(totalGames++, msg.sender, bootAmount);
    }


    function enterGame(uint gameId) public {
        require(gameId < totalGames, "Game does not exist");

        Game storage game = Games[gameId];

        require(game.players[msg.sender].registered == false, "You are already in the game");
        require(game.totalPlayers < 2, "Game is full");
        require(game.currentGameStage == GameStage.NotStarted, "Game has already started");

        gameToken.transferFrom(msg.sender, address(this), game.potBalance);
        game.totalPlayers = 2;
        uint256[] memory cards;
        game.players[msg.sender] = PlayerState(msg.sender, true, false, cards);
        game.currentGameStage = GameStage.Started;
        game.allPlayerAddresses[game.totalPlayers - 1] = msg.sender;
        
        game.lastmove = Move(gameId, 0, msg.sender, BetType.call, game.potBalance, block.timestamp);

        game.potBalance = game.potBalance * 2;

        (uint card1, uint card2, uint card3) = dealCards();
        game.players[msg.sender].cards.push(card1);
        game.players[msg.sender].cards.push(card2);
        game.players[msg.sender].cards.push(card3);

        emit EnteredAGame(gameId, msg.sender, game.potBalance);
    }

    uint256 randNonce = 0;
    function dealCards() internal returns(uint, uint, uint) {
        // increase nonce
        randNonce += 3;
        uint card1 = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 52;
        uint card2 = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce+1))) % 52;
        uint card3 = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce+2))) % 52;
        return (card1, card2, card3);
    }

    function viewMyCards(uint gameId) external returns(uint256[] memory cards) {
        Game storage game = Games[gameId];
        PlayerState storage playerState = game.players[msg.sender];
        require(playerState.SeenOrNot == false, "You have already seen your cards");
        playerState.SeenOrNot = true;
        cards = playerState.cards;
        emit CardsSeen(playerState.cards, gameId, msg.sender);
    }

    function playMove(uint gameId, BetType betType, uint amount, bool show) public {
        require(gameId < totalGames, "Game does not exist");

        Game storage game = Games[gameId];

        require(game.currentGameStage == GameStage.Started, "Game has not Started yet, or has ended");
        require(game.totalPlayers == 2, "Game is not full");
        require(game.players[msg.sender].playerAddress != address(0), "You are not in the game");
        require(game.lastmove.playerAddress != msg.sender, "You have already played a move");

        bool moverSeenOrNot = game.players[game.lastmove.playerAddress].SeenOrNot;
        bool opponentSeenOrNot = game.players[msg.sender].SeenOrNot;


        if (betType == BetType.pack) {
            require(amount == 0, "Amount should be 0");
            game.currentGameStage = GameStage.Ended;
            game.result = Result(gameId, false, game.lastmove.playerAddress, msg.sender, game.potBalance);
        }
        else if(betType == BetType.call) {
            if(moverSeenOrNot == opponentSeenOrNot) {
                require(amount == game.lastmove.amount, "Amount should be same as previous move");
            }
            else {
                if(moverSeenOrNot)
                    require(amount == game.lastmove.amount * 2, "Amount should be double of previous move");
                else 
                    require(amount == game.lastmove.amount / 2, "Amount should be half of previous move");
            }
        } else if(betType == BetType.raise) {
            if(moverSeenOrNot == opponentSeenOrNot) {
                require(amount == 2*game.lastmove.amount, "Amount should be same as previous move");
            }
            else {
                if(moverSeenOrNot)
                    require(amount == game.lastmove.amount * 4, "Amount should be double of previous move");
                else 
                    require(amount == game.lastmove.amount, "Amount should be half of previous move");
            }
        }
        gameToken.transferFrom(msg.sender, address(this), amount);
        game.lastmove = Move(gameId, game.lastmove.moveId + 1, msg.sender, betType, amount, block.timestamp);
        game.potBalance += amount;

        if(betType == BetType.raise && show) {
            address[2] memory allPlayerAddresses = game.allPlayerAddresses;
            uint256[] memory cardsOfPlayer1 = game.players[allPlayerAddresses[0]].cards;
            uint256[] memory cardsOfPlayer2 = game.players[allPlayerAddresses[1]].cards;


            uint256 scoreOfPlayer1 = (cardsOfPlayer1[0] + cardsOfPlayer1[1] + cardsOfPlayer1[2]) % 10;
            uint256 scoreOfPlayer2 = (cardsOfPlayer2[0] + cardsOfPlayer2[1] + cardsOfPlayer2[2]) % 10;

            emit Scored(gameId, allPlayerAddresses[0], scoreOfPlayer1, allPlayerAddresses[1], scoreOfPlayer2);

            if(scoreOfPlayer1 == scoreOfPlayer2) {
                game.result = Result(gameId, true, allPlayerAddresses[0], allPlayerAddresses[1], game.potBalance);
                gameToken.transfer(allPlayerAddresses[0], game.potBalance/2);
                gameToken.transfer(allPlayerAddresses[1], game.potBalance/2);
            } else if(scoreOfPlayer1 > scoreOfPlayer2) {
                game.result = Result(gameId, false, allPlayerAddresses[0], allPlayerAddresses[1], game.potBalance);
                gameToken.transfer(allPlayerAddresses[0], game.potBalance);
            } else {
                game.result = Result(gameId, false, allPlayerAddresses[1], allPlayerAddresses[0], game.potBalance);
                gameToken.transfer(allPlayerAddresses[1], game.potBalance);
            }
        }
    }
}
