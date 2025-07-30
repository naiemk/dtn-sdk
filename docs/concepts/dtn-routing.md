# DTN Routing

DTN Routing is a flexible system that allows you to specify your trust expectations when making AI requests. The routing mechanism determines which nodes will process your requests based on your trust requirements.

## What is DTN Routing?

DTN Routing is about choosing which nodes you trust to handle your AI requests. The system is very flexible and allows you to:

- Use the default DTN network trust namespace
- Specify your own proprietary nodes
- Create custom routing configurations
- Balance trust vs. cost vs. performance

## Trust Namespaces

### Default DTN Network

The most common routing option uses the default DTN network trust namespace:

```solidity
// Use the default system trust (staked nodes)
bytes32[] memory routing = DtnDefaults.defaultSystemTrust();
```

This routes requests to a set of staked nodes that are part of the DTN network.

### Custom Node Routing

For testing or custom use cases, you can route directly to specific nodes:

```solidity
// Route to a specific node
bytes32 nodeId = keccak256(abi.encodePacked("node.mynode.node1"));
bytes32[] memory routing = DtnDefaults.defaultCustomNodesValidatedAny(
    DtnDefaults.singleArray(nodeId)
);
```

### Mixed Routing

You can combine different routing strategies:

```solidity
// Use both system trust and custom nodes
bytes32[] memory customNodes = new bytes32[](2);
customNodes[0] = keccak256(abi.encodePacked("node.mynode.node1"));
customNodes[1] = keccak256(abi.encodePacked("node.mynode.node2"));

bytes32[] memory routing = DtnDefaults.defaultCustomNodesValidatedAny(customNodes);
```

## Routing Functions

### Default System Trust

```solidity
function defaultSystemTrust() internal pure returns (bytes32[] memory)
```

Returns the default DTN network trust namespace. This is the most common choice for production applications.

### Custom Nodes Validated Any

```solidity
function defaultCustomNodesValidatedAny(bytes32[] memory nodes) internal pure returns (bytes32[] memory)
```

Creates a routing configuration that accepts responses from any of the specified nodes.

### Custom Nodes Validated All

```solidity
function defaultCustomNodesValidatedAll(bytes32[] memory nodes) internal pure returns (bytes32[] memory)
```

Creates a routing configuration that requires responses from all specified nodes (for consensus).

### Single Array Helper

```solidity
function singleArray(bytes32 node) internal pure returns (bytes32[] memory)
```

Helper function to create an array with a single node ID.

## Routing Examples

### Basic System Trust

```solidity
function makeRequestWithSystemTrust(string memory prompt) public payable {
    string[] memory prompt_lines = new string[](1);
    prompt_lines[0] = prompt;
    
    requestId = ai.request{value: msg.value}(
        sessionId,
        modelId,
        DtnDefaults.defaultSystemTrust(), // Use default DTN network
        IDtnAi.DtnRequest({
            call: abi.encode(prompt_lines),
            extraParams: "",
            calltype: IDtnAi.CallType.DIRECT,
            feePerByteReq: 0.001 * 10**18,
            feePerByteRes: 0.001 * 10**18,
            totalFeePerRes: 1 * 10**18
        }),
        callback,
        msg.sender,
        msg.value
    );
}
```

### Custom Node Routing

```solidity
function makeRequestWithCustomNode(string memory prompt, string memory nodeName) public payable {
    string[] memory prompt_lines = new string[](1);
    prompt_lines[0] = prompt;
    
    // Route to a specific custom node
    bytes32 nodeId = keccak256(abi.encodePacked(nodeName));
    bytes32[] memory routing = DtnDefaults.defaultCustomNodesValidatedAny(
        DtnDefaults.singleArray(nodeId)
    );
    
    requestId = ai.request{value: msg.value}(
        sessionId,
        modelId,
        routing,
        IDtnAi.DtnRequest({
            call: abi.encode(prompt_lines),
            extraParams: "",
            calltype: IDtnAi.CallType.DIRECT,
            feePerByteReq: 0.001 * 10**18,
            feePerByteRes: 0.001 * 10**18,
            totalFeePerRes: 1 * 10**18
        }),
        callback,
        msg.sender,
        msg.value
    );
}
```

