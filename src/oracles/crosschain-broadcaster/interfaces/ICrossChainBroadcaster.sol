// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @notice Interface for Cross-Chain Broadcaster implementing EIP-7888.
 * @dev Defines the core functionality for broadcasting messages across chains using storage proofs.
 */
interface ICrossChainBroadcaster {
    /// @dev Event emitted when a message is broadcast
    event MessageBroadcast(
        address indexed sender,
        bytes32 indexed messageHash,
        uint256 timestamp,
        bytes message
    );

    /**
     * @notice Broadcasts a message to be verifiable on other chains via storage proofs.
     * @param message The message to broadcast
     * @return messageHash The hash of the broadcasted message
     */
    function broadcastMessage(bytes calldata message) external returns (bytes32 messageHash);

    /**
     * @notice Checks if a message has been broadcast by a specific sender.
     * @param sender The address that potentially broadcast the message
     * @param messageHash The hash of the message to check
     * @return timestamp The timestamp when the message was broadcast (0 if not broadcast)
     */
    function isMessageBroadcast(
        address sender,
        bytes32 messageHash
    ) external view returns (uint256 timestamp);

    /**
     * @notice Computes the message hash for a given sender and message.
     * @param sender The address that would broadcast the message
     * @param message The message content
     * @return messageHash The computed message hash
     */
    function computeMessageHash(
        address sender,
        bytes calldata message
    ) external pure returns (bytes32 messageHash);
}
