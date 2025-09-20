// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IAuction} from "./IAuction.sol";

contract AuctionController is
    IERC721Receiver,
    IAuction,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public seller;
    // address public nftContract;
    IERC721 public nft;

    uint256 public tokenId;

    // address public paymentToken; // address(0) 表示 ETH
    IERC20 public bidToken; //ERC20 token for bidding (null is ETH)

    // uint256 public reservePrice;
    uint256 public startTime;
    uint256 public endTime;

    address public highestBidder;
    // uint256 public highestBid;
    uint256 public highestBidUSD; // in USD with 8 decimals

    mapping(address => uint256) public bids;

    bool public settled;

    AggregatorV3Interface internal priceFeed;

    address public factory; //deploy factory address

    uint256 private _status;

    IRouterClient public router;
    address public ccipReceiver;

    uint256 private auctionID;

    event BidPlaced(address indexed bidder, uint256 amount, uint256 amountInUSD);
    event AuctionEnded(address winner, uint256 winningBidUSD);
    event AuctionCancelled();
    event AuctionInitialized(
        uint256 auctionID,
        address seller,
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 reservePrice,
        uint256 startTime,
        uint256 endTime
    );

    function initialize(
        address _owner,
        uint256 _auctionID,
        address _nftContract,
        uint256 _tokenId,
        address _seller,
        address _bidToken,
        address _priceFeed,
        uint256 _startTime,
        uint256 _endTime,
        address _router
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        auctionID = _auctionID;
        nft = IERC721(_nftContract);
        tokenId = _tokenId;
        seller = _seller;
        bidToken = IERC20(_bidToken);
        startTime = _startTime;
        endTime = _endTime;

        priceFeed = AggregatorV3Interface(_priceFeed);

        factory = msg.sender; //factory address

        _status = 0;

        router = IRouterClient(_router);

        // set owner (for upgrades) to provided _owner (should be multisig/timelock)
        transferOwnership(_owner);

        emit AuctionInitialized(auctionID, seller, _nftContract, _tokenId, _bidToken, 0, _startTime, _endTime);
    }

    function getLastPrice() internal view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function ToUSD(uint256 amount) internal view returns (uint256) {
        uint256 price = getLastPrice();
        require(price > 0, "Invalid price");

        uint256 decials = 10 ** priceFeed.decimals();

        return (amount * price) / decials;
    }

    // UUPS authorize upgrade
    function _authorizeUpgrade(address newImpl) internal override onlyOwner {}

    /// @dev Handles the receipt of an NFT
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    function bid(uint256 amount) external payable nonReentrant {
        require(block.timestamp >= startTime, "Auction not started");
        require(block.timestamp <= endTime, "Auction ended");
        require(!settled, "Auction already settled");

        uint256 bidAmount;
        if (address(bidToken) == address(0)) {
            // 用 ETH 出价
            require(msg.value > 0, "ETH bid required");
            bidAmount = msg.value;
        } else {
            // 用 ERC20 出价
            require(amount > 0, "ERC20 bid required");
            bidToken.transferFrom(msg.sender, address(this), amount);
            bidAmount = amount;
        }

        uint256 bidInUSD = ToUSD(bidAmount);
        require(bidInUSD > highestBidUSD, "Bid too low");

        if (highestBidder != address(0)) {
            if (address(bidToken) == address(0)) {
                payable(highestBidder).transfer(bids[highestBidder]);
            } else {
                bidToken.transfer(highestBidder, bids[highestBidder]);
            }
        }

        bids[msg.sender] = bidAmount;
        highestBidder = msg.sender;
        highestBidUSD = bidInUSD;

        emit BidPlaced(msg.sender, amount, bidInUSD);
    }

    function placeBidFromCrossChain(
        uint256 auctionId,
        address bidder,
        address token,
        uint256 amount,
        uint64 sourceChainSelector
    ) external {
        require(msg.sender == address(router), "Only router can call");
        require(block.timestamp < endTime, "Auction ended");

        uint256 bidInUSD = ToUSD(amount);
        require(bidInUSD > highestBidUSD, "Bid too low");

        if (highestBidder != address(0)) {
            _sendCrossChainRefund(sourceChainSelector, highestBidder, token, bids[highestBidder]);
        }

        bids[bidder] = amount;
        highestBidder = bidder;
        highestBidUSD = bidInUSD;

        emit BidPlaced(bidder, amount, bidInUSD);
    }

    function _sendCrossChainRefund(uint64 _destChainSelector, address _receiver, address _token, uint256 _amount)
        internal
    {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

        bytes memory payload = abi.encode(_receiver, _token, _amount);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: payload,
            tokenAmounts: tokenAmounts,
            feeToken: _token,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300000}))
        });

        uint256 fee = router.getFee(_destChainSelector, message);

        router.ccipSend{value: fee}(_destChainSelector, message);
    }

    function endAuction() external nonReentrant {
        require(block.timestamp >= endTime, "Auction not ended yet");
        require(!settled, "Auction already settled");
        require(highestBidder != address(0), "No bids placed");
        settled = true;

        nft.transferFrom(address(this), highestBidder, tokenId);

        if (address(bidToken) == address(0)) {
            payable(seller).transfer(bids[highestBidder]);
        } else {
            bidToken.transfer(seller, bids[highestBidder]);
        }

        emit AuctionEnded(highestBidder, highestBidUSD);
    }

    function cancelAuction() external nonReentrant {
        require(msg.sender == seller, "Only seller");
        require(highestBidder == address(0), "Can't cancel, bid exists");
        require(!settled, "Already settled");
        settled = true;

        nft.safeTransferFrom(address(this), seller, tokenId);

        emit AuctionCancelled();
    }

    receive() external payable {}
}
