// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IStreamingContractV1} from "./interfaces/IStreamingContractV1.sol";

/// @title StreamingContractV1
/// @notice Locks ETH and lets a recipient withdraw it as it vests linearly.
contract StreamingContractV1 is IStreamingContractV1 {
    uint256 public nextStreamId;
    mapping(uint256 streamId => Stream stream) private _streams;

    function createStream(address recipient, uint256 startTime, uint256 endTime)
        external
        payable
        returns (uint256 streamId)
    {
        if (recipient == address(0)) revert ZeroAddress();
        if (startTime < block.timestamp) revert StartTimeInPast();
        if (startTime >= endTime) revert InvalidTimeRange();
        if (msg.value == 0) revert ZeroAmount();

        streamId = nextStreamId;
        nextStreamId++;

        _streams[streamId] = Stream({
            recipient: recipient,
            sender: msg.sender,
            startTime: startTime,
            endTime: endTime,
            totalAmount: msg.value,
            withdrawnAmount: 0
        });

        emit StreamCreated(streamId, msg.sender, recipient, msg.value, startTime, endTime);
    }

    function withdrawFromStream(uint256 streamId) external {
        if (streamId >= nextStreamId) revert InvalidStreamId();

        Stream memory stream = _streams[streamId];
        if (msg.sender != stream.recipient) revert Unauthorized();

        uint256 withdrawableAmount = _calculateWithdrawableAmount(stream);
        if (withdrawableAmount == 0) revert NothingToWithdraw();

        _streams[streamId].withdrawnAmount += withdrawableAmount;

        (bool success,) = stream.recipient.call{value: withdrawableAmount}("");
        if (!success) revert EthTransferFailed();

        emit Withdrawal(streamId, stream.recipient, withdrawableAmount);
    }

    function getStream(uint256 streamId) external view returns (Stream memory) {
        if (streamId >= nextStreamId) revert InvalidStreamId();
        return _streams[streamId];
    }

    function calculateWithdrawableAmount(uint256 streamId) external view returns (uint256) {
        if (streamId >= nextStreamId) revert InvalidStreamId();
        return _calculateWithdrawableAmount(_streams[streamId]);
    }

    function _calculateWithdrawableAmount(Stream memory stream) private view returns (uint256) {
        if (block.timestamp <= stream.startTime) return 0;
        if (block.timestamp >= stream.endTime) return stream.totalAmount - stream.withdrawnAmount;

        uint256 duration = stream.endTime - stream.startTime;
        uint256 elapsed = block.timestamp - stream.startTime;
        uint256 vestedAmount = stream.totalAmount * elapsed / duration;

        return vestedAmount - stream.withdrawnAmount;
    }
}
