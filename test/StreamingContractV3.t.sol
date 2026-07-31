// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test} from "forge-std/Test.sol";

import {IStreamingContractV3} from "../src/interfaces/IStreamingContractV3.sol";
import {StreamingContractV3} from "../src/StreamingContractV3.sol";

contract MockStreamingTokenV3 is ERC20 {
    constructor() ERC20("Streaming Token", "STR") {}

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }
}

contract StreamingContractV3Test is Test {
    IStreamingContractV3 internal streaming;
    MockStreamingTokenV3 internal token;

    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    address internal buyer = makeAddr("buyer");

    function setUp() external {
        streaming = new StreamingContractV3();
        token = new MockStreamingTokenV3();

        vm.deal(sender, 10 ether);
        token.mint(sender, 10 ether);
    }

    function test_CreateStreamMintsPositionNftToRecipient() external {
        uint256 startTime = block.timestamp;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, startTime + 10 days);

        assertEq(streaming.ownerOf(streamId), recipient);
        assertEq(streaming.getStream(streamId).sender, sender);
    }

    function test_CurrentNftOwnerCanWithdrawAfterTransfer() external {
        uint256 startTime = block.timestamp;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, startTime + 10 days);
        vm.prank(recipient);
        streaming.transferFrom(recipient, buyer, streamId);
        vm.warp(startTime + 5 days);

        vm.expectRevert(IStreamingContractV3.Unauthorized.selector);
        vm.prank(recipient);
        streaming.withdrawFromStream(streamId);

        vm.prank(buyer);
        streaming.withdrawFromStream(streamId);

        assertEq(buyer.balance, 0.5 ether);
        assertEq(streaming.getStream(streamId).withdrawnAmount, 0.5 ether);
    }

    function test_CancelledClaimRemainsWithdrawableByNftOwner() external {
        uint256 startTime = block.timestamp;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, startTime + 10 days);
        vm.prank(recipient);
        streaming.transferFrom(recipient, buyer, streamId);
        vm.warp(startTime + 4 days);

        vm.prank(sender);
        streaming.cancelStream(streamId);

        assertEq(streaming.calculateWithdrawableAmount(streamId), 0.4 ether);
        vm.prank(buyer);
        streaming.withdrawFromStream(streamId);
        assertEq(buyer.balance, 0.4 ether);
    }

    function test_TokenClaimFollowsNftOwner() external {
        uint256 startTime = block.timestamp;

        vm.startPrank(sender);
        token.approve(address(streaming), 1 ether);
        uint256 streamId =
            streaming.createTokenStream(recipient, address(token), 1 ether, startTime, startTime + 10 days);
        vm.stopPrank();

        vm.prank(recipient);
        streaming.transferFrom(recipient, buyer, streamId);
        vm.warp(startTime + 10 days);
        vm.prank(buyer);
        streaming.withdrawFromStream(streamId);

        assertEq(token.balanceOf(buyer), 1 ether);
        assertEq(token.balanceOf(address(streaming)), 0);
    }

    function test_RevertWhenNonOwnerWithdraws() external {
        uint256 startTime = block.timestamp;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, startTime + 10 days);
        vm.warp(startTime + 1 days);

        vm.expectRevert(IStreamingContractV3.Unauthorized.selector);
        vm.prank(buyer);
        streaming.withdrawFromStream(streamId);
    }
}
