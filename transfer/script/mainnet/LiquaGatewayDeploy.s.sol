// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";


import {MainnetHelper} from "./MainnetHelper.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {LiquaGateway} from "../../src/LiquaGateway.sol";


contract MainnetDepolyScript is Script, MainnetHelper {
    
    function setUp() public {}

    function run(SupportedNetworks network) public {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (, address router, address linkToken, address usdc) = getLiquaGatewayDeployConfig(network);

        address proxy = Upgrades.deployUUPSProxy(
            "LiquaGateway.sol",
            abi.encodeCall(LiquaGateway.initialize, (
                router,
                linkToken
            ))
        );

        console2.log("LiquaGateway deployed at", proxy);

        LiquaGateway(payable(proxy)).setTokenFeeConfig(
            usdc,
            1000,
            0,
            0
        );


        vm.stopBroadcast();
    }

    // function set_token_fee_config(address proxy, address token, uint256 feeConfig, uint256 fee, uint256 feeLimit) public {
        
    //     LiquaGateway(payable(proxy)).setTokenFeeConfig(token, feeConfig, fee, feeLimit);
    // }
}
