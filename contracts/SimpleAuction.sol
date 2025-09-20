// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleAuction {
    struct Auction {
        uint256 tokenId;
        address nftContract;
        address seller;
        address paymentToken; //address(0) for ETH
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool isSold;
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;

    uint256 private _status;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 reservePrice,
        uint256 startTime,
        uint256 endTime
    );
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 amount);
    event AuctionCancelled(uint256 indexed auctionId);

    constructor() {
        _status = 0;
    }

    /// @dev Prevents a contract from calling itself, directly or indirectly.
    modifier nonReentrant() {
        require(_status == 0, "Reentrant call");
        _status = 1;
        _;
        _status = 0;
    }

    /// @dev Create an auction
    /// @param _nftContract The address of the NFT contract
    /// @param _tokenId The ID of the token to auction
    /// @param _paymentToken The address of the payment token (address(0) for ETH)
    /// @param _reserveprice The reserve price of the auction
    /// @param _startTime The start time of the auction
    /// @param _endTime The end time of the auction
    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        address _paymentToken,
        uint256 _reserveprice,
        uint256 _startTime,
        uint256 _endTime
    ) external {
        require(_endTime > _startTime, "Invalid time range");
        require(IERC721(_nftContract).ownerOf(_tokenId) == msg.sender, "Not the owner");

        IERC721(_nftContract).safeTransferFrom(msg.sender, address(this), _tokenId);

        auctionCounter++;
        auctions[auctionCounter] = Auction({
            tokenId: _tokenId,
            seller: msg.sender,
            nftContract: _nftContract,
            paymentToken: _paymentToken,
            reservePrice: _reserveprice,
            startTime: _startTime,
            endTime: _endTime,
            highestBidder: address(0),
            highestBid: 0,
            isSold: false
        });
        emit AuctionCreated(
            auctionCounter, msg.sender, _nftContract, _tokenId, _paymentToken, _reserveprice, _startTime, _endTime
        );
    }

    /// @dev End an auction and transfer the NFT to the highest bidder
    /// @param auctionId The ID of the auction to end
    function endAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(a.seller == msg.sender, "Not the seller");
        require(block.timestamp > a.endTime, "Auction not ended");
        require(!a.isSold, "Already sold");

        a.isSold = true;

        if (a.highestBidder == address(0)) {
            IERC721(a.nftContract).safeTransferFrom(address(this), a.seller, a.tokenId);
            emit AuctionEnded(auctionId, address(0), 0);
            return;
        }

        IERC721(a.nftContract).safeTransferFrom(address(this), a.highestBidder, a.tokenId);

        if (a.paymentToken == address(0)) {
            payable(a.seller).transfer(a.highestBid);
        } else {
            bool success = IERC20(a.paymentToken).transfer(a.seller, a.highestBid);
            require(success, "Payment transfer failed");
        }
        emit AuctionEnded(auctionId, a.highestBidder, a.highestBid);
    }

    /// @dev Cancel an auction if there are no bids
    /// @param auctionId The ID of the auction to cancel
    function cancelAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(a.seller != address(0), "Invalid auction");
        require(a.seller == msg.sender, "Not the seller");
        require(a.highestBidder == address(0), "Cannot cancel with bids");
        require(!a.isSold, "Already sold");

        a.isSold = true; // Mark as sold to prevent further actions

        IERC721(a.nftContract).safeTransferFrom(address(this), a.seller, a.tokenId);
        emit AuctionCancelled(auctionId);
    }

    /// @dev Bid on an auction
    /// @param auctionId The ID of the auction
    /// @param bidAmount The amount of the bid
    function bid(uint256 auctionId, uint256 bidAmount) external payable nonReentrant {
        Auction storage a = auctions[auctionId];
        require(block.timestamp >= a.startTime, "Auction not started");
        require(block.timestamp < a.endTime, "Auction ended");
        require(a.seller != address(0), "Invalid seller");
        require(!a.isSold, "Already sold");

        if (a.paymentToken == address(0)) {
            require(msg.value == bidAmount, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "Cannot send ETH with payment token");
        }

        require(bidAmount >= a.reservePrice, "Bid below reserve price");
        require(bidAmount > a.highestBid, "Bid not high enough");

        // Transfer bid amount to contract
        if (a.paymentToken != address(0)) {
            bool success = IERC20(a.paymentToken).transferFrom(msg.sender, address(this), bidAmount);
            require(success, "Token transfer failed");
        }

        // Refund previous highest bidder
        if (a.highestBidder != address(0)) {
            if (a.paymentToken == address(0)) {
                payable(a.highestBidder).transfer(a.highestBid);
            } else {
                bool success = IERC20(a.paymentToken).transfer(a.highestBidder, a.highestBid);
                require(success, "Refund failed");
            }
        }

        a.highestBidder = msg.sender;
        a.highestBid = bidAmount;
        emit BidPlaced(auctionId, msg.sender, bidAmount);
    }

    function getAuction(uint256 auctionId) public view returns (Auction memory) {
        return auctions[auctionId];
    }

    // To receive ETH from bidders
    receive() external payable {}
}
