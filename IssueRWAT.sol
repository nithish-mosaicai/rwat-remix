// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FunctionsClient} from "@chainlink/contracts@1.1.1/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@1.1.1/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts@1.1.1/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract IssueRWAT is FunctionsClient, Ownable, ERC721URIStorage{
    using FunctionsRequest for FunctionsRequest.Request;

    struct Property {
        string location;
        uint256 lotSize;
        uint256 totalPrice;
        uint256 taxAssessedValue;
    }
    Property public property;

    bool public propertyTokenized = false;
    int public usdcValue;
    uint256 public tokenPriceUSD; // price in USD
    uint256 public tokenPriceUSDC; // price in USDC multiplied with 10^6 => 100 USDC -> 100000000 = 100.000000
    uint256 public totalTokens;
    uint256 public issuedTokens = 0;

    bytes32 internal s_lastRequestId;
    bytes internal s_lastResponse;
    bytes internal s_lastError;

    error UnexpectedRequestID(bytes32 requestId);

    event Response(
        bytes32 indexed requestId,
        string location,
        uint256 areaSquareFeet,
        uint256 price,
        uint256 taxAssessedValue,
        bytes response,
        bytes err
    );
    event TokensIssued(uint256 totalTokens, uint256 tokenPrice);

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

    uint32 immutable gasLimit = 300000;

    // Router address - Hardcoded for Sepolia
    address immutable router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    // donID - Hardcoded for Sepolia
    bytes32 immutable donID = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Sepolia Testnet
     * Aggregator: USDC/USD
     * Address: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
     */

    constructor() FunctionsClient(router) Ownable(msg.sender) ERC721("RealWorldAssetToken", "RWAT"){
        priceFeed = AggregatorV3Interface(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E);
    }

    // ==== Retrieval of external API data using Chainlink Functions ====

    // send request to chainlnk with the JS snippet of api request     
    function sendRequest(
        uint64 subscriptionId
    ) external onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);

        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
    }

    // receive the data & decode it to store on local property structure
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }
        (property.location, property.lotSize, property.totalPrice, property.taxAssessedValue) = abi.decode(response, (string, uint256, uint256, uint256));
        s_lastError = err;
        emit Response(requestId, property.location, property.lotSize, property.totalPrice, property.taxAssessedValue, s_lastResponse, s_lastError);
    }

    // ==== Retrieval of USDC value =====

    function getLatestPrice() public{
        (
            , 
            int price,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        usdcValue = price;
    }


    // ==== Issuing/Minting RWAT Token on ERC 721 standards ====

    // issuing tokens
    function issueTokens(uint256 _totalTokens, uint256 _tokenPriceUSD) external onlyOwner {
        require(!propertyTokenized, "Tokens have already been issued");

        totalTokens = _totalTokens;
        tokenPriceUSD = _tokenPriceUSD;
        tokenPriceUSDC = ((tokenPriceUSD * uint256(usdcValue)) / 10**8) * 10**6;
        propertyTokenized = true;

        string memory finalTokenUri = createTokenUri();

        for (uint256 i = 1; i <= _totalTokens; i++) {
            _mint(msg.sender, i);
            _setTokenURI(i, finalTokenUri);
        }
        issuedTokens = _totalTokens;

        emit TokensIssued(_totalTokens, _tokenPriceUSD);
    }

    // setting metadata for the minted tokens
    function createTokenUri() internal view returns (string memory) {
        string memory json = string(
            abi.encodePacked(
                '{"name": "629 Harlem LLM",',
                '"description": "RWAT for 629 Harlem LLM",',
                '"image": "ipfs://QmYXMF36M4tn4LmuTWjayebobTPsyErwbg94qzLAXqdMGy",',
                '"attributes": [',
                '{"trait_type": "Location","value": "', property.location, '"},',
                '{"trait_type": "Lot Size","value": ', Strings.toString(property.lotSize), '},',
                '{"trait_type": "Total Price","value": ', Strings.toString(property.totalPrice), '},',
                '{"trait_type": "Tax Assessed Value","value": ', Strings.toString(property.taxAssessedValue), '}',
                ']}'
            )
        );

        string memory encodedJson = Base64.encode(bytes(json));
        return string(abi.encodePacked("data:application/json;base64,", encodedJson));
    }

    //updating token price
    function updateTokenPrice(uint256 _tokenPriceUSD) external onlyOwner {
        require(propertyTokenized, "Tokens have not been issued");

        tokenPriceUSD = _tokenPriceUSD;
        tokenPriceUSDC = ((tokenPriceUSD * uint256(usdcValue)) / 10**8) * 10**6;
    }
    
}
