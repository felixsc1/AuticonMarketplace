// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/token/ERC721/IERC721.sol";
import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.4.2/contracts/access/Ownable.sol";
import "smartcontractkit/chainlink@1.0.1/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MarketPlace is Ownable {
    uint256 private _listingId;
    uint256 public salesTax;
    mapping(uint256 => Listing) public _listings;
    // Functionality to allow tokens for payment, by providing their address, symbol, and price feed.
    mapping(string => address) public tokenSymbolAddressMapping;
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

    event NewAllowedToken(string symbol, address tokenAddress);

    event Cancel(uint256 listingId, address seller);

    // AutiCoin is added in constructor
    constructor(
        address _nativePriceFeed,
        address _autiCoin,
        uint256 _salesTax
    ) {
        nativePriceFeed = _nativePriceFeed; // ETH or MATIC
        tokenSymbolAddressMapping["AC"] = _autiCoin;
        salesTax = _salesTax;
    }

    /*
        Functions related to tokens for payment
        Mostly based on this tutorial project: https://github.com/felixsc1/defi-stake-yield-brownie
    */

    function addAllowedToken(
        string memory symbol,
        address _token,
        address _priceFeed
    ) public onlyOwner {
        tokenSymbolAddressMapping[symbol] = _token;
        tokenPriceFeedMapping[_token] = _priceFeed;

        emit NewAllowedToken(symbol, _token);
    }

    function tokenIsAllowed(string memory symbol) public view returns (bool) {
        // since by default non-existant entry contains a 0.
        return tokenSymbolAddressMapping[symbol] != address(0);
    }

    function setSalesTax(uint256 salesTaxPercentage) public onlyOwner {
        // provide amount in percentage (e.g. 10 for 10%) to be subtracted from every payment and sent to owner.
        salesTax = salesTaxPercentage;
    }

    // can be called to convert any token to USD
    // when providing second _token argument, returns ERC20 price
    function getTokenValue(uint256 amount, string memory symbol)
        public
        view
        returns (uint256)
    {
        // using chainlink price feeds, the addresses of which were set above
        require(tokenIsAllowed(symbol), "This token is not accepted");
        address priceFeedAddress = tokenPriceFeedMapping[
            tokenSymbolAddressMapping[symbol]
        ];
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
        require(_paymentInUSD >= listing.priceUSD, "Insufficient payment");

        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        uint256 eth_price = USDtoETH(listing.priceUSD);

        // if there is a sales tax, send that percentage of the price to the owner of this contract.
        uint256 salesFee = (eth_price / 100) * salesTax;
        payable(owner()).transfer(salesFee);

        payable(listing.seller).transfer(eth_price - salesFee);
        // reimbursing any excess payment.
        payable(msg.sender).transfer(msg.value - eth_price);

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
    function buyOfferedItem(uint256 listingId, string memory symbol) external {
        Listing storage listing = _listings[listingId];

        require(msg.sender != listing.seller, "Seller cannot be buyer");
        require(
            listing.status == ListingStatus.Active,
            "Listing is not active"
        );

        uint256 _valueInToken;
        // solidity doesnt allow string comparisons, workaround is to use hash (see https://soliditytips.com/articles/compare-strings-solidity/):
        if (
            keccak256(abi.encodePacked(symbol)) ==
            keccak256(abi.encodePacked("AC"))
        ) {
            // here we set AutiCoin equal to USD. Could add a setter function to change this
            _valueInToken = listing.priceUSD;
        } else {
            require(tokenIsAllowed(symbol), "This token is not accepted");
            // Convert listing price to desired token
            _valueInToken = getTokenValue(listing.priceUSD, symbol);
        }

        // in case there is a sales tax:
        uint256 salesFee = (_valueInToken / 100) * salesTax;

        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenId
        );

        IERC20(tokenSymbolAddressMapping[symbol]).transferFrom(
            msg.sender,
            payable(listing.seller),
            _valueInToken - salesFee
        );

        IERC20(tokenSymbolAddressMapping[symbol]).transferFrom(
            msg.sender,
            payable(owner()),
            salesFee
        );

        listing.status = ListingStatus.Sold;

        emit Sale(
            listingId,
            msg.sender,
            listing.token,
            listing.tokenId,
            listing.priceUSD
        );
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
