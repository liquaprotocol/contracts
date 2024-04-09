// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";



import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {LiquaGateway} from "../src/LiquaGateway.sol";

contract DepolyScript is Script {
    


    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // SupportedNetworks network = SupportedNetworks.POLYGON;

        address uupsProxy = 0xcD978bF791342b64Bc964DA8EDF6BC94b31D985D;


        // (address router, ,address linkToken,,) = getLiquaGatewayDeployConfig(network);

        Options memory opts;
        opts.referenceContract = "LiquaGateway.sol";

        Upgrades.upgradeProxy(
            uupsProxy,
            "LiquaGatewayV2.sol",
            "",
            opts
        );

        // console2.log("LiquaGateway upgraded successfully!");


        vm.stopBroadcast();
    }
}
