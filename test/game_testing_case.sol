
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Import Foundry's testing framework and console for debugging
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Import the tested CasinoGame contract from the specified file path
import {CasinoGame} from "../src/CasinoGame_flattened_20852978_1747151294.sol";

/*
    A simple mock ERC20 token contract to simulate the casino token functionality.
    It implements the minimal functions required by the CasinoGame contract.
*/
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    
    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        // Mint the entire supply to the deployer (msg.sender)
        balances[msg.sender] = _initialSupply;
    }
    
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        unchecked {
            balances[msg.sender] -= amount;
            balances[to] += amount;
        }
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }
    
    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balances[from] >= amount, "Insufficient balance");
        require(allowances[from][msg.sender] >= amount, "Insufficient allowance");
        unchecked {
            balances[from] -= amount;
            allowances[from][msg.sender] -= amount;
            balances[to] += amount;
        }
        return true;
    }
    
    // Mint additional tokens to an account (for testing)
    function mint(address to, uint256 amount) external {
        balances[to] += amount;
        totalSupply += amount;
    }
}

/*
    Test contract for CasinoGame. It covers all main business flows:
    1. Playing slots: checking for insufficient allowance, insufficient contract funds,
       and normal play flow.
    2. Blackjack game: starting a game, handling timeout via hit, stand flow,
       and owner-forced timeout.
    3. Admin functions: profit withdrawal and updating house edge with proper access control.
    4. General checks: access control on owner-only functions.
*/
contract CasinoGameTest is Test {
    // Instances of the tested contract and the mock token.
    CasinoGame public casinoGame;
    MockERC20 public mockToken;
    
    // Test addresses to simulate different roles.
    address public player = address(0x1);
    address public nonOwner = address(0x2);
    
    // Constants for initial token supplies and bet amounts for tests.
    uint256 constant INITIAL_MOCK_SUPPLY = 1_000_000 ether;
    uint256 constant CONTRACT_FUND_AMOUNT = 100_000 ether;
    uint256 constant BET_AMOUNT = 100 ether;
    
    // setUp runs before each test case.
    function setUp() public {
        // Deploy the mock token with an initial supply minted to this contract.
        mockToken = new MockERC20(INITIAL_MOCK_SUPPLY);
        
        // Deploy the CasinoGame contract with this contract as the owner.
        casinoGame = new CasinoGame(address(mockToken), address(this));
        
        // Fund the CasinoGame contract with tokens to simulate available funds.
        // Transfer tokens from this contract (which holds initial supply) to the CasinoGame.
        bool success = mockToken.transfer(address(casinoGame), CONTRACT_FUND_AMOUNT);
        require(success, "Initial funding failed");
        
        // Mint tokens to the player for placing bets.
        // Here, we assume the test contract can call mint; in real cases the token might have different access.
        mockToken.mint(player, 10_000 ether);
    }
    
    // -------------------------------
    // Test cases for Slots game
    // -------------------------------
    
    // Test that calling playSlots fails if the player's token allowance is insufficient.
    function testPlaySlotsInsufficientAllowance() public {
        vm.prank(player);
        // Do not approve casinoGame for token spending, so validBet modifier should fail.
        vm.expectRevert(bytes("Insufficient allowance"));
        casinoGame.playSlots(BET_AMOUNT);
    }
    
    // Test that playSlots fails if the CasinoGame contract does not have enough tokens available.
    function testPlaySlotsInsufficientFunds() public {
        vm.startPrank(player);
        // Approve the CasinoGame contract to spend tokens.
        mockToken.approve(address(casinoGame), BET_AMOUNT);
        // Drain CasinoGame funds to simulate insufficient funds.
        // Transfer almost all tokens out of contract so that available funds < BET_AMOUNT * 10.
        bool success = mockToken.transfer(address(0xDEAD), CONTRACT_FUND_AMOUNT - (BET_AMOUNT * 9));
        require(success, "Token draining failed");
        
        // Expect revert due to insufficient available funds.
        vm.expectRevert(bytes("Insufficient available funds"));
        casinoGame.playSlots(BET_AMOUNT);
        vm.stopPrank();
    }
    
    // Test normal flow of playSlots. Since randomness is nondeterministic, we test that state variables are updated and event is emitted.
    function testPlaySlotsNormalFlow() public {
        vm.startPrank(player);
        // Approve tokens for the bet.
        mockToken.approve(address(casinoGame), BET_AMOUNT);
        
        // Record contract and player token balances before playing.
        uint256 contractBalanceBefore = mockToken.balanceOf(address(casinoGame));
        uint256 playerBalanceBefore = mockToken.balanceOf(player);
        
        // Call playSlots. The outcome (Jackpot, Small Win, or Lose) is based on randomness.
        casinoGame.playSlots(BET_AMOUNT);
        
        // After playSlots execution, totalReserved should return to zero.
        // And player's balance might have increased if they win.
        uint256 totalReservedAfter = casinoGame.totalReserved();
        assertEq(totalReservedAfter, 0, "Total reserved should be zero after playSlots");
        
        // Emit event verification could be added if using expectEmit (omitted for brevity).
        vm.stopPrank();
    }
    
    // -------------------------------
    // Test cases for Blackjack game flow
    // -------------------------------
    
    // Test starting a blackjack game.
    function testStartBlackjack() public {
        vm.startPrank(player);
        // Approve tokens for betting.
        mockToken.approve(address(casinoGame), BET_AMOUNT);
        
        // Start a blackjack game.
        casinoGame.startBlackjack(BET_AMOUNT);
        
        // Retrieve player game details from the blackjackGames mapping.
        (uint256 bet, CasinoGame.GameState stateVal, uint256 startedAt, ) = casinoGame.blackjackGames(player);
        assertEq(bet, BET_AMOUNT, "Bet amount mismatch in blackjack game");
        // State should be Playing.
        assertEq(uint(stateVal), uint(CasinoGame.GameState.Playing), "Game state should be Playing");
        // startedAt should be set (non zero).
        assertGt(startedAt, 0, "Game start time not recorded");
        vm.stopPrank();
    }
    
    // Test blackjack timeout using hit(). If the game times out, the contract should finish the game automatically.
    function testBlackjackTimeoutByHit() public {
        vm.startPrank(player);
        // Approve tokens.
        mockToken.approve(address(casinoGame), BET_AMOUNT);
        casinoGame.startBlackjack(BET_AMOUNT);
        
        // Warp the time beyond the blackjack timeout period.
        // BLACKJACK_TIMEOUT is set to 5 minutes in the contract.
        vm.warp(block.timestamp + 6 minutes);
        
        // Call hit() to trigger the timeout flow by the checkTimeout modifier.
        // Even though hit() is normally for drawing a card, in this case it should detect the timeout.
        casinoGame.hit();
        
        // After timeout, retrieve the game state.
        (, CasinoGame.GameState stateAfter, , ) = casinoGame.blackjackGames(player);
        assertEq(uint(stateAfter), uint(CasinoGame.GameState.Finished), "Game should be finished after timeout");
        vm.stopPrank();
    }
    
    // Test stand function flow. Due to randomness, we only check that the game is finished
    // and that totalReserved is updated accordingly.
    function testBlackjackStandFlow() public {
        vm.startPrank(player);
        // Approve tokens.
        mockToken.approve(address(casinoGame), BET_AMOUNT);
        casinoGame.startBlackjack(BET_AMOUNT);
        
        // Call stand() without warping time (normal flow)
        casinoGame.stand();
        
        // Retrieve the game state and check that it is finished.
        (, CasinoGame.GameState stateAfter, , ) = casinoGame.blackjackGames(player);
        assertEq(uint(stateAfter), uint(CasinoGame.GameState.Finished), "Game should be finished after stand");
        vm.stopPrank();
    }
    
    // Test admin function ownerTimeoutGame by simulating a timeout case and then calling the owner function.
    function testOwnerTimeoutGame() public {
        // First, start a blackjack game as the player.
        vm.startPrank(player);
        mockToken.approve(address(casinoGame), BET_AMOUNT);
        casinoGame.startBlackjack(BET_AMOUNT);
        vm.stopPrank();
        
        // Warp time beyond the timeout period.
        vm.warp(block.timestamp + 6 minutes);
        
        // As owner, call ownerTimeoutGame.
        casinoGame.ownerTimeoutGame(player);
        
        // Check that the game state for the player is Finished.
        (, CasinoGame.GameState stateAfter, , ) = casinoGame.blackjackGames(player);
        assertEq(uint(stateAfter), uint(CasinoGame.GameState.Finished), "Game should be finished after admin timeout");
    }
    
    // -------------------------------
    // Test cases for Admin (owner) functions and access control
    // -------------------------------
    
    // Test that a non-owner cannot call withdrawProfit.
    function testWithdrawProfitAccessControl() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        casinoGame.withdrawProfit(nonOwner);
    }
    
    // Test withdrawProfit functionality when called by the owner.
    function testWithdrawProfit() public {
        // To simulate profit, we force a blackjack loss.
        vm.startPrank(player);
        // Approve and start a blackjack game.
        mockToken.approve(address(casinoGame), BET_AMOUNT);
        casinoGame.startBlackjack(BET_AMOUNT);
        // Warp to force timeout.
        vm.warp(block.timestamp + 6 minutes);
        casinoGame.hit(); // triggers timeout and house profit accumulation
        vm.stopPrank();
        
        // Record owner's balance before withdrawal.
        uint256 ownerBalanceBefore = mockToken.balanceOf(address(this));
        
        // Call withdrawProfit as owner.
        casinoGame.withdrawProfit(address(this));
        
        // Check that owner's balance increased by the expected profit.
        uint256 ownerBalanceAfter = mockToken.balanceOf(address(this));
        // Expected profit = (houseProfit * houseEdgeBP) / 10000.
        // We know houseProfit increased by BET_AMOUNT during the timeout
        uint256 expectedProfit = (BET_AMOUNT * casinoGame.houseEdgeBP()) / 10000;
        assertEq(ownerBalanceAfter - ownerBalanceBefore, expectedProfit, "Owner did not receive correct profit");
    }
    
    // Test that non-owner cannot update the house edge.
    function testUpdateHouseEdgeAccessControl() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        casinoGame.updateHouseEdge(300); // Attempt to set new house edge by non-owner
    }
    
    // Test updating the house edge by the owner.
    function testUpdateHouseEdge() public {
        uint256 newEdge = 300; // 3%
        casinoGame.updateHouseEdge(newEdge);
        assertEq(casinoGame.houseEdgeBP(), newEdge, "House edge was not updated correctly");
    }
    
    // -------------------------------
    // Test common potential bugs: Arbitrary caller updating owner-only state
    // -------------------------------
    
    // For example, if the owner modifier was missing in updateHouseEdge,
    // an arbitrary caller could update the house edge. This test ensures that
    // in the absence of the vulnerability, non-owners are not allowed.
    // (This test is expected to revert.)
    function test_arbitraryCallerCannotUpdateOwnerOnly() public {
        vm.prank(nonOwner);
        // Expect revert because nonOwner should not update house edge.
        vm.expectRevert();
        casinoGame.updateHouseEdge(400);
        
        // Similarly, check that withdrawProfit cannot be called by arbitrary addresses.
        vm.prank(nonOwner);
        vm.expectRevert();
        casinoGame.withdrawProfit(nonOwner);
    }
    
    // Receive and fallback functions so the test contract can receive tokens.
    receive() external payable {}
    fallback() external payable {}
}

