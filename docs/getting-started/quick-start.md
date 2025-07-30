# Quick Start

This guide will walk you through creating your first AI-powered smart contract using the DTN SDK in just a few minutes.

## Prerequisites

- [Installation completed](installation.md)
- Basic understanding of Solidity
- A development environment (Hardhat, Truffle, or Foundry)

## Step 1: Create Your Contract

Create a new Solidity file for your AI contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@deeptrust/contracts/with-dtn-ai.sol";
import "@deeptrust/contracts/dtn-defaults.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MyFirstAIContract is WithDtnAi {
    using SafeERC20 for IERC20;
    
    string public lastResult;
    bytes32 public lastRequestId;
    
    constructor(address ai) {
        setAi(ai);
    }
    
    function askAI(string memory question) public payable {
        // Create a simple prompt
        string[] memory prompt_lines = new string[](1);
        prompt_lines[0] = question;
        
        // Make the AI request
        lastRequestId = ai.request{value: msg.value}(
            0, // sessionId (0 for new session)
            keccak256(abi.encodePacked("gpt-3.5-turbo")), // model ID
            DtnDefaults.defaultSystemTrust(), // use default DTN network
            IDtnAi.DtnRequest({
                call: abi.encode(prompt_lines),
                extraParams: "",
                calltype: IDtnAi.CallType.DIRECT,
                feePerByteReq: 0.001 * 10**18,
                feePerByteRes: 0.001 * 10**18,
                totalFeePerRes: 1 * 10**18
            }),
            IDtnAi.CallBack(
                this.onSuccess.selector,
                this.onError.selector,
                address(this)
            ),
            msg.sender,
            msg.value
        );
    }
    
    function onSuccess(bytes32 requestId) external onlyDtn {
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
            ai.fetchResponse(requestId);
        
        lastResult = abi.decode(response, (string));
    }
    
    function onError(bytes32 requestId) external onlyDtn {
        (, string memory message, ) = ai.fetchResponse(requestId);
        lastResult = string(abi.encodePacked("Error: ", message));
    }
}
```

## Step 2: Deploy Your Contract

Deploy the contract using your preferred development framework:

### Using Hardhat

```javascript
// deploy.js
const { ethers } = require("hardhat");

async function main() {
  const aiAddress = "0x..."; // DTN AI contract address on your network
  
  const MyFirstAIContract = await ethers.getContractFactory("MyFirstAIContract");
  const contract = await MyFirstAIContract.deploy(aiAddress);
  
  await contract.deployed();
  console.log("Contract deployed to:", contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

## Step 3: Interact with Your Contract

Once deployed, you can interact with your AI contract:

```javascript
// Interact with the contract
const question = "What is the capital of France?";
const gasEstimate = await contract.estimateGas.askAI(question, { value: ethers.utils.parseEther("0.1") });

const tx = await contract.askAI(question, { 
  value: ethers.utils.parseEther("0.1"),
  gasLimit: gasEstimate.mul(120).div(100) // Add 20% buffer
});

await tx.wait();
console.log("AI request submitted!");
```

## Step 4: Handle the Response

The AI response will be automatically handled by your callback functions. You can check the result:

```javascript
// Check the result
const result = await contract.lastResult();
console.log("AI Response:", result);
```

## Key Concepts Covered

This quick start example demonstrates:

- **Basic AI Request**: Making a simple text-based AI request
- **Session Management**: Using session ID 0 for automatic session creation
- **Default Routing**: Using the default DTN network trust namespace
- **Callbacks**: Handling success and error responses
- **Gas Management**: Including sufficient gas for callback execution

## Next Steps

Now that you have a working AI contract, explore:

- [AI Sessions](../concepts/ai-sessions.md) - Learn about session management
- [DTN Routing](../concepts/dtn-routing.md) - Understand different routing options
- [Advanced Examples](../examples/basic-ai-call.md) - See more complex implementations
- [API Reference](../api/interfaces.md) - Complete function documentation

## Common Issues

**"Insufficient gas" errors**: Make sure to include enough gas for the callback execution. The gas sent with the request must cover both the request and the callback.

**"Session not found" errors**: Ensure you're using a valid session ID or 0 for automatic session creation.

**"Model not supported" errors**: Verify the model ID is correct and supported on the network you're using. 