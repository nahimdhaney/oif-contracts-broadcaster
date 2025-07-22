# Cross-Chain Broadcaster Oracle (EIP-7888)

This directory contains the implementation of a Cross-Chain Broadcaster Oracle based on [EIP-7888](https://eips.ethereum.org/EIPS/eip-7888), which defines a standardized protocol for cross-rollup message broadcasting and reception via storage proofs.

## Overview

EIP-7888 enables trustless message passing across rollups hosted on different rollup architecture stacks. Users can broadcast messages on a source chain, which can then be read by many other chains, as long as those chains share a common ancestor chain with the source chain.

## Key Features

- **Trustless Cross-Chain Communication**: Uses storage proofs instead of trusted relayers
- **Broadcast Pattern**: One-to-many message distribution
- **Replay Protection**: Prevents duplicate message broadcasts
- **Gas Efficient**: Stores timestamps instead of booleans
- **Deterministic Storage**: Predictable storage slots for proof generation

## Architecture

### Core Components

1. **CrossChainBroadcasterOracle.sol**: Main oracle contract that integrates with the Open Intents Framework
2. **SimpleBroadcaster.sol**: Minimal EIP-7888 broadcaster implementation
3. **StorageProofVerifier.sol**: Verifies storage proofs for cross-chain messages
4. **Interfaces**: Define the standard interfaces for cross-chain broadcasting

### Integration with Open Intents Framework

The `CrossChainBroadcasterOracle` extends the existing oracle pattern by:
- Inheriting from `BaseOracle` for attestation storage
- Using `ChainMap` for chain ID mapping
- Implementing `ICrossChainBroadcaster` for broadcasting functionality
- Following the standard `submit()` pattern for payload validation

## EIP-7888 Implementation Details

### Message Broadcasting

```solidity
function broadcastMessage(bytes calldata message) external returns (bytes32 messageHash)
```

- Creates deterministic hash: `keccak256(abi.encodePacked(msg.sender, message))`
- Stores timestamp (not boolean) for gas efficiency
- Prevents replay attacks
- Emits events for off-chain indexing

### Storage Proof Verification

```solidity
function receiveMessage(
    uint256 sourceChainId,
    address sender,
    bytes calldata message,
    bytes calldata storageProof
) external
```

- Verifies storage proofs using `IStorageProofVerifier`
- Validates chain mapping
- Extracts and stores payload attestations
- Emits `OutputProven` events

### Storage Layout

Messages are stored in a nested mapping:
```solidity
mapping(address => mapping(bytes32 => uint256)) public broadcastedMessages;
```

Storage slot calculation:
```solidity
slot = keccak256(abi.encodePacked(messageHash, keccak256(abi.encodePacked(sender, mapSlot))))
```

## Usage Examples

### Broadcasting a Message

```solidity
// Deploy broadcaster
SimpleBroadcaster broadcaster = new SimpleBroadcaster();

// Broadcast a message
bytes memory message = abi.encode("Hello, cross-chain world!");
bytes32 messageHash = broadcaster.broadcastMessage(message);
```

### Verifying a Message on Another Chain

```solidity
// On destination chain
CrossChainBroadcasterOracle oracle = CrossChainBroadcasterOracle(oracleAddress);

// Receive and verify message
oracle.receiveMessage(
    sourceChainId,
    senderAddress,
    originalMessage,
    storageProof
);
```

### Checking if Message is Proven

```solidity
bool isProven = oracle.isProven(
    sourceChainId,
    remoteSender,
    application,
    payloadHash
);
```

## Security Considerations

### Storage Proof Verification

The current `StorageProofVerifier` is a simplified implementation. Production deployments should:

1. **Implement Full MPT Verification**: Verify Merkle Patricia Trie proofs against state roots
2. **Validate State Roots**: Ensure state roots are committed on L1 or verified by trusted oracles
3. **Handle Chain Reorganizations**: Account for potential reorgs on source chains
4. **Rate Limiting**: Prevent spam attacks through message rate limiting

### Message Replay Protection

- Each `(sender, message)` pair can only be broadcast once
- Message hashes include sender address for uniqueness
- Timestamps provide additional context and prevent certain replay scenarios

### Chain Mapping Security

- Only authorized owners can modify chain mappings
- Invalid chain IDs are rejected
- Mapping validation prevents routing to unsupported chains

## Gas Optimization

### Timestamp Storage

Following EIP-7888, timestamps are stored instead of booleans:
- Provides more information (when message was broadcast)
- Uses same storage slot size
- Enables time-based validations

### Batch Operations

Both contracts support batch operations:
- `broadcastMessages()`: Broadcast multiple messages
- `receiveMessages()`: Process multiple proofs
- `getBroadcastStatuses()`: Query multiple statuses

## Deployment Guide

### Prerequisites

1. Deploy `StorageProofVerifier` with supported chain IDs
2. Configure chain mappings for supported networks
3. Deploy `CrossChainBroadcasterOracle` with verifier address

### Configuration

```solidity
// Deploy verifier
StorageProofVerifier verifier = new StorageProofVerifier(owner);

// Add supported chains
verifier.addSupportedChain(1);     // Ethereum Mainnet
verifier.addSupportedChain(42161); // Arbitrum One
verifier.addSupportedChain(10);    // Optimism

// Deploy oracle
CrossChainBroadcasterOracle oracle = new CrossChainBroadcasterOracle(
    owner,
    address(verifier)
);

// Configure chain mappings
oracle.setChainMapping(42161, 42161); // Arbitrum
oracle.setChainMapping(10, 10);       // Optimism
```

## Testing

The implementation includes comprehensive test coverage for:
- Message broadcasting and replay protection
- Storage proof verification (mock implementation)
- Cross-chain message reception
- Chain mapping validation
- Integration with Open Intents Framework

## Future Enhancements

### Production-Ready Storage Proofs

- Full Merkle Patricia Trie verification
- Integration with L1 state commitments
- Support for various rollup architectures

### Enhanced Security

- Multi-signature verification for critical operations
- Slashing mechanisms for invalid proofs
- Economic incentives for honest behavior

### Scalability Improvements

- Batch proof verification
- Compressed storage proofs
- Optimized gas usage

## References

- [EIP-7888: Cross-Chain Broadcaster](https://eips.ethereum.org/EIPS/eip-7888)
- [Ethereum Magicians Discussion](https://ethereum-magicians.org/t/new-erc-cross-chain-broadcaster/22927)
- [EIP-7683: Cross Chain Intents](https://eips.ethereum.org/EIPS/eip-7683)
- [EIP-5164: Cross-Chain Execution](https://eips.ethereum.org/EIPS/eip-5164)
