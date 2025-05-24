// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ERC20interface.sol";

contract CryptoICO is ReentrancyGuard {
    using SafeMath for uint256;
    address public owner;
    
    // ICO Properties
    Crypto public cryptoToken;
    uint256 public tokenPrice = 0.001 ether; // 1000 tokens per 1 ETH
    uint256 public maxTokensForSale;
    uint256 public tokensSold = 0;
    uint256 public icoStartTime;
    uint256 public icoEndTime;
    uint256 public minPurchase = 0.01 ether;
    uint256 public maxPurchase = 10 ether;

    // ICO Status
    bool public icoActive = false;
    
    // ICO tracking
    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokensPurchased;
    address[] public investors;
    
    // Events
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event ICOStarted(uint256 startTime, uint256 endTime);
    event ICOEnded();
    event FundsWithdrawn(uint256 amount);
    event TokensWithdrawn(uint256 amount);
    
    constructor(address _tokenAddress, uint256 _maxTokensForSale) {
        cryptoToken = Crypto(_tokenAddress);
        maxTokensForSale = _maxTokensForSale;
        owner = msg.sender;
    }
    
    // ICO Management Functions
    function startICO(uint256 _duration) external onlyOwner {
        require(!icoActive, "ICO: Already active");
        require(cryptoToken.balanceOf(address(this)) >= maxTokensForSale, "ICO: Insufficient tokens in contract");
        
        icoStartTime = block.timestamp;
        icoEndTime = block.timestamp.add(_duration);
        icoActive = true;
        
        emit ICOStarted(icoStartTime, icoEndTime);
    }
    
    function endICO() external onlyOwner {
        require(icoActive, "ICO: Not active");
        icoActive = false;
        emit ICOEnded();
    }
    
    // Calculate how many tokens you get for a given ETH amount
    function calculateTokenAmount(uint256 _weiAmount) public pure returns (uint256) {
        return _weiAmount.mul(1000).div(1 ether); // 1000 tokens per 1 ETH
    }
    
    // Calculate how much ETH is needed for a specific token amount
    function calculateEthAmount(uint256 _tokenAmount) public view returns (uint256) {
        return _tokenAmount.mul(tokenPrice);
    }
    
    // Token Purchase Function - Main method for buying tokens during ICO
    function buyTokens() public payable nonReentrant {
        require(icoActive, "ICO: Not active");
        require(block.timestamp >= icoStartTime && block.timestamp <= icoEndTime, "ICO: Outside sale period");
        require(msg.value >= minPurchase, "ICO: Below minimum purchase");
        require(msg.value <= maxPurchase, "ICO: Above maximum purchase");
        
        // Calculate tokens to give
        uint256 tokenAmount = calculateTokenAmount(msg.value);
        require(tokensSold.add(tokenAmount) <= maxTokensForSale, "ICO: Not enough tokens available");
        require(cryptoToken.balanceOf(address(this)) >= tokenAmount, "ICO: Insufficient tokens in contract");
        
        // Update tracking variables
        tokensSold = tokensSold.add(tokenAmount);
        contributions[msg.sender] = contributions[msg.sender].add(msg.value);
        
        // Add to investors list if first purchase
        if (tokensPurchased[msg.sender] == 0) {
            investors.push(msg.sender);
        }
        tokensPurchased[msg.sender] = tokensPurchased[msg.sender].add(tokenAmount);
        
        // Transfer tokens from this contract to buyer
        require(cryptoToken.transfer(msg.sender, tokenAmount), "ICO: Token transfer failed");
        emit TokensPurchased(msg.sender, tokenAmount, msg.value);
    }
    
    // Alternative purchase method with explicit amount
    function buyTokensWithAmount(uint256 _tokenAmount) external payable nonReentrant {
        require(icoActive, "ICO: Not active");
        require(block.timestamp >= icoStartTime && block.timestamp <= icoEndTime, "ICO: Outside sale period");
        require(_tokenAmount > 0, "ICO: Token amount must be greater than 0");
        
        uint256 requiredEth = calculateEthAmount(_tokenAmount);
        require(msg.value >= requiredEth, "ICO: Insufficient ETH sent");
        require(msg.value >= minPurchase, "ICO: Below minimum purchase");
        require(msg.value <= maxPurchase, "ICO: Above maximum purchase");
        require(tokensSold.add(_tokenAmount) <= maxTokensForSale, "ICO: Not enough tokens available");
        require(cryptoToken.balanceOf(address(this)) >= _tokenAmount, "ICO: Insufficient tokens in contract");
        
        // Update tracking
        tokensSold = tokensSold.add(_tokenAmount);
        contributions[msg.sender] = contributions[msg.sender].add(requiredEth);
        
        if (tokensPurchased[msg.sender] == 0) {
            investors.push(msg.sender);
        }
        tokensPurchased[msg.sender] = tokensPurchased[msg.sender].add(_tokenAmount);
        
        // Transfer tokens from this contract to buyer
        require(cryptoToken.transfer(msg.sender, _tokenAmount), "ICO: Token transfer failed");
        emit TokensPurchased(msg.sender, _tokenAmount, requiredEth);
        
        // Refund excess ETH
        if (msg.value > requiredEth) {
            payable(msg.sender).transfer(msg.value.sub(requiredEth));
        }
    }
    
    // Admin Functions
    function withdrawFunds() external onlyOwner {
        require(address(this).balance > 0, "ICO: No funds to withdraw");
        
        uint256 amount = address(this).balance;
        payable(owner).transfer(amount);
        emit FundsWithdrawn(amount);
    }
    
    function withdrawUnsoldTokens() external onlyOwner {
        require(!icoActive, "ICO: Must end ICO first");
        
        uint256 unsoldTokens = cryptoToken.balanceOf(address(this));
        if (unsoldTokens > 0) {
            require(cryptoToken.transfer(owner, unsoldTokens), "ICO: Token transfer failed");
            emit TokensWithdrawn(unsoldTokens);
        }
    }
    
    function updateTokenPrice(uint256 _newPrice) external onlyOwner {
        require(!icoActive, "ICO: Cannot change price during active ICO");
        tokenPrice = _newPrice;
    }
    
    function updatePurchaseLimits(uint256 _minPurchase, uint256 _maxPurchase) external onlyOwner {
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
    }
    
    function updateMaxTokensForSale(uint256 _maxTokensForSale) external onlyOwner {
        require(!icoActive, "ICO: Cannot change during active ICO");
        maxTokensForSale = _maxTokensForSale;
    }
    
    // View Functions
    function getICOInfo() external view returns (
        bool active,
        uint256 currentPrice,
        uint256 tokensRemaining,
        uint256 tokensInContract,
        uint256 startTime,
        uint256 endTime,
        uint256 totalRaised
    ) {
        return (
            icoActive,
            tokenPrice,
            maxTokensForSale.sub(tokensSold),
            cryptoToken.balanceOf(address(this)),
            icoStartTime,
            icoEndTime,
            address(this).balance
        );
    }
    
    function getInvestorCount() external view returns (uint256) {
        return investors.length;
    }
    
    function getTokenBalance() external view returns (uint256) {
        return cryptoToken.balanceOf(address(this));
    }
    
    // Emergency pause functionality
    function emergencyPause() external onlyOwner {
        icoActive = false;
        emit ICOEnded();
    }
    
    // Fallback function to receive ETH - calls buyTokens automatically
    receive() external payable {
        buyTokens();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _; // Insert the original function's code here
    }

}
