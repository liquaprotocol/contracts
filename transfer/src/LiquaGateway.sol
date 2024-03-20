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
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {BytesLib} from "./library/BytesLib.sol";
import {CCIPReceiverUpgradeable} from "./upgradeable/CCIPReceiverUpgradeable.sol";

contract LiquaGateway is
    Initializable,
    UUPSUpgradeable,
    CCIPReceiverUpgradeable,
    AccessControlUpgradeable
{
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
    address internal i_link;
    bytes32[] public receivedMessages; // Array to keep track of the IDs of received messages.

    struct TokenFeeConfig {
        uint256 fee; // 0.0001% = 1, 0.05% = 500, 1% = 10000
        uint256 minAmount;
        uint256 maxAmount;
    }
    mapping (address => TokenFeeConfig) public tokenFeeConfigs;

    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // constructor() {
    //     _disableInitializers();
    // }

    function initialize(address _router, address _link) public initializer {
        __CCIPReceiverUpgradeable_init(_router);

        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURY_ROLE, msg.sender);
        _setRoleAdmin(TREASURY_ROLE, DEFAULT_ADMIN_ROLE);

        i_link = _link;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
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
        tokens = IRouterClient(i_router).getSupportedTokens(chainSelector);
    }

    /// @param destinationChainSelector The destination chainSelector
    /// @param message The cross-chain CCIP message including data and/or tokens
    /// @return fee returns execution fee for the message delivery to destination chain,
    function getFee(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage calldata message
    ) external view returns (uint256 fee) {
        return IRouterClient(i_router).getFee(destinationChainSelector, message);
    }

    function getCommissionFee(
        address token,
        uint256 amount
    ) public view returns (uint256 commissionFee) {
        TokenFeeConfig memory tokenFeeConfig = tokenFeeConfigs[token];

        commissionFee = (amount * tokenFeeConfig.fee) / 1e6;

        if (commissionFee < tokenFeeConfig.minAmount) {
            commissionFee = tokenFeeConfig.minAmount;
        } else if (tokenFeeConfig.maxAmount > 0 && commissionFee > tokenFeeConfig.maxAmount) {
            commissionFee = tokenFeeConfig.maxAmount;
        }
    }

    // /// @notice Returns the CCIP router contract.
    function getRouter() public view override returns (address) {
        return super.getRouter();
    }

    /// @notice Simply forwards the request to the CCIP router and returns the result.
    /// @param destinationChainSelector The destination chainSelector
    /// @param receiver The address of the recipient on the destination blockchain.
 // /// @param message The string text to be sent.
    /// @param token The address of the token to transfer.
    /// @param amount The amount of the token to transfer.
    /// @return messageId The ID of the message that was sent.
    /// @dev Reverts with appropriate reason upon invalid message.
    function send(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        uint256 gasLimit,
        FeeTokenType feeTokenType
    ) external payable returns (bytes32 messageId) {
        // calculate the fees
        uint commissionFee = getCommissionFee(token, amount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: token,
            amount: amount - commissionFee
        });
        tokenAmounts[0] = tokenAmount;

        // Create an EVM2AnyMessage struct in memory with necessary information
        // for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: new bytes(0),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: gasLimit})
            ),
            // Set the feeToken address
            feeToken: feeTokenType == FeeTokenType.LINK ? i_link : address(0)
        });
        _validateMessage(evm2AnyMessage);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(i_router, amount);
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
        ) revert InvalidToken(message.tokenAmounts[0].token);
    }

    /// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
    /// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
    /// It should only be callable by the owner of the contract.
    /// @param beneficiary The address to which the Ether should be sent.
    function withdraw(address beneficiary) external onlyRole(TREASURY_ROLE) {
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
    ) external onlyRole(TREASURY_ROLE) {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        IERC20(token).safeTransfer(beneficiary, amount);
    }
    function setTokenFeeConfig(
        address token,
        uint256 fee,
        uint256 minAmount,
        uint256 maxAmount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenFeeConfigs[token] = TokenFeeConfig({
            fee: fee,
            minAmount: minAmount,
            maxAmount: maxAmount
        });
    }
}
