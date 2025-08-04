pragma solidity 0.8.26;

/// @title IStreamingContractV1
/// @notice Interface for basic ETH streaming functionality
/// @dev Defines the contract interface for creating and managing ETH payment streams
interface IStreamingContractV1 {
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

    error AddressZero();
    error MustStartInFuture();
    error InvalidInterval();
    error Unauthorized();
    error InvalidStreamId();
    error AlreadyStreamed();
    error ZeroToWithdraw();
    error MustStreamAmountGreaterThanZero();

    /// @notice Creates a new ETH stream
    /// @param recipient The address that will receive the streamed ETH
    /// @param startTime Unix timestamp when the stream starts
    /// @param endTime Unix timestamp when the stream ends
    /// @return streamId The unique identifier for the created stream
    function createStream(address recipient, uint256 startTime, uint256 endTime)
        external
        payable
        returns (uint256 streamId);

    /// @notice Withdraws available funds from a stream
    /// @param streamId The ID of the stream to withdraw from
    /// @dev Only the recipient can withdraw from their stream
    function withdrawFromStream(uint256 streamId) external;

    /// @notice Retrieves stream details
    /// @param streamId The ID of the stream to query
    /// @return Stream struct containing all stream information
    function getStream(uint256 streamId) external view returns (Stream memory);

    /// @notice Calculates the amount available for withdrawal
    /// @param streamId The ID of the stream to check
    /// @return The amount of ETH available to withdraw
    function calculateWithdrawableAmount(uint256 streamId) external view returns (uint256);
}