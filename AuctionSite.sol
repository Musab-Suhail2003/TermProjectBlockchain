// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0 < 0.9.0;

import "./Auction.sol";

contract AuctionSite {
    address public siteOwner;
    Crypto public token;
    address[] public auctions;
    mapping(address => address[]) public userAuctions;
    
    event AuctionCreated(
        address indexed auctionAddress,
        address indexed creator,
        string name,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        siteOwner = msg.sender;
        token = Crypto(_tokenAddress);
    }

    function createAuction(
        string memory _name, string memory _description,
        uint256 _startTime, uint256 _endTime, uint256 _increment
    ) external returns (address) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_increment > 0, "Increment must be greater than 0");

        // Create new auction contract
        TokenAuction newAuction = new TokenAuction(
            _name,
            _description,
            address(token),
            _startTime,
            _endTime,
            _increment,
            msg.sender
        );

        address auctionAddress = address(newAuction);
        
        // Add to arrays
        auctions.push(auctionAddress);
        userAuctions[msg.sender].push(auctionAddress);

        emit AuctionCreated(
            auctionAddress,
            msg.sender,
            _name,
            _description,
            _startTime,
            _endTime
        );

        return auctionAddress;
    }

    // ===== BIDDING FUNCTIONS =====
    
    function placeBid(address auctionAddress, uint256 bidAmount) external {
        require(_isValidAuction(auctionAddress), "Invalid auction address");
        TokenAuction auction = TokenAuction(auctionAddress);
        auction.placeBid(bidAmount);
    }

    function getBid(address auctionAddress, address bidder) external view returns (uint256) {
        require(_isValidAuction(auctionAddress), "Invalid auction address");
        TokenAuction auction = TokenAuction(auctionAddress);
        return auction.getBid(bidder);
    }

    function getMyBid(address auctionAddress) external view returns (uint256) {
        require(_isValidAuction(auctionAddress), "Invalid auction address");
        TokenAuction auction = TokenAuction(auctionAddress);
        return auction.getBid(msg.sender);
    }

    // ===== AUCTION MANAGEMENT FUNCTIONS =====
    
    function cancelAuction(address auctionAddress) external {
        require(_isValidAuction(auctionAddress), "Invalid auction address");
        TokenAuction auction = TokenAuction(auctionAddress);
        require(auction.owner() == msg.sender, "Only auction owner can cancel");
        auction.cancelAuction();
    }

    function finalizeAuction(address auctionAddress) external {
        require(_isValidAuction(auctionAddress), "Invalid auction address");
        TokenAuction auction = TokenAuction(auctionAddress);
        require(auction.owner() == msg.sender, "Only auction owner can finalize");
        auction.finalizeAuction();
    }

    function withdrawFromAuction(address auctionAddress) external {
        require(_isValidAuction(auctionAddress), "Invalid auction address");
        TokenAuction auction = TokenAuction(auctionAddress);
        auction.withdraw();
    }

    // ===== QUERY FUNCTIONS =====

    function getAllAuctions() external view returns (address[] memory) {
        return auctions;
    }

    function getLiveAuctions() external view returns (address[] memory) {        
        address[] memory liveAuctions = new address[](auctions.length);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < auctions.length; i++) {
            TokenAuction auction = TokenAuction(auctions[i]);
            if (auction.isActive()) {
                liveAuctions[currentIndex] = auctions[i];
                currentIndex++;
            }
        }

        return liveAuctions;
    }

    function getUserAuctions(address user) external view returns (address[] memory) {
        return userAuctions[user];
    }

    function getAuctionCount() external view returns (uint256) {
        return auctions.length;
    }

    function getLiveAuctionCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < auctions.length; i++) {
            TokenAuction auction = TokenAuction(auctions[i]);
            if (auction.isActive()) {
                count++;
            }
        }
        return count;
    }

    // ===== DETAILED AUCTION INFO FUNCTIONS =====

    function getAuctionInfo(address auctionAddress) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            address owner,
            uint256 start,
            uint256 end,
            uint256 highestBid,
            address highestBidder,
            bool isActive,
            bool ended,
            bool canceled
        ) 
    {
        require(_isValidAuction(auctionAddress), "Invalid auction address");
        TokenAuction auction = TokenAuction(auctionAddress);
        return auction.getAuctionInfo();
    }

    // ===== UTILITY FUNCTIONS =====

    function isAuctionActive(address auctionAddress) external view returns (bool) {
        require(_isValidAuction(auctionAddress), "Invalid auction address");
        TokenAuction auction = TokenAuction(auctionAddress);
        return auction.isActive();
    }

    function canBidOnAuction(address auctionAddress, uint256 bidAmount) 
        external 
        view 
        returns (bool canBid, string memory reason) 
    {
        if (!_isValidAuction(auctionAddress)) {
            return (false, "Invalid auction address");
        }
        
        TokenAuction auction = TokenAuction(auctionAddress);
        
        if (!auction.isActive()) {
            return (false, "Auction is not active");
        }
        
        if (auction.owner() == msg.sender) {
            return (false, "Owner cannot bid");
        }
        
        if (token.balanceOf(msg.sender) < bidAmount) {
            return (false, "Insufficient token balance");
        }
        
        uint256 currentBid = auction.getBid(msg.sender);
        uint256 totalBid = currentBid + bidAmount;
        uint256 requiredBid = auction.highestBindingBid() + auction.increment();
        
        if (totalBid < requiredBid) {
            return (false, "Bid too low");
        }
        
        return (true, "Can bid");
    }
    function _isValidAuction(address auctionAddress) private view returns (bool) {
        for (uint256 i = 0; i < auctions.length; i++) {
            if (auctions[i] == auctionAddress) {
                return true;
            }
        }
        return false;
    }
}