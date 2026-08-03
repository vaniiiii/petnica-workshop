// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test} from "forge-std/Test.sol";

import {IStreamingContractV2} from "../src/interfaces/IStreamingContractV2.sol";
import {StreamingContractV2} from "../src/StreamingContractV2.sol";

contract MockStreamingToken is ERC20 {
    constructor() ERC20("Streaming Token", "STR") {}

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }
}

contract RejectsEth {
    receive() external payable {
        revert();
    }
}

contract StreamingContractV2Test is Test {
    IStreamingContractV2 internal streaming;
    MockStreamingToken internal token;

    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");

    function setUp() external {
        streaming = new StreamingContractV2();
        token = new MockStreamingToken();

        vm.deal(sender, 10 ether);
        token.mint(sender, 10 ether);
    }

    function test_CreateEthStreamStoresAssetAndEmitsEvent() external {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 10 days;

        vm.expectEmit(true, true, true, true);
        emit IStreamingContractV2.StreamCreated(0, sender, recipient, address(0), 1 ether, startTime, endTime);
        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, endTime);

        IStreamingContractV2.Stream memory stream = streaming.getStream(streamId);
        assertEq(stream.sender, sender);
        assertEq(stream.recipient, recipient);
        assertEq(stream.tokenAddress, address(0));
        assertEq(stream.totalAmount, 1 ether);
        assertEq(address(streaming).balance, 1 ether);
    }

    function test_CreateTokenStreamPullsTokens() external {
        uint256 startTime = block.timestamp;

        vm.startPrank(sender);
        token.approve(address(streaming), 1 ether);
        uint256 streamId =
            streaming.createTokenStream(recipient, address(token), 1 ether, startTime, startTime + 10 days);
        vm.stopPrank();

        assertEq(token.balanceOf(address(streaming)), 1 ether);
        assertEq(streaming.getStream(streamId).tokenAddress, address(token));
    }

    function test_TokenRecipientCanWithdrawVestedAmount() external {
        uint256 startTime = block.timestamp;

        vm.startPrank(sender);
        token.approve(address(streaming), 1 ether);
        uint256 streamId =
            streaming.createTokenStream(recipient, address(token), 1 ether, startTime, startTime + 10 days);
        vm.stopPrank();

        vm.warp(startTime + 5 days);
        vm.prank(recipient);
        streaming.withdrawFromStream(streamId);

        assertEq(token.balanceOf(recipient), 0.5 ether);
        assertEq(streaming.getStream(streamId).withdrawnAmount, 0.5 ether);
    }

    function test_EthWithdrawalScheduleBeforeDuringAndAfterStream() external {
        uint256 startTime = block.timestamp + 1 days;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, startTime + 10 days);

        assertEq(streaming.calculateWithdrawableAmount(streamId), 0);

        vm.warp(startTime + 5 days);
        assertEq(streaming.calculateWithdrawableAmount(streamId), 0.5 ether);
        vm.prank(recipient);
        streaming.withdrawFromStream(streamId);

        vm.warp(startTime + 10 days);
        assertEq(streaming.calculateWithdrawableAmount(streamId), 0.5 ether);
        vm.prank(recipient);
        streaming.withdrawFromStream(streamId);

        assertEq(recipient.balance, 1 ether);
        assertEq(address(streaming).balance, 0);
    }

    function test_CancelFreezesVestedClaimAndRefundsUnvestedEth() external {
        uint256 startTime = block.timestamp;

        vm.prank(sender);
        uint256 streamId = streaming.createStream{value: 1 ether}(recipient, startTime, startTime + 10 days);
        vm.warp(startTime + 4 days);

        vm.expectEmit(true, false, false, true);
        emit IStreamingContractV2.StreamCancelled(streamId, 0.4 ether, 0.6 ether);
        vm.prank(sender);
        streaming.cancelStream(streamId);

        IStreamingContractV2.Stream memory stream = streaming.getStream(streamId);
        assertTrue(stream.cancelled);
        assertEq(stream.totalAmount, 0.4 ether);
        assertEq(streaming.calculateWithdrawableAmount(streamId), 0.4 ether);
        assertEq(address(streaming).balance, 0.4 ether);

        vm.prank(recipient);
        streaming.withdrawFromStream(streamId);
        assertEq(recipient.balance, 0.4 ether);
    }

    function test_RecipientCannotBlockSenderCancellation() external {
        RejectsEth rejectingRecipient = new RejectsEth();
        uint256 startTime = block.timestamp;

        vm.prank(sender);
        uint256 streamId =
            streaming.createStream{value: 1 ether}(address(rejectingRecipient), startTime, startTime + 10 days);
        vm.warp(startTime + 5 days);

        vm.prank(sender);
        streaming.cancelStream(streamId);

        assertEq(address(streaming).balance, 0.5 ether);
        assertEq(streaming.calculateWithdrawableAmount(streamId), 0.5 ether);
    }

    function test_RevertWhenTokenAmountIsZero() external {
        uint256 startTime = block.timestamp;

        vm.expectRevert(IStreamingContractV2.ZeroAmount.selector);
        vm.prank(sender);
        streaming.createTokenStream(recipient, address(token), 0, startTime, startTime + 1 days);
    }

    function test_RevertWhenStreamIdDoesNotExist() external {
        vm.expectRevert(IStreamingContractV2.InvalidStreamId.selector);
        streaming.withdrawFromStream(0);
    }

    function test_RevertWhenStartAndEndAreEqual() external {
        uint256 startTime = block.timestamp;

        vm.expectRevert(IStreamingContractV2.InvalidTimeRange.selector);
        vm.prank(sender);
        streaming.createStream{value: 1 ether}(recipient, startTime, startTime);
    }
}
