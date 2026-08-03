// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";

import {IStreamingContractV1} from "../src/interfaces/IStreamingContractV1.sol";
import {StreamingContractV1} from "../src/StreamingContractV1.sol";

contract StreamingContractV1Test is Test {
    IStreamingContractV1 internal streaming;

    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");

    function setUp() external {
        streaming = new StreamingContractV1();
        vm.deal(sender, 10 ether);
    }

    function test_CreateStreamStoresEthAndStreamData() external {
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 10 days;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, endTime);

        IStreamingContractV1.Stream memory stream = streaming.getStream(streamId);
        assertEq(streamId, 0);
        assertEq(stream.sender, sender);
        assertEq(stream.recipient, recipient);
        assertEq(stream.startTime, startTime);
        assertEq(stream.endTime, endTime);
        assertEq(stream.totalAmount, 1 ether);
        assertEq(address(streaming).balance, 1 ether);
    }

    function test_WithdrawTransfersOnlyVestedEthAndEmitsEvent() external {
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 10 days;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, endTime);
        vm.warp(startTime + 4 days);

        vm.expectEmit(true, true, false, true);
        emit IStreamingContractV1.Withdrawal(streamId, recipient, 0.4 ether);
        vm.prank(recipient);
        streaming.withdrawFromStream(streamId);

        assertEq(recipient.balance, 0.4 ether);
        assertEq(streaming.getStream(streamId).withdrawnAmount, 0.4 ether);
        assertEq(streaming.calculateWithdrawableAmount(streamId), 0);
    }

    function test_RecipientCanWithdrawRemainingDustAtEnd() external {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 3;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, endTime);

        vm.warp(startTime + 1);
        vm.prank(recipient);
        streaming.withdrawFromStream(streamId);

        vm.warp(endTime);
        vm.prank(recipient);
        streaming.withdrawFromStream(streamId);

        assertEq(recipient.balance, 1 ether);
        assertEq(address(streaming).balance, 0);
        assertEq(streaming.calculateWithdrawableAmount(streamId), 0);
    }

    function test_RevertWhenStreamIdDoesNotExist() external {
        vm.expectRevert(IStreamingContractV1.InvalidStreamId.selector);
        streaming.withdrawFromStream(0);
    }

    function test_RevertWhenTimeRangeHasNoDuration() external {
        uint256 startTime = block.timestamp + 1 days;

        vm.expectRevert(IStreamingContractV1.InvalidTimeRange.selector);
        vm.prank(sender);
        streaming.createStream{value: 1 ether}(recipient, startTime, startTime);
    }

    function test_RevertWhenNothingHasVested() external {
        uint256 startTime = block.timestamp + 1 days;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, startTime + 10 days);

        vm.expectRevert(IStreamingContractV1.NothingToWithdraw.selector);
        vm.prank(recipient);
        streaming.withdrawFromStream(streamId);
    }
}
