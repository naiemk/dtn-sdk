# DTN Callbacks

DTN Callbacks are the mechanism for handling responses from AI requests. Every AI request requires two callback functions: one for success and one for failure. Understanding how to implement and use callbacks is essential for building robust AI-powered applications.

## What are DTN Callbacks?

DTN Callbacks are functions that are automatically called by the DTN network when an AI request is completed. They allow your contract to:

- Process successful AI responses
- Handle errors and failures
- Update contract state based on results
- Trigger additional actions

## Callback Structure

Every AI request requires two callbacks:

```solidity
IDtnAi.CallBack(
    this.successCallback.selector,  // Function called on success
    this.errorCallback.selector,    // Function called on failure
    address(this)                   // Contract that owns the callbacks
)
```

## Callback Function Requirements

### Function Signature

All callback functions must follow this exact signature:

```solidity
function myCallback(bytes32 requestId) external onlyDtn
```

### Required Modifier

All callback functions must use the `onlyDtn` modifier to ensure only DTN contracts can call them:

```solidity
function myCallback(bytes32 requestId) external onlyDtn {
    // Your callback logic here
}
```

## Success Callbacks

Success callbacks are called when an AI request completes successfully.

### Basic Success Callback

```solidity
function onSuccess(bytes32 requestId) external onlyDtn {
    // Fetch the response from the AI system
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    // Parse the response based on your expected data type
    string memory result = abi.decode(response, (string));
    
    // Update your contract state
    lastResult = result;
    lastRequestId = requestId;
    
    // Emit an event
    emit AIResponseReceived(requestId, result);
}
```

### Handling Different Response Types

#### Text Responses

```solidity
function onTextSuccess(bytes32 requestId) external onlyDtn {
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    string memory textResult = abi.decode(response, (string));
    textResults[requestId] = textResult;
}
```

#### Image Responses (IPFS)

```solidity
function onImageSuccess(bytes32 requestId) external onlyDtn {
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    string memory ipfsCid = abi.decode(response, (string));
    imageResults[requestId] = ipfsCid;
}
```

#### Structured Data Responses

```solidity
function onStructuredSuccess(bytes32 requestId) external onlyDtn {
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    // Decode structured data
    (uint256 score, string memory analysis) = abi.decode(response, (uint256, string));
    analysisResults[requestId] = Analysis(score, analysis);
}
```

## Error Callbacks

Error callbacks are called when an AI request fails or encounters an error.

### Basic Error Callback

```solidity
function onError(bytes32 requestId) external onlyDtn {
    // Fetch error information
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    // Store error information
    lastError = message;
    lastErrorRequestId = requestId;
    
    // Emit error event
    emit AIRequestFailed(requestId, message);
}
```

### Error Handling Strategies

#### Retry Logic

```solidity
function onErrorWithRetry(bytes32 requestId) external onlyDtn {
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    // Check if we should retry
    if (retryCount[requestId] < maxRetries) {
        retryCount[requestId]++;
        // Retry the request
        retryRequest(requestId);
    } else {
        // Give up after max retries
        failedRequests[requestId] = message;
        emit MaxRetriesExceeded(requestId, message);
    }
}
```

#### Fallback Logic

```solidity
function onErrorWithFallback(bytes32 requestId) external onlyDtn {
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    // Try a different model or approach
    if (bytes(message).length > 0) {
        // Use fallback model
        makeFallbackRequest(requestId);
    }
}
```

## Response Status Handling

The `fetchResponse` function returns a status that indicates the response state:

```solidity
enum ResponseStatus {
    PENDING,    // Request is still being processed
    SUCCESS,    // Request completed successfully
    FAILED,     // Request failed
    TIMEOUT     // Request timed out
}
```

### Status-Based Handling

```solidity
function handleResponse(bytes32 requestId) external onlyDtn {
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    if (status == IDtnAi.ResponseStatus.SUCCESS) {
        // Handle successful response
        string memory result = abi.decode(response, (string));
        processSuccess(requestId, result);
    } else if (status == IDtnAi.ResponseStatus.FAILED) {
        // Handle failure
        processFailure(requestId, message);
    } else if (status == IDtnAi.ResponseStatus.TIMEOUT) {
        // Handle timeout
        processTimeout(requestId);
    }
    // PENDING status means the request is still being processed
}
```

## Gas Considerations

### Gas Requirements

Callbacks must have sufficient gas to execute. The gas sent with the original request must cover:

1. The original request execution
2. The callback execution
3. Any state changes in the callback

### Gas Optimization

```solidity
function gasOptimizedCallback(bytes32 requestId) external onlyDtn {
    // Minimize storage operations
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    // Use events instead of storage when possible
    emit ResponseProcessed(requestId, status, message);
    
    // Only store essential data
    if (status == IDtnAi.ResponseStatus.SUCCESS) {
        essentialData[requestId] = abi.decode(response, (uint256));
    }
}
```

## Security Considerations

### Access Control

Always use the `onlyDtn` modifier to prevent unauthorized access:

```solidity
modifier onlyDtn() {
    require(msg.sender == address(ai), "Only DTN can call this function");
    _;
}
```

### Input Validation

Validate callback parameters:

```solidity
function secureCallback(bytes32 requestId) external onlyDtn {
    require(requestId != bytes32(0), "Invalid request ID");
    
    // Process the response
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    // Validate response data
    require(response.length > 0, "Empty response");
}
```

## Best Practices

### 1. Error Handling

- Always implement both success and error callbacks
- Handle all possible response statuses
- Provide meaningful error messages
- Implement retry logic when appropriate

### 2. State Management

- Update contract state atomically
- Use events for important state changes
- Avoid complex logic in callbacks
- Keep callbacks gas-efficient

### 3. Response Processing

- Validate response data before processing
- Handle different response formats
- Implement fallback mechanisms
- Log important events

### 4. Gas Optimization

- Minimize storage operations in callbacks
- Use events for non-critical data
- Batch operations when possible
- Estimate gas requirements accurately

## Common Issues

### "Insufficient gas" Error

**Cause**: Callback doesn't have enough gas to execute
**Solution**: Include more gas with the original request

### "Only DTN can call" Error

**Cause**: Missing `onlyDtn` modifier or incorrect AI contract address
**Solution**: Ensure proper modifier and contract setup

### "Invalid response format" Error

**Cause**: Trying to decode response with wrong data type
**Solution**: Match decode type with expected response format

### "Callback not found" Error

**Cause**: Incorrect function selector or missing callback function
**Solution**: Verify function exists and selector is correct

## Next Steps

- [Basic AI Call Example](../examples/basic-ai-call.md) - See callbacks in action
- [Error Handling](../advanced/error-handling.md) - Advanced error handling techniques
- [API Reference](../api/interfaces.md) - Complete callback interface documentation 