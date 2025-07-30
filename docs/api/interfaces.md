# Contract Interfaces

This section provides comprehensive documentation for all interfaces, structs, and enums used in the DTN SDK.

## IDtnAi Interface

The main interface that defines all AI-related functions and data structures.

### Core Functions

#### request

```solidity
function request(
    uint256 sessionId,
    bytes32 modelId,
    bytes32[] memory routing,
    DtnRequest memory request,
    CallBack memory callback,
    address payable user,
    uint256 gasLimit
) external payable returns (bytes32 requestId);
```

**Parameters**:
- `sessionId`: The session ID for payment management
- `modelId`: Hash of the AI model name
- `routing`: Array of node IDs for routing
- `request`: The AI request structure
- `callback`: Callback configuration
- `user`: Address of the requesting user
- `gasLimit`: Gas limit for the request

**Returns**: `bytes32` - The unique request ID

**Description**: Makes an AI request to the DTN network.

#### fetchResponse

```solidity
function fetchResponse(bytes32 requestId) external view returns (
    ResponseStatus status,
    string memory message,
    bytes memory response
);
```

**Parameters**:
- `requestId`: The request ID to fetch response for

**Returns**:
- `status`: Response status (PENDING, SUCCESS, FAILED, TIMEOUT)
- `message`: Status message or error description
- `response`: The actual response data (encoded)

**Description**: Fetches the response for a completed request.

#### startUserSession

```solidity
function startUserSession() external returns (uint256 sessionId);
```

**Returns**: `uint256` - The session ID

**Description**: Starts a new user session for AI requests.

#### closeUserSession

```solidity
function closeUserSession(uint256 sessionId) external;
```

**Parameters**:
- `sessionId`: The session ID to close

**Description**: Closes a user session and refunds unused funds.

#### feeToken

```solidity
function feeToken() external view returns (address);
```

**Returns**: `address` - The fee token contract address (USDT)

**Description**: Returns the address of the fee token used for payments.

#### feeTarget

```solidity
function feeTarget() external view returns (address);
```

**Returns**: `address` - The fee target address

**Description**: Returns the address where fee tokens should be sent.

## Data Structures

### DtnRequest Struct

```solidity
struct DtnRequest {
    bytes call;           // Encoded call data (prompt, parameters, etc.)
    bytes extraParams;    // Additional parameters for the request
    CallType calltype;    // Type of call (DIRECT or IPFS)
    uint256 feePerByteReq; // Fee per byte for request
    uint256 feePerByteRes; // Fee per byte for response
    uint256 totalFeePerRes; // Total fee for response
}
```

**Fields**:
- `call`: The main request data, typically encoded prompt lines
- `extraParams`: Additional parameters for complex requests
- `calltype`: Whether to use direct call or IPFS storage
- `feePerByteReq`: Cost per byte for request processing
- `feePerByteRes`: Cost per byte for response processing
- `totalFeePerRes`: Maximum total fee for the response

### CallBack Struct

```solidity
struct CallBack {
    bytes4 successSelector; // Function selector for success callback
    bytes4 errorSelector;   // Function selector for error callback
    address contractAddress; // Contract to call callbacks on
}
```

**Fields**:
- `successSelector`: Function selector for successful response callback
- `errorSelector`: Function selector for error callback
- `contractAddress`: Address of the contract implementing callbacks

## Enums

### ResponseStatus

```solidity
enum ResponseStatus {
    PENDING,  // Request is still being processed
    SUCCESS,  // Request completed successfully
    FAILED,   // Request failed
    TIMEOUT   // Request timed out
}
```

**Values**:
- `PENDING`: Request is still being processed by the network
- `SUCCESS`: Request completed successfully and response is available
- `FAILED`: Request failed due to an error
- `TIMEOUT`: Request timed out and was not completed

### CallType

```solidity
enum CallType {
    DIRECT, // Direct call with response in callback
    IPFS    // IPFS call with CID in callback
}
```

**Values**:
- `DIRECT`: Response data is returned directly in the callback
- `IPFS`: Response data is stored on IPFS, CID is returned in callback

## Usage Examples

### Creating a Request

