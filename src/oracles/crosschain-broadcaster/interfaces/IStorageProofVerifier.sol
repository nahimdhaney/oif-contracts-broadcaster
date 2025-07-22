// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @notice Interface for verifying storage proofs to validate cross-chain messages.
 * @dev Used to verify that a message was actually broadcast on a source chain.
 */
interface IStorageProofVerifier {
    /**
     * @notice Verifies a storage proof to confirm a message was broadcast on a source chain.
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
    ) external view returns (bool isValid);

    /**
     * @notice Gets the expected storage slot for a broadcasted message.
     * @param sender The address that broadcast the message
     * @param messageHash The hash of the message
     * @return slot The storage slot that should contain the broadcast timestamp
     */
    function getExpectedStorageSlot(
        address sender,
        bytes32 messageHash
    ) external pure returns (bytes32 slot);

    /**
     * @notice Verifies the state root for a given chain and block.
     * @param chainId The chain ID to verify
     * @param blockNumber The block number
     * @param stateRoot The claimed state root
     * @return isValid True if the state root is valid for the given chain and block
     */
    function verifyStateRoot(
        uint256 chainId,
        uint256 blockNumber,
        bytes32 stateRoot
    ) external view returns (bool isValid);
}
