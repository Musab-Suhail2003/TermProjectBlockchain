// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.5.0 < 0.9.0;

import "./ERC20interface.sol";
contract TokenAuction {
    address payable public owner;
    string public name;
    string public description;
    uint256 public start;
    uint256 public end;
    bool public canceled;
    bool public ended;
    
    // ERC20 token contract
    Crypto public token;

    mapping(address => uint256) bids;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public highestBindingBid;
    uint256 public increment;

    event BidPlaced(address bidder, uint256 amount);
    event AuctionCanceled();
    event AuctionFinalized(address winner, uint256 amount);

    constructor(
        string memory _name,
        string memory _description,
        address _tokenAddress,
        uint256 startAt, 
        uint256 endAt, 
        uint256 _increment,
        address _owner
    ) {
        require(startAt < endAt, "Invalid times");
        require(_tokenAddress != address(0), "Invalid token address");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        name = _name;
        description = _description;
        owner = payable(_owner);
        token = Crypto(_tokenAddress);
        start = startAt;
        end = endAt;
        increment = _increment;
    }

    function placeBid(uint256 bidAmount) public {
        require(msg.sender != owner, "Owner cannot bid");
        require(!ended && !canceled, "Auction ended or canceled");
        require(block.timestamp >= start, "Auction not started");
        require(block.timestamp < end, "Auction ended");
        require(bidAmount > 0, "Bid must be greater than 0");
        
        // Check if bidder has enough tokens
        require(token.balanceOf(msg.sender) >= bidAmount, "Insufficient token balance");
        
        // Calculate total bid for this bidder
        uint256 totalBid = bids[msg.sender] + bidAmount;
        require(totalBid >= highestBindingBid + increment, "Bid is too low");

        // Transfer tokens from bidder to this contract using transferFrom
        require(token.transferFrom(msg.sender, address(this), bidAmount), "Token transfer failed");
        
        // Update bid amount
        bids[msg.sender] = totalBid;

        // Store previous highest bidder info
        uint256 previousHighestBid = highestBid;
        address previousHighestBidder = highestBidder;

        // Update highest bid info
        highestBidder = msg.sender;
        highestBid = totalBid;
        
        // Calculate new highest binding bid
        if (previousHighestBidder != address(0)) {
            // Return the previous highest bid to the previous bidder
            bids[previousHighestBidder] = 0;
            require(token.transfer(previousHighestBidder, previousHighestBid), "Refund transfer failed");
            
            // Set binding bid to previous bid + increment, or current bid if lower
            highestBindingBid = previousHighestBid + increment;
            if (highestBindingBid > totalBid) {
                highestBindingBid = totalBid;
            }
        } else {
            // First bid
            highestBindingBid = totalBid;
        }

        emit BidPlaced(msg.sender, totalBid);
    }

    function cancelAuction() external {
        require(msg.sender == owner, "Not owner");
        require(!canceled, "Already canceled");
        require(!ended, "Already ended");
        
        canceled = true;
        
        // Refund the highest bidder if there is one
        if (highestBidder != address(0) && highestBid > 0) {
            require(token.transfer(highestBidder, highestBid), "Refund transfer failed");
            bids[highestBidder] = 0;
        }
        
        emit AuctionCanceled();
    }

    function finalizeAuction() external {
        require(msg.sender == owner, "Not owner");
        require(block.timestamp > end || canceled, "Auction not ended");
        require(!ended, "Already ended");
        
        ended = true;

        if (highestBidder != address(0) && !canceled) {
            // Transfer the winning amount to the owner
            require(token.transfer(owner, highestBindingBid), "Payment transfer failed");
            
            // If there's a difference between highest bid and binding bid, refund it
            uint256 refund = highestBid - highestBindingBid;
            if (refund > 0) {
                require(token.transfer(highestBidder, refund), "Refund transfer failed");
            }
            
            bids[highestBidder] = 0;
        }
        
        emit AuctionFinalized(highestBidder, highestBindingBid);
    }

    function withdraw() external {
        require(ended || canceled, "Auction not ended");
        uint256 amount = bids[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        
        bids[msg.sender] = 0;
        require(token.transfer(msg.sender, amount), "Withdrawal transfer failed");
    }

    // View functions
    function getBid(address bidder) external view returns (uint256) {
        return bids[bidder];
    }
    
    function getTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    function isActive() public view returns (bool) {
        return !ended && !canceled && block.timestamp >= start && block.timestamp < end;
    }

    function getAuctionInfo() external view returns (
        string memory _name,
        string memory _description,
        address _owner,
        uint256 _start,
        uint256 _end,
        uint256 _highestBid,
        address _highestBidder,
        bool _isActive,
        bool _ended,
        bool _canceled
    ) {
        bool _act = isActive();
        return (
            name,
            description,
            owner,
            start,
            end,
            highestBid,
            highestBidder,
            _act,
            ended,
            canceled
        );
    }
}