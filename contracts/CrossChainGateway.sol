// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAuction} from "./IAuction.sol";

contract CrossChainGateway is CCIPReceiver {
    event CrossChainMessageHandled(
        bytes32 indexed messageId,
        uint64 srcChain,
        address bidderOrigin,
        uint256 auctionId,
        address token,
        uint256 amount
    );

    address public admin;
    address public auctionContract;

    constructor(address _router, address _auctionContract) CCIPReceiver(_router) {
        admin = msg.sender;
        auctionContract = _auctionContract;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    function setAuctionContract(address a) external onlyAdmin {
        auctionContract = a;
    }

    /// @dev CCIP router will call ccipReceive -> which calls this _ccipReceive
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (uint256 auctionId, address bider) = abi.decode(message.data, (uint256, address));
        address token = address(0);
        uint256 amount = 0;
        if (message.destTokenAmounts.length > 0) {
            token = message.destTokenAmounts[0].token;
            amount = message.destTokenAmounts[0].amount;
        }

        IAuction(auctionContract).placeBidFromCrossChain(auctionId, bider, token, amount, message.sourceChainSelector);

        emit CrossChainMessageHandled(message.messageId, message.sourceChainSelector, bider, auctionId, token, amount);
    }
}
