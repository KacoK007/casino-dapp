
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Import Foundry's test framework and console for logging
import {Test, console} from "forge-std/Test.sol";
// Import the tested contract
import {CasinoGame} from "../src/CasinoGame_flattened_v_20852978_1747841172.sol";

// A minimal ERC20 token for testing purposes implementing IERC20
contract TestERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Events matching the IERC20 interface
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, address initialOwner) {
        name = _name;
        symbol = _symbol;
        // Optionally mint zero tokens here; mint tokens via mint function later.
        // Set initialOwner if needed.
        // But do nothing here.
    }

    // Mint tokens to an address
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    // Approve spender to transfer tokens on behalf of msg.sender
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // Transfer tokens from msg.sender to recipient
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // Transfer tokens from one address to another using allowance mechanism
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

// Our test contract for CasinoGame
contract CasinoGameTest is Test {
    // Instance of the tested contract
    CasinoGame public casinoGame;
    // Instance of the test token to simulate casinoToken
    TestERC20 public token;

    // Addresses for owner and a sample player (non-owner)
    address public owner;
    address public player = address(0xBEEF);

    // A constant bet amount used in tests
    uint256 constant BET_AMOUNT = 100 ether; // using "ether" as token unit for testing convenience

    // Set up function to deploy contracts and allocate tokens
    function setUp() public {
        owner = address(this); // Test contract acts as the owner for owner functions.

        // Deploy the test ERC20 token
        token = new TestERC20("Test Token", "TT", owner);
        // Mint tokens for owner and player
        token.mint(owner, 10_000 ether);
        token.mint(player, 10_000 ether);

        // Mint tokens to the CasinoGame contract for payouts/reserves.
        // We deploy CasinoGame with address(token) and initial owner.
        casinoGame = new CasinoGame(address(token), owner);
        token.mint(address(casinoGame), 10_000 ether);
    }

    // ============================================================
    // Test Cases for Slots Game
    // ============================================================

    // Test that playSlots reverts if the player's token allowance is insufficient.
    function testSlots_InsufficientAllowance() public {
        // Using player as sender
        vm.prank(player);
        // Do not approve any tokens, so allowance is 0.
        vm.expectRevert(bytes("Insufficient allowance"));
        casinoGame.playSlots(BET_AMOUNT);
    }

    // Test that playSlots executes successfully and resets totalReserved after execution.
    // Note: Since the outcome (Jackpot, Small Win, or Lose) is determined by randomness,
    // we only check core state changes and event emission.
    function testSlots_TotalReservedReset() public {
        // Have player approve the casinoGame to spend tokens.
        vm.prank(player);
        token.approve(address(casinoGame), 10_000 ether);
        
        // Ensure that the casinoGame has sufficient funds: available funds = token.balanceOf(casinoGame) - totalReserved.
        // Before the play, totalReserved should be 0.
        uint256 availableBefore = token.balanceOf(address(casinoGame)) - casinoGame.totalReserved();
        require(availableBefore >= BET_AMOUNT * 10, "Precondition: insufficient available funds in CasinoGame");

        // Call playSlots. Outcome will emit GameResult event.
        vm.prank(player);
        casinoGame.playSlots(BET_AMOUNT);

        // Assert that totalReserved resets to 0
        assertEq(casinoGame.totalReserved(), 0, "Total reserved funds should be reset to 0 after playSlots");
    }

    // ============================================================
    // Test Cases for Blackjack Game - Start, Hit, and Stand Flows
    // ============================================================

    // Test that startBlackjack reverts if allowance is insufficient.
    function testBlackjack_InsufficientAllowance() public {
        vm.prank(player);
        // Do not approve tokens.
        vm.expectRevert(bytes("Insufficient allowance"));
        casinoGame.startBlackjack(BET_AMOUNT);
    }

    // Test a normal startBlackjack flow where the game starts properly.
    function testBlackjack_StartGame() public {
        // Player approves tokens for the bet.
        vm.prank(player);
        token.approve(address(casinoGame), 10_000 ether);

        // Start a blackjack game.
        vm.prank(player);
        casinoGame.startBlackjack(BET_AMOUNT);

        // Retrieve the player's game state from the contract.
        (uint256 bet, CasinoGame.GameState state, uint8 cardsDealt, uint256 startedAt) = casinoGame.blackjackGames(player);
        
        // Check that game state is Playing and bet is recorded
        assertEq(uint(state), uint(CasinoGame.GameState.Playing), "Game state should be Playing after startBlackjack");
        assertEq(bet, BET_AMOUNT, "Bet amount must match the provided amount");
        // According to game logic, 3 cards are dealt in total (player gets 2, dealer gets 1)
        assertEq(cardsDealt, 3, "Total cards dealt should be 3");
        assertGt(startedAt, 0, "StartedAt timestamp must be set");
    }

    // Test hit() function when the blackjack game has timed out.
    // In this test, we simulate a timeout by warping the time beyond BLACKJACK_TIMEOUT.
    function testBlackjack_HitTimeout() public {
        // Set up game for player.
        vm.prank(player);
        token.approve(address(casinoGame), 10_000 ether);
        vm.prank(player);
        casinoGame.startBlackjack(BET_AMOUNT);

        // Warp time to trigger timeout. BLACKJACK_TIMEOUT is 5 minutes.
        vm.warp(block.timestamp + 6 minutes);

        // Call hit. According to the contract, if timed out, the game should finish with a "Timeout" result.
        vm.prank(player);
        casinoGame.hit();

        // Check that the game state is now Finished.
        (, CasinoGame.GameState state, , ) = casinoGame.blackjackGames(player);
        assertEq(uint(state), uint(CasinoGame.GameState.Finished), "Game should be finished after hit timeout");
    }

    // Test stand() function when the blackjack game times out.
    function testBlackjack_StandTimeout() public {
        // Set up game for player.
        vm.prank(player);
        token.approve(address(casinoGame), 10_000 ether);
        vm.prank(player);
        casinoGame.startBlackjack(BET_AMOUNT);

        // Warp time beyond the timeout period.
        vm.warp(block.timestamp + 6 minutes);
        // Call stand; should trigger timeout behavior.
        vm.prank(player);
        casinoGame.stand();

        // Verify that the game has finished.
        (, CasinoGame.GameState state, , ) = casinoGame.blackjackGames(player);
        assertEq(uint(state), uint(CasinoGame.GameState.Finished), "Game should be finished after stand timeout");
    }

    // ============================================================
    // Test Cases for Owner-Only Functions
    // ============================================================

    // Test that the owner can call ownerTimeoutGame successfully after a game times out.
    function testAdmin_OwnerTimeoutGame_Success() public {
        // Setup a blackjack game for player.
        vm.prank(player);
        token.approve(address(casinoGame), 10_000 ether);
        vm.prank(player);
        casinoGame.startBlackjack(BET_AMOUNT);

        // Warp time to simulate timeout.
        vm.warp(block.timestamp + 6 minutes);

        // Owner calls ownerTimeoutGame on behalf of the player.
        casinoGame.ownerTimeoutGame(player);

        // Verify that the game is now finished.
        (, CasinoGame.GameState state, , ) = casinoGame.blackjackGames(player);
        assertEq(uint(state), uint(CasinoGame.GameState.Finished), "Game should be finished after admin timeout");
    }

    // Test that a non-owner cannot call ownerTimeoutGame.
    function testAdmin_OwnerTimeoutGame_NonOwner() public {
        // Set up a blackjack game for player.
        vm.prank(player);
        token.approve(address(casinoGame), 10_000 ether);
        vm.prank(player);
        casinoGame.startBlackjack(BET_AMOUNT);

        // Warp time to simulate timeout.
        vm.warp(block.timestamp + 6 minutes);

        // Try calling ownerTimeoutGame from a non-owner account.
        vm.prank(player);
        vm.expectRevert();
        casinoGame.ownerTimeoutGame(player);
    }

    // Test that only the owner can call withdrawProfit.
    function testAdmin_WithdrawProfit_NonOwner() public {
        vm.prank(player);
        vm.expectRevert();
        casinoGame.withdrawProfit(player);
    }

    // Test updateHouseEdge: owner can successfully update it to a valid value, and failure when too high.
    function testAdmin_UpdateHouseEdge() public {
        casinoGame.updateHouseEdge(500);
        assertEq(casinoGame.houseEdgeBP(), 500, "House edge should be updated to 500 bps");

        vm.expectRevert(bytes("House edge too high"));
        casinoGame.updateHouseEdge(1500);
    }

    // ============================================================
    // Test Case for withdrawProfit (Successful Flow)
    // ============================================================
    function testAdmin_WithdrawProfit_Success() public {
        // Set up a blackjack game for player.
        vm.prank(player);
        token.approve(address(casinoGame), 10_000 ether);
        vm.prank(player);
        casinoGame.startBlackjack(BET_AMOUNT);

        // Warp to trigger timeout.
        vm.warp(block.timestamp + 6 minutes);
        // Player calls hit to trigger timeout handling (profit increases).
        vm.prank(player);
        casinoGame.hit();

        // Capture the current houseProfit value.
        uint256 profitBefore = casinoGame.houseProfit();
        require(profitBefore >= BET_AMOUNT, "House profit should have increased by the bet amount on timeout");

        // Calculate expected actual profit using the houseEdgeBP.
        uint256 currentHouseEdge = casinoGame.houseEdgeBP();
        uint256 expectedProfitWithdrawn = (profitBefore * currentHouseEdge) / 10000;

        // Record owner's token balance before withdrawal.
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        // Owner withdraws profit.
        casinoGame.withdrawProfit(owner);

        // After withdrawal, houseProfit should be zero.
        assertEq(casinoGame.houseProfit(), 0, "House profit should be zero after withdrawal");

        // Owner's token balance should increase by expectedProfitWithdrawn.
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + expectedProfitWithdrawn, "Owner should receive profit tokens");
    }

    // ============================================================
    // Test Case demonstrating expected access control behavior.
    // ============================================================
    function testAccessControl_OwnerOnlyFunctions() public {
        vm.prank(player);
        vm.expectRevert();
        casinoGame.updateHouseEdge(300);
    }
    
    // ============================================================
    // Fallback and receive functions are provided to allow token transfer
    // ============================================================
    receive() external payable {}
    fallback() external payable {}
}

