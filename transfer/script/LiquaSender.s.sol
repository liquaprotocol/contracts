// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";

import {LiquaGateway} from "../src/LiquaGateway.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";


contract SendMessage is Script, Helper {
    function run(
        SupportedNetworks destination
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address receiver = vm.addr(deployerPrivateKey);


        address gateway = 0xC8940d11a671beed2b7bD09F3256A40148a14812;

        (, , , uint64 destinationChainId) = getConfigFromNetwork(destination);
        (address ccipBnM,) = getDummyTokensFromNetwork(SupportedNetworks.ETHEREUM_SEPOLIA);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: ccipBnM,
            amount: 1 ether
        });
        tokenAmounts[0] = tokenAmount;

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(""),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 0})
            ),
            feeToken: address(0)
        });

        uint256 fee = LiquaGateway(payable(gateway)).getFee(
            destinationChainId,
            evm2AnyMessage
        );

        IERC20(ccipBnM).approve(gateway, 1 ether);


        bytes32 messageId = LiquaGateway(payable(gateway)).send{
            value: fee
        }(
            destinationChainId,
            receiver,
            "",
            ccipBnM,
            1 ether,
            0,
            LiquaGateway.FeeTokenType.NATIVE
        );

        console.log(
            "You can now monitor the status of your Chainlink CCIP Message via https://ccip.chain.link using CCIP Message ID: "
        );
        console.logBytes32(messageId);

        vm.stopBroadcast();
    }
}