```solidity
// Create prompt lines
string[] memory prompt_lines = new string[](2);
prompt_lines[0] = "System: You are a helpful assistant.";
prompt_lines[1] = "User: What is blockchain?";

// Create the request structure
IDtnAi.DtnRequest memory request = IDtnAi.DtnRequest({
    call: abi.encode(prompt_lines),
    extraParams: "",
    calltype: IDtnAi.CallType.DIRECT,
    feePerByteReq: 0.001 * 10**18,
    feePerByteRes: 0.001 * 10**18,
    totalFeePerRes: 1 * 10**18
});

// Create callback structure
IDtnAi.CallBack memory callback = IDtnAi.CallBack({
    successSelector: this.onSuccess.selector,
    errorSelector: this.onError.selector,
    contractAddress: address(this)
});

// Make the request
bytes32 requestId = ai.request{value: msg.value}(
    sessionId,
    keccak256(abi.encodePacked("gpt-3.5-turbo")),
    routing,
    request,
    callback,
    msg.sender,
    msg.value
);
```

### Handling Responses

```solidity
function onSuccess(bytes32 requestId) external onlyDtn {
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    if (status == IDtnAi.ResponseStatus.SUCCESS) {
        // Decode the response based on expected type
        string memory result = abi.decode(response, (string));
        processSuccess(requestId, result);
    } else {
        // Handle unexpected status
        processError(requestId, message);
    }
}

function onError(bytes32 requestId) external onlyDtn {
    (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
        ai.fetchResponse(requestId);
    
    processError(requestId, message);
}
```

### Session Management

```solidity
// Start a new session
uint256 sessionId = ai.startUserSession();

// Use session for requests
bytes32 requestId = ai.request{value: msg.value}(
    sessionId,
    modelId,
    routing,
    request,
    callback,
    msg.sender,
    msg.value
);

// Close session when done
ai.closeUserSession(sessionId);
```

## Error Handling

### Common Error Scenarios

1. **Invalid Session**: Session doesn't exist or belongs to different user
2. **Insufficient Funds**: Session doesn't have enough balance
3. **Invalid Model**: Model ID doesn't exist on the network
4. **Invalid Routing**: No valid nodes available for routing
5. **Callback Failure**: Callback function doesn't exist or fails

### Error Response Format

```solidity
// Error response structure
struct ErrorResponse {
    string errorCode;    // Machine-readable error code
    string message;      // Human-readable error message
    bytes details;       // Additional error details
}
```

### Error Codes

- `SESSION_NOT_FOUND`: Session ID is invalid
- `INSUFFICIENT_BALANCE`: Session has insufficient funds
- `MODEL_NOT_SUPPORTED`: Requested model is not available
- `INVALID_ROUTING`: No valid nodes for routing
- `CALLBACK_FAILED`: Callback execution failed
- `REQUEST_TIMEOUT`: Request exceeded timeout limit

## Best Practices

### 1. Request Structure

- **Use Appropriate Call Type**: Use IPFS for large data, DIRECT for small responses
- **Set Reasonable Fees**: Too low fees may cause requests to be ignored
- **Validate Parameters**: Ensure all parameters are valid before making requests
- **Handle Callbacks**: Always implement both success and error callbacks

### 2. Session Management

- **Reuse Sessions**: Don't create new sessions for each request
- **Monitor Balance**: Keep track of session balances
- **Close Sessions**: Close sessions when done to get refunds
- **Handle Errors**: Implement proper error handling for session operations

### 3. Response Processing

- **Check Status**: Always check response status before processing
- **Validate Data**: Validate response data before using it
- **Handle Timeouts**: Implement timeout handling for long-running requests
- **Log Events**: Log important events for debugging

### 4. Gas Optimization

- **Estimate Gas**: Estimate gas requirements accurately
- **Use Events**: Use events instead of storage for non-critical data
- **Batch Operations**: Batch related operations when possible
- **Optimize Callbacks**: Keep callbacks gas-efficient

## Security Considerations

### 1. Access Control

- **onlyDtn Modifier**: Always use `onlyDtn` modifier for callbacks
- **Session Ownership**: Verify session ownership before use
- **Input Validation**: Validate all inputs before processing

### 2. Data Validation

- **Response Validation**: Validate response data before use
- **Parameter Validation**: Validate all request parameters
- **Error Handling**: Handle all possible error conditions

### 3. Reentrancy Protection

- **Use ReentrancyGuard**: Protect against reentrancy attacks
- **State Management**: Update state before external calls
- **Callback Safety**: Ensure callbacks are safe from reentrancy

## Next Steps

- [Functions](functions.md) - Detailed function documentation
- [Events](events.md) - Event definitions and usage
- [Advanced Topics](../advanced/custom-routing.md) - Advanced usage patterns
- [Examples](../examples/basic-ai-call.md) - Practical implementation examples 