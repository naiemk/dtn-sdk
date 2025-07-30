# Image Generation Example

This example demonstrates how to create AI-powered image generation contracts using the DTN SDK. It shows how to work with image models, handle IPFS responses, and manage image-specific parameters.

## Complete Image Generation Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@deeptrust/contracts/with-dtn-ai.sol";
import "@deeptrust/contracts/dtn-defaults.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ImageGenerationExample is WithDtnAi {
    using SafeERC20 for IERC20;
    
    // Events
    event ImageRequested(bytes32 requestId, string prompt, uint64 width, uint64 height);
    event ImageGenerated(bytes32 requestId, string ipfsCid, string prompt);
    event ImageError(bytes32 requestId, string error);
    
    // State variables
    struct ImageRequest {
        string prompt;
        uint64 width;
        uint64 height;
        string model;
        bool completed;
        string ipfsCid;
        string error;
    }
    
    mapping(bytes32 => ImageRequest) public imageRequests;
    bytes32[] public requestHistory;
    uint256 public sessionId;
    
    // Image generation parameters
    uint64 public defaultWidth = 512;
    uint64 public defaultHeight = 512;
    string public defaultModel = "dall-e";
    
    constructor(address ai) {
        setAi(ai);
    }
    
    // Generate image with default parameters
    function generateImage(string memory prompt) public payable {
        generateImageWithParams(prompt, defaultWidth, defaultHeight, defaultModel);
    }
    
    // Generate image with custom parameters
    function generateImageWithParams(
        string memory prompt,
        uint64 width,
        uint64 height,
        string memory model
    ) public payable {
        if (sessionId == 0) {
            restartSession();
        }
        
        // Validate parameters
        require(bytes(prompt).length > 0, "Prompt cannot be empty");
        require(width >= 256 && width <= 1024, "Width must be between 256 and 1024");
        require(height >= 256 && height <= 1024, "Height must be between 256 and 1024");
        require(width % 64 == 0, "Width must be divisible by 64");
        require(height % 64 == 0, "Height must be divisible by 64");
        
        // Create prompt lines
        string[] memory prompt_lines = new string[](1);
        prompt_lines[0] = prompt;
        
        // Make the AI request
        bytes32 requestId = ai.request{value: msg.value}(
            sessionId,
            keccak256(abi.encodePacked(model)),
            DtnDefaults.defaultSystemTrust(),
            IDtnAi.DtnRequest({
                call: abi.encode(prompt_lines, width, height),
                extraParams: "",
                calltype: IDtnAi.CallType.IPFS, // Use IPFS for image data
                feePerByteReq: 0.002 * 10**18, // Higher fee for image models
                feePerByteRes: 0.002 * 10**18,
                totalFeePerRes: 2 * 10**18
            }),
            IDtnAi.CallBack(
                this.onImageSuccess.selector,
                this.onImageError.selector,
                address(this)
            ),
            msg.sender,
            msg.value
        );
        
        // Store request information
        imageRequests[requestId] = ImageRequest({
            prompt: prompt,
            width: width,
            height: height,
            model: model,
            completed: false,
            ipfsCid: "",
            error: ""
        });
        
        requestHistory.push(requestId);
        
        emit ImageRequested(requestId, prompt, width, height);
    }
    
    // Generate multiple images in batch
    function generateImageBatch(
        string[] memory prompts,
        uint64 width,
        uint64 height,
        string memory model
    ) public payable {
        require(prompts.length > 0 && prompts.length <= 5, "Batch size must be 1-5");
        require(msg.value >= prompts.length * 0.2 ether, "Insufficient payment for batch");
        
        for (uint i = 0; i < prompts.length; i++) {
            generateImageWithParams(prompts[i], width, height, model);
        }
    }
    
    // Generate image variations
    function generateImageVariation(
        string memory basePrompt,
        string memory variation,
        uint64 width,
        uint64 height
    ) public payable {
        string memory fullPrompt = string(abi.encodePacked(
            basePrompt, 
            " with variation: ", 
            variation
        ));
        
        generateImageWithParams(fullPrompt, width, height, defaultModel);
    }
    
    // Session management
    function restartSession() public {
        if (sessionId != 0) {
            ai.closeUserSession(sessionId);
        }
        uint amount = IERC20(ai.feeToken()).balanceOf(address(this));
        require(amount > 0, "Not enough tokens to start a session");
        IERC20(ai.feeToken()).safeTransfer(ai.feeTarget(), amount);
        sessionId = ai.startUserSession();
    }
    
    // Success callback for image generation
    function onImageSuccess(bytes32 requestId) external onlyDtn {
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
            ai.fetchResponse(requestId);
        
        require(status == IDtnAi.ResponseStatus.SUCCESS, "Request not successful");
        
        // Decode IPFS CID
        string memory ipfsCid = abi.decode(response, (string));
        
        // Update request information
        ImageRequest storage request = imageRequests[requestId];
        request.completed = true;
        request.ipfsCid = ipfsCid;
        
        emit ImageGenerated(requestId, ipfsCid, request.prompt);
    }
    
    // Error callback for image generation
    function onImageError(bytes32 requestId) external onlyDtn {
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
            ai.fetchResponse(requestId);
        
        // Update request information
        ImageRequest storage request = imageRequests[requestId];
        request.completed = true;
        request.error = message;
        
        emit ImageError(requestId, message);
    }
    
    // Get request information
    function getRequest(bytes32 requestId) public view returns (ImageRequest memory) {
        return imageRequests[requestId];
    }
    
    // Get all requests for an address
    function getRequestsByAddress(address user) public view returns (bytes32[] memory) {
        // This is a simplified implementation
        // In a real contract, you might want to track requests by user
        return requestHistory;
    }
    
    // Update default parameters
    function updateDefaults(uint64 width, uint64 height, string memory model) public {
        require(width >= 256 && width <= 1024, "Invalid width");
        require(height >= 256 && height <= 1024, "Invalid height");
        require(width % 64 == 0, "Width must be divisible by 64");
        require(height % 64 == 0, "Height must be divisible by 64");
        
        defaultWidth = width;
        defaultHeight = height;
        defaultModel = model;
    }
    
    // Get IPFS URL for an image
    function getImageUrl(bytes32 requestId) public view returns (string memory) {
        ImageRequest memory request = imageRequests[requestId];
        require(request.completed && bytes(request.ipfsCid).length > 0, "Image not available");
        
        return string(abi.encodePacked("https://ipfs.io/ipfs/", request.ipfsCid));
    }
}
```

## Key Features Explained

### 1. Image-Specific Parameters

```solidity
struct ImageRequest {
    string prompt;
    uint64 width;
    uint64 height;
    string model;
    bool completed;
    string ipfsCid;
    string error;
}
```

- **Width and Height**: Image dimensions (must be divisible by 64)
- **Model**: AI model for image generation (e.g., "dall-e", "stable-diffusion")
- **IPFS CID**: Content identifier for the generated image
- **Completion Status**: Tracks whether the request is complete

### 2. Parameter Validation

```solidity
require(width >= 256 && width <= 1024, "Width must be between 256 and 1024");
require(height >= 256 && height <= 1024, "Height must be between 256 and 1024");
require(width % 64 == 0, "Width must be divisible by 64");
require(height % 64 == 0, "Height must be divisible by 64");
```

- **Size Limits**: Most image models have size constraints
- **Divisibility**: Many models require dimensions divisible by 64
- **Prompt Validation**: Ensures non-empty prompts

### 3. IPFS Integration

```solidity
calltype: IDtnAi.CallType.IPFS, // Use IPFS for image data
```

- **Large Data**: Images are stored on IPFS to save gas
- **CID Retrieval**: Get IPFS content identifier from response
- **URL Generation**: Convert CID to accessible URL

### 4. Higher Fees for Images

```solidity
feePerByteReq: 0.002 * 10**18, // Higher fee for image models
feePerByteRes: 0.002 * 10**18,
totalFeePerRes: 2 * 10**18
```

- **Image Models**: Typically cost more than text models
- **Data Size**: Images require more processing and storage
- **Quality**: Higher fees ensure better quality results

## Usage Examples

### Deploying the Contract

```javascript
const { ethers } = require("hardhat");

