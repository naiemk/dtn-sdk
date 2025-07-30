# AI Models and APIs

The Deep Trust Network supports multiple AI models, each with different capabilities, APIs, and pricing structures. Understanding how to select and use the right model is crucial for building effective AI-powered applications.

## Available Models

The DTN network supports various AI models, each optimized for different use cases:

### Text Models

- **GPT-3.5-turbo**: General-purpose text generation and conversation
- **GPT-4**: Advanced reasoning and complex tasks
- **Claude**: Anthropic's conversational AI
- **Llama**: Open-source language models

### Image Models

- **DALL-E**: Text-to-image generation
- **Stable Diffusion**: Open-source image generation
- **Midjourney**: Artistic image creation

### Specialized Models

- **Code Models**: Programming and code generation
- **Analysis Models**: Data analysis and insights
- **Translation Models**: Multi-language support

## Model Selection

### Factors to Consider

1. **Use Case**: What type of task are you performing?
2. **Cost**: Different models have different pricing per byte
3. **Performance**: Speed vs. quality trade-offs
4. **API Support**: What APIs does the model support?

### Model ID Format

Models are identified by their hash in the DTN system:

```solidity
bytes32 modelId = keccak256(abi.encodePacked("gpt-3.5-turbo"));
```

## Supported APIs

Each model may support different APIs depending on its capabilities:

### Text APIs

- **Completion**: Generate text based on a prompt
- **Chat**: Multi-turn conversations
- **Embedding**: Convert text to vector representations

### Image APIs

- **Generation**: Create images from text descriptions
- **Variation**: Create variations of existing images
- **Editing**: Modify existing images

### Code APIs

- **Generation**: Generate code from descriptions
- **Completion**: Complete partial code
- **Review**: Analyze and suggest improvements

## Using Models in Your Contract

### Basic Model Usage

```solidity
function callTextModel(string memory prompt) public payable {
    string[] memory prompt_lines = new string[](1);
    prompt_lines[0] = prompt;
    
    // Use GPT-3.5-turbo for text generation
    bytes32 modelId = keccak256(abi.encodePacked("gpt-3.5-turbo"));
    
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

### Image Model Usage

```solidity
function generateImage(
    string memory description,
    uint64 width,
    uint64 height
) public payable {
    string[] memory prompt_lines = new string[](1);
    prompt_lines[0] = description;
    
    // Use DALL-E for image generation
    bytes32 modelId = keccak256(abi.encodePacked("dall-e"));
    
    requestId = ai.request{value: msg.value}(
        sessionId,
        modelId,
        DtnDefaults.defaultSystemTrust(),
        IDtnAi.DtnRequest({
            call: abi.encode(prompt_lines, width, height),
            extraParams: "",
            calltype: IDtnAi.CallType.IPFS, // Use IPFS for image data
            feePerByteReq: 0.002 * 10**18, // Higher fee for image models
            feePerByteRes: 0.002 * 10**18,
            totalFeePerRes: 2 * 10**18
        }),
        callback,
        msg.sender,
        msg.value
    );
}
```

## Fee Structure

### Fee Components

Each model has different fee structures:

1. **Request Fee** (`feePerByteReq`): Cost per byte of input data
2. **Response Fee** (`feePerByteRes`): Cost per byte of output data
3. **Total Response Fee** (`totalFeePerRes`): Maximum fee for the response

### Fee Guidelines

```solidity
// Text models (lower fees)
uint256 textFeePerByte = 0.001 * 10**18;
uint256 textTotalFee = 1 * 10**18;

// Image models (higher fees)
uint256 imageFeePerByte = 0.002 * 10**18;
uint256 imageTotalFee = 2 * 10**18;

// Code models (medium fees)
uint256 codeFeePerByte = 0.0015 * 10**18;
uint256 codeTotalFee = 1.5 * 10**18;
```

### Fee Optimization

1. **Choose Appropriate Models**: Use simpler models for basic tasks
2. **Optimize Prompts**: Shorter, more focused prompts cost less
3. **Batch Requests**: Combine multiple requests when possible
4. **Monitor Usage**: Track costs to optimize spending

## Model Discovery

### Finding Available Models

You can discover available models through:

1. **DTN Explorer**: Check the model dashboard
2. **Network Queries**: Query the network for supported models
3. **Documentation**: Refer to official model lists

### Model Capabilities

Each model has specific capabilities:

```solidity
struct ModelInfo {
    string name;
    string[] supportedAPIs;
    uint256 baseFeePerByte;
    uint256 maxInputSize;
    uint256 maxOutputSize;
    bool supportsImages;
    bool supportsCode;
}
```

## Best Practices

### 1. Model Selection

- **Start Simple**: Use basic models for proof of concepts
- **Scale Up**: Move to advanced models as needed
- **Cost-Benefit**: Balance quality vs. cost

### 2. API Usage

- **Use Appropriate APIs**: Match API to your use case
- **Handle Responses**: Different APIs return different data formats
- **Error Handling**: Models may fail or return unexpected results

### 3. Fee Management

- **Set Reasonable Fees**: Too low fees may cause requests to be ignored
- **Monitor Costs**: Track spending across different models
- **Optimize Usage**: Use the most cost-effective model for your needs

## Common Issues

### "Model not supported" Error

**Cause**: Using a model ID that doesn't exist on the network
**Solution**: Verify model ID and check network documentation

### "Insufficient fee" Error

**Cause**: Fee too low for the requested model
**Solution**: Increase fee or use a different model

### "API not supported" Error

**Cause**: Requesting an API that the model doesn't support
**Solution**: Check model capabilities and use appropriate API

## Next Steps

- [DTN Routing](dtn-routing.md) - Learn about routing options
- [Basic AI Call Example](../examples/basic-ai-call.md) - See practical model usage
- [Image Generation Example](../examples/image-generation.md) - Work with image models
- [API Reference](../api/interfaces.md) - Complete API documentation 