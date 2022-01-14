// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/token/ERC721/IERC721.sol";
import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/access/Ownable.sol";
import "smartcontractkit/chainlink@1.0.1/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MarketPlace is Ownable {
    uint256 private _listingId;
    mapping(uint256 => Listing) private _listings;
    // Functionality to allow tokens for payment, by providing their address and price feed.
    address[] public allowedTokens;
    mapping(address => address) public tokenPriceFeedMapping;
    address public nativePriceFeed;

    enum ListingStatus {
        Active,
        Sold,
        Cancelled
    }

    struct Listing {
        ListingStatus status;
        address seller;
        address token;
        uint256 tokenId;
        uint256 priceUSD;
    }

    /*
        Functions related to tokens for payment
        Mostly based on this tutorial project: https://github.com/felixsc1/defi-stake-yield-brownie
    */

    function addAllowedToken(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function setPriceFeedContract(address _token, address _priceFeed)
        public
        onlyOwner
    {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    function setPriceFeedContract_nativecurrency(address _priceFeed)
        public
        onlyOwner
    {
        nativePriceFeed = _priceFeed;
    }

    function tokenIsAllowed(address _token) public returns (bool) {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        return false;
    }

    // can be called to convert any token to USD
    function getTokenValue(uint256 amount, address _token)
        public
        view
        returns (uint256)
    {
        // using chainlink price feeds, the addresses of which were set above
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals());
        // amount: int with 18 decimals, price: x decimals
        // product will be 18*x decimals, so we divide by x to get back to 18.
        return ((amount * uint256(price)) / (10**decimals));
    }

    // Same function without _token argument returns USD price for native token
    // https://docs.soliditylang.org/en/v0.4.21/contracts.html#function-overloading
    function getTokenValue(uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            nativePriceFeed
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals());
        return ((amount * uint256(price)) / (10**decimals));
    }

    /*
        Market place functions, for creating and buying offers.
        This part is mostly based on https://github.com/felixsc1/NFT-marketplace
    */

    function createNewOffer(
        address token,
        uint256 tokenId,
        uint256 priceUSD
    ) external {
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);

        Listing memory listing = Listing(
            ListingStatus.Active,
            msg.sender,
            token,
            tokenId,
            priceUSD
        );

        _listingId++;
        _listings[_listingId] = listing;
    }

    // This function comes twice, here for payment in native currency
    function buyListingItem(uint256 listingId, uint256 _amount)
        external
        payable
    {
        Listing storage listing = _listings[listingId];

        require(msg.sender != listing.seller, "Seller cannot be buyer");
        require(
            listing.status == ListingStatus.Active,
            "Listing is not active"
        );

        // Payment check in USD
        uint256 _valueInUSD = getTokenValue(msg.value);
        // todo: return the values in error message so that buyer knows how much to add
        require(_valueInUSD >= listing.priceUSD, "Insufficient payment");

        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );
        payable(listing.seller).transfer(msg.value);

        listing.status = ListingStatus.Sold;
    }

    // Same function when providing ERC20 _token address
    function buyListingItem(
        uint256 listingId,
        address _token,
        uint256 _amount
    ) external payable {
        Listing storage listing = _listings[listingId];

        require(msg.sender != listing.seller, "Seller cannot be buyer");
        require(
            listing.status == ListingStatus.Active,
            "Listing is not active"
        );
        require(tokenIsAllowed(_token), "This token is not accepted");

        // Payment check in USD
        uint256 _valueInUSD = getTokenValue(_amount, _token);
        require(_valueInUSD >= listing.priceUSD, "Insufficient payment");

        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        // check, does buyer have to approve payment?
        IERC20(_token).transferFrom(
            msg.sender,
            payable(listing.seller),
            _amount
        );

        listing.status = ListingStatus.Sold;
    }
}
