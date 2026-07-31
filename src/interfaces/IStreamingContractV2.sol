// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title IStreamingContractV2
/// @notice Streams ETH or ERC20 tokens and lets the sender cancel unvested payments.
interface IStreamingContractV2 {
    error EthTransferFailed();
    error InvalidStreamId();
    error InvalidTimeRange();
    error NothingToWithdraw();
    error StartTimeInPast();
    error StreamAlreadyCancelled();
    error StreamComplete();
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();

    struct Stream {
        address recipient;
        address sender;
        address tokenAddress;
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        uint256 withdrawnAmount;
        bool cancelled;
    }

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        address tokenAddress,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    );
    event StreamCancelled(uint256 indexed streamId, uint256 recipientBalance, uint256 senderBalance);
    event Withdrawal(uint256 indexed streamId, address indexed recipient, uint256 amount);

    function createStream(address recipient, uint256 startTime, uint256 endTime)
        external
        payable
        returns (uint256 streamId);

    function createTokenStream(
        address recipient,
        address tokenAddress,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    ) external returns (uint256 streamId);

    function cancelStream(uint256 streamId) external;

    function withdrawFromStream(uint256 streamId) external;

    function getStream(uint256 streamId) external view returns (Stream memory);

    function calculateWithdrawableAmount(uint256 streamId) external view returns (uint256);
}
