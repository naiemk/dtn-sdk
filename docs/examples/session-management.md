# Session Management Example

This example demonstrates advanced session management techniques for the DTN SDK, including session pooling, automatic renewal, and efficient resource management.

## Advanced Session Management Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@deeptrust/contracts/with-dtn-ai.sol";
import "@deeptrust/contracts/dtn-defaults.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AdvancedSessionManager is WithDtnAi, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Events
    event SessionCreated(uint256 sessionId, address owner, uint256 balance);
    event SessionClosed(uint256 sessionId, address owner, uint256 refund);
    event SessionRenewed(uint256 sessionId, uint256 newBalance);
    event SessionPooled(uint256 sessionId, address user);
    
    // Session information
    struct SessionInfo {
        uint256 sessionId;
        address owner;
        uint256 balance;
        uint256 lastUsed;
        bool active;
        uint256 requestCount;
    }
    
    // State variables
    mapping(uint256 => SessionInfo) public sessions;
    mapping(address => uint256[]) public userSessions;
    uint256[] public activeSessions;
    
    // Configuration
    uint256 public minSessionBalance = 10 * 10**18; // 10 USDT minimum
    uint256 public maxSessionAge = 24 hours;
    uint256 public sessionPoolSize = 5;
    
    // Session pool for efficient reuse
    uint256[] public sessionPool;
    mapping(uint256 => bool) public isPooled;
    
    constructor(address ai) {
        setAi(ai);
    }
    
    // Create a new session with specified balance
    function createSession(uint256 balance) public nonReentrant {
        require(balance >= minSessionBalance, "Balance too low");
        
        // Transfer tokens to fee target
        IERC20(ai.feeToken()).safeTransferFrom(msg.sender, ai.feeTarget(), balance);
        
        // Start the session
        uint256 sessionId = ai.startUserSession();
        
        // Store session information
        sessions[sessionId] = SessionInfo({
            sessionId: sessionId,
            owner: msg.sender,
            balance: balance,
            lastUsed: block.timestamp,
            active: true,
            requestCount: 0
        });
        
        userSessions[msg.sender].push(sessionId);
        activeSessions.push(sessionId);
        
        emit SessionCreated(sessionId, msg.sender, balance);
    }
    
    // Get or create a session for the caller
    function getOrCreateSession() public returns (uint256) {
        // Check if user has an active session
        uint256[] memory userSess = userSessions[msg.sender];
        for (uint i = 0; i < userSess.length; i++) {
            SessionInfo storage session = sessions[userSess[i]];
            if (session.active && session.balance > 0) {
                session.lastUsed = block.timestamp;
                session.requestCount++;
                return session.sessionId;
            }
        }
        
        // Create new session with minimum balance
        createSession(minSessionBalance);
        return userSessions[msg.sender][userSessions[msg.sender].length - 1];
    }
    
    // Make AI request with automatic session management
    function makeAIRequest(
        string memory prompt,
        string memory model,
        bytes32[] memory routing
    ) public payable returns (bytes32) {
        uint256 sessionId = getOrCreateSession();
        
        string[] memory prompt_lines = new string[](1);
        prompt_lines[0] = prompt;
        
        bytes32 requestId = ai.request{value: msg.value}(
            sessionId,
            keccak256(abi.encodePacked(model)),
            routing,
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
        
        return requestId;
    }
    
    // Close a specific session
    function closeSession(uint256 sessionId) public nonReentrant {
        SessionInfo storage session = sessions[sessionId];
        require(session.owner == msg.sender, "Not session owner");
        require(session.active, "Session not active");
        
        // Close the session
        ai.closeUserSession(sessionId);
        
        // Mark as inactive
        session.active = false;
        
        // Remove from active sessions
        removeFromArray(activeSessions, sessionId);
        
        // Remove from pool if pooled
        if (isPooled[sessionId]) {
            removeFromArray(sessionPool, sessionId);
            isPooled[sessionId] = false;
        }
        
        emit SessionClosed(sessionId, msg.sender, session.balance);
    }
    
    // Close all sessions for a user
    function closeAllSessions() public {
        uint256[] memory userSess = userSessions[msg.sender];
        for (uint i = 0; i < userSess.length; i++) {
            SessionInfo storage session = sessions[userSess[i]];
            if (session.active) {
                closeSession(session.sessionId);
            }
        }
    }
    
    // Renew session with additional balance
    function renewSession(uint256 sessionId, uint256 additionalBalance) public nonReentrant {
        SessionInfo storage session = sessions[sessionId];
        require(session.owner == msg.sender, "Not session owner");
        require(session.active, "Session not active");
        
        // Transfer additional tokens
        IERC20(ai.feeToken()).safeTransferFrom(msg.sender, ai.feeTarget(), additionalBalance);
        
        // Update session balance
        session.balance += additionalBalance;
        session.lastUsed = block.timestamp;
        
        emit SessionRenewed(sessionId, session.balance);
    }
    
    // Add session to pool for reuse
    function addToPool(uint256 sessionId) public {
        SessionInfo storage session = sessions[sessionId];
        require(session.owner == msg.sender, "Not session owner");
        require(session.active, "Session not active");
        require(!isPooled[sessionId], "Already pooled");
        require(sessionPool.length < sessionPoolSize, "Pool full");
        
        sessionPool.push(sessionId);
        isPooled[sessionId] = true;
        
        emit SessionPooled(sessionId, msg.sender);
    }
    
    // Get session from pool
    function getFromPool() public returns (uint256) {
        require(sessionPool.length > 0, "Pool empty");
        
        uint256 sessionId = sessionPool[sessionPool.length - 1];
        sessionPool.pop();
        isPooled[sessionId] = false;
        
        SessionInfo storage session = sessions[sessionId];
        session.lastUsed = block.timestamp;
        session.requestCount++;
        
        return sessionId;
    }
    
    // Clean up old sessions
    function cleanupOldSessions() public {
        for (uint i = activeSessions.length; i > 0; i--) {
            uint256 sessionId = activeSessions[i - 1];
            SessionInfo storage session = sessions[sessionId];
            
            if (block.timestamp - session.lastUsed > maxSessionAge) {
                // Auto-close old sessions
                ai.closeUserSession(sessionId);
                session.active = false;
                
                // Remove from arrays
                removeFromArray(activeSessions, sessionId);
                if (isPooled[sessionId]) {
                    removeFromArray(sessionPool, sessionId);
                    isPooled[sessionId] = false;
                }
                
                emit SessionClosed(sessionId, session.owner, session.balance);
            }
        }
    }
    
    // Get session statistics
    function getSessionStats(uint256 sessionId) public view returns (
        address owner,
        uint256 balance,
        uint256 lastUsed,
        bool active,
        uint256 requestCount
    ) {
        SessionInfo storage session = sessions[sessionId];
        return (
            session.owner,
            session.balance,
            session.lastUsed,
            session.active,
            session.requestCount
        );
    }
    
    // Get user session count
    function getUserSessionCount(address user) public view returns (uint256) {
        return userSessions[user].length;
    }
    
    // Get pool status
    function getPoolStatus() public view returns (uint256 poolSize, uint256 maxSize) {
        return (sessionPool.length, sessionPoolSize);
    }
    
    // Update configuration
    function updateConfig(
        uint256 _minSessionBalance,
        uint256 _maxSessionAge,
        uint256 _sessionPoolSize
    ) public {
        minSessionBalance = _minSessionBalance;
        maxSessionAge = _maxSessionAge;
        sessionPoolSize = _sessionPoolSize;
    }
    
    // Callbacks
    function onSuccess(bytes32 requestId) external onlyDtn {
        // Handle successful response
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
            ai.fetchResponse(requestId);
        
        // Process response as needed
        emit AIResponseReceived(requestId, status, message);
    }
    
    function onError(bytes32 requestId) external onlyDtn {
        // Handle error response
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = 
            ai.fetchResponse(requestId);
        
        emit AIRequestFailed(requestId, message);
    }
    
    // Utility function to remove element from array
    function removeFromArray(uint256[] storage arr, uint256 element) internal {
        for (uint i = 0; i < arr.length; i++) {
            if (arr[i] == element) {
                arr[i] = arr[arr.length - 1];
                arr.pop();
                break;
            }
        }
    }
    
    // Events for AI responses
    event AIResponseReceived(bytes32 requestId, IDtnAi.ResponseStatus status, string message);
    event AIRequestFailed(bytes32 requestId, string error);
}
```

## Key Features Explained

### 1. Session Information Tracking

```solidity
struct SessionInfo {
    uint256 sessionId;
    address owner;
    uint256 balance;
    uint256 lastUsed;
    bool active;
    uint256 requestCount;
}
```

- **Owner Tracking**: Knows who owns each session
- **Balance Management**: Tracks remaining balance
- **Usage Statistics**: Monitors last usage and request count
- **Active Status**: Tracks whether session is still active

### 2. Automatic Session Management

```solidity
function getOrCreateSession() public returns (uint256)
```

- **Session Reuse**: Automatically reuses existing active sessions
- **Auto-Creation**: Creates new sessions when needed
- **Balance Checking**: Ensures sessions have sufficient balance
- **Usage Tracking**: Updates usage statistics

### 3. Session Pooling

```solidity
function addToPool(uint256 sessionId) public
function getFromPool() public returns (uint256)
```

- **Resource Sharing**: Allows sharing sessions between users
- **Efficiency**: Reduces session creation overhead
- **Pool Management**: Maintains pool size limits
- **Access Control**: Only owners can add sessions to pool

### 4. Session Renewal

```solidity
function renewSession(uint256 sessionId, uint256 additionalBalance) public
```

- **Balance Addition**: Add more funds to existing sessions
- **No Recreation**: Avoids creating new sessions unnecessarily
- **Usage Reset**: Updates last used timestamp
- **Cost Efficiency**: Saves gas on session creation

### 5. Automatic Cleanup

```solidity
function cleanupOldSessions() public
```

- **Age-Based Cleanup**: Removes sessions older than max age
- **Resource Management**: Frees up resources automatically
- **Pool Maintenance**: Cleans up pooled sessions
- **Gas Optimization**: Reduces storage costs

## Usage Examples

### Deploying the Contract

```javascript
const { ethers } = require("hardhat");

