// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RWATnft is ERC721URIStorage, Ownable {
    uint256 public totalTokens;
    uint256 public tokenPrice;
    uint256 private currentTokenId;

    constructor() ERC721("RealWorldAssetTokens", "RWAT") Ownable(msg.sender) {
        currentTokenId = 1; // Initialize token ID
    }

    function mint(address _to, string calldata _uri, uint256 _totalTokens, uint256 _tokenPrice) external onlyOwner {
        totalTokens = _totalTokens;
        tokenPrice = _tokenPrice;

        for (uint256 i = 0; i < totalTokens; i++) {
            _mint(_to, currentTokenId);
            _setTokenURI(currentTokenId, _uri);
            currentTokenId++;
        }
    }
}
