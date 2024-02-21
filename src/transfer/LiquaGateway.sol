// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/utils/SafeERC20.sol";

contract LiquaGateway is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

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
    uint256 internal i_rate;

 }
