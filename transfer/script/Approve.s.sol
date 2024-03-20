// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";


contract SendMessage is Script, Helper {
    function run(
        SupportedNetworks destination
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.addr(deployerPrivateKey);

        console2.log("owner: ", owner);

        address receiver = owner;

        (address router, , ,) = getConfigFromNetwork(destination);
        (address ccipBnM, address ccipLnM) = getDummyTokensFromNetwork(destination);


        IERC20(ccipBnM).approve(router, 1000000000000 ether);
        IERC20(ccipLnM).approve(router, 1000000000000 ether);

        console.log("ccipBnM allowance of:", IERC20(ccipBnM).allowance(address(receiver), router));
        console.log("ccipLnM allowance of:", IERC20(ccipLnM).allowance(address(receiver), router));


        // Client.EVMTokenAmount[]
        //     memory tokenAmounts = new Client.EVMTokenAmount[](1);
        // Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
        //     token: ccipLnM,
        //     amount: 100 ether
        // });
        // // Client.EVMTokenAmount memory tokenAmount2 = Client.EVMTokenAmount({
        // //     token: ccipLnM,
        // //     amount: 100 ether
        // // });
        // tokenAmounts[0] = tokenAmount;
        // // tokenAmounts[1] = tokenAmount2;


        // Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
        //     receiver: abi.encode(receiver),
        //     data: new bytes(0),
        //     tokenAmounts: tokenAmounts,
        //     extraArgs: Client._argsToBytes(
        //         Client.EVMExtraArgsV1({gasLimit: 0})
        //     ),
        //     feeToken: address(0)
        // });

        // uint256 fee = IRouterClient(router).getFee(
        //     chainIdBaseSepolia,
        //     evm2AnyMessage
        // );

        // console.log("fee: ", fee);

        vm.stopBroadcast();
    }
}
