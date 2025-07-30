# Deep Trust Network Software Development Kit

This repository is the set of smart contracts to be 

## Installation

```
$ npm i --save @deeptrust/contracts
```

## What will this install?

You will have access to the base and helper contracts to be used with DTN network.

- with-dtn-ai.sol
- with-dtn-ai-upgradeable.sol
- idtn-ai.sol
- dtn-defaults.sol

## Step by step guideline to use DTN AI

To utilize AI functionality in your dApp, you need to understand three concepts:

- **AI Session**: Sessions are used to manage payment for AI requests the services. It works with USDT. To start a session, you need to first send some tokens to the `ai.feeTarget()`, and then call `ai.startUserSession();` That's all.
- **AI Models and APIs**: You need to select a model for your request. Each model, may support a different API. Different models may cost different per byte. You can find supported models and their APIs in the model dashboard of DTN explorer. In future sections we will give some examples.
- **DTN Routing**: Routing is about your trust expectation. DTN is very flexible in this regards. You need to choose a trust namespace based on your requirements. Two common use-cases are the default DTN network trust namesapce: `system.trust.dtn` which is a set of staked nodes. Or your own proprietary nodes: `node.mynode.node1`. Direct nodes routing can be useful for testing, or custom usecases. We will come back to this a bit later.
- **DTN Callback**: Every request needs two callbacks. First for success, and second for failure. Call back functions have the following syntax - `function myCallBack(bytes32 requestId) external onlyDtn { ... }`

## Example


Following is an example that shows how to use DTN contracts.


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
    event Request(bytes32 requestId, string[] prompt_lines, bytes extraParams);
    event Result(bytes32 requestId, IDtnAi.ResponseStatus status, string message, string result);
    event Error(bytes32 requestId);

    string public result;
    string public error;
    uint256 public sessionId;
    bytes32 public requestId;
    string public ipfsCid;
    
    constructor(address ai) {
        setAi(ai);
    }

    function doCallAi(string memory prompt, string memory node, string memory model) public payable {
        // Prompts are usually multiple lines. They will be concatenated in multiple lines.
        // They also provide parameterization. You can include positioned arguments, with their relevant type in the prompt.
        // Then you need to provide the extraParams, as the encoded value of these positional arguments. 
        // Note that if the provided arguments are not exact match, your request will be rejected and failure callback will be called.

        string[] memory prompt_lines = new string[](2);
        prompt_lines[0] = "This is metadata - {0:uint8} and {1:address} -. Ignore the metadata and answer the next question:";
        prompt_lines[1] = prompt;
        bytes memory extraParams = abi.encode(26, address(this)); // These are the extra parmeters to the prompt's line[0]
        doCallAiDetailed(prompt_lines, extraParams, node, model);
    }

    function doCallAiDetailed(string[] memory prompt_lines, bytes memory extraParamsEncoded, string memory node, string memory model) public payable {
        if (sessionId == 0) {
            restartSession(); // Requests need a valid session ID. The contract starting the session will be it's owner
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

    function doCallAiImage(
        string[] memory prompt_lines, bytes memory extraParamsEncoded, string memory node, string memory model, uint64 width, uint64 height
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

    function restartSession() public {
        if (sessionId != 0) {
            ai.closeUserSession(sessionId); // Unused funds will be refunded when we close the session
        }
        uint amount = IERC20(ai.feeToken()).balanceOf(address(this)); // Use what we have to start a session
        require(amount > 0, "Not enough tokens to start a session");
        IERC20( ai.feeToken() ).safeTransfer(ai.feeTarget(), amount);
        sessionId = ai.startUserSession();
    }

    function callback(bytes32 _requestId) external onlyDtn {
        // NOTE: Callback must use the `onlyDtn` modifier to make sure only DTN contracts are allowed to call it
        // otherwise this function can be abused
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = ai.fetchResponse(_requestId);

        // You should know what the expected return type is and you need to parse the return type (always encoded as bytes) to the
        // expected type. If you expect an IPFS cid because your request had IPFS type, parse the result into string.
        result = abi.decode(response, (string));
        emit Result(_requestId, status, message, result);
    }

    function callbackIpfs(bytes32 _requestId) external onlyDtn {
        (IDtnAi.ResponseStatus status, string memory message, bytes memory response) = ai.fetchResponse(_requestId);
        ipfsCid = abi.decode(response, (string));
        emit Result(_requestId, status, message, ipfsCid);
    }

    function aiError(bytes32 _requestId) external onlyDtn {
        (, string memory message, ) = ai.fetchResponse(_requestId);
        error = message;
        emit Error(_requestId);
    }
}
```


# Tests

You can test your contracts functionality (unit tests) by using the provided `MockDtnAi.sol`

1. Deploy the mock AI in your test
2. Use it as the Dtn Router (`WithDtnAi.setAi`)
3. Inspect the created request by using `getRequest`
4. Mock respond to the request by: `mockAi.respondSuccess` or `mockAi.respondError`
