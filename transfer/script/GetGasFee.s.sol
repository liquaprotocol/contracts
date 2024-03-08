// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";


contract SendMessage is Script, Helper {
    function run(
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.addr(deployerPrivateKey);

        console2.log("owner: ", owner);

        address receiver = 0xb16b50a9da586A9C760d5D08902AA25BD3B8C2Ff;

        address router = 0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe;

        address tokenAddress = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

        // uint64 destinationChainId = 4051577828743386545;

        uint64 ethChainSelectId =  5009297550715157269;


        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: tokenAddress,
            amount: 1000000
        });
        tokenAmounts[0] = tokenAmount;

        console.log("balance of:", IERC20(tokenAddress).balanceOf(address(receiver)));
        console.log("allowance of:", IERC20(tokenAddress).allowance(address(receiver), router));

        // IERC20(tokenAddress).approve(router, 100 ether);

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: new bytes(0),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 0})
            ),
            feeToken: address(0)
        });

        Client.EVM2AnyMessage memory evm2AnyMessage2 = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: new bytes(0),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200000})
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(router).getFee(
            ethChainSelectId,
            evm2AnyMessage
        );

        uint256 fee2 = IRouterClient(router).getFee(
            ethChainSelectId,
            evm2AnyMessage2
        );


        // bytes32 messageId = IRouterClient(router).ccipSend{
        //     value: fee
        // }(destinationChainId ,evm2AnyMessage);

        // console.log(
        //     "You can now monitor the status of your Chainlink CCIP Message via https://ccip.chain.link using CCIP Message ID: "
        // );
        // console.logBytes32(messageId);

        console.log("gas limit is 0, fee: ", fee);
        console.log("gas limit is 200_000, fee: ", fee2);



        vm.stopBroadcast();
    }
}
