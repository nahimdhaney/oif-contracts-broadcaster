// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ICrossChainBroadcaster } from "./interfaces/ICrossChainBroadcaster.sol";

/**
 * @notice Simple Cross-Chain Broadcaster implementing the core EIP-7888 pattern.
 * @dev This is a minimal implementation that demonstrates the key concepts of EIP-7888:
 * - Messages are stored with deterministic storage slots
 * - Storage proofs can be generated to verify messages on other chains
 * - Replay protection through unique message hashing
 */
contract SimpleBroadcaster is ICrossChainBroadcaster {
    
    /// @dev Mapping to track broadcasted messages: sender => messageHash => timestamp
    mapping(address => mapping(bytes32 => uint256)) public broadcastedMessages;
    
    /**
     * @notice Broadcasts a message to be verifiable on other chains via storage proofs.
     * @dev Following EIP-7888, the message and sender are hashed together to create a unique identifier.
     * The timestamp is stored rather than a boolean to provide more information and save storage costs.
     * @param message The message to broadcast
     * @return messageHash The hash of the broadcasted message
     */
    function broadcastMessage(bytes calldata message) external returns (bytes32 messageHash) {
        // Create deterministic hash from sender and message (EIP-7888 pattern)
        messageHash = keccak256(abi.encodePacked(msg.sender, message));
        
        // Prevent replay attacks - each (sender, message) pair can only be broadcast once
        require(broadcastedMessages[msg.sender][messageHash] == 0, "Message already broadcast");
        
        // Store timestamp instead of boolean (EIP-7888 optimization)
        uint256 timestamp = block.timestamp;
        broadcastedMessages[msg.sender][messageHash] = timestamp;
        
        // Emit event for off-chain indexing and proof generation
        emit MessageBroadcast(msg.sender, messageHash, timestamp, message);
        
        return messageHash;
    }
    
    /**
     * @notice Checks if a message has been broadcast by a specific sender.
     * @param sender The address that potentially broadcast the message
     * @param messageHash The hash of the message to check
     * @return timestamp The timestamp when the message was broadcast (0 if not broadcast)
     */
    function isMessageBroadcast(
        address sender,
        bytes32 messageHash
    ) external view returns (uint256 timestamp) {
        return broadcastedMessages[sender][messageHash];
    }
    
    /**
     * @notice Computes the message hash for a given sender and message.
     * @dev This is useful for off-chain tools and other contracts that need to predict the message hash.
     * @param sender The address that would broadcast the message
     * @param message The message content
     * @return messageHash The computed message hash
     */
    function computeMessageHash(
        address sender,
        bytes calldata message
    ) external pure returns (bytes32 messageHash) {
        return keccak256(abi.encodePacked(sender, message));
    }
    
    /**
     * @notice Returns the storage slot for a broadcasted message.
     * @dev This function helps off-chain tools generate storage proofs by providing
     * the exact storage slot where the broadcast timestamp is stored.
     * @param sender The address that broadcast the message
     * @param messageHash The hash of the message
     * @return slot The storage slot containing the broadcast timestamp
     */
    function getMessageStorageSlot(
        address sender,
        bytes32 messageHash
    ) external pure returns (bytes32 slot) {
        // Calculate the storage slot using Solidity's mapping storage layout
        // For mapping(address => mapping(bytes32 => uint256)), the slot is:
        // keccak256(abi.encodePacked(messageHash, keccak256(abi.encodePacked(sender, slot_of_broadcastedMessages))))
        uint256 broadcastedMessagesSlot = 0; // This would be the actual slot number in a real contract
        bytes32 innerMapSlot = keccak256(abi.encodePacked(sender, broadcastedMessagesSlot));
        return keccak256(abi.encodePacked(messageHash, innerMapSlot));
    }
    
    /**
     * @notice Batch broadcast multiple messages in a single transaction.
     * @dev More gas efficient when broadcasting multiple messages.
     * @param messages Array of messages to broadcast
     * @return messageHashes Array of computed message hashes
     */
    function broadcastMessages(
        bytes[] calldata messages
    ) external returns (bytes32[] memory messageHashes) {
        uint256 numMessages = messages.length;
        messageHashes = new bytes32[](numMessages);
        
        for (uint256 i = 0; i < numMessages; i++) {
            messageHashes[i] = broadcastMessage(messages[i]);
        }
        
        return messageHashes;
    }
    
    /**
     * @notice Get multiple broadcast statuses at once.
     * @param senders Array of sender addresses
     * @param messageHashes Array of message hashes
     * @return timestamps Array of broadcast timestamps (0 if not broadcast)
     */
    function getBroadcastStatuses(
        address[] calldata senders,
        bytes32[] calldata messageHashes
    ) external view returns (uint256[] memory timestamps) {
        require(senders.length == messageHashes.length, "Array length mismatch");
        
        uint256 numQueries = senders.length;
        timestamps = new uint256[](numQueries);
        
        for (uint256 i = 0; i < numQueries; i++) {
            timestamps[i] = broadcastedMessages[senders[i]][messageHashes[i]];
        }
        
        return timestamps;
    }
}
