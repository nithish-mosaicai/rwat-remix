// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SecurePropertyTokens.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SecondaryMarket is Ownable {
    SecurePropertyToken public propertyToken;
    IERC20 public usdcToken;

    struct SaleListing {
        uint256 tokenId;
        address seller;
        uint256 price;
    }

    mapping(uint256 => SaleListing) public saleListings;

    event TokenListedForSale(uint256 indexed tokenId, address indexed seller, uint256 price);
    event TokenPurchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

    constructor(address _propertyTokenAddress, address _usdcTokenAddress) Ownable(msg.sender) {
        propertyToken = SecurePropertyToken(_propertyTokenAddress);
        usdcToken = IERC20(_usdcTokenAddress);
    }

    function listTokenForSale(uint256 _tokenId, uint256 _price) external {
        require(propertyToken.ownerOf(_tokenId) == msg.sender, "You are not the owner of this token");
        require(_price > 0, "Price must be greater than zero");

        saleListings[_tokenId] = SaleListing({
            tokenId: _tokenId,
            seller: msg.sender,
            price: _price * 10**6
        });

        emit TokenListedForSale(_tokenId, msg.sender, _price);
    }

    function buyListedToken(uint256 _tokenId) external {
        SaleListing memory listing = saleListings[_tokenId];
        
        require(listing.price > 0, "This token is not for sale");
        require(usdcToken.balanceOf(msg.sender) >= listing.price, "Insufficient USDC balance");
        require(usdcToken.allowance(msg.sender, address(this)) >= listing.price, "USDC allowance too low");
        require(listing.seller != address(0), "Invalid seller address");

        address seller = listing.seller;
        uint256 price = listing.price;

        // Transfer USDC from buyer to the seller
        usdcToken.transferFrom(msg.sender, seller, price);

        // Transfer the token from seller to buyer
        propertyToken.transferFrom(seller, msg.sender, _tokenId);

        // Remove the listing
        delete saleListings[_tokenId];

        emit TokenPurchased(_tokenId, msg.sender, seller, price);
    }

    function getSaleListings() external view returns (SaleListing[] memory) {
        uint256 totalTokens = propertyToken.totalTokens();
        uint256 count = 0;

        for (uint256 i = 1; i <= totalTokens; i++) {
            if (saleListings[i].price > 0) {
                count++;
            }
        }

        SaleListing[] memory listings = new SaleListing[](count);
        uint256 index = 0;

        for (uint256 i = 1; i <= totalTokens; i++) {
            if (saleListings[i].price > 0) {
                listings[index] = saleListings[i];
                index++;
            }
        }

        return listings;
    }
}
