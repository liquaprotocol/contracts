// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";


import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/utils/SafeERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {WETH9} from "../src/mock/Weth.sol";

import {MockCCIPRouter} from "../src/mock/MockRouter.sol";

import {MockLinkToken} from "../src/mock/MockLinkToken.sol";
import {LiquaGateway} from "../src/LiquaGateway.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract GateWayTest is Test {
    MockCCIPRouter public router;
    WETH9 public weth;
    MockLinkToken public link;
    address public gateway;
    address public owner = 0x25044d07b6BF88a84FaC422c49f8604000248A9A;


    function setUp() public {
        vm.startPrank(owner);

        vm.deal(owner, 100 ether);

        weth = new WETH9();
        router = new MockCCIPRouter();
        link = new MockLinkToken();
        gateway = Upgrades.deployUUPSProxy(
            "LiquaGateway.sol",
            abi.encodeCall(LiquaGateway.initialize, (
                address(router),
                address(link)
            ))
        );

        weth.deposit{value: 10 ether}();

    }

    function test_normal() public {

        address receiver = owner;

        uint64 destinationChainId = 16015286601757825753;

        uint256 balance = weth.balanceOf(owner);
        assert(balance == 10 ether);

        weth.approve(address(gateway), 1 ether);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(weth),
            amount: 1 ether
        });
        tokenAmounts[0] = tokenAmount;

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(""),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            feeToken: address(0)
        });

        uint256 fee = LiquaGateway(payable(gateway)).getFee(
            destinationChainId,
            evm2AnyMessage
        );

        console.log("fee", fee);

        bytes32 messageId = LiquaGateway(payable(gateway)).send{
            value: fee
        }(
            destinationChainId,
            owner,
            address(weth),
            1 ether,
            0,
            LiquaGateway.FeeTokenType.NATIVE
        );

        console.log(vm.toString(messageId));

    }

}