async function deploy() {
    const aiAddress = "0x..."; // DTN AI contract address
    
    const ImageGenerationExample = await ethers.getContractFactory("ImageGenerationExample");
    const contract = await ImageGenerationExample.deploy(aiAddress);
    
    await contract.deployed();
    console.log("Image generation contract deployed to:", contract.address);
}
```

### Basic Image Generation

```javascript
// Generate a simple image
const prompt = "A beautiful sunset over mountains";
const tx = await contract.generateImage(prompt, {
    value: ethers.utils.parseEther("0.2")
});

await tx.wait();
console.log("Image generation request submitted!");
```

### Custom Parameters

```javascript
// Generate image with custom parameters
const prompt = "A futuristic city skyline";
const width = 1024;
const height = 512;
const model = "dall-e";

const tx = await contract.generateImageWithParams(
    prompt, 
    width, 
    height, 
    model, 
    { value: ethers.utils.parseEther("0.3") }
);

await tx.wait();
console.log("Custom image request submitted!");
```

### Batch Generation

```javascript
// Generate multiple images
const prompts = [
    "A cat sitting on a chair",
    "A dog running in a park",
    "A bird flying in the sky"
];

const tx = await contract.generateImageBatch(
    prompts,
    512,
    512,
    "dall-e",
    { value: ethers.utils.parseEther("0.6") }
);

