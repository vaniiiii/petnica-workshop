pragma solidity 0.8.26;

import {IStreamingContractV1} from "./IStreamingContractV1.sol";

/// @title StreamingContractV1
/// @notice Implementation of basic ETH streaming functionality
/// @dev Allows creation of ETH payment streams that unlock funds linearly over time
contract StreamingContractV1 is IStreamingContractV1 {
    uint256 id;
    mapping(uint256 id => Stream stream) streams;

    /// @inheritdoc IStreamingContractV1
    function createStream(address recipient, uint256 startTime, uint256 endTime)
        external
        payable
        returns (uint256 streamId)
    {
        if (recipient == address(0)) revert AddressZero();
        if (startTime < block.timestamp) revert MustStartInFuture();
        if (startTime >= endTime) revert InvalidInterval();
        if (msg.value == 0) revert MustStreamAmountGreaterThanZero();

        streamId = id;
        id++;

        streams[streamId] = Stream({
            recipient: recipient,
            sender: msg.sender,
            startTime: startTime,
            endTime: endTime,
            totalAmount: msg.value,
            withdrawnAmount: 0
        });

        emit StreamCreated(streamId, msg.sender, recipient, msg.value, startTime, endTime);
    }

    /// @inheritdoc IStreamingContractV1
    function withdrawFromStream(uint256 streamId) external {
        Stream memory stream = streams[streamId];
        if (streamId >= id) revert InvalidStreamId();
        if (msg.sender != stream.recipient) revert Unauthorized();
        if (stream.totalAmount == stream.withdrawnAmount) revert AlreadyStreamed();

        uint256 withdrawableAmount =
            _calculateWithdrawableAmount(stream.startTime, stream.endTime, stream.totalAmount, stream.withdrawnAmount);

        if (withdrawableAmount == 0) revert ZeroToWithdraw();

        streams[streamId].withdrawnAmount += withdrawableAmount;

        (bool success,) = stream.recipient.call{value: withdrawableAmount}("");
        require(success);

        emit Withdrawal(streamId, stream.recipient, withdrawableAmount);
    }

    /// @inheritdoc IStreamingContractV1
    function getStream(uint256 streamId) external view returns (Stream memory) {
        if (streamId >= id) revert InvalidStreamId();
        return streams[streamId];
    }

    /// @inheritdoc IStreamingContractV1
    function calculateWithdrawableAmount(uint256 streamId) external view returns (uint256) {
        if (streamId >= id) revert InvalidStreamId();
        Stream memory stream = streams[streamId];
        if (stream.totalAmount == stream.withdrawnAmount) revert AlreadyStreamed();
        return
            _calculateWithdrawableAmount(stream.startTime, stream.endTime, stream.totalAmount, stream.withdrawnAmount);
    }

    /// @notice Calculates withdrawable amount based on time elapsed
    /// @param startTime Stream start timestamp
    /// @param endTime Stream end timestamp  
    /// @param totalAmount Total ETH locked in the stream
    /// @param withdrawnAmount Amount already withdrawn
    /// @return Amount available to withdraw
    function _calculateWithdrawableAmount(
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount,
        uint256 withdrawnAmount
    ) internal view returns (uint256) {
        if (block.timestamp <= startTime) {
            return 0;
        } else if (block.timestamp > endTime) {
            return totalAmount - withdrawnAmount;
        } else {
            uint256 timeElapsed = block.timestamp - startTime;
            uint256 duration = endTime - startTime;
            return (totalAmount * timeElapsed / duration) - withdrawnAmount;
        }
    }
}