async function deploy() {
    const aiAddress = "0x..."; // DTN AI contract address
    
    const AdvancedSessionManager = await ethers.getContractFactory("AdvancedSessionManager");
    const contract = await AdvancedSessionManager.deploy(aiAddress);
    
    await contract.deployed();
    console.log("Session manager deployed to:", contract.address);
}
```

### Creating and Using Sessions

```javascript
// Create a session with initial balance
const initialBalance = ethers.utils.parseUnits("50", 18); // 50 USDT
const usdtAddress = await contract.ai.feeToken();

// Approve tokens first
const usdt = await ethers.getContractAt("IERC20", usdtAddress);
await usdt.approve(contract.address, initialBalance);

// Create session
const tx = await contract.createSession(initialBalance);
await tx.wait();
console.log("Session created!");

// Make AI request (automatically uses existing session)
const prompt = "What is the weather like?";
const model = "gpt-3.5-turbo";
const routing = await contract.DtnDefaults.defaultSystemTrust();

const requestId = await contract.makeAIRequest(prompt, model, routing, {
    value: ethers.utils.parseEther("0.1")
});

console.log("AI request submitted with ID:", requestId);
```

### Session Pooling

```javascript
// Add session to pool for sharing
const sessionId = await contract.getOrCreateSession();
await contract.addToPool(sessionId);
console.log("Session added to pool");

