# Basic AI Call Example

This example demonstrates how to create a complete AI-powered smart contract using the DTN SDK. The contract shows all the core concepts: AI sessions, model selection, routing, callbacks, and error handling.

## Complete Example Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@deeptrust/contracts/with-dtn-ai.sol";
import "@deeptrust/contracts/dtn-defaults.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract CallAiExample is WithDtnAi {
    using SafeERC20 for IERC20;
    
    // Events for tracking requests and responses
    event Request(bytes32 requestId, string[] prompt_lines, bytes extraParams);
    event Result(bytes32 requestId, IDtnAi.ResponseStatus status, string message, string result);
    event Error(bytes32 requestId);
    
    // State variables
    string public result;
    string public error;
    uint256 public sessionId;
    bytes32 public requestId;
    string public ipfsCid;
    
    constructor(address ai) {
        setAi(ai);
    }
    
    // Basic AI call with simple prompt
    function doCallAi(string memory prompt, string memory node, string memory model) public payable {
        // Prompts are usually multiple lines. They will be concatenated in multiple lines.
        // They also provide parameterization. You can include positioned arguments, with their relevant type in the prompt.
        // Then you need to provide the extraParams, as the encoded value of these positional arguments. 
        // Note that if the provided arguments are not exact match, your request will be rejected and failure callback will be called.
        
        string[] memory prompt_lines = new string[](2);
        prompt_lines[0] = "This is metadata - {0:uint8} and {1:address} -. Ignore the metadata and answer the next question:";
        prompt_lines[1] = prompt;
        bytes memory extraParams = abi.encode(26, address(this)); // These are the extra parameters to the prompt's line[0]
        
        doCallAiDetailed(prompt_lines, extraParams, node, model);
    }
    
    // Detailed AI call with full control over parameters
    function doCallAiDetailed(
        string[] memory prompt_lines, 
        bytes memory extraParamsEncoded, 
        string memory node, 
        string memory model
    ) public payable {
        if (sessionId == 0) {
            restartSession(); // Requests need a valid session ID. The contract starting the session will be its owner
        }
        
        // This is the main part. Creating a request:
        // - The ETH value passed, MUST cover the gas cost of the callback. If the fee is not enough, the callback will not be executed. You need to
        // fetch the result on your own.
        // - Routing usually uses one of the provided defaults. If you have custom requirements for routing, you can construct your own.
        // - Call type can be either DIRECT, or IPFS. Use IPFS if the data size is large to save gas.
        // - You identify fee per byte you are willing to pay for the request. If the fee is too low, your request may not be picked up by the nodes.
        // Some more expensive models may require higher fees. Fee currency is USD
        
        requestId = ai.request{value: msg.value}(
            sessionId,
            keccak256(abi.encodePacked(model)), // the model ID
            DtnDefaults.defaultCustomNodesValidatedAny(DtnDefaults.singleArray(keccak256(abi.encodePacked(node)))),
            IDtnAi.DtnRequest({
                call: abi.encode(prompt_lines),
                extraParams: extraParamsEncoded,
                calltype: IDtnAi.CallType.DIRECT, 
                feePerByteReq: 0.001 * 10**18,
                feePerByteRes: 0.001 * 10**18,
                totalFeePerRes: 1 * 10**18
            }),
            IDtnAi.CallBack(
                this.callback.selector,
                this.aiError.selector,
                address(this)
            ),
            msg.sender, 
            msg.value
        );
        
        emit Request(requestId, prompt_lines, extraParamsEncoded);
    }
    
    // Image generation example
    function doCallAiImage(
        string[] memory prompt_lines, 
        bytes memory extraParamsEncoded, 
        string memory node, 
        string memory model, 
        uint64 width, 
        uint64 height
    ) public payable {
        // This is a repeat of the previous function, but uses an image model that expects binary data stored on IPFS
        if (sessionId == 0) {
            restartSession();
        }
        
        requestId = ai.request{value: msg.value}(
            sessionId,
            keccak256(abi.encodePacked(model)), // the model ID
            DtnDefaults.defaultCustomNodesValidatedAny(DtnDefaults.singleArray(keccak256(abi.encodePacked(node)))),
            IDtnAi.DtnRequest({
                call: abi.encode(prompt_lines, width, height),
                extraParams: extraParamsEncoded,
                calltype: IDtnAi.CallType.IPFS, 
                feePerByteReq: 0.001 * 10**18,
                feePerByteRes: 0.001 * 10**18,
                totalFeePerRes: 1 * 10**18
            }),
            IDtnAi.CallBack(
                this.callbackIpfs.selector,
                this.aiError.selector,
                address(this)
            ),
            msg.sender, 
            msg.value
        );
        
        emit Request(requestId, prompt_lines, extraParamsEncoded);
    }
    
    // Session management
    function restartSession() public {
        if (sessionId != 0) {
            ai.closeUserSession(sessionId); // Unused funds will be refunded when we close the session
        }
        uint amount = IERC20(ai.feeToken()).balanceOf(address(this)); // Use what we have to start a session
        require(amount > 0, "Not enough tokens to start a session");
        IERC20(ai.feeToken()).safeTransfer(ai.feeTarget(), amount);
        sessionId = ai.startUserSession();
    }
    
    // Success callback for text responses
    function callback(bytes32 _requestId) external onlyDtn {
        // NOTE: Callback must use the `onlyDtn` modifier to make sure only DTN contracts are allowed to call it
        // otherwise this function can be abused
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = ai.fetchResponse(_requestId);
        
        // You should know what the expected return type is and you need to parse the return type (always encoded as bytes) to the
        // expected type. If you expect an IPFS cid because your request had IPFS type, parse the result into string.
        result = abi.decode(response, (string));
        emit Result(_requestId, status, message, result);
    }
    
    // Success callback for IPFS responses (images)
    function callbackIpfs(bytes32 _requestId) external onlyDtn {
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = ai.fetchResponse(_requestId);
        ipfsCid = abi.decode(response, (string));
        emit Result(_requestId, status, message, ipfsCid);
    }
    
    // Error callback
    function aiError(bytes32 _requestId) external onlyDtn {
        (, string memory message, ) = ai.fetchResponse(_requestId);
        error = message;
        emit Error(_requestId);
    }
}
```

## Key Features Explained

### 1. Contract Setup

```solidity
contract CallAiExample is WithDtnAi {
    using SafeERC20 for IERC20;
    
    constructor(address ai) {
        setAi(ai);
    }
}
```

- Inherits from `WithDtnAi` to get AI functionality
- Uses `SafeERC20` for secure token transfers
- Sets the AI contract address in constructor

### 2. State Management

```solidity
string public result;
string public error;
uint256 public sessionId;
bytes32 public requestId;
string public ipfsCid;
```

- `result`: Stores the latest AI response
- `error`: Stores error messages
- `sessionId`: Tracks the current AI session
- `requestId`: Tracks the latest request
- `ipfsCid`: Stores IPFS content IDs for images

### 3. Basic AI Call

```solidity
function doCallAi(string memory prompt, string memory node, string memory model) public payable
```

This function demonstrates:
- **Prompt Parameterization**: Using placeholders like `{0:uint8}` and `{1:address}`
- **Extra Parameters**: Encoding additional data with `abi.encode()`
- **Session Management**: Automatic session creation if needed
- **Model Selection**: Using different AI models
- **Node Routing**: Specifying which nodes to use

### 4. Detailed AI Call

```solidity
function doCallAiDetailed(string[] memory prompt_lines, bytes memory extraParamsEncoded, string memory node, string memory model) public payable
```

This function provides full control over:
- **Multi-line Prompts**: Array of prompt lines
- **Custom Parameters**: Pre-encoded extra parameters
- **Fee Structure**: Setting request and response fees
- **Call Type**: Choosing between DIRECT and IPFS
- **Routing**: Custom node selection

### 5. Image Generation

```solidity
function doCallAiImage(string[] memory prompt_lines, bytes memory extraParamsEncoded, string memory node, string memory model, uint64 width, uint64 height) public payable
```

Key differences for image generation:
- **IPFS Call Type**: Uses `CallType.IPFS` for large binary data
- **Image Parameters**: Includes width and height
- **IPFS Callback**: Uses `callbackIpfs` for handling IPFS responses

### 6. Session Management

```solidity
function restartSession() public
```

This function:
- **Closes Existing Session**: Refunds unused funds
- **Transfers Tokens**: Sends USDT to fee target
- **Starts New Session**: Creates a fresh session
- **Error Handling**: Ensures sufficient token balance

### 7. Callbacks

#### Success Callback (Text)

```solidity
function callback(bytes32 _requestId) external onlyDtn
```

- **Security**: Uses `onlyDtn` modifier
- **Response Fetching**: Gets response from AI system
- **Data Decoding**: Parses response to expected type
- **State Update**: Stores result and emits event

#### Success Callback (IPFS)

```solidity
function callbackIpfs(bytes32 _requestId) external onlyDtn
```

- **IPFS Handling**: Decodes IPFS content ID
- **Image Storage**: Stores CID for later retrieval

#### Error Callback

```solidity
function aiError(bytes32 _requestId) external onlyDtn
```

- **Error Handling**: Captures error messages
- **State Update**: Stores error information
- **Event Emission**: Notifies about failures

## Usage Examples

### Deploying the Contract

```javascript
const { ethers } = require("hardhat");

