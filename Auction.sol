// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0 < 0.9.0;

import "./ERC20interface.sol";

contract Auction {
    address payable public owner;
    string public name;
    string public description;
    uint256 public minAmount;
    uint256 public start;
    uint256 public end;
    bool public canceled;
    bool public ended;
    
    // Token configuration
    Crypto internal token;
    bool public useEth; // true for ETH, false for ERC20

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
        address _tokenAddress, // Pass address(0) for ETH, token address for ERC20
        uint256 _minAmount,
        uint256 startAt, 
        uint256 endAt, 
        uint256 _increment
    ) {
        require(startAt < endAt, "Invalid times");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_minAmount > 0, "Minimum amount must be greater than 0");
        
        name = _name;
        description = _description;
        minAmount = _minAmount;
        owner = payable(msg.sender);
        start = startAt;
        end = endAt;
        increment = _increment;
        
        // Determine if using ETH or ERC20
        if (_tokenAddress == address(0)) {
            useEth = true;
        } else {
            useEth = false;
            token = Crypto(_tokenAddress);
        }
    }

    function placeBid(uint256 bidAmount) public payable {
        require(msg.sender != owner, "Owner cannot bid");
        require(!ended && !canceled, "Auction ended or canceled");
        require(block.timestamp >= start, "Auction not started");
        require(block.timestamp >= end, "Auction ended");
        require(bidAmount > minAmount, "Bid must be greater than minimum amount");
        
        uint256 actualBidAmount;
        
        if (useEth) {
            require(msg.value > 0, "Must send ETH to bid");
            actualBidAmount = msg.value;
        } else {
            require(bidAmount > 0, "Bid must be greater than 0");
            require(token.balanceOf(msg.sender) >= bidAmount, "Insufficient token balance");
            actualBidAmount = bidAmount;
        }
        
        // Calculate total bid for this bidder
        uint256 totalBid = bids[msg.sender] + actualBidAmount;
        require(totalBid >= highestBindingBid + increment, "Bid is too low");

        // Handle token transfer for ERC20
        if (!useEth) {
            require(token.transferFrom(msg.sender, address(this), actualBidAmount), "Token transfer failed");
        }
        
        // Update bid amount
        bids[msg.sender] = totalBid;

        // Store previous highest bidder info
        uint256 previousHighestBid = highestBid;
        address previousHighestBidder = highestBidder;

        // Update highest bid info
        highestBidder = msg.sender;
        highestBid = totalBid;
        
        // Calculate new highest binding bid and handle refunds
        if (previousHighestBidder != address(0)) {
            // Return the previous highest bid to the previous bidder

            // bids[previousHighestBidder] = 0;
            // if (useEth) {
            //     payable(previousHighestBidder).transfer(previousHighestBid);
            // } else {
            //     require(token.transfer(previousHighestBidder, previousHighestBid), "Refund transfer failed");
            // }
            
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
            if (useEth) {
                payable(highestBidder).transfer(highestBid);
            } else {
                require(token.transfer(highestBidder, highestBid), "Refund transfer failed");
            }
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
            if (useEth) {
                owner.transfer(highestBindingBid);
            } else {
                require(token.transfer(owner, highestBindingBid), "Payment transfer failed");
            }
            
            // If there's a difference between highest bid and binding bid, refund it
            uint256 refund = highestBid - highestBindingBid;
            if (refund > 0) {
                if (useEth) {
                    payable(highestBidder).transfer(refund);
                } else {
                    require(token.transfer(highestBidder, refund), "Refund transfer failed");
                }
            }
            
            bids[highestBidder] = 0;
        }
        
        emit AuctionFinalized(highestBidder, highestBindingBid);
    }

    function endAuctionEarly() external {
        require(msg.sender == owner, "Not owner");
        require(block.timestamp < end || canceled, "Auction already Ended use finalizeAuction() instead");
        require(!ended, "Already ended");
        
        ended = true;

        if (highestBidder != address(0) && !canceled) {
            // Transfer the winning amount to the owner
            if (useEth) {
                owner.transfer(highestBindingBid);
            } else {
                require(token.transfer(owner, highestBindingBid), "Payment transfer failed");
            }
            
            // If there's a difference between highest bid and binding bid, refund it
            uint256 refund = highestBid - highestBindingBid;
            if (refund > 0) {
                if (useEth) {
                    payable(highestBidder).transfer(refund);
                } else {
                    require(token.transfer(highestBidder, refund), "Refund transfer failed");
                }
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
        
        if (useEth) {
            payable(msg.sender).transfer(amount);
        } else {
            require(token.transfer(msg.sender, amount), "Withdrawal transfer failed");
        }
    }

    // View functions
    function getBid(address bidder) external view returns (uint256) {
        return bids[bidder];
    }
    
    function getBalance() external view returns (uint256) {
        if (useEth) {
            return address(this).balance;
        } else {
            return token.balanceOf(address(this));
        }
    }
    
    function isActive() public view returns (bool) {
        return !ended && !canceled && block.timestamp >= start && block.timestamp < end;
    }

    function getAuctionInfo() external view returns (
        string memory _name,
        string memory _description,
        uint256 _minAmount,
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
            minAmount,
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
