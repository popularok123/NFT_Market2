// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";

contract CrossChainMessager is CCIPReceiver {
    using SafeERC20 for IERC20;

    IRouterClient public s_router; // router on source chain
    IERC20 private s_linkToken;
    mapping(address => mapping(address => uint256)) public refunds; // user => token => amount

    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 requiredBalance); // Used to make sure contract has enough token balance

    event CrossChainBidSent(
        bytes32 indexed messageId,
        uint64 destChain,
        address receiver,
        uint256 auctionId,
        address token,
        uint256 amount,
        address feeToken,
        uint256 fee
    );

    constructor(address _router, address _link) CCIPReceiver(_router) {
        s_router = IRouterClient(_router);
        s_linkToken = IERC20(_link);
    }

    function _buildCCIPMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        address _feeTokenAddress,
        uint256 _auctionId,
        address _owner
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // Set the token amounts
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

        bytes memory payload = abi.encode(_auctionId, _owner);

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: payload, // No data
            tokenAmounts: tokenAmounts, // The amount and type of token being transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and allowing out-of-order execution.
                // Best Practice: For simplicity, the values are hardcoded. It is advisable to use a more dynamic approach
                // where you set the extra arguments off-chain. This allows adaptation depending on the lanes, messages,
                // and ensures compatibility with future CCIP upgrades. Read more about it here: https://docs.chain.link/ccip/concepts/best-practices/evm#using-extraargs
                Client.GenericExtraArgsV2({
                    gasLimit: 0, // Gas limit for the callback on the destination chain
                    allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
                })
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
    }

    function sendCrossChainBidByLink(
        uint64 _destinationChainSelector,
        address _receiver,
        uint256 _auctionId,
        address _token,
        uint256 _amount
    ) external returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        //  address(linkToken) means fees are paid in LINK
        Client.EVM2AnyMessage memory evm2AnyMessage =
            _buildCCIPMessage(_receiver, _token, _amount, address(s_linkToken), _auctionId, msg.sender);

        uint256 fees = s_router.getFee(_destinationChainSelector, evm2AnyMessage);

        uint256 requiredLinkBalance;
        if (_token == address(s_linkToken)) {
            // Required LINK Balance is the sum of fees and amount to transfer, if the token to transfer is LINK
            requiredLinkBalance = fees + _amount;
        } else {
            requiredLinkBalance = fees;
        }

        uint256 linkBalance = s_linkToken.balanceOf(address(this));

        if (requiredLinkBalance > linkBalance) {
            revert NotEnoughBalance(linkBalance, requiredLinkBalance);
        }

        s_linkToken.approve(address(s_router), requiredLinkBalance);

        if (_token != address(s_linkToken)) {
            uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
            if (_amount > tokenBalance) {
                revert NotEnoughBalance(tokenBalance, _amount);
            }
            // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
            IERC20(_token).approve(address(s_router), _amount);
        }

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        emit CrossChainBidSent(
            messageId, _destinationChainSelector, _receiver, _auctionId, _token, _amount, address(s_linkToken), fees
        );
    }

    function sendCrossChainBidByNative(
        uint64 _destinationChainSelector,
        address _receiver,
        uint256 _auctionId,
        address _token,
        uint256 _amount
    ) external returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(0) means fees are paid in native gas
        Client.EVM2AnyMessage memory evm2AnyMessage =
            _buildCCIPMessage(_receiver, _token, _amount, address(0), _auctionId, msg.sender);

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > address(this).balance) {
            revert NotEnoughBalance(address(this).balance, fees);
        }

        IERC20(_token).approve(address(s_router), _amount);

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend{value: fees}(_destinationChainSelector, evm2AnyMessage);

        emit CrossChainBidSent(
            messageId, _destinationChainSelector, _receiver, _auctionId, _token, _amount, address(0), fees
        );
    }

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        (address user, address token, uint256 amount) = abi.decode(any2EvmMessage.data, (address, address, uint256));

        refunds[user][token] += amount;
    }

    function withdrawRefund(address _token) external {
        uint256 amount = refunds[msg.sender][_token];
        require(amount > 0, "No refund available");
        refunds[msg.sender][_token] = 0;

        if (_token == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(_token).transfer(msg.sender, amount);
        }
    }
}
