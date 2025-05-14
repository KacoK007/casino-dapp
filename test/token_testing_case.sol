
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Import Foundry testing utilities and console for logging
import {Test, console} from "forge-std/Test.sol";
// Import the tested contract from the specified file location
import {CasinoToken} from "../src/CasinoToken_flattened_20852978_1747146047.sol";

// ContractTest is our test contract that encapsulates all test cases for CasinoToken
contract ContractTest is Test {
    CasinoToken public token;
    address public owner;
    // A non-owner account for testing unauthorized calls
    address public nonOwner = address(0xBEEF);

    // setUp runs before each test case
    function setUp() public {
        // Set the owner to be this test contract address
        owner = address(this);
        // Instantiate the CasinoToken with the owner address
        token = new CasinoToken(owner);
        // Fund the test contract with some ETH to perform buy and other operations
        vm.deal(owner, 10 ether);
        // Fund the nonOwner account as well for testing unauthorized access
        vm.deal(nonOwner, 10 ether);
        // Log the initial token reserve and ETH balances
        console.log("Initial CasinoToken reserve: %s", token.balanceOf(address(token)));
        console.log("Initial ETH balance of token contract: %s", address(token).balance);
    }

    // ---------------------------
    // Test cases for buying tokens
    // ---------------------------

    // Test that calling buy() with a nonzero ETH value gives the expected number of tokens.
    function testBuyTokens() public {
        console.log("Running testBuyTokens");
        uint256 initialReserve = token.balanceOf(address(token));
        uint256 ethSent = 1 ether;
        
        // Call buy() with 1 ETH; the token purchase logic calculates tokens as (msg.value * RATE) / 1 ether.
        token.buy{value: ethSent}();
        
        uint256 tokensExpected = ethSent * token.RATE() / 1 ether;
        // Assert that the buyer (this contract) receives the correct token amount.
        assertEq(token.balanceOf(address(this)), tokensExpected, "Incorrect number of tokens received on buy");
        // Assert that the contract reserve decreases by the right amount.
        assertEq(token.balanceOf(address(token)), initialReserve - tokensExpected, "Token reserve not reduced correctly");
    }

    // Test that sending ETH via the fallback (receive) automatically calls buy()
    function testReceiveFallbackBuy() public {
        console.log("Running testReceiveFallbackBuy");
        uint256 ethSent = 0.5 ether;
        uint256 initialReserve = token.balanceOf(address(token));
        
        // Send ETH to the token contract without specifying a function.
        (bool success, ) = address(token).call{value: ethSent}("");
        require(success, "Fallback call failed");
        
        uint256 tokensExpected = ethSent * token.RATE() / 1 ether;
        // Assert that tokens are received after fallback call.
        assertEq(token.balanceOf(address(this)), tokensExpected, "Fallback did not yield correct token amount");
        assertEq(token.balanceOf(address(token)), initialReserve - tokensExpected, "Token reserve not updated correctly after fallback");
    }

    // Test that calling buy() with 0 ETH reverts with expected error message.
    function testBuyNoETH() public {
        console.log("Running testBuyNoETH");
        vm.expectRevert("Send ETH to buy tokens");
        token.buy{value: 0}();
    }

    // ---------------------------
    // Test cases for selling tokens
    // ---------------------------

    // Test a successful sell: First buy tokens then sell a portion.
    function testSellTokens() public {
        console.log("Running testSellTokens");
        uint256 ethToSpend = 1 ether;
        // Ensure the test contract has enough balance
        vm.deal(address(this), 10 ether);
        // Buy tokens for 1 ETH.
        token.buy{value: ethToSpend}();
        uint256 tokensBought = ethToSpend * token.RATE() / 1 ether;
        uint256 sellAmount = tokensBought / 2;
        
        // Capture ETH balance of seller before selling tokens.
        uint256 ethBefore = address(this).balance;
        // Sell half of the tokens.
        token.sell(sellAmount);
        uint256 ethReceived = sellAmount * 1 ether / token.RATE();
        
        // Check that the contract's token balance for the seller is reduced.
        assertEq(token.balanceOf(address(this)), tokensBought - sellAmount, "Token balance not reduced correctly after sell");
        // Verify that the seller’s ETH balance increased by the correct amount.
        assertEq(address(this).balance, ethBefore + ethReceived, "ETH balance not updated correctly after sell");
    }

    // Test that attempting to sell more tokens than owned reverts.
    function testSellWithoutTokens() public {
        console.log("Running testSellWithoutTokens");
        // Caller has no tokens; expect revert with "Not enough tokens"
        vm.expectRevert("Not enough tokens");
        token.sell(1);
    }

    // Test that selling fails when the contract does not have enough ETH reserve.
    function testSellNotEnoughETHReserve() public {
        console.log("Running testSellNotEnoughETHReserve");
        uint256 ethToSpend = 1 ether;
        vm.deal(address(this), 10 ether);
        // Buy tokens so that contract receives ETH on purchase.
        token.buy{value: ethToSpend}();
        // Drain the ETH reserve from the token contract by withdrawing all ETH.
        uint256 contractEthBalance = address(token).balance;
        token.withdrawETH(contractEthBalance);
        
        uint256 tokensBought = ethToSpend * token.RATE() / 1 ether;
        // Expect reverting due to insufficient ETH reserve when trying to sell tokens.
        vm.expectRevert("Not enough ETH in reserve");
        token.sell(tokensBought / 2);
    }

    // ---------------------------
    // Test cases for administrative functions
    // ---------------------------

    // Test that the owner can mint tokens to the contract's reserve.
    function testMintByOwner() public {
        console.log("Running testMintByOwner");
        uint256 reserveBefore = token.balanceOf(address(token));
        uint256 mintAmount = 1000 * 10 ** token.decimals();
        token.mint(mintAmount);
        uint256 reserveAfter = token.balanceOf(address(token));
        assertEq(reserveAfter, reserveBefore + mintAmount, "Mint did not increase reserve correctly");
    }

    // Test that a non-owner cannot mint tokens.
    function testMintByNonOwner() public {
        console.log("Running testMintByNonOwner");
        vm.prank(nonOwner);
        vm.expectRevert();
        token.mint(1000);
    }

    // Test that the owner can update the token exchange rate.
    function testSetRateByOwner() public {
        console.log("Running testSetRateByOwner");
        uint256 newRate = 5000000 * 1 ether;
        token.setRate(newRate);
        assertEq(token.RATE(), newRate, "Rate not updated correctly by owner");
    }

    // Test that a non-owner is not permitted to update the rate.
    function testSetRateByNonOwner() public {
        console.log("Running testSetRateByNonOwner");
        vm.prank(nonOwner);
        vm.expectRevert();
        token.setRate(5000000);
    }

    // Test that setting the rate to zero reverts.
    function testSetRateZero() public {
        console.log("Running testSetRateZero");
        vm.expectRevert("Rate must be positive");
        token.setRate(0);
    }

    // Test that the owner can withdraw ETH from the contract.
    function testWithdrawETHByOwner() public {
        console.log("Running testWithdrawETHByOwner");
        // First, purchase tokens to deposit ETH into the token contract.
        uint256 ethToSpend = 1 ether;
        vm.deal(address(this), 10 ether);
        token.buy{value: ethToSpend}();
        uint256 contractEthBalance = address(token).balance;
        uint256 ownerBalanceBefore = address(this).balance;
        
        // Owner withdraws the entire ETH reserve.
        token.withdrawETH(contractEthBalance);
        uint256 ownerBalanceAfter = address(this).balance;
        
        // Verify that the owner's balance increased by the withdrawn amount.
        assertEq(ownerBalanceAfter, ownerBalanceBefore + contractEthBalance, "ETH not withdrawn correctly by owner");
        // Verify that the contract's ETH balance is now zero.
        assertEq(address(token).balance, 0, "Token contract ETH balance should be zero after withdrawal");
    }

    // Test that non-owner cannot withdraw ETH.
    function testWithdrawETHByNonOwner() public {
        console.log("Running testWithdrawETHByNonOwner");
        // Purchase tokens so that the contract holds some ETH.
        uint256 ethToSpend = 1 ether;
        vm.deal(address(this), 10 ether);
        token.buy{value: ethToSpend}();
        // Attempt withdrawal from a non-owner account.
        vm.prank(nonOwner);
        vm.expectRevert();
        token.withdrawETH(1 ether);
    }

    // ---------------------------
    // Fallback and receive functions handling
    // ---------------------------
    // The token contract's receive() method calls buy(), so no explicit fallback test is needed beyond testReceiveFallbackBuy.

    // Allow the contract to receive ETH.
    receive() external payable {}
    fallback() external payable {}
}

