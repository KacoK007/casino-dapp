// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CasinoToken is ReentrancyGuard, ERC20, Ownable{
    uint256 public RATE = 10000000 * 1 ether;
    event TokensPurchased(address indexed buyer, uint256 ethSpent, uint256 tokensReceived);
    event TokensSold(address indexed seller, uint256 tokensSold, uint256 ethReceived);
    event ETHWithdrawn(address indexed owner, uint256 amount);

    constructor(address initialOwner) ERC20("CasinoToken", "CTKN") Ownable(initialOwner) {
        _mint(address(this), 10_000_000 * 10 ** decimals());
    }

    function buy() public payable {
        require(msg.value > 0, "Send ETH to buy tokens");
        uint256 amount = msg.value * RATE / 1 ether;
        require(balanceOf(address(this)) >= amount, "Not enough CST in reserve");

        _transfer(address(this), msg.sender, amount);
        emit TokensPurchased(msg.sender, msg.value, amount);
    }

    function sell(uint256 tokenAmount) external nonReentrant {
        require(balanceOf(msg.sender) >= tokenAmount, "Not enough tokens");
        uint256 ethAmount = tokenAmount * 1 ether / RATE;
        require(address(this).balance >= ethAmount, "Not enough ETH in reserve");

        _transfer(msg.sender, address(this), tokenAmount);
        payable(msg.sender).transfer(ethAmount);

        emit TokensSold(msg.sender, tokenAmount, ethAmount);
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(address(this), amount);
    }

    function setRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Rate must be positive");
        RATE = newRate;
    }

    function withdrawETH(uint256 amount) external onlyOwner nonReentrant {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(owner()).transfer(amount); // Interaction after all checks
        emit ETHWithdrawn(owner(), amount);
    }

    receive() external payable {
        buy();
    }
}
