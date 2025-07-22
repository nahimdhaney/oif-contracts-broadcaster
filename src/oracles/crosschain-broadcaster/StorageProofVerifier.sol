// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IStorageProofVerifier } from "./interfaces/IStorageProofVerifier.sol";

/**
 * @notice Storage Proof Verifier for Cross-Chain Broadcaster.
 * @dev Verifies storage proofs to validate cross-chain messages.
 * This is a simplified implementation - production versions would need more sophisticated proof verification.
 */
contract StorageProofVerifier is IStorageProofVerifier {
    
    /// @dev Mapping of supported chain IDs
    mapping(uint256 => bool) public supportedChains;
    
    /// @dev Owner of the contract
    address public owner;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(address _owner) {
        owner = _owner;
    }
    
    /**
     * @notice Adds support for a new chain ID.
     * @param chainId The chain ID to support
     */
    function addSupportedChain(uint256 chainId) external onlyOwner {
        supportedChains[chainId] = true;
    }
    
    /**
     * @notice Removes support for a chain ID.
     * @param chainId The chain ID to remove support for
     */
    function removeSupportedChain(uint256 chainId) external onlyOwner {
        supportedChains[chainId] = false;
    }
    
    /**
     * @notice Verifies a storage proof to confirm a message was broadcast on a source chain.
     * @dev This is a simplified implementation. Production versions would implement proper
     * MPT (Merkle Patricia Trie) proof verification against the state root.
     * @param sourceChainId The chain ID where the message was broadcast
     * @param contractAddress The address of the broadcaster contract on the source chain
     * @param sender The address that broadcast the message
     * @param messageHash The hash of the message
     * @param storageProof The storage proof data
     * @return isValid True if the storage proof is valid, false otherwise
     */
    function verifyStorageProof(
        uint256 sourceChainId,
        address contractAddress,
        address sender,
        bytes32 messageHash,
        bytes calldata storageProof
    ) external view returns (bool isValid) {
        // Check if the source chain is supported
        if (!supportedChains[sourceChainId]) {
            return false;
        }
        
        // In a real implementation, this would:
        // 1. Extract the state root from the storage proof
        // 2. Verify the state root against a trusted source (L1 contract, oracle, etc.)
        // 3. Verify the storage proof against the state root using MPT verification
        // 4. Ensure the proven value matches the expected message timestamp
        
        // For demonstration purposes, we'll do basic validation
        if (storageProof.length < 32) {
            return false;
        }
        
        // Extract the claimed timestamp from the proof (simplified)
        uint256 claimedTimestamp = uint256(bytes32(storageProof[0:32]));
        
        // Basic sanity check - timestamp should be reasonable
        if (claimedTimestamp == 0 || claimedTimestamp > block.timestamp) {
            return false;
        }
        
        // In a real implementation, we would verify the full merkle proof here
        // For now, we'll return true if basic checks pass
        return true;
    }
    
    /**
     * @notice Gets the expected storage slot for a broadcasted message.
     * @param sender The address that broadcast the message
     * @param messageHash The hash of the message
     * @return slot The storage slot that should contain the broadcast timestamp
     */
    function getExpectedStorageSlot(
        address sender,
        bytes32 messageHash
    ) external pure returns (bytes32 slot) {
        // This matches the slot calculation in CrossChainBroadcasterOracle
        return keccak256(abi.encodePacked(
            keccak256(abi.encodePacked(messageHash, uint256(keccak256("broadcastedMessages")) + 1)),
            sender
        ));
    }
    
    /**
     * @notice Verifies the state root for a given chain and block.
     * @dev This is a simplified implementation. Production versions would verify against
     * L1 state commitments or other trusted sources.
     * @param chainId The chain ID to verify
     * @param blockNumber The block number
     * @param stateRoot The claimed state root
     * @return isValid True if the state root is valid for the given chain and block
     */
    function verifyStateRoot(
        uint256 chainId,
        uint256 blockNumber,
        bytes32 stateRoot
    ) external view returns (bool isValid) {
        // Check if the chain is supported
        if (!supportedChains[chainId]) {
            return false;
        }
        
        // In a real implementation, this would verify the state root against:
        // - L1 contract state commitments for L2s
        // - Cross-chain oracles
        // - Consensus mechanisms
        
        // For demonstration, we'll do basic validation
        if (stateRoot == bytes32(0) || blockNumber > block.number) {
            return false;
        }
        
        return true;
    }
}
