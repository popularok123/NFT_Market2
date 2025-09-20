// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./AuctionController.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AuctionFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address[] public allAuctions;

    mapping(address => mapping(uint256 => address)) public auctionContracts; // nftContract => tokenId => auctionContract
    address public auctionImplementation;

    event AuctionImplUpdated(address oldImpl, address newImpl);
    event AuctionCreated(
        address indexed auctionProxy, address indexed seller, address indexed nftContract, uint256 tokenId
    );

    function initialize(address _owner, address _auctionImplementation) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        require(_auctionImplementation != address(0), "impl zero");
        auctionImplementation = _auctionImplementation;
        transferOwnership(_owner);
    }

    function setAuctionImplementation(address _newImpl) external onlyOwner {
        require(_newImpl != address(0), "zero");
        address old = auctionImplementation;
        auctionImplementation = _newImpl;
        emit AuctionImplUpdated(old, _newImpl);
    }

    function createAuction(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId,
        address bidToken,
        address priceFeed,
        uint256 startTime,
        uint256 endTime,
        address _router
    ) external returns (address auctionAddress) {
        require(auctionContracts[nftContract][tokenId] == address(0), "Auction already exists for this NFT");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");

        // address _owner,
        // uint256 _auctionID,
        // address _nftContract,
        // uint256 _tokenId,
        // address _seller,
        // address _bidToken,
        // address _priceFeed,
        // uint256 _startTime,
        // uint256 _endTime,
        // address _router
        // build init calldata matching AuctionUpgradeable.initialize
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,uint256,address,uint256,address,address,address,uint256,uint256,address)",
            owner(), // _owner -> factory owner (multisig/timelock)
            auctionId,
            nftContract,
            tokenId,
            msg.sender, // seller
            bidToken,
            priceFeed,
            startTime,
            endTime,
            _router
        );

        // AuctionController newAuction = new AuctionController(
        //     auctionId, nftContract, tokenId, msg.sender, bidToken, priceFeed, startTime, endTime, _router
        // );
        ERC1967Proxy proxy = new ERC1967Proxy(auctionImplementation, initData);

        auctionAddress = address(proxy);

        // auctionAddress = address(newAuction);

        IERC721(nftContract).safeTransferFrom(msg.sender, auctionAddress, tokenId);

        // IERC721(nftContract).approve(auctionAddress, tokenId);

        allAuctions.push(auctionAddress);

        auctionContracts[nftContract][tokenId] = auctionAddress;

        // Transfer the NFT to the auction contract
        // IERC721(nftContract).safeTransferFrom(msg.sender, auctionAddress, tokenId);
    }

    function allAuctionsLength() external view returns (uint256) {
        return allAuctions.length;
    }

    // UUPS authorize upgrade for factory itself
    function _authorizeUpgrade(address newImpl) internal override onlyOwner {}
}
