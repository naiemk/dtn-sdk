// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDtnAi} from "./idtn-ai.sol";

/**
 * @title MockDtnAi
 * @notice Mock implementation of IDtnAi for testing purposes
 */
contract MockDtnAi is IDtnAi {
    // State variables
    address public feeToken;
    address public feeTarget;
    uint256 private sessionCounter;
    uint256 private requestCounter;
    
    // Mappings to store data
    mapping(uint256 => bool) public activeSessions;
    mapping(bytes32 => DtnRequest) public requests;
    mapping(bytes32 => CallBack) public callbacks;
    mapping(bytes32 => Response) public responses;
    mapping(string => bytes32) public modelIds;
    
    // Events for tracking
    event RequestRecorded(bytes32 indexed requestId, uint256 sessionId, bytes32 modelId);
    event ResponseSuccess(bytes32 indexed requestId, bytes response);
    event ResponseFailure(bytes32 indexed requestId, string message);
    event CallbackExecuted(bytes32 indexed requestId, bool success);

    constructor(address _feeToken, address _feeTarget) {
        feeToken = _feeToken;
        feeTarget = _feeTarget;
        sessionCounter = 1;
        requestCounter = 1;
    }

    /**
     * @notice Mock implementation of modelId
     */
    function modelId(string memory modelName) external view override returns (bytes32) {
        return modelIds[modelName];
    }

    /**
     * @notice Set a model ID for testing
     */
    function setModelId(string memory modelName, bytes32 id) external {
        modelIds[modelName] = id;
    }

    /**
     * @notice Starts a new user session
     */
    function startUserSession() external override returns (uint256 sessionId) {
        sessionId = sessionCounter++;
        activeSessions[sessionId] = true;
        return sessionId;
    }

    /**
     * @notice Closes an active user session
     */
    function closeUserSession(uint256 sessionId) external override {
        require(activeSessions[sessionId], "Session not active");
        activeSessions[sessionId] = false;
    }

    /**
     * @notice Records the request in a mapping and returns a request ID
     */
    function request(
        uint256 sessionId,
        bytes32 modelId,
        IDtnAi.DtnRouting memory routingSystem,
        IDtnAi.DtnRequest memory dtnRequest,
        IDtnAi.CallBack memory callback,
        address user,
        uint256 callbackGas
    ) external payable override returns (bytes32 requestId) {
        require(activeSessions[sessionId], "Session not active");
        
        requestId = bytes32(requestCounter++);
        
        // Record the request
        requests[requestId] = dtnRequest;
        callbacks[requestId] = callback;
        
        emit RequestRecorded(requestId, sessionId, modelId);
        
        return requestId;
    }

    /**
     * @notice Fetches the response from the last AI request
     */
    function fetchResponse(bytes32 requestId) external view override returns (
        ResponseStatus status,
        string memory message,
        bytes memory response
    ) {
        Response storage resp = responses[requestId];
        return (resp.status, resp.message, resp.response);
    }

    /**
     * @notice Responds to an AI request (internal function)
     */
    function respondToRequest(
        bytes32 requestId,
        ResponseStatus status,
        string memory message,
        bytes memory response,
        bytes32 nodeId,
        uint256 requestSize,
        uint256 responseSize
    ) external override {
        // This is a mock, so we'll allow anyone to call this
        responses[requestId] = Response({
            status: status,
            message: message,
            response: response,
            nodeId: nodeId,
            timestamp: block.timestamp
        });
    }

    /**
     * @notice Mock function to respond with success
     */
    function respondSuccess(bytes32 requestId, bytes memory value, uint256 fee) external {
        require(requests[requestId].call.length > 0, "Request not found");
        
        // Store the response
        responses[requestId] = Response({
            status: ResponseStatus.SUCCESS,
            message: "Success",
            response: value,
            nodeId: bytes32(0),
            timestamp: block.timestamp
        });
        
        emit ResponseSuccess(requestId, value);
        
        // Execute callback if provided
        CallBack storage callback = callbacks[requestId];
        if (callback.target != address(0) && callback.success != bytes4(0)) {
            (bool success, ) = callback.target.call(
                abi.encodeWithSelector(callback.success, requestId, value)
            );
            emit CallbackExecuted(requestId, success);
        }
    }

    /**
     * @notice Mock function to respond with failure
     */
    function respondFailure(bytes32 requestId, string memory message) external {
        require(requests[requestId].call.length > 0, "Request not found");
        
        // Store the response
        responses[requestId] = Response({
            status: ResponseStatus.FAILURE,
            message: message,
            response: "",
            nodeId: bytes32(0),
            timestamp: block.timestamp
        });
        
        emit ResponseFailure(requestId, message);
        
        // Execute callback if provided
        CallBack storage callback = callbacks[requestId];
        if (callback.target != address(0) && callback.failure != bytes4(0)) {
            (bool success, ) = callback.target.call(
                abi.encodeWithSelector(callback.failure, requestId, message)
            );
            emit CallbackExecuted(requestId, success);
        }
    }

    /**
     * @notice Get request details
     */
    function getRequest(bytes32 requestId) external view returns (DtnRequest memory) {
        return requests[requestId];
    }

    /**
     * @notice Get callback details
     */
    function getCallback(bytes32 requestId) external view returns (CallBack memory) {
        return callbacks[requestId];
    }

    /**
     * @notice Get response details
     */
    function getResponse(bytes32 requestId) external view returns (Response memory) {
        return responses[requestId];
    }

    /**
     * @notice Check if session is active
     */
    function isSessionActive(uint256 sessionId) external view returns (bool) {
        return activeSessions[sessionId];
    }

    /**
     * @notice Reset the mock contract state
     */
    function reset() external {
        sessionCounter = 1;
        requestCounter = 1;
    }
} 