// Get session from pool
const pooledSessionId = await contract.getFromPool();
console.log("Got session from pool:", pooledSessionId);
```

### Session Renewal

```javascript
// Renew session with additional balance
const sessionId = await contract.getOrCreateSession();
const additionalBalance = ethers.utils.parseUnits("25", 18); // 25 USDT

await usdt.approve(contract.address, additionalBalance);
await contract.renewSession(sessionId, additionalBalance);
console.log("Session renewed!");
```

### Session Management

```javascript
// Get session statistics
const sessionId = await contract.getOrCreateSession();
const stats = await contract.getSessionStats(sessionId);
console.log("Session stats:", stats);

// Get user session count
const userSessionCount = await contract.getUserSessionCount(userAddress);
console.log("User has", userSessionCount, "sessions");

// Get pool status
const poolStatus = await contract.getPoolStatus();
console.log("Pool size:", poolStatus.poolSize, "/", poolStatus.maxSize);
```

### Cleanup and Maintenance

```javascript
// Clean up old sessions
await contract.cleanupOldSessions();
console.log("Old sessions cleaned up");

// Close all user sessions
await contract.closeAllSessions();
console.log("All sessions closed");
```

## Advanced Features

### Configuration Management

```javascript
// Update session configuration
const newMinBalance = ethers.utils.parseUnits("20", 18); // 20 USDT minimum
const newMaxAge = 12 * 60 * 60; // 12 hours
const newPoolSize = 10; // 10 sessions in pool

