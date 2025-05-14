// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CasinoGame is Ownable, ReentrancyGuard {
    IERC20 public immutable casinoToken;
    uint256 public houseProfit;
    uint256 public totalReserved; //
    uint256 public houseEdgeBP = 200; // 2% house edge
    uint256 private _nonce; // add randomness


    enum GameState { None, Playing, Finished }

    struct BlackjackGame {
        uint8[] playerCards;
        uint8[] dealerCards;
        uint256 betAmount;
        GameState state;
        uint8[52] deck;
        uint8 cardsDealt;
        uint256 startedAt;
    }

    mapping(address => BlackjackGame) public blackjackGames;
    uint256 public constant BLACKJACK_TIMEOUT = 5 minutes;

    event GameResult(address indexed player, string game, uint256 betAmount, uint256 payout, string result);
    event DeckShuffled(address indexed player);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        casinoToken = IERC20(_token);
    }

    modifier validBet(uint256 amount) {
        require(amount > 0, "Bet must be greater than zero");
        require(casinoToken.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");
        _;
    }

    modifier checkTimeout(address player) {
        BlackjackGame storage game = blackjackGames[player];
        if (game.state == GameState.Playing && 
            block.timestamp >= game.startedAt + BLACKJACK_TIMEOUT) {
            game.state = GameState.Finished;
            totalReserved -= game.betAmount * 2;
            houseProfit += game.betAmount;
            emit GameResult(player, "Blackjack", game.betAmount, 0, "Timeout");
        }
        _;
    }

    // Improved randomness generator
    function _random(uint256 max) internal returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            _nonce++
        ))) % max;
    }

    // === SLOTS ===
    function playSlots(uint256 betAmount) external nonReentrant validBet(betAmount) {
        require(
            casinoToken.balanceOf(address(this)) - totalReserved >= betAmount * 10,
            "Insufficient available funds"
        );
        totalReserved += betAmount * 10;
        casinoToken.transferFrom(msg.sender, address(this), betAmount);
        uint256 rand = _random(1000);
        string memory result;
        uint256 payout;
        
        if (rand < 5) {
            payout = betAmount * 10;
            result = "Jackpot";
        } else if (rand < 50) {
            payout = betAmount * 2;
            result = "Small Win";
        } else {
            payout = 0;
            result = "Lose";
        }

        totalReserved -= betAmount * 10;
        if (payout > 0) {
            totalReserved += payout;
            _safeTransfer(msg.sender, payout);
            totalReserved -= payout;
        } else {
            houseProfit += betAmount;
        }

        emit GameResult(msg.sender, "Slots", betAmount, payout, result);
    }

    // === BLACKJACK ===
    function startBlackjack(uint256 betAmount) external nonReentrant validBet(betAmount) {
        BlackjackGame storage game = blackjackGames[msg.sender];
        require(game.state != GameState.Playing, "Finish your current game first");
        require(
            casinoToken.balanceOf(address(this)) - totalReserved >= betAmount * 2,
            "Insufficient available funds"
        );
        totalReserved += betAmount * 2;

        casinoToken.transferFrom(msg.sender, address(this), betAmount);

        game.betAmount = betAmount;
        game.state = GameState.Playing;
        game.cardsDealt = 0;
        game.startedAt = block.timestamp;
        delete game.playerCards;
        delete game.dealerCards;
        shuffleDeck(game);

        game.playerCards.push(drawCard(game));
        game.dealerCards.push(drawCard(game));
        game.playerCards.push(drawCard(game));
    }

    function hit() external nonReentrant checkTimeout(msg.sender) {
        BlackjackGame storage game = blackjackGames[msg.sender];
        require(game.state == GameState.Playing, "No active game or timed out");

        game.playerCards.push(drawCard(game));

        if (handValue(game.playerCards) > 21) {
            totalReserved -= game.betAmount * 2;
            game.state = GameState.Finished;
            houseProfit += game.betAmount;
            emit GameResult(msg.sender, "Blackjack", game.betAmount, 0, "Bust");
        }
    }

    function stand() external nonReentrant checkTimeout(msg.sender) {
        BlackjackGame storage game = blackjackGames[msg.sender];
        require(game.state == GameState.Playing, "No active game or timed out");

        while (handValue(game.dealerCards) < 17) {
            game.dealerCards.push(drawCard(game));
        }

        uint256 playerScore = handValue(game.playerCards);
        uint256 dealerScore = handValue(game.dealerCards);
        uint256 payout = 0;
        string memory result;

        totalReserved -= game.betAmount * 2;
        
        if (dealerScore > 21 || playerScore > dealerScore) {
            payout = game.betAmount * 2;
            totalReserved += payout;
            _safeTransfer(msg.sender, payout);
            totalReserved -= payout;
            result = "Win";
        } else if (playerScore == dealerScore) {
            payout = game.betAmount;
            totalReserved += payout;
            _safeTransfer(msg.sender, payout);
            totalReserved -= payout;
            result = "Push";
        } else {
            result = "Lose";
            houseProfit += game.betAmount;
        }

        game.state = GameState.Finished;
        emit GameResult(msg.sender, "Blackjack", game.betAmount, payout, result);
    }


    // Improved deck shuffling
    function shuffleDeck(BlackjackGame storage game) internal {
        // Initialize deck
        for (uint8 i = 0; i < 52; i++) {
            game.deck[i] = (i % 13) + 1; // Values from 1 (Ace) to 13 (King)
        }

        // Fisher-Yates shuffle with improved randomness
        for (uint8 i = 51; i > 0; i--) {
            uint256 n = _random(i + 1);
            (game.deck[i], game.deck[n]) = (game.deck[n], game.deck[i]);
        }

        emit DeckShuffled(msg.sender);
    }

    // === Helper Functions ===
    function drawCard(BlackjackGame storage game) internal returns (uint8) {
        require(game.cardsDealt < 52, "Deck exhausted");
        return game.deck[game.cardsDealt++];
    }

    function handValue(uint8[] memory cards) internal pure returns (uint256 total) {
        uint256 aces = 0;
        for (uint256 i = 0; i < cards.length; i++) {
            uint8 card = cards[i];
            if (card > 10) card = 10;
            if (card == 1) {
                aces++;
                total += 11;
            } else {
                total += card;
            }
        }
        while (total > 21 && aces > 0) {
            total -= 10;
            aces--;
        }
    }

    function _safeTransfer(address to, uint256 amount) internal {
        bool success = casinoToken.transfer(to, amount);
        require(success, "Token transfer failed");
    }

    // === Admin ===
     function ownerTimeoutGame(address player) external onlyOwner nonReentrant {
        BlackjackGame storage game = blackjackGames[player];
        require(game.state == GameState.Playing, "No active game for this player");
        require(block.timestamp >= game.startedAt + BLACKJACK_TIMEOUT, "Game not expired");

        game.state = GameState.Finished;
        totalReserved -= game.betAmount * 2;
        houseProfit += game.betAmount;
        emit GameResult(player, "Blackjack", game.betAmount, 0, "Admin Timeout");
    }
    function withdrawProfit(address to) external onlyOwner nonReentrant {
        uint256 totalBalance = casinoToken.balanceOf(address(this));
        uint256 actualProfit = (houseProfit * houseEdgeBP) / 10000;
        require(totalBalance >= actualProfit, "Insufficient contract balance");
        
        houseProfit = 0;
        _safeTransfer(to, actualProfit);
    }

    function updateHouseEdge(uint256 newEdgeBP) external onlyOwner {
        require(newEdgeBP <= 1000, "House edge too high");
        houseEdgeBP = newEdgeBP;
    }

    // View functions remain the same
    function getPlayerCards() external view returns (uint8[] memory) {
        return blackjackGames[msg.sender].playerCards;
    }

    function getDealerCards() external view returns (uint8[] memory) {
        return blackjackGames[msg.sender].dealerCards;
    }
}