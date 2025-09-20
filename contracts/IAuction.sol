// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAuction {
    function placeBidFromCrossChain(
        uint256 auctionId,
        address bidder,
        address token,
        uint256 amount,
        uint64 sourceChainSelector
    ) external;
}