await contract.updateConfig(newMinBalance, newMaxAge, newPoolSize);
console.log("Configuration updated!");
```

### Batch Operations

```javascript
// Make multiple requests efficiently
const prompts = [
    "What is AI?",
    "Explain blockchain",
    "How does DTN work?"
];

for (const prompt of prompts) {
    const requestId = await contract.makeAIRequest(
        prompt, 
        "gpt-3.5-turbo", 
        routing, 
        { value: ethers.utils.parseEther("0.1") }
    );
    console.log("Request submitted:", requestId);
}
```

## Best Practices

### 1. Session Lifecycle Management

- **Create Early**: Create sessions before making requests
- **Reuse Efficiently**: Reuse sessions for multiple requests
- **Monitor Balance**: Keep track of session balances
- **Clean Up**: Close sessions when done

### 2. Pool Management

- **Share Resources**: Use session pooling for efficiency
- **Monitor Pool**: Keep track of pool usage
- **Balance Pool**: Maintain appropriate pool size
- **Access Control**: Ensure proper access controls

### 3. Gas Optimization

- **Batch Operations**: Group related operations
- **Session Reuse**: Avoid creating new sessions unnecessarily
- **Efficient Cleanup**: Clean up old sessions regularly
- **Pool Usage**: Use pooled sessions when available

### 4. Error Handling

- **Session Validation**: Check session status before use
- **Balance Checks**: Ensure sufficient balance
- **Graceful Failures**: Handle session failures gracefully
- **Recovery Mechanisms**: Implement session recovery

## Common Issues

### "Session not found" Error

**Cause**: Using an invalid or closed session
**Solution**: Use `getOrCreateSession()` for automatic management

### "Insufficient balance" Error

**Cause**: Session doesn't have enough funds
**Solution**: Use `renewSession()` to add more balance

### "Pool full" Error

**Cause**: Session pool has reached maximum size
**Solution**: Wait for pool space or increase pool size

### "Session expired" Error

**Cause**: Session has exceeded maximum age
**Solution**: Run `cleanupOldSessions()` and create new session

## Next Steps

- [Error Handling](../advanced/error-handling.md) - Advanced error handling techniques
- [Custom Routing](../advanced/custom-routing.md) - Advanced routing strategies
- [Fee Management](../advanced/fee-management.md) - Sophisticated fee handling
- [API Reference](../api/interfaces.md) - Complete interface documentation 