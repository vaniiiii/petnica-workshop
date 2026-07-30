// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title IStreamingContractV1
/// @notice A minimal interface for linearly streaming ETH.
interface IStreamingContractV1 {
    error EthTransferFailed();
    error InvalidStreamId();
    error InvalidTimeRange();
    error NothingToWithdraw();
    error StartTimeInPast();
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();

    struct Stream {
        address recipient;
        address sender;
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        uint256 withdrawnAmount;
    }

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    );
    event Withdrawal(uint256 indexed streamId, address indexed recipient, uint256 amount);

    function createStream(address recipient, uint256 startTime, uint256 endTime)
        external
        payable
        returns (uint256 streamId);

    function withdrawFromStream(uint256 streamId) external;

    function getStream(uint256 streamId) external view returns (Stream memory);

    function calculateWithdrawableAmount(uint256 streamId) external view returns (uint256);
}
