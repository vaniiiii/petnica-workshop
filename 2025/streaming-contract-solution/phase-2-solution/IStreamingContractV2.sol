pragma solidity 0.8.26;

/// @title IStreamingContractV2
/// @notice Interface for ETH and ERC20 token streaming with cancellation
/// @dev Extends V1 functionality with token support and stream cancellation
interface IStreamingContractV2 {
    struct Stream {
        address recipient;
        address sender;
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        uint256 withdrawnAmount;
        address tokenAddress; // address(0) for ETH
        bool cancelled;
    }

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    );

    event StreamCancelled(
        uint256 indexed streamId,
        uint256 recipientBalance,
        uint256 senderBalance
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
    error StreamAlreadyCancelled();
    error OnlySenderCanCancel();

    /// @notice Creates a new ETH stream
    /// @param recipient The address that will receive the streamed ETH
    /// @param startTime Unix timestamp when the stream starts
    /// @param endTime Unix timestamp when the stream ends
    /// @return streamId The unique identifier for the created stream
    function createStream(address recipient, uint256 startTime, uint256 endTime)
        external
        payable
        returns (uint256 streamId);

    /// @notice Creates a new ERC20 token stream
    /// @param recipient The address that will receive the streamed tokens
    /// @param tokenAddress The ERC20 token contract address
    /// @param totalAmount The total amount of tokens to stream
    /// @param startTime Unix timestamp when the stream starts
    /// @param endTime Unix timestamp when the stream ends
    /// @return streamId The unique identifier for the created stream
    function createTokenStream(
        address recipient,
        address tokenAddress,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    ) external returns (uint256 streamId);

    /// @notice Cancels an active stream
    /// @param streamId The ID of the stream to cancel
    /// @dev Only the stream sender can cancel. Distributes streamed amount to recipient and remainder to sender
    function cancelStream(uint256 streamId) external;

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
    /// @return The amount of tokens/ETH available to withdraw
    function calculateWithdrawableAmount(uint256 streamId) external view returns (uint256);
}