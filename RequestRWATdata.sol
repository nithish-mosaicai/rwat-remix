// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FunctionsClient} from "@chainlink/contracts@1.1.1/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@1.1.1/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts@1.1.1/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
contract RequestRWATdata is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        string location,
        uint256 areaSquareFeet,
        uint256 price,
        uint256 taxAssessedValue,
        bytes response,
        bytes err
    );

    // Router address - Hardcoded for Sepolia
    // Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    // JavaScript source code
    string source = 
        "const { ethers } = await import('npm:ethers@6.10.0');"
        "const abiCoder = ethers.AbiCoder.defaultAbiCoder();"
        "const apiResponse = await Functions.makeHttpRequest({"
        "    url: 'https://geniebackbone.azurewebsites.net/api/properties/demo'"
        "});"
        "const { data } = apiResponse.data;"
        "const location = data.location;"
        "const lotSize = Number(data.lotSize);"
        "const totalPrice = Number(data.totalPrice);"
        "const taxAssessedValue = Number(data.taxAssessedValue);"
        "const encoded = abiCoder.encode([`string`, `uint256`, `uint256`, `uint256`], [location, lotSize, totalPrice, taxAssessedValue]);"
        "return ethers.getBytes(encoded);";

    uint32 gasLimit = 300000;

    // donID - Hardcoded for Sepolia
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID =
        0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    // State variable to store the returned property information
    string public location;
    uint256 public lotSize;
    uint256 public totalPrice;
    uint256 public taxAssessedValue;

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor() FunctionsClient(router) ConfirmedOwner(msg.sender) {}
     
    function sendRequest(
        uint64 subscriptionId
    ) external onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }
        (location, lotSize, totalPrice, taxAssessedValue) = abi.decode(response, (string, uint256, uint256, uint256));
        s_lastError = err;
        emit Response(requestId, location, lotSize, totalPrice, taxAssessedValue, s_lastResponse, s_lastError);
    }
}
