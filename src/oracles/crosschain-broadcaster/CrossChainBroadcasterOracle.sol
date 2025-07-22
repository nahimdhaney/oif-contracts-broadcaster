// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable } from "solady/auth/Ownable.sol";

import { IPayloadCreator } from "../../interfaces/IPayloadCreator.sol";

import { LibAddress } from "../../libs/LibAddress.sol";
import { MessageEncodingLib } from "../../libs/MessageEncodingLib.sol";

import { BaseOracle } from "../BaseOracle.sol";
import { ChainMap } from "../ChainMap.sol";

import { ICrossChainBroadcaster } from "./interfaces/ICrossChainBroadcaster.sol";
import { IStorageProofVerifier } from "./interfaces/IStorageProofVerifier.sol";

/**
 * @notice Cross-Chain Broadcaster Oracle implementing EIP-7888.
 * @dev Enables trustless cross-rollup message broadcasting and reception via storage proofs.
 * Users can broadcast messages on a source chain, which can then be read by many other chains,
 * as long as those chains share a common ancestor chain with the source chain.
 */
contract CrossChainBroadcasterOracle is ChainMap, BaseOracle, ICrossChainBroadcaster {
    using LibAddress for address;

    error InvalidStorageProof();
    error MessageNotBroadcast();
    error InvalidChainMapping();
    error NotAllPayloadsValid();

    /// @dev Storage proof verifier contract
    IStorageProofVerifier public immutable STORAGE_PROOF_VERIFIER;

    /// @dev Mapping to track broadcasted messages: sender => messageHash => timestamp
    mapping(address => mapping(bytes32 => uint256)) public broadcastedMessages;

    constructor(
        address _owner,
        address _storageProofVerifier
    ) payable ChainMap(_owner) {
        STORAGE_PROOF_VERIFIER = IStorageProofVerifier(_storageProofVerifier);
    }

    // --- Sending Messages --- //

    /**
     * @notice Broadcasts a message to be readable by other chains via storage proofs.
     * @param message The message to broadcast
     * @return messageHash The hash of the broadcasted message
     */
    function broadcastMessage(bytes calldata message) external returns (bytes32 messageHash) {
        messageHash = keccak256(abi.encodePacked(msg.sender, message));
        
        // Check if this exact message from this sender has already been broadcast
        require(broadcastedMessages[msg.sender][messageHash] == 0, "Message already broadcast");
        
        // Store the timestamp when the message was broadcast
        uint256 timestamp = block.timestamp;
        broadcastedMessages[msg.sender][messageHash] = timestamp;
        
        // Emit event for off-chain indexing and proof generation
        emit MessageBroadcast(msg.sender, messageHash, timestamp, message);
        
        return messageHash;
    }

    /**
     * @notice Takes proofs that have been marked as valid by a source and submits them for broadcast.
     * @param source Application that has payloads that are marked as valid.
     * @param payloads List of payloads to broadcast.
     */
    function submit(address source, bytes[] calldata payloads) external {
        if (!IPayloadCreator(source).arePayloadsValid(payloads)) revert NotAllPayloadsValid();
        _submit(source, payloads);
    }

    /**
     * @notice Internal function to submit validated payloads for broadcasting.
     * @param source Application that validated the payloads.
     * @param payloads List of validated payloads to broadcast.
     */
    function _submit(address source, bytes[] calldata payloads) internal {
        bytes memory encodedMessage = MessageEncodingLib.encodeMessage(source.toIdentifier(), payloads);
        
        // Broadcast the encoded message
        bytes32 messageHash = broadcastMessage(encodedMessage);
        
        // Store attestations for each payload
        uint256 numPayloads = payloads.length;
        for (uint256 i; i < numPayloads; ++i) {
            bytes32 payloadHash = keccak256(payloads[i]);
            _attestations[block.chainid][address(this).toIdentifier()][source.toIdentifier()][payloadHash] = true;
            emit OutputProven(block.chainid, address(this).toIdentifier(), source.toIdentifier(), payloadHash);
        }
    }

    // --- Receiving Messages --- //

    /**
     * @notice Verifies and processes a cross-chain message using storage proofs.
     * @param sourceChainId The chain ID where the message was originally broadcast
     * @param sender The address that broadcast the message on the source chain
     * @param message The original message that was broadcast
     * @param storageProof The storage proof demonstrating the message was broadcast
     */
    function receiveMessage(
        uint256 sourceChainId,
        address sender,
        bytes calldata message,
        bytes calldata storageProof
    ) external {
        // Verify the source chain is supported
        uint256 mappedChainId = _getMappedChainId(sourceChainId);
        if (mappedChainId == 0) revert InvalidChainMapping();

        bytes32 messageHash = keccak256(abi.encodePacked(sender, message));
        
        // Verify the storage proof
        bool isValid = STORAGE_PROOF_VERIFIER.verifyStorageProof(
            sourceChainId,
            address(this), // Expected contract address on source chain
            sender,
            messageHash,
            storageProof
        );
        
        if (!isValid) revert InvalidStorageProof();

        // Decode the message to extract application and payloads
        (bytes32 application, bytes32[] memory payloadHashes) = 
            MessageEncodingLib.getHashesOfEncodedPayloads(message);

        // Store attestations for the verified payloads
        uint256 numPayloads = payloadHashes.length;
        for (uint256 i; i < numPayloads; ++i) {
            bytes32 payloadHash = payloadHashes[i];
            _attestations[mappedChainId][sender.toIdentifier()][application][payloadHash] = true;
            emit OutputProven(mappedChainId, sender.toIdentifier(), application, payloadHash);
        }
    }

    // --- View Functions --- //

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
     * @dev This is used by off-chain tools to generate storage proofs.
     * @param sender The address that broadcast the message
     * @param messageHash The hash of the message
     * @return slot The storage slot containing the broadcast timestamp
     */
    function getMessageStorageSlot(
        address sender,
        bytes32 messageHash
    ) external pure returns (bytes32 slot) {
        return keccak256(abi.encodePacked(
            keccak256(abi.encodePacked(messageHash, uint256(keccak256("broadcastedMessages")) + 1)),
            sender
        ));
    }
}