### Multi-Node Consensus

```solidity
function makeRequestWithConsensus(string memory prompt) public payable {
    string[] memory prompt_lines = new string[](1);
    prompt_lines[0] = prompt;
    
    // Require consensus from multiple nodes
    bytes32[] memory nodes = new bytes32[](3);
    nodes[0] = keccak256(abi.encodePacked("node.trusted.node1"));
    nodes[1] = keccak256(abi.encodePacked("node.trusted.node2"));
    nodes[2] = keccak256(abi.encodePacked("node.trusted.node3"));
    
    bytes32[] memory routing = DtnDefaults.defaultCustomNodesValidatedAll(nodes);
    
    requestId = ai.request{value: msg.value}(
        sessionId,
        modelId,
        routing,
        IDtnAi.DtnRequest({
            call: abi.encode(prompt_lines),
            extraParams: "",
            calltype: IDtnAi.CallType.DIRECT,
            feePerByteReq: 0.001 * 10**18,
            feePerByteRes: 0.001 * 10**18,
            totalFeePerRes: 1 * 10**18
        }),
        callback,
        msg.sender,
        msg.value
    );
}
```

## Routing Considerations

### Trust vs. Cost

- **System Trust**: Lower cost, higher trust (staked nodes)
- **Custom Nodes**: Variable cost, depends on node pricing
- **Consensus**: Higher cost, maximum trust (multiple validations)

### Performance vs. Reliability

- **Single Node**: Fastest response, single point of failure
- **Multiple Nodes**: Slower response, higher reliability
- **Consensus**: Slowest response, maximum reliability

### Use Case Guidelines

#### Development and Testing

```solidity
// Use direct node routing for testing
bytes32[] memory routing = DtnDefaults.defaultCustomNodesValidatedAny(
    DtnDefaults.singleArray(keccak256(abi.encodePacked("node.test.node1")))
);
```

#### Production Applications

```solidity
// Use system trust for production
bytes32[] memory routing = DtnDefaults.defaultSystemTrust();
```

#### High-Security Applications

```solidity
// Use consensus for critical applications
bytes32[] memory routing = DtnDefaults.defaultCustomNodesValidatedAll(trustedNodes);
```

## Node Discovery

### Finding Available Nodes

You can discover available nodes through:

1. **DTN Explorer**: Browse available nodes and their capabilities
2. **Network Queries**: Query the network for node information
3. **Node Registries**: Check official node registries

### Node Information

Each node provides information about:

- **Capabilities**: What models and APIs it supports
- **Performance**: Response times and reliability metrics
- **Pricing**: Fee structure and cost per request
- **Trust Score**: Reputation and validation history

## Best Practices

### 1. Choose Appropriate Routing

- **Development**: Use custom nodes for testing
- **Production**: Use system trust for reliability
- **Critical Apps**: Use consensus for maximum trust

### 2. Monitor Performance

- Track response times for different routing configurations
- Monitor success rates and error patterns
- Adjust routing based on performance metrics

### 3. Cost Optimization

- Balance trust requirements with cost constraints
- Use system trust for most applications
- Reserve custom routing for specific needs

## Common Issues

### "No nodes available" Error

**Cause**: Specified nodes are not available or don't support the requested model
**Solution**: Use system trust or verify node availability

### "Node validation failed" Error

**Cause**: Custom nodes failed to validate the request
**Solution**: Check node capabilities and request parameters

### "Consensus timeout" Error

**Cause**: Not all required nodes responded within timeout
**Solution**: Reduce consensus requirements or increase timeout

## Next Steps

- [DTN Callbacks](dtn-callbacks.md) - Learn about handling responses
- [Custom Routing Example](../advanced/custom-routing.md) - Advanced routing techniques
- [Basic AI Call Example](../examples/basic-ai-call.md) - Practical routing usage 