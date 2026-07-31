// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStreamingContractV2} from "./interfaces/IStreamingContractV2.sol";

/// @title StreamingContractV2
/// @notice Extends ETH streams with ERC20 payments and cancellation.
/// @dev Fee-on-transfer and rebasing tokens are outside this workshop example.
contract StreamingContractV2 is IStreamingContractV2 {
    using SafeERC20 for IERC20;

    uint256 public nextStreamId;
    mapping(uint256 streamId => Stream stream) private _streams;

    function createStream(address recipient, uint256 startTime, uint256 endTime)
        external
        payable
        returns (uint256 streamId)
    {
        _validateStream(recipient, startTime, endTime, msg.value);

        streamId = nextStreamId;
        nextStreamId++;

        _streams[streamId] = Stream({
            recipient: recipient,
            sender: msg.sender,
            tokenAddress: address(0),
            startTime: startTime,
            endTime: endTime,
            totalAmount: msg.value,
            withdrawnAmount: 0,
            cancelled: false
        });

        emit StreamCreated(streamId, msg.sender, recipient, address(0), msg.value, startTime, endTime);
    }

    function createTokenStream(
        address recipient,
        address tokenAddress,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    ) external returns (uint256 streamId) {
        if (tokenAddress == address(0)) revert ZeroAddress();
        _validateStream(recipient, startTime, endTime, totalAmount);

        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), totalAmount);

        streamId = nextStreamId;
        nextStreamId++;

        _streams[streamId] = Stream({
            recipient: recipient,
            sender: msg.sender,
            tokenAddress: tokenAddress,
            startTime: startTime,
            endTime: endTime,
            totalAmount: totalAmount,
            withdrawnAmount: 0,
            cancelled: false
        });

        emit StreamCreated(streamId, msg.sender, recipient, tokenAddress, totalAmount, startTime, endTime);
    }

    function cancelStream(uint256 streamId) external {
        if (streamId >= nextStreamId) revert InvalidStreamId();

        Stream storage stream = _streams[streamId];
        if (msg.sender != stream.sender) revert Unauthorized();
        if (stream.cancelled) revert StreamAlreadyCancelled();
        if (stream.withdrawnAmount == stream.totalAmount) revert StreamComplete();

        uint256 vestedAmount = _calculateVestedAmount(stream);
        uint256 recipientBalance = vestedAmount - stream.withdrawnAmount;
        uint256 senderBalance = stream.totalAmount - vestedAmount;

        stream.cancelled = true;
        stream.totalAmount = vestedAmount;

        if (senderBalance != 0) _transferAsset(stream.tokenAddress, stream.sender, senderBalance);

        emit StreamCancelled(streamId, recipientBalance, senderBalance);
    }

    function withdrawFromStream(uint256 streamId) external {
        if (streamId >= nextStreamId) revert InvalidStreamId();

        Stream storage stream = _streams[streamId];
        if (msg.sender != stream.recipient) revert Unauthorized();

        uint256 withdrawableAmount = _calculateWithdrawableAmount(stream);
        if (withdrawableAmount == 0) revert NothingToWithdraw();

        stream.withdrawnAmount += withdrawableAmount;
        _transferAsset(stream.tokenAddress, stream.recipient, withdrawableAmount);

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

    function _calculateVestedAmount(Stream memory stream) private view returns (uint256) {
        if (block.timestamp <= stream.startTime) return 0;
        if (block.timestamp >= stream.endTime) return stream.totalAmount;

        uint256 duration = stream.endTime - stream.startTime;
        uint256 elapsed = block.timestamp - stream.startTime;
        return stream.totalAmount * elapsed / duration;
    }

    function _calculateWithdrawableAmount(Stream memory stream) private view returns (uint256) {
        if (stream.cancelled) return stream.totalAmount - stream.withdrawnAmount;
        return _calculateVestedAmount(stream) - stream.withdrawnAmount;
    }

    function _validateStream(address recipient, uint256 startTime, uint256 endTime, uint256 amount) private view {
        if (recipient == address(0)) revert ZeroAddress();
        if (startTime < block.timestamp) revert StartTimeInPast();
        if (startTime >= endTime) revert InvalidTimeRange();
        if (amount == 0) revert ZeroAmount();
    }

    function _transferAsset(address tokenAddress, address recipient, uint256 amount) private {
        if (tokenAddress == address(0)) {
            (bool success,) = recipient.call{value: amount}("");
            if (!success) revert EthTransferFailed();
        } else {
            IERC20(tokenAddress).safeTransfer(recipient, amount);
        }
    }
}
