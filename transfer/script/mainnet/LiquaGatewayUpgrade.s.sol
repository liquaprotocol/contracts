// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";



import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {LiquaGateway} from "../../src/LiquaGateway.sol";

import {MainnetHelper} from "./MainnetHelper.sol";


contract DepolyScript is Script, MainnetHelper {
    


    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SupportedNetworks network = SupportedNetworks.POLYGON;

        address uupsProxy = 0xe0629bA9108ec108e050E7F37c5CB7985338eCDE;

        Upgrades.upgradeProxy(
            uupsProxy,
            "LiquaGateway.sol",
            ""
        );

        console2.log("LiquaGateway upgraded successfully!");


        vm.stopBroadcast();
    }
}
