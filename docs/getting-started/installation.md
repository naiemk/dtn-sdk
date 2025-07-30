# Installation

The Deep Trust Network SDK is available as an npm package that provides smart contracts for integrating AI functionality into your blockchain applications.

## Prerequisites

Before installing the DTN SDK, ensure you have:

- Node.js (version 16 or higher)
- npm or yarn package manager
- A Solidity development environment (Hardhat, Truffle, or Foundry)

## Installing the SDK

Install the DTN SDK using npm:

```bash
npm install --save @deeptrust/contracts
```

Or using yarn:

```bash
yarn add @deeptrust/contracts
```

## What Gets Installed

The installation provides access to the following core contracts:

### Core Contracts

- **`with-dtn-ai.sol`** - Base contract that provides AI functionality to your smart contracts
- **`with-dtn-ai-upgradeable.sol`** - Upgradeable version of the base contract for upgradeable contracts
- **`idtn-ai.sol`** - Interface definitions for AI interactions and data structures
- **`dtn-defaults.sol`** - Default configurations and helper functions for common use cases

### Dependencies

The SDK automatically installs required dependencies:

- OpenZeppelin contracts for security and standard implementations
- SafeERC20 for secure token transfers

## Verification

To verify the installation, you can import the contracts in your Solidity files:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@deeptrust/contracts/with-dtn-ai.sol";
import "@deeptrust/contracts/dtn-defaults.sol";

contract MyContract is WithDtnAi {
    // Your implementation here
}
```

## Next Steps

After installation, you can:

1. [Read the Quick Start guide](quick-start.md) to create your first AI-powered contract
2. [Learn about Core Concepts](../concepts/ai-sessions.md) to understand how DTN works
3. [Explore Examples](../examples/basic-ai-call.md) to see practical implementations

## Troubleshooting

### Common Issues

**Import errors**: Ensure you're using the correct import path with the `@deeptrust/contracts` prefix.

**Version conflicts**: If you encounter dependency conflicts, try using a specific version:

```bash
npm install --save @deeptrust/contracts@latest
```

**Hardhat/Truffle configuration**: Make sure your development framework is configured to resolve npm packages correctly.

### Getting Help

If you encounter issues during installation:

- Check the [GitHub repository](https://github.com/deeptrust/dtn-sdk) for known issues
- Review the [API documentation](../api/interfaces.md) for contract details
- Join the community discussions for support 