await tx.wait();
console.log("Batch image generation submitted!");
```

### Checking Results

```javascript
// Get the latest request ID
const requestHistory = await contract.requestHistory();
const latestRequestId = requestHistory[requestHistory.length - 1];

// Check request status
const request = await contract.getRequest(latestRequestId);
console.log("Request completed:", request.completed);
console.log("IPFS CID:", request.ipfsCid);
console.log("Error:", request.error);

// Get image URL
if (request.completed && request.ipfsCid) {
    const imageUrl = await contract.getImageUrl(latestRequestId);
    console.log("Image URL:", imageUrl);
}
```

## Advanced Features

### Image Variations

```javascript
// Generate variations of a base image
const basePrompt = "A portrait of a woman";
const variation = "in Renaissance style";

const tx = await contract.generateImageVariation(
    basePrompt,
    variation,
    512,
    512,
    { value: ethers.utils.parseEther("0.2") }
);

await tx.wait();
```

### Parameter Updates

```javascript
// Update default parameters
const tx = await contract.updateDefaults(1024, 1024, "stable-diffusion");
await tx.wait();
console.log("Default parameters updated!");
```

## Best Practices

### 1. Parameter Validation

- Always validate image dimensions
- Check prompt length and content
- Ensure model compatibility

### 2. Gas Management

- Use IPFS for large image data
- Include sufficient gas for callbacks
- Consider batch operations for efficiency

### 3. Error Handling

- Handle image generation failures
- Provide meaningful error messages
- Implement retry mechanisms

### 4. User Experience

- Provide default parameters
- Support batch operations
- Generate accessible URLs

## Common Issues

### "Invalid dimensions" Error

**Cause**: Image dimensions don't meet model requirements
**Solution**: Use dimensions divisible by 64 and within valid ranges

### "Insufficient fee" Error

**Cause**: Fee too low for image generation
**Solution**: Increase fee or use a different model

### "IPFS CID not found" Error

**Cause**: Image generation failed or response corrupted
**Solution**: Check error callback and retry request

## Next Steps

- [Session Management Example](session-management.md) - Advanced session handling
- [Error Handling](../advanced/error-handling.md) - Sophisticated error handling
- [Custom Routing](../advanced/custom-routing.md) - Advanced routing techniques
- [API Reference](../api/interfaces.md) - Complete interface documentation 