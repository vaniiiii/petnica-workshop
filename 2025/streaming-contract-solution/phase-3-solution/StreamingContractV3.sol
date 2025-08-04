pragma solidity 0.8.26;

import {IStreamingContractV3} from "./IStreamingContractV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title StreamingContractV3
/// @notice Implementation of NFT-based tradeable payment streams
/// @dev Each stream is an ERC721 NFT that can be transferred, with payments going to the current owner
contract StreamingContractV3 is IStreamingContractV3, ERC721 {
    using SafeERC20 for IERC20;
    
    uint256 id;
    mapping(uint256 id => Stream stream) streams;

    constructor() ERC721("Stream NFT", "STREAM") {}

    /// @inheritdoc IStreamingContractV3
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
            withdrawnAmount: 0,
            tokenAddress: address(0), // ETH stream
            cancelled: false
        });

        _mint(recipient, streamId);

        emit StreamCreated(streamId, msg.sender, recipient, msg.value, startTime, endTime);
    }

    /// @inheritdoc IStreamingContractV3
    function createTokenStream(
        address recipient,
        address tokenAddress,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    ) external returns (uint256 streamId) {
        if (recipient == address(0)) revert AddressZero();
        if (tokenAddress == address(0)) revert AddressZero();
        if (startTime < block.timestamp) revert MustStartInFuture();
        if (startTime >= endTime) revert InvalidInterval();
        if (totalAmount == 0) revert MustStreamAmountGreaterThanZero();

        streamId = id;
        id++;

        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), totalAmount);

        streams[streamId] = Stream({
            recipient: recipient,
            sender: msg.sender,
            startTime: startTime,
            endTime: endTime,
            totalAmount: totalAmount,
            withdrawnAmount: 0,
            tokenAddress: tokenAddress,
            cancelled: false
        });

        _mint(recipient, streamId);

        emit StreamCreated(streamId, msg.sender, recipient, totalAmount, startTime, endTime);
    }

    /// @inheritdoc IStreamingContractV3
    function cancelStream(uint256 streamId) external {
        if (streamId >= id) revert InvalidStreamId();
        Stream memory stream = streams[streamId];
        
        if (msg.sender != stream.sender) revert OnlySenderCanCancel();
        if (stream.cancelled) revert StreamAlreadyCancelled();
        if (stream.totalAmount == stream.withdrawnAmount) revert AlreadyStreamed();

        streams[streamId].cancelled = true;

        uint256 streamedAmount = _calculateStreamedAmount(
            stream.startTime,
            stream.endTime,
            stream.totalAmount
        );
        
        address currentRecipient = ownerOf(streamId);
        
        uint256 recipientBalance = streamedAmount > stream.withdrawnAmount 
            ? streamedAmount - stream.withdrawnAmount 
            : 0;
        uint256 senderBalance = stream.totalAmount - streamedAmount;

        streams[streamId].withdrawnAmount = streamedAmount;

        if (recipientBalance > 0) {
            _transferPayment(stream.tokenAddress, currentRecipient, recipientBalance);
        }
        
        if (senderBalance > 0) {
            _transferPayment(stream.tokenAddress, stream.sender, senderBalance);
        }

        emit StreamCancelled(streamId, recipientBalance, senderBalance);
    }

    /// @inheritdoc IStreamingContractV3
    function withdrawFromStream(uint256 streamId) external {
        Stream memory stream = streams[streamId];
        if (streamId >= id) revert InvalidStreamId();
        
        address nftOwner = ownerOf(streamId);
        if (msg.sender != nftOwner) revert Unauthorized();
        
        if (stream.cancelled) revert StreamAlreadyCancelled();
        if (stream.totalAmount == stream.withdrawnAmount) revert AlreadyStreamed();

        uint256 withdrawableAmount = _calculateWithdrawableAmount(
            stream.startTime,
            stream.endTime,
            stream.totalAmount,
            stream.withdrawnAmount
        );

        if (withdrawableAmount == 0) revert ZeroToWithdraw();

        streams[streamId].withdrawnAmount += withdrawableAmount;

        _transferPayment(stream.tokenAddress, msg.sender, withdrawableAmount);

        emit Withdrawal(streamId, msg.sender, withdrawableAmount);
    }

    /// @inheritdoc IStreamingContractV3
    function getStream(uint256 streamId) external view returns (Stream memory) {
        if (streamId >= id) revert InvalidStreamId();
        return streams[streamId];
    }

    /// @inheritdoc IStreamingContractV3
    function calculateWithdrawableAmount(uint256 streamId) external view returns (uint256) {
        if (streamId >= id) revert InvalidStreamId();
        Stream memory stream = streams[streamId];
        if (stream.cancelled) return 0;
        if (stream.totalAmount == stream.withdrawnAmount) return 0;
        
        return _calculateWithdrawableAmount(
            stream.startTime,
            stream.endTime,
            stream.totalAmount,
            stream.withdrawnAmount
        );
    }

    /// @notice Overrides ERC721 transfer to update stream recipient
    /// @dev Updates the recipient field when NFT ownership changes
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._transfer(from, to, tokenId);
        
        if (tokenId < id) {
            streams[tokenId].recipient = to;
        }
    }

    /// @notice Calculates total amount streamed based on elapsed time
    /// @param startTime Stream start timestamp
    /// @param endTime Stream end timestamp
    /// @param totalAmount Total amount locked in stream
    /// @return Amount that has been streamed so far
    function _calculateStreamedAmount(
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount
    ) internal view returns (uint256) {
        if (block.timestamp <= startTime) {
            return 0;
        } else if (block.timestamp >= endTime) {
            return totalAmount;
        } else {
            uint256 timeElapsed = block.timestamp - startTime;
            uint256 duration = endTime - startTime;
            return totalAmount * timeElapsed / duration;
        }
    }

    /// @notice Calculates withdrawable amount (streamed minus withdrawn)
    /// @param startTime Stream start timestamp
    /// @param endTime Stream end timestamp
    /// @param totalAmount Total amount locked in stream
    /// @param withdrawnAmount Amount already withdrawn
    /// @return Amount available to withdraw
    function _calculateWithdrawableAmount(
        uint256 startTime,
        uint256 endTime,
        uint256 totalAmount,
        uint256 withdrawnAmount
    ) internal view returns (uint256) {
        uint256 streamedAmount = _calculateStreamedAmount(startTime, endTime, totalAmount);
        return streamedAmount > withdrawnAmount ? streamedAmount - withdrawnAmount : 0;
    }

    /// @notice Handles both ETH and ERC20 transfers
    /// @param tokenAddress Token address (address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to transfer
    function _transferPayment(address tokenAddress, address to, uint256 amount) internal {
        if (tokenAddress == address(0)) {
            (bool success,) = to.call{value: amount}("");
            require(success);
        } else {
            IERC20(tokenAddress).safeTransfer(to, amount);
        }
    }
}