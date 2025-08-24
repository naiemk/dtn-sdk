# Deep Trust Network Software Development Kit

Welcome to the Deep Trust Network (DTN) SDK documentation. This comprehensive guide will help you integrate AI functionality into your decentralized applications using the DTN network.

## What is DTN SDK?

The Deep Trust Network SDK provides a set of smart contracts that enable developers to seamlessly integrate AI capabilities into their blockchain applications. The SDK handles the complex aspects of AI request routing, payment processing, and result delivery through a trust-based network.

## Deployed Contracts

**BASE Network**

- DTN Router (0x45B80f551646fDaC777A4991FbdA748Fc5A72194)
- DTN Node Manager (0xa579c301bB320276b85Ec12C6693eCf9f493146B)
- DTN Model Manager (0x27d0BAEcb181c3bB1B5850049092D40eE7b1fE3d) 
- DTN Session Manager (0xB93f4869C36beF19C610c32e2596C1abb8Fa878d)

## Key Features

- **AI Session Management**: Handle payments and session lifecycle for AI requests
- **Flexible Routing**: Choose between trusted network nodes or custom routing
- **Multiple AI Models**: Support for various AI models with different APIs and pricing
- **Gas-Efficient**: Optimized for cost-effective AI interactions on blockchain
- **Trust-Based Network**: Leverage staked nodes for reliable AI service delivery

## Quick Start

```bash
npm install --save @deeptrust/contracts
```

```solidity
import "@deeptrust/contracts/with-dtn-ai.sol";

contract MyAIContract is WithDtnAi {
    // Your AI-powered contract implementation
}
```

## What You'll Learn

This documentation covers:

- **Getting Started**: Installation and basic setup
- **Core Concepts**: Understanding AI sessions, models, routing, and callbacks
- **Smart Contracts**: Detailed reference for all available contracts
- **Examples**: Practical implementations for common use cases
- **API Reference**: Complete function and event documentation
- **Advanced Topics**: Custom routing, fee management, and error handling

## Supported Contracts

The SDK includes the following core contracts:

- `with-dtn-ai.sol` - Base contract for AI functionality
- `with-dtn-ai-upgradeable.sol` - Upgradeable version of the base contract
- `idtn-ai.sol` - Interface definitions for AI interactions
- `dtn-defaults.sol` - Default configurations and helper functions

## Getting Help

- 📖 [Installation Guide](getting-started/installation.md)
- 🚀 [Quick Start Tutorial](getting-started/quick-start.md)
- 💡 [Core Concepts](concepts/ai-sessions.md)
- 📚 [API Reference](api/interfaces.md)
- 🐛 [Report Issues](https://github.com/deeptrust/dtn-sdk/issues)

---

*Ready to build the future of decentralized AI? Let's get started!* 
