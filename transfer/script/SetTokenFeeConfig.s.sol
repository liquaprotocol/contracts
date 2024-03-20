// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";

import {LiquaGateway} from "../src/LiquaGateway.sol";

contract SendMessage is Script, Helper {
    function run(
        
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SupportedNetworks target = SupportedNetworks.BNB_CHAIN_TESTNET;
        (,address liqua,,,) = getConfigFromNetwork(target);
        (address ccipBnM, address ccipLnM) = getDummyTokensFromNetwork(target);

        LiquaGateway(payable(liqua)).setTokenFeeConfig(
            ccipBnM,
            1000,
            0,
            0
        );

        LiquaGateway(payable(liqua)).setTokenFeeConfig(
            ccipLnM,
            1000,
            0,
            0
        );

        uint commissionFee = LiquaGateway(payable(liqua)).getCommissionFee(
            ccipBnM,
            10000 ether
        );

        (uint fee,,) = LiquaGateway(payable(liqua)).tokenFeeConfigs(ccipBnM);

        console2.log("tokenFeeConfig", fee);
        console2.log("commissionFee", commissionFee);
        

        vm.stopBroadcast();
    }
}
