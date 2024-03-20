// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";


import {Helper} from "./Helper.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {LiquaGateway} from "../src/LiquaGateway.sol";


contract DepolyScript is Script, Helper {
    


    function setUp() public {}

    function run(SupportedNetworks network) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);


        (address router, ,address linkToken,,) = getConfigFromNetwork(network);

        address proxy = Upgrades.deployUUPSProxy(
            "LiquaGateway.sol",
            abi.encodeCall(LiquaGateway.initialize, (
                router,
                linkToken
            ))
        );

        console2.log("LiquaGateway deployed at", proxy);


        vm.stopBroadcast();
    }
}
