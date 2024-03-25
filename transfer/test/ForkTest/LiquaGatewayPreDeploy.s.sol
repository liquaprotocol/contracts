// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Helper} from "../../script/Helper.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {LiquaGateway} from "../../src/LiquaGateway.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";

contract LiquaGatewayForkTest is Test, Helper {
    address public proxy;

    function setUp() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SupportedNetworks network = SupportedNetworks.ETHEREUM_SEPOLIA;

        (address router, , address linkToken, , ) = getConfigFromNetwork(
            network
        );

        proxy = Upgrades.deployUUPSProxy(
            "LiquaGateway.sol",
            abi.encodeCall(LiquaGateway.initialize, (router, linkToken))
        );

        console.log("chainId", block.chainid);
    }

    function test_run() public {
        SupportedNetworks network = SupportedNetworks.ETHEREUM_SEPOLIA;
        (address ccipBnM, address ccipLnM) = getDummyTokensFromNetwork(network);

        LiquaGateway(payable(proxy)).setTokenFeeConfig(ccipBnM, 1000, 0, 0);

        LiquaGateway(payable(proxy)).setTokenFeeConfig(ccipLnM, 1000, 0, 0);

        uint commissionFee = LiquaGateway(payable(proxy)).getCommissionFee(
            ccipBnM,
            10000 ether
        );

        (uint feeConfig, , ) = LiquaGateway(payable(proxy)).tokenFeeConfigs(
            ccipBnM
        );

        console.log("tokenFeeConfig", feeConfig);
        console.log("commissionFee", commissionFee);

        // vm.stopBroadcast();
    }

    function test_send() public {
        SupportedNetworks network = SupportedNetworks.ETHEREUM_SEPOLIA;

        SupportedNetworks destination = SupportedNetworks.POLYGON_MUMBAI;

        (address ccipBnM,) = getDummyTokensFromNetwork(network);

        address receiver = 0x25044d07b6BF88a84FaC422c49f8604000248A9A;

        (, , , , uint64 destinationChainId) = getConfigFromNetwork(destination);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: ccipBnM,
            amount: 1 ether
        });
        tokenAmounts[0] = tokenAmount;

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: new bytes(0),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 0})
            ),
            feeToken: address(0)
        });

        uint256 fee = LiquaGateway(payable(proxy)).getFee(
            destinationChainId,
            evm2AnyMessage
        );

        IERC20(ccipBnM).approve(proxy, 1 ether);

        bytes32 messageId = LiquaGateway(payable(proxy)).send{value: fee}(
            destinationChainId,
            receiver,
            ccipBnM,
            1 ether,
            0,
            LiquaGateway.FeeTokenType.NATIVE
        );

        console.log(
            "You can now monitor the status of your Chainlink CCIP Message via https://ccip.chain.link using CCIP Message ID: "
        );
        console.logBytes32(messageId);
    }
}
