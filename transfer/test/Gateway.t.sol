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
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";


contract GateWayTest is Test {
    MockCCIPRouter public router;
    WETH9 public weth;
    MockLinkToken public link;
    LiquaGateway public gateway;
    address public owner = 0x25044d07b6BF88a84FaC422c49f8604000248A9A;
    address public receiver = 0x9fccc08e4Ab9CF4688a219194DC4dDab6483e3E3;
    address public treasury = 0xe2406f8cE1F5d698E58E2C2C42dbf128A047A760;


    function swapWethByLiqua(uint amount, address feeToken) public returns(bytes32 messageId) {
                uint64 destinationChainId = 16015286601757825753;

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(weth),
            amount: amount
        });
        tokenAmounts[0] = tokenAmount;

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: new bytes(0),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 0})
            ),
            feeToken: feeToken
        });

        if (feeToken == address(0)) {
            uint256 fee = gateway.getFee(destinationChainId, evm2AnyMessage);

            messageId = gateway.send{value: fee}(
                destinationChainId,
                receiver,
                address(weth),
                amount,
                0,
                LiquaGateway.FeeTokenType.NATIVE
            );
        } else {
            uint256 fee = gateway.getFee(destinationChainId, evm2AnyMessage);
            IERC20(feeToken).approve(address(gateway), fee);
            messageId = gateway.send(
                destinationChainId,
                receiver,
                address(weth),
                amount,
                0,
                LiquaGateway.FeeTokenType.NATIVE
            );
        }
    }

    function setUp() public {
        vm.startPrank(owner);

        vm.deal(owner, 110 ether);
        vm.deal(receiver, 20 ether);

        weth = new WETH9();
        router = new MockCCIPRouter();
        link = new MockLinkToken();
        gateway = LiquaGateway(
            payable(
                Upgrades.deployUUPSProxy(
                    "LiquaGateway.sol",
                    abi.encodeCall(
                        LiquaGateway.initialize,
                        (address(router), address(link))
                    )
                )
            )
        );

        gateway.grantRole(gateway.TREASURY_ROLE(), treasury);

        weth.deposit{value: 10 ether}();
    }

    function test_sendToken_pay_native_token() public {
        uint64 destinationChainId = 16015286601757825753;

        uint256 swapAmount = 1 ether;

        // owner eth balance
        uint256 ethBalance = owner.balance;
        uint256 balance = weth.balanceOf(owner);

        weth.approve(address(gateway), swapAmount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(weth),
            amount: swapAmount
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

        uint256 fee = gateway.getFee(destinationChainId, evm2AnyMessage);

        gateway.send{value: fee}(
            destinationChainId,
            receiver,
            address(weth),
            swapAmount,
            0,
            LiquaGateway.FeeTokenType.NATIVE
        );
        assert(weth.balanceOf(owner) == balance - swapAmount);
        assert(ethBalance - fee == owner.balance);
    }

    function test_sendToken_pay_link_token() public {
        uint64 destinationChainId = 16015286601757825753;

        uint256 swapAmount = 1 ether;

        weth.approve(address(gateway), swapAmount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(weth),
            amount: swapAmount
        });
        tokenAmounts[0] = tokenAmount;

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: new bytes(0),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 0})
            ),
            feeToken: address(link)
        });

        uint256 fee = gateway.getFee(destinationChainId, evm2AnyMessage);

        vm.expectRevert();
        gateway.send(
            destinationChainId,
            receiver,
            address(weth),
            swapAmount,
            0,
            LiquaGateway.FeeTokenType.LINK
        );

        link.approve(address(gateway), fee);
        gateway.send(
            destinationChainId,
            receiver,
            address(weth),
            swapAmount,
            fee,
            LiquaGateway.FeeTokenType.LINK
        );
        // assert(weth.balanceOf(owner) == balance - swapAmount);
        // assert(ethBalance - fee == owner.balance);
    }

    function test_access_withdraw() public {

        gateway.setTokenFeeConfig(
            address(weth),
            1000,
            0,
            1 ether
        );

        uint commissionFee = gateway.getCommissionFee(address(weth), 1 ether);
        assert(commissionFee == 1 ether * 1000 / 1e6);
        uint256 swapAmount = 1 ether;
        weth.approve(address(gateway), swapAmount);

        swapWethByLiqua(1 ether, address(0));

        vm.startPrank(receiver);
        // TODO: should revert AccessControlUnauthorizedAccount
        vm.expectRevert();
        gateway.withdrawToken(receiver, address(weth));

        vm.startPrank(treasury);
        gateway.withdrawToken(treasury, address(weth));
        assert(weth.balanceOf(treasury) == commissionFee);

    }

    /// @notice Test withdraw extra eth
    /// @dev In normal case, there should not be extra eth in the contract
    function test_access_withdraw_extra_eth() public {
        uint64 destinationChainId = 16015286601757825753;


        uint256 swapAmount = 1 ether;
        weth.approve(address(gateway), swapAmount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(weth),
            amount: swapAmount
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

        uint256 fee = gateway.getFee(destinationChainId, evm2AnyMessage);

        gateway.send{value: fee + 1 ether}(
            destinationChainId,
            receiver,
            address(weth),
            swapAmount,
            0,
            LiquaGateway.FeeTokenType.NATIVE
        );

        vm.startPrank(receiver);
        vm.expectRevert();
        gateway.withdraw(receiver);


        vm.startPrank(treasury);
        uint256 beforeBalance = treasury.balance;
        gateway.withdraw(treasury);
        assert(treasury.balance == beforeBalance + 1 ether);
    }

    
}
