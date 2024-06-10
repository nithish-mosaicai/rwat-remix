// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract issueRWAT is ERC721URIStorage, Ownable {
    struct Property {
        string location;
        uint256 lotSize;
        uint256 totalPrice;
        uint256 taxAssessedValue;
    }

    // Data from ATTOM API
    Property public property = Property({
        location: "629 HARLEM AVE # 1, FOREST PARK, IL 60130",
        lotSize: 3564,
        totalPrice: 290000,
        taxAssessedValue: 24062
    });

    bool public propertyTokenized = false;
    uint256 public tokenPrice; // price in wei
    uint256 public totalTokens;
    uint256 public issuedTokens = 0;
    mapping(uint256 => bool) public soldTokens;

    constructor() ERC721("RealWorldAssetTokens", "RWAT") Ownable(msg.sender) {}

    event TokensIssued(uint256 totalTokens, uint256 tokenPrice);

    function mint(address _to, uint256 _tokenId, string calldata _uri) external onlyOwner {
        _mint(_to, _tokenId);
        _setTokenURI(_tokenId, _uri);
    }

    function issueTokens(uint256 _totalTokens, uint256 _tokenPrice, string calldata _uri) external onlyOwner {
        require(!propertyTokenized, "Tokens have already been issued");

        totalTokens = _totalTokens;
        tokenPrice = _tokenPrice;
        propertyTokenized = true;

        for (uint256 i = 1; i <= _totalTokens; i++) {
            _mint(msg.sender, i);
        }
        issuedTokens = _totalTokens;

        emit TokensIssued(_totalTokens, _tokenPrice);
    }
}

