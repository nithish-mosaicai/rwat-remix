//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Chainlink, ChainlinkClient} from "@chainlink/contracts@1.1.1/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@1.1.1/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts@1.1.1/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract getPropertyDetails is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    bytes32 private jobId1;
    bytes32 private jobId2;
    uint256 private fee;

    uint256 public lotSize;
    uint256 public totalPrice;
    uint256 public taxAssessedValue;
    string public location;

    event RequestMultipleFulfilled(
        bytes32 indexed requestId,
        uint256 lotSize,
        uint256 totalPrice,
        uint256 taxAssessedValue
    );

    constructor() ConfirmedOwner(msg.sender) {
        _setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        _setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId1 = "53f9755920cd451a8fe46f5087468395";
        jobId2 = "7d80a6386ef543a3abb52817f6707e3b";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function requestMultipleParameters() public {
        Chainlink.Request memory req = _buildChainlinkRequest(
            jobId1,
            address(this),
            this.fulfillMultipleParameters.selector
        );
        req._add(
            "urlBTC",
            "https://geniebackbone.azurewebsites.net/api/properties/demo"
        );
        req._add("pathBTC", "data,lotSize");
        req._add(
            "urlUSD",
            "https://geniebackbone.azurewebsites.net/api/properties/demo"
        );
        req._add("pathUSD", "data,totalPrice");
        req._add(
            "urlEUR",
            "https://geniebackbone.azurewebsites.net/api/properties/demo"
        );
        req._add("pathEUR", "data,taxAssessedValue");
        _sendChainlinkRequest(req, fee);
    }

    function fulfillMultipleParameters(
        bytes32 requestId,
        uint256 lotSizeResponse,
        uint256 totalPriceResponse,
        uint256 taxAssessedValueResponse
    ) public recordChainlinkFulfillment(requestId) {
        emit RequestMultipleFulfilled(
            requestId,
            lotSizeResponse,
            totalPriceResponse,
            taxAssessedValueResponse
        );
        lotSize = lotSizeResponse / 10**5;
        totalPrice = totalPriceResponse / 10**5;
        taxAssessedValue = taxAssessedValueResponse / 10**5;
    }

    function requestVolumeData() public returns (bytes32 requestId) {
        Chainlink.Request memory req = _buildChainlinkRequest(
            jobId2,
            address(this),
            this.fulfill.selector
        );

        req._add(
            "get",
            "https://geniebackbone.azurewebsites.net/api/properties/demo"
        );
        req._add("path", "data,location");

        return _sendChainlinkRequest(req, fee);
    }
    function fulfill(
        bytes32 _requestId,
        string memory locationResponse
    ) public recordChainlinkFulfillment(_requestId) {
        location = locationResponse;
    }


    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}