async function deploy() {
    const aiAddress = "0x..."; // DTN AI contract address
    
    const CallAiExample = await ethers.getContractFactory("CallAiExample");
    const contract = await CallAiExample.deploy(aiAddress);
    
    await contract.deployed();
    console.log("Contract deployed to:", contract.address);
}
```

### Making a Basic AI Call

```javascript
// Simple text request
const prompt = "What is the capital of France?";
const node = "node.default.node1";
const model = "gpt-3.5-turbo";

const tx = await contract.doCallAi(prompt, node, model, {
    value: ethers.utils.parseEther("0.1")
});

await tx.wait();
console.log("AI request submitted!");
```

### Making an Image Request

```javascript
// Image generation request
const prompt_lines = ["A beautiful sunset over mountains"];
const extraParams = "0x"; // No extra parameters
const node = "node.image.node1";
const model = "dall-e";
const width = 512;
const height = 512;

const tx = await contract.doCallAiImage(
    prompt_lines, 
    extraParams, 
    node, 
    model, 
    width, 
    height, 
    { value: ethers.utils.parseEther("0.2") }
);

await tx.wait();
console.log("Image generation request submitted!");
```

### Checking Results

```javascript
// Check text result
const result = await contract.result();
console.log("AI Response:", result);

// Check image result
const ipfsCid = await contract.ipfsCid();
console.log("Image IPFS CID:", ipfsCid);

// Check for errors
const error = await contract.error();
if (error) {
    console.log("Error:", error);
}
```

## Best Practices Demonstrated

1. **Security**: Using `onlyDtn` modifier for callbacks
2. **Error Handling**: Comprehensive error capture and reporting
3. **Gas Management**: Including sufficient gas for callbacks
4. **Session Management**: Efficient session lifecycle handling
5. **Event Logging**: Tracking all important operations
6. **Parameter Validation**: Ensuring proper data encoding
7. **Flexibility**: Supporting both text and image models

## Next Steps

- [Image Generation Example](image-generation.md) - More detailed image generation
- [Session Management Example](session-management.md) - Advanced session handling
- [Error Handling](../advanced/error-handling.md) - More sophisticated error handling
- [API Reference](../api/interfaces.md) - Complete interface documentation 