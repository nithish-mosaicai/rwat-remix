// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {RequestRWATdata} from "RequestRWATdata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SecurePropertyToken is ERC721URIStorage, Ownable {
    struct Property {
        string location;
        uint256 lotSize;
        uint256 totalPrice;
        uint256 taxAssessedValue;
    }

    struct RentPaymentDetail {
        address recipient;
        uint256 amount;
    }

    struct Investor {
        address investor;
        uint256 tokenCount;
    }

    Property public property;
    RequestRWATdata public requestRWATdata;

    // External function to initialize property
    function fetchPropertyDetails(address requestRWATdataAddress) external {
        requestRWATdata = RequestRWATdata(requestRWATdataAddress);
        property = Property({
            location: requestRWATdata.location(),
            lotSize: requestRWATdata.lotSize(),
            totalPrice: requestRWATdata.totalPrice(),
            taxAssessedValue: requestRWATdata.taxAssessedValue()
        });
    }

    bool public propertyTokenized = false;
    int public usdcValue;
    uint256 public tokenPriceUSD; // price in USD
    uint256 public tokenPriceUSDC; // price in USDC multiplied with 10^6 => 100 USDC -> 100000000 = 100.000000
    uint256 public totalTokens;
    uint256 public issuedTokens = 0;
    // string public tokenURI = "ipfs://QmUoPYACuFAwAXYy318fma6c89ogyJxCjzDUVBc5g3KR8X";
    mapping(uint256 => bool) public soldTokens;

    address public constant mosaicAccount = 0x05B9E9514Fce6b5d903c7e763429b1D497DE6b3b; //MosaicAI MetaMask Wallet
    // address public constant mosaicAccount = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2; // MosaicTest
    IERC20 public usdcToken = IERC20(0xF31B086459C2cdaC006Feedd9080223964a9cDdB);

    // Hardcoded whitelist and blacklist addresses
    address[] public whitelistedAddresses = [
        0x3762bA161a7ADba9Ee84A8cAFfFE57aa2E13347F, // Investor1
        0x5cA6AAE74E45BD7271aA9eeDE684A047c77cAb53, // Investor2
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, // Investor Test1ß
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db // Investor Test2
    ];
    address[] public blacklistedAddresses = [
        0x27a503629A5354982735D5706286fb4731418aDA, // Investor3
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB // Investor Test3
    ];

    event TokensIssued(uint256 totalTokens, uint256 tokenPriceUSD);
    event TokenPurchased(address indexed buyer, uint256 tokenId, uint256 price);
    event CommissionPaid(address indexed recipient, uint256 amount);
    event PaymentReceived(address indexed recipient, uint256 amount);
    event Refund(address indexed recipient, uint256 amount);
    event RentPayment(address indexed recipient, uint256 amount); // Event for rent payment to token owner

    uint256 public propertyValuation = 2800; //valuation = (w1*29000 + w2*24062) / (w1+w2)

    RentPaymentDetail[] public rentPayments;
    mapping(address => uint256) public tokenOwnership;
    Investor[] public investors;

    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Sepolia Testnet
     * Aggregator: USDC/USD
     * Address: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
     */
    
    constructor() ERC721("RealWorldAssetToken", "RWAT") Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E);
    }
    
    function getLatestPrice() public{
        (
            , 
            int price,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        usdcValue = price;
    }

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

    function updateTokenPrice(uint256 _tokenPriceUSD) external onlyOwner {
        require(propertyTokenized, "Tokens have not been issued");

        tokenPriceUSD = _tokenPriceUSD;
        tokenPriceUSDC = ((tokenPriceUSD * uint256(usdcValue)) / 10**8) * 10**6;
    }

    function getPropertyDetails() external view returns (
        string memory location,
        uint256 lotSize,
        uint256 totalPrice,
        uint256 taxAssessedValue
    ) {
        return (
            property.location,
            property.lotSize,
            property.totalPrice,
            property.taxAssessedValue
        );
    }

    function buyTokens(uint256 _numTokens) external {
        require(propertyTokenized, "Tokens have not been issued");
        require(_numTokens > 0 && _numTokens <= 8, "Number of tokens must be between 1 and 8");
        require(_numTokens <= availableTokens(), "Not enough tokens available");
        require(isWhitelisted(msg.sender), "Address not whitelisted");
        require(!isBlacklisted(msg.sender), "Address blacklisted");

        uint256 totalCost = _numTokens * tokenPriceUSDC;
        require(usdcToken.balanceOf(msg.sender) >= totalCost, "Insufficient USDC balance");
        require(usdcToken.allowance(msg.sender, address(this)) >= totalCost, "USDC allowance too low");

        // Transfer USDC from buyer to the contract
        usdcToken.transferFrom(msg.sender, address(this), totalCost);

        uint256 tokensBought = 0;
        for (uint256 i = 1; i <= totalTokens && tokensBought < _numTokens; i++) {
            if (soldTokens[i]) {
                continue;
            }

            _transfer(owner(), msg.sender, i);
            soldTokens[i] = true;
            tokenOwnership[msg.sender] += 1; // Update token ownership

            // Check if the investor already exists in the array
            bool investorExists = false;
            for (uint256 j = 0; j < investors.length; j++) {
                if (investors[j].investor == msg.sender) {
                    investors[j].tokenCount += 1;
                    investorExists = true;
                    break;
                }
            }

            // If the investor does not exist, add them to the array
            if (!investorExists) {
                investors.push(Investor({
                    investor: msg.sender,
                    tokenCount: 1
                }));
            }

            tokensBought++;

            emit TokenPurchased(msg.sender, i, tokenPriceUSD);
        }

        // Calculate commission and owner payment
        uint256 commission = (totalCost * 2) / 100; // 2% commission
        uint256 ownerPayment = totalCost - commission; // 98% to the owner

        // Transfer the commission to mosaicAccount
        usdcToken.transfer(mosaicAccount, commission);
        emit CommissionPaid(mosaicAccount, commission);

        // Transfer the USDC to the contract owner
        usdcToken.transfer(owner(), ownerPayment);
        emit PaymentReceived(owner(), ownerPayment);
    }

    function availableTokens() public view returns (uint256) {
        uint256 available = 0;
        for (uint256 i = 1; i <= totalTokens; i++) {
            if (ownerOf(i) == address(0) || soldTokens[i]) {
                continue;
            }
            available++;
        }
        return available;
    }

    function getTokenOwners() public view returns (address[] memory owners, uint256[] memory tokenIds) {
        address[] memory _owners = new address[](totalTokens);
        uint256[] memory _tokenIds = new uint256[](totalTokens);
        uint256 count = 0;
        for (uint256 i = 1; i <= totalTokens; i++) {
            if (ownerOf(i) != address(0)) {
                _owners[count] = ownerOf(i);
                _tokenIds[count] = i;
                count++;
            }
        }
        owners = new address[](count);
        tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            owners[i] = _owners[i];
            tokenIds[i] = _tokenIds[i];
        }
    }

    function isWhitelisted(address _address) public view returns (bool) {
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            if (whitelistedAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function isBlacklisted(address _address) public view returns (bool) {
        for (uint256 i = 0; i < blacklistedAddresses.length; i++) {
            if (blacklistedAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function distributeRentIncome() external onlyOwner {
        require(propertyTokenized, "Tokens have not been issued");

        // Calculate rent income per token based on 0.5% of property valuation
        uint256 rentIncomePerToken = (propertyValuation * 5) / 1000;

        uint256 totalDistributed = 0;

        // Get the list of investors
        Investor[] memory investorList = getInvestors();

        for (uint256 i = 0; i < investorList.length; i++) {
            uint256 tokenCount = investorList[i].tokenCount;
            uint256 rentIncome = rentIncomePerToken * tokenCount;
            totalDistributed += rentIncome;
        }

        // Ensure the contract is approved to spend the total USDC
        require(usdcToken.allowance(msg.sender, address(this)) >= totalDistributed, "USDC allowance too low");

        // Transfer the total rent income from the owner to the contract
        usdcToken.transferFrom(msg.sender, address(this), totalDistributed);

        for (uint256 i = 0; i < investorList.length; i++) {
            address tokenOwner = investorList[i].investor;
            uint256 tokenCount = investorList[i].tokenCount;
            uint256 rentIncome = rentIncomePerToken * tokenCount;

            // Transfer the calculated rent income to the token owner in USDC
            usdcToken.transfer(tokenOwner, rentIncome);

            // Store the rent payment details
            rentPayments.push(RentPaymentDetail({
                recipient: tokenOwner,
                amount: rentIncome
            }));
            
            emit RentPayment(tokenOwner, rentIncome);
        }
    }

    function getInvestors() public view returns (Investor[] memory) {
        return investors;
    }

    function isInvestor(address _address) public view returns (bool) {
        for (uint256 i = 0; i < investors.length; i++) {
            if (investors[i].investor == _address) {
                return true;
            }
        }
        return false;
    }
}