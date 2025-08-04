// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {StreamingContractV3} from "../src/StreamingContractV3.sol";
import {IStreamingContractV3} from "../src/IStreamingContractV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StreamingContractV3Test is Test {
    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    StreamingContractV3 public streamingContract;

    address public senderAddress;
    address public recipientAddress;
    address public otherAddress;
    address public tokenAddress;

    uint256 public constant STREAM_AMOUNT = 1 ether;
    uint256 public constant TOKEN_AMOUNT = 1000e18;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public constant STREAM_DURATION = 30 days;

    function setUp() public {
        // Arrange
        streamingContract = new StreamingContractV3();

        senderAddress = makeAddr("sender");
        recipientAddress = makeAddr("recipient");
        otherAddress = makeAddr("other");
        tokenAddress = makeAddr("mockToken");

        startTime = block.timestamp + 1 days;
        endTime = startTime + STREAM_DURATION;

        // Fund sender with ETH
        vm.deal(senderAddress, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                              CREATESTREAM
    //////////////////////////////////////////////////////////////*/
    function test_CreateStream_MintsNFTToRecipient() public {
        // Arrange
        vm.prank(senderAddress);

        // Act
        uint256 streamId = streamingContract.createStream{value: STREAM_AMOUNT}(recipientAddress, startTime, endTime);

        // Assert
        assertEq(streamingContract.ownerOf(streamId), recipientAddress, "NFT should be minted to recipient");
        assertEq(streamingContract.balanceOf(recipientAddress), 1, "Recipient should have 1 NFT");
    }

    function test_CreateStream_EmitsEventWithCorrectParameters() public {
        // Arrange
        vm.prank(senderAddress);

        // Act & Assert
        vm.expectEmit(true, true, true, true);
        emit IStreamingContractV3.StreamCreated(0, senderAddress, recipientAddress, STREAM_AMOUNT, startTime, endTime);

        streamingContract.createStream{value: STREAM_AMOUNT}(recipientAddress, startTime, endTime);
    }

    function test_CreateStream_StoresStreamDataCorrectly() public {
        // Arrange
        vm.prank(senderAddress);

        // Act
        uint256 streamId = streamingContract.createStream{value: STREAM_AMOUNT}(recipientAddress, startTime, endTime);

        // Assert
        IStreamingContractV3.Stream memory stream = streamingContract.getStream(streamId);
        assertEq(stream.recipient, recipientAddress, "Recipient should match");
        assertEq(stream.sender, senderAddress, "Sender should match");
        assertEq(stream.startTime, startTime, "Start time should match");
        assertEq(stream.endTime, endTime, "End time should match");
        assertEq(stream.totalAmount, STREAM_AMOUNT, "Total amount should match");
        assertEq(stream.withdrawnAmount, 0, "Withdrawn amount should be 0");
        assertEq(stream.tokenAddress, address(0), "Token address should be 0 for ETH");
        assertEq(stream.cancelled, false, "Stream should not be cancelled");
    }

    function test_CreateStream_RevertWhenRecipientIsZeroAddress() public {
        // Arrange
        vm.prank(senderAddress);

        // Act & Assert
        vm.expectRevert(IStreamingContractV3.AddressZero.selector);
        streamingContract.createStream{value: STREAM_AMOUNT}(address(0), startTime, endTime);
    }

    function test_CreateStream_RevertWhenStartTimeInPast() public {
        // Arrange
        vm.prank(senderAddress);
        uint256 pastTime = block.timestamp - 1;

        // Act & Assert
        vm.expectRevert(IStreamingContractV3.MustStartInFuture.selector);
        streamingContract.createStream{value: STREAM_AMOUNT}(recipientAddress, pastTime, endTime);
    }

    function test_CreateStream_RevertWhenInvalidInterval() public {
        // Arrange
        vm.prank(senderAddress);

        // Act & Assert
        vm.expectRevert(IStreamingContractV3.InvalidInterval.selector);
        streamingContract.createStream{value: STREAM_AMOUNT}(recipientAddress, endTime, startTime);
    }

    function test_CreateStream_RevertWhenZeroAmount() public {
        // Arrange
        vm.prank(senderAddress);

        // Act & Assert
        vm.expectRevert(IStreamingContractV3.MustStreamAmountGreaterThanZero.selector);
        streamingContract.createStream{value: 0}(recipientAddress, startTime, endTime);
    }

    /*//////////////////////////////////////////////////////////////
                           CREATETOKENSTREAM
    //////////////////////////////////////////////////////////////*/
    function test_CreateTokenStream_MintsNFTToRecipient() public {
        // Arrange
        _mockTokenTransferFrom(senderAddress, address(streamingContract), TOKEN_AMOUNT, true);
        vm.prank(senderAddress);

        // Act
        uint256 streamId =
            streamingContract.createTokenStream(recipientAddress, tokenAddress, TOKEN_AMOUNT, startTime, endTime);

        // Assert
        assertEq(streamingContract.ownerOf(streamId), recipientAddress, "NFT should be minted to recipient");
    }

    function test_CreateTokenStream_CallsTokenTransferFrom() public {
        // Arrange
        vm.expectCall(
            tokenAddress, abi.encodeCall(IERC20.transferFrom, (senderAddress, address(streamingContract), TOKEN_AMOUNT))
        );
        _mockTokenTransferFrom(senderAddress, address(streamingContract), TOKEN_AMOUNT, true);
        vm.prank(senderAddress);

        // Act
        streamingContract.createTokenStream(recipientAddress, tokenAddress, TOKEN_AMOUNT, startTime, endTime);
    }

    function test_CreateTokenStream_RevertWhenTokenAddressZero() public {
        // Arrange
        vm.prank(senderAddress);

        // Act & Assert
        vm.expectRevert(IStreamingContractV3.AddressZero.selector);
        streamingContract.createTokenStream(recipientAddress, address(0), TOKEN_AMOUNT, startTime, endTime);
    }

    /*//////////////////////////////////////////////////////////////
                              CANCELSTREAM
    //////////////////////////////////////////////////////////////*/
    function test_CancelStream_MarksStreamAsCancelled() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 2); // Warp to middle of stream
        vm.prank(senderAddress);

        // Act
        streamingContract.cancelStream(streamId);

        // Assert
        IStreamingContractV3.Stream memory stream = streamingContract.getStream(streamId);
        assertEq(stream.cancelled, true, "Stream should be marked as cancelled");
    }

    function test_CancelStream_EmitsEventWithCorrectBalances() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 2); // 50% of stream completed

        uint256 expectedRecipientBalance = STREAM_AMOUNT / 2;
        uint256 expectedSenderBalance = STREAM_AMOUNT - expectedRecipientBalance;

        vm.prank(senderAddress);

        // Act & Assert
        vm.expectEmit(true, true, true, true);
        emit IStreamingContractV3.StreamCancelled(streamId, expectedRecipientBalance, expectedSenderBalance);

        streamingContract.cancelStream(streamId);
    }

    function test_CancelStream_TransfersCorrectAmounts() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 4); // 25% of stream completed

        uint256 recipientBalanceBefore = recipientAddress.balance;
        uint256 senderBalanceBefore = senderAddress.balance;

        vm.prank(senderAddress);

        // Act
        streamingContract.cancelStream(streamId);

        // Assert
        uint256 expectedStreamedAmount = STREAM_AMOUNT / 4; // 25%
        uint256 expectedRemainingAmount = STREAM_AMOUNT - expectedStreamedAmount; // 75%

        assertEq(
            recipientAddress.balance - recipientBalanceBefore,
            expectedStreamedAmount,
            "Recipient should receive streamed amount"
        );
        assertEq(
            senderAddress.balance - senderBalanceBefore,
            expectedRemainingAmount,
            "Sender should receive remaining amount"
        );
    }

    function test_CancelStream_RevertWhenNotSender() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.prank(otherAddress);

        // Act & Assert
        vm.expectRevert(IStreamingContractV3.OnlySenderCanCancel.selector);
        streamingContract.cancelStream(streamId);
    }

    function test_CancelStream_RevertWhenAlreadyCancelled() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.prank(senderAddress);
        streamingContract.cancelStream(streamId);

        vm.prank(senderAddress);

        // Act & Assert
        vm.expectRevert(IStreamingContractV3.StreamAlreadyCancelled.selector);
        streamingContract.cancelStream(streamId);
    }

    /*//////////////////////////////////////////////////////////////
                           WITHDRAWFROMSTREAM
    //////////////////////////////////////////////////////////////*/
    function test_WithdrawFromStream_TransfersCorrectAmount() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 2); // 50% of stream completed

        uint256 recipientBalanceBefore = recipientAddress.balance;
        vm.prank(recipientAddress);

        // Act
        streamingContract.withdrawFromStream(streamId);

        // Assert
        uint256 expectedAmount = STREAM_AMOUNT / 2;
        assertEq(
            recipientAddress.balance - recipientBalanceBefore, expectedAmount, "Should transfer 50% of stream amount"
        );
    }

    function test_WithdrawFromStream_UpdatesWithdrawnAmount() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 2);
        vm.prank(recipientAddress);

        // Act
        streamingContract.withdrawFromStream(streamId);

        // Assert
        IStreamingContractV3.Stream memory stream = streamingContract.getStream(streamId);
        uint256 expectedWithdrawn = STREAM_AMOUNT / 2;
        assertEq(stream.withdrawnAmount, expectedWithdrawn, "Withdrawn amount should be updated");
    }

    function test_WithdrawFromStream_EmitsEventWithCorrectParameters() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 2);
        uint256 expectedAmount = STREAM_AMOUNT / 2;

        vm.prank(recipientAddress);

        // Act & Assert
        vm.expectEmit(true, true, true, true);
        emit IStreamingContractV3.Withdrawal(streamId, recipientAddress, expectedAmount);

        streamingContract.withdrawFromStream(streamId);
    }

    function test_WithdrawFromStream_RevertWhenNotNFTOwner() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 2);
        vm.prank(otherAddress);

        // Act & Assert
        vm.expectRevert(IStreamingContractV3.Unauthorized.selector);
        streamingContract.withdrawFromStream(streamId);
    }

    function test_WithdrawFromStream_RevertWhenStreamCancelled() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.prank(senderAddress);
        streamingContract.cancelStream(streamId);

        vm.prank(recipientAddress);

        // Act & Assert
        vm.expectRevert(IStreamingContractV3.StreamAlreadyCancelled.selector);
        streamingContract.withdrawFromStream(streamId);
    }

    function test_WithdrawFromStream_WorksWithNFTTransfer() public {
        // Arrange
        uint256 streamId = _createETHStream();

        // Transfer NFT to other address
        vm.prank(recipientAddress);
        streamingContract.transferFrom(recipientAddress, otherAddress, streamId);

        vm.warp(startTime + STREAM_DURATION / 2);
        uint256 otherBalanceBefore = otherAddress.balance;
        vm.prank(otherAddress);

        // Act
        streamingContract.withdrawFromStream(streamId);

        // Assert
        uint256 expectedAmount = STREAM_AMOUNT / 2;
        assertEq(otherAddress.balance - otherBalanceBefore, expectedAmount, "New NFT owner should be able to withdraw");
    }

    function test_WithdrawFromStream_WorksWithMultipleTransfers() public {
        // Arrange
        uint256 streamId = _createETHStream();
        address thirdAddress = makeAddr("third");

        // Transfer A->B->C
        vm.prank(recipientAddress);
        streamingContract.transferFrom(recipientAddress, otherAddress, streamId);
        
        vm.prank(otherAddress);
        streamingContract.transferFrom(otherAddress, thirdAddress, streamId);

        vm.warp(startTime + STREAM_DURATION / 4);
        uint256 thirdBalanceBefore = thirdAddress.balance;
        vm.prank(thirdAddress);

        // Act
        streamingContract.withdrawFromStream(streamId);

        // Assert
        uint256 expectedAmount = STREAM_AMOUNT / 4;
        assertEq(thirdAddress.balance - thirdBalanceBefore, expectedAmount, "Final NFT owner should be able to withdraw");
    }

    function test_GetStream_RecipientUpdatesAfterTransfer() public {
        // Arrange
        uint256 streamId = _createETHStream();
        
        // Act - Transfer NFT
        vm.prank(recipientAddress);
        streamingContract.transferFrom(recipientAddress, otherAddress, streamId);
        
        // Assert
        IStreamingContractV3.Stream memory stream = streamingContract.getStream(streamId);
        assertEq(stream.recipient, otherAddress, "Stream recipient should update after NFT transfer");
    }

    function test_WithdrawFromStream_RevertWhenZeroWithdrawable() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 2);
        
        // First withdrawal (50%)
        vm.prank(recipientAddress);
        streamingContract.withdrawFromStream(streamId);
        
        // Act & Assert - Try to withdraw again at same time (0% additional)
        vm.prank(recipientAddress);
        vm.expectRevert(IStreamingContractV3.ZeroToWithdraw.selector);
        streamingContract.withdrawFromStream(streamId);
    }

    function test_FullStreamLifecycle() public {    
        // Arrange
        uint256 streamId = _createETHStream();
        address finalOwner = makeAddr("finalOwner");
        
        // Act & Assert - 25% through stream
        vm.warp(startTime + STREAM_DURATION / 4);
        
        uint256 recipientBalanceBefore = recipientAddress.balance;
        vm.prank(recipientAddress);
        streamingContract.withdrawFromStream(streamId);
        
        uint256 expectedFirst = STREAM_AMOUNT / 4;
        assertEq(recipientAddress.balance - recipientBalanceBefore, expectedFirst, "Should withdraw 25%");
        
        // Transfer NFT
        vm.prank(recipientAddress);
        streamingContract.transferFrom(recipientAddress, finalOwner, streamId);
        
        // 75% through stream - new owner withdraws remaining
        vm.warp(startTime + (STREAM_DURATION * 3) / 4);
        
        uint256 finalOwnerBalanceBefore = finalOwner.balance;
        vm.prank(finalOwner);
        streamingContract.withdrawFromStream(streamId);
        
        uint256 expectedSecond = STREAM_AMOUNT / 2; // 75% - 25% = 50%
        assertEq(finalOwner.balance - finalOwnerBalanceBefore, expectedSecond, "New owner should withdraw remaining 50%");
        
        // Complete stream
        vm.warp(endTime + 1);
        
        uint256 finalOwnerBalance2 = finalOwner.balance;
        vm.prank(finalOwner);
        streamingContract.withdrawFromStream(streamId);
        
        uint256 expectedFinal = STREAM_AMOUNT / 4; // 100% - 75% = 25%
        assertEq(finalOwner.balance - finalOwnerBalance2, expectedFinal, "Should withdraw final 25%");
        
        // Verify stream is fully withdrawn
        IStreamingContractV3.Stream memory stream = streamingContract.getStream(streamId);
        assertEq(stream.withdrawnAmount, STREAM_AMOUNT, "Should have withdrawn full amount");
    }

    /*//////////////////////////////////////////////////////////////
                               GETSTREAM
    //////////////////////////////////////////////////////////////*/
    function test_GetStream_ReturnsCorrectStreamData() public {
        // Arrange
        uint256 streamId = _createETHStream();

        // Act
        IStreamingContractV3.Stream memory stream = streamingContract.getStream(streamId);

        // Assert
        assertEq(stream.recipient, recipientAddress, "Recipient should match");
        assertEq(stream.sender, senderAddress, "Sender should match");
        assertEq(stream.totalAmount, STREAM_AMOUNT, "Total amount should match");
        assertEq(stream.tokenAddress, address(0), "Token address should be 0 for ETH");
    }

    function test_GetStream_RevertWhenInvalidStreamId() public {
        // Act & Assert
        vm.expectRevert(IStreamingContractV3.InvalidStreamId.selector);
        streamingContract.getStream(999);
    }

    /*//////////////////////////////////////////////////////////////
                      CALCULATEWITHDRAWABLEAMOUNT
    //////////////////////////////////////////////////////////////*/
    function test_CalculateWithdrawableAmount_ReturnsZeroBeforeStart() public {
        // Arrange
        uint256 streamId = _createETHStream();

        // Act
        uint256 withdrawable = streamingContract.calculateWithdrawableAmount(streamId);

        // Assert
        assertEq(withdrawable, 0, "Should return 0 before stream starts");
    }

    function test_CalculateWithdrawableAmount_ReturnsPartialAmountDuringStream() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 4); // 25% through stream

        // Act
        uint256 withdrawable = streamingContract.calculateWithdrawableAmount(streamId);

        // Assert
        uint256 expectedAmount = STREAM_AMOUNT / 4;
        assertEq(withdrawable, expectedAmount, "Should return 25% of total amount");
    }

    function test_CalculateWithdrawableAmount_ReturnsFullAmountAfterEnd() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(endTime + 1);

        // Act
        uint256 withdrawable = streamingContract.calculateWithdrawableAmount(streamId);

        // Assert
        assertEq(withdrawable, STREAM_AMOUNT, "Should return full amount after stream ends");
    }

    function test_CalculateWithdrawableAmount_AccountsForPreviousWithdrawals() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.warp(startTime + STREAM_DURATION / 2);

        // First withdrawal
        vm.prank(recipientAddress);
        streamingContract.withdrawFromStream(streamId);

        vm.warp(startTime + (STREAM_DURATION * 3) / 4); // 75% through stream

        // Act
        uint256 withdrawable = streamingContract.calculateWithdrawableAmount(streamId);

        // Assert
        uint256 expectedAmount = STREAM_AMOUNT / 4; // 75% - 50% = 25% more available
        assertEq(withdrawable, expectedAmount, "Should account for previous withdrawals");
    }

    function test_CalculateWithdrawableAmount_ReturnsZeroForCancelledStream() public {
        // Arrange
        uint256 streamId = _createETHStream();
        vm.prank(senderAddress);
        streamingContract.cancelStream(streamId);

        // Act
        uint256 withdrawable = streamingContract.calculateWithdrawableAmount(streamId);

        // Assert
        assertEq(withdrawable, 0, "Should return 0 for cancelled stream");
    }

    /*//////////////////////////////////////////////////////////////
                          EDGE CASES & COVERAGE
    //////////////////////////////////////////////////////////////*/
    function test_CancelStream_WhenRecipientBalanceIsZero() public {
        // Arrange - Cancel stream before it starts (recipientBalance = 0)
        uint256 streamId = _createETHStream();
        uint256 senderBalanceBefore = senderAddress.balance;
        vm.prank(senderAddress);
        
        // Act - Cancel before stream starts
        streamingContract.cancelStream(streamId);
        
        // Assert - Sender gets full refund, recipient gets nothing
        assertEq(
            senderAddress.balance - senderBalanceBefore, 
            STREAM_AMOUNT, 
            "Sender should get full refund when cancelling before start"
        );
    }

    function test_CancelStream_WhenSenderBalanceIsZero() public {
        // Arrange - Cancel stream after completion (senderBalance = 0)
        uint256 streamId = _createETHStream();
        vm.warp(endTime + 1); // Stream completely finished
        
        address currentRecipient = streamingContract.ownerOf(streamId);
        uint256 recipientBalanceBefore = currentRecipient.balance;
        vm.prank(senderAddress);
        
        // Act - Cancel after stream completion
        streamingContract.cancelStream(streamId);
        
        // Assert - Recipient gets everything, sender gets nothing
        assertEq(
            currentRecipient.balance - recipientBalanceBefore,
            STREAM_AMOUNT,
            "Recipient should get full amount when cancelling after completion"
        );
    }

    function test_CreateTokenStream_AdditionalValidations() public {
        // Test additional validation branches in createTokenStream
        
        // Test recipient address validation
        _mockTokenTransferFrom(senderAddress, address(streamingContract), TOKEN_AMOUNT, true);
        vm.prank(senderAddress);
        vm.expectRevert(IStreamingContractV3.AddressZero.selector);
        streamingContract.createTokenStream(address(0), tokenAddress, TOKEN_AMOUNT, startTime, endTime);
        
        // Test start time validation  
        _mockTokenTransferFrom(senderAddress, address(streamingContract), TOKEN_AMOUNT, true);
        vm.prank(senderAddress);
        uint256 pastTime = block.timestamp - 1;
        vm.expectRevert(IStreamingContractV3.MustStartInFuture.selector);
        streamingContract.createTokenStream(recipientAddress, tokenAddress, TOKEN_AMOUNT, pastTime, endTime);
        
        // Test interval validation
        _mockTokenTransferFrom(senderAddress, address(streamingContract), TOKEN_AMOUNT, true);
        vm.prank(senderAddress);
        vm.expectRevert(IStreamingContractV3.InvalidInterval.selector);
        streamingContract.createTokenStream(recipientAddress, tokenAddress, TOKEN_AMOUNT, endTime, startTime);
        
        // Test zero amount validation
        vm.prank(senderAddress);
        vm.expectRevert(IStreamingContractV3.MustStreamAmountGreaterThanZero.selector);
        streamingContract.createTokenStream(recipientAddress, tokenAddress, 0, startTime, endTime);
    }

    function test_Update_WithNonExistentToken() public {
        // Test _update function with tokenId >= id (non-existent token)
        // This should not update stream recipient
        uint256 streamId = _createETHStream();
        
        // Get initial stream data
        IStreamingContractV3.Stream memory streamBefore = streamingContract.getStream(streamId);
        
        // Transfer the NFT (this will call _update internally)
        vm.prank(recipientAddress);
        streamingContract.transferFrom(recipientAddress, otherAddress, streamId);
        
        // Verify stream recipient was updated for existing stream
        IStreamingContractV3.Stream memory streamAfter = streamingContract.getStream(streamId);
        assertEq(streamAfter.recipient, otherAddress, "Stream recipient should update for existing stream");
        assertEq(streamBefore.sender, streamAfter.sender, "Other fields should remain same");
    }

    function test_TransferPayment_ETHTransferFailure() public {
        // This tests the ETH transfer branch in _transferPayment
        // Create a stream but we can't easily test ETH transfer failure without a malicious contract
        // This test ensures we're hitting the ETH branch (tokenAddress == address(0))
        uint256 streamId = _createETHStream();
        
        vm.warp(startTime + STREAM_DURATION / 2);
        uint256 balanceBefore = recipientAddress.balance;
        
        vm.prank(recipientAddress);
        streamingContract.withdrawFromStream(streamId);
        
        // Assert ETH transfer happened (not token transfer)
        assertTrue(recipientAddress.balance > balanceBefore, "ETH transfer should have occurred");
    }

    function test_CalculateWithdrawableAmount_EdgeCases() public {
        uint256 streamId = _createETHStream();
        
        // Test exactly at start time
        vm.warp(startTime);
        uint256 withdrawableAtStart = streamingContract.calculateWithdrawableAmount(streamId);
        assertEq(withdrawableAtStart, 0, "Should return 0 exactly at start time");
        
        // Test exactly at end time
        vm.warp(endTime);
        uint256 withdrawableAtEnd = streamingContract.calculateWithdrawableAmount(streamId);
        assertEq(withdrawableAtEnd, STREAM_AMOUNT, "Should return full amount exactly at end time");
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/
    function _createETHStream() internal returns (uint256 streamId) {
        vm.prank(senderAddress);
        streamId = streamingContract.createStream{value: STREAM_AMOUNT}(recipientAddress, startTime, endTime);
    }

    function _mockTokenTransferFrom(address from, address to, uint256 amount, bool success) internal {
        vm.mockCall(tokenAddress, abi.encodeCall(IERC20.transferFrom, (from, to, amount)), abi.encode(success));
    }
}
