// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/token/ERC721/IERC721.sol";
import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/access/Ownable.sol";
import "smartcontractkit/chainlink@1.0.1/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MarketPlace_old is Ownable {
    uint256 private _listingId;
    mapping(uint256 => Listing) private _listings;
    // Functionality to allow tokens for payment, by providing their address and price feed.
    address[] public allowedTokens;
    mapping(address => address) public tokenPriceFeedMapping;
    address public nativePriceFeed;
    address public autiCoinAddress;

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

    event Listed(
        uint256 listingId,
        address seller,
        address token,
        uint256 tokenId,
        uint256 priceUSD
    );

    event Sale(
        uint256 listingId,
        address buyer,
        address token,
        uint256 tokenId,
        uint256 priceUSD
    );

    event Cancel(uint256 listingId, address seller);

    // AutiCoin is added in constructor
    constructor(address _nativePriceFeed, address _autiCoin) {
        nativePriceFeed = _nativePriceFeed; // ETH or MATIC
        autiCoinAddress = _autiCoin;
    }

    /*
        Functions related to tokens for payment
        Mostly based on this tutorial project: https://github.com/felixsc1/defi-stake-yield-brownie
    */

    function addAllowedToken(address _token, address _priceFeed)
        public
        onlyOwner
    {
        allowedTokens.push(_token);
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    // loop through mapping of allowed tokens, return true or false
    function tokenIsAllowed(address _token) public view returns (bool) {
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
    // when providing second _token argument, returns ERC20 price
    function getTokenValue(uint256 amount, address _token)
        public
        view
        returns (uint256)
    {
        // using chainlink price feeds, the addresses of which were set above
        require(tokenIsAllowed(_token), "This token is not accepted");
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
        uint256 decimals = uint256(priceFeed.decimals()); // needed in a calculation below
        return ((amount * uint256(price)) / (10**decimals));
    }

    // the oppsite: enter any USD value to get ETH (for buyer who wants to pay with ETH)
    function USDtoETH(uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            nativePriceFeed
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals()); // needed in a calculation below
        return ((amount / uint256(price)) * (10**decimals));
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

        emit Listed(_listingId, msg.sender, token, tokenId, priceUSD);
    }

    function showOffer(uint256 listingId) public view returns (Listing memory) {
        return _listings[listingId];
    }

    // This function comes twice, here for payment in native currency
    function buyOfferedItem(uint256 listingId) external payable {
        Listing storage listing = _listings[listingId];

        require(msg.sender != listing.seller, "Seller cannot be buyer");
        require(
            listing.status == ListingStatus.Active,
            "Listing is not active"
        );

        uint256 _paymentInUSD = getTokenValue(msg.value);
        // todo: return the values in error message so that buyer knows how much to add
        // see https://stackoverflow.com/questions/47129173/how-to-convert-uint-to-string-in-solidity
        require(_paymentInUSD >= listing.priceUSD, "Insufficient payment");

        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );
        // todo: how to only transfer listing.priceUSD? or return excess payment to sender...
        payable(listing.seller).transfer(msg.value);

        listing.status = ListingStatus.Sold;

        emit Sale(
            listingId,
            msg.sender,
            listing.token,
            listing.tokenId,
            listing.priceUSD
        );
    }

    // Same function when providing ERC20 _token address
    function buyOfferedItem(uint256 listingId, address _token)
        external
        payable
    {
        Listing storage listing = _listings[listingId];

        require(msg.sender != listing.seller, "Seller cannot be buyer");
        require(
            listing.status == ListingStatus.Active,
            "Listing is not active"
        );

        uint256 _valueInToken;
        if (_token == autiCoinAddress) {
            // here we set AutiCoin equal to USD. Could add a setter function to change this
            _valueInToken = listing.priceUSD;
        } else {
            require(tokenIsAllowed(_token), "This token is not accepted");
            // Convert listing price to desired token
            _valueInToken = getTokenValue(listing.priceUSD, _token);
        }

        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        IERC20(_token).transferFrom(
            msg.sender,
            payable(listing.seller),
            _valueInToken
        );

        listing.status = ListingStatus.Sold;
    }

    function cancel(uint256 listingId) public {
        Listing storage listing = _listings[listingId];
        require(listing.seller == msg.sender, "You are not the seller");
        require(
            listing.status == ListingStatus.Active,
            "Listing is not active"
        );

        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );
        listing.status = ListingStatus.Cancelled;

        emit Cancel(listingId, listing.seller);
    }
}
