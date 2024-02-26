// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BytesLib} from "./library/BytesLib.sol";
import {CCIPReceiverUpgradeable} from "./upgradeable/CCIPReceiverUpgradeable.sol";



contract LiquaGateway is Initializable, UUPSUpgradeable, CCIPReceiverUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    enum FeeTokenType {
        NATIVE,
        LINK
    }

 	// Custom errors to provide more descriptive revert messages.
    error InvalidToken(address tokenAddr);
    error NoDataAllowed();
    error GasShouldBeZero();
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error NotEnoughFees(uint256 paidFees, uint256 calculatedFees); // Used to make sure user paid enough fees

	/// @notice The CCIP router contract
    IRouterClient internal i_ccipRouter;
    address internal i_link;
    uint256 public commissionFee;
    bytes32[] public receivedMessages; // Array to keep track of the IDs of received messages.


    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _router,
        address _link
        ) initializer public {
        __CCIPReceiverUpgradeable_init(_router);
            i_ccipRouter = IRouterClient(_router);
            i_link = _link;
            commissionFee = 2000;
    }

    function _authorizeUpgrade(address) internal onlyOwner() override {}


	// Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        string message, // The text being sent.
        Client.EVMTokenAmount tokenAmount, // The token amount that was sent.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelctor, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        string message, // The message that was received.
        Client.EVMTokenAmount tokenAmmount // The token amount that was received.
    );

	/// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

    function getSupportedTokens(
        uint64 chainSelector
    ) external view returns (address[] memory tokens) {
        tokens = IRouterClient(i_ccipRouter).getSupportedTokens(chainSelector);
    }

    /// @param destinationChainSelector The destination chainSelector
    /// @param message The cross-chain CCIP message including data and/or tokens
    /// @return fee returns execution fee for the message delivery to destination chain,
    function getFee(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage calldata message
    ) external view returns (uint256 fee) {
        return i_ccipRouter.getFee(destinationChainSelector, message) * commissionFee / 1000 ; // + commission
    }

    function setCommissionFee(uint256 amount) external onlyOwner {
        commissionFee = amount;
    }

	// /// @notice Returns the CCIP router contract.
    function getRouter() public override view returns (address) {
        return getRouter();
    }

    /// @notice Simply forwards the request to the CCIP router and returns the result.
    /// @param destinationChainSelector The destination chainSelector
    /// @param receiver The address of the recipient on the destination blockchain.
    /// @param message The string text to be sent.
    /// @param token The address of the token to transfer.
    /// @param amount The amount of the token to transfer.
    /// @return messageId The ID of the message that was sent.
    /// @dev Reverts with appropriate reason upon invalid message.
	function send(
        uint64 destinationChainSelector,
        address receiver,
        string calldata message,
        address token,
        uint256 amount,
        FeeTokenType feeTokenType
    ) external payable returns (bytes32 messageId) {
        // Set the token amounts
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: token,
            amount: amount
        });
        tokenAmounts[0] = tokenAmount;

        // Create an EVM2AnyMessage struct in memory with necessary information
        // for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(message),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            // Set the feeToken address
            feeToken: feeTokenType == FeeTokenType.LINK ? i_link : address(0)
        });
        _validateMessage(evm2AnyMessage);

		// Get the fee required to send the message
        uint256 fees = this.getFee(destinationChainSelector, evm2AnyMessage);

        if (feeTokenType == FeeTokenType.LINK) {
            IERC20(i_link).approve(i_router, fees);
            messageId = IRouterClient(i_router).ccipSend(
                destinationChainSelector,
                evm2AnyMessage
            );
        } else {
            // Send the message through the router and store the returned message ID
            messageId = IRouterClient(i_router).ccipSend{value: fees}(
                destinationChainSelector,
                evm2AnyMessage
            );
        }

        // Emit an event with message details
        emit MessageSent(
            messageId,
            destinationChainSelector,
            receiver,
            message,
            tokenAmount,
            fees
        );
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        bytes32 messageId = any2EvmMessage.messageId; // fetch the messageId
        uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector; // fetch the source chain identifier (aka selector)
        address sender = abi.decode(any2EvmMessage.sender, (address)); // abi-decoding of the sender address
        Client.EVMTokenAmount[] memory tokenAmounts = any2EvmMessage
            .destTokenAmounts;
        string memory message = abi.decode(any2EvmMessage.data, (string)); // abi-decoding of the sent string message
        receivedMessages.push(messageId);

        //TODO: handle the received message

        emit MessageReceived(
            messageId,
            sourceChainSelector,
            sender,
            message,
            tokenAmounts[0]
        );
    }

	

	/// @notice Validates the message content.
    /// @dev Only allows a single token to be sent, and no data.
    function _validateMessage(
        Client.EVM2AnyMessage memory message
    ) internal pure {
        if (
            message.tokenAmounts.length != 1 
            // || message.tokenAmounts[0].token != i_token
        ) revert InvalidToken(message.tokenAmounts[0].token);
        if (message.data.length > 0) revert NoDataAllowed();

        if (
            message.extraArgs.length == 0 ||
            bytes4(message.extraArgs) != Client.EVM_EXTRA_ARGS_V1_TAG
        ) revert GasShouldBeZero();

        if (
            abi.decode(message.extraArgs.slice(4, message.extraArgs.length), (Client.EVMExtraArgsV1)).gasLimit != 0
        ) revert GasShouldBeZero();
    }

	/// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
    /// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
    /// It should only be callable by the owner of the contract.
    /// @param beneficiary The address to which the Ether should be sent.
    function withdraw(address beneficiary) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = address(this).balance;

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        // Attempt to send the funds, capturing the success status and discarding any return data
        (bool sent, ) = beneficiary.call{value: amount}("");

        // Revert if the send failed, with information about the attempted transfer
        if (!sent) revert FailedToWithdrawEth(msg.sender, beneficiary, amount);
    }

	/// @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
    /// @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
    /// @param beneficiary The address to which the tokens will be sent.
    /// @param token The contract address of the ERC20 token to be withdrawn.
    function withdrawToken(
        address beneficiary,
        address token
    ) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        IERC20(token).safeTransfer(beneficiary, amount);
    }